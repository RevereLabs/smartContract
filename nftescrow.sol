/**
 * @file nftescrow.sol
 * @author Jackson Ng <jackson@jacksonng.org>
 * @date created 16th Sep 2021
 * @date last modified 18th Sep 2021
 */

//SPDX-License-Identifier: MIT
 
// https://github.com/jacksonng77/NFT-Escrow-Service/blob/main/nftescrow.sol
// https://medium.com/coinmonks/nft-based-escrow-service-business-logic-3dfc5be85a03

pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract nftescrow is IERC721Receiver {
    
    enum ProjectState {newEscrow, nftDeposited, cancelNFT, ethDeposited, canceledBeforeDelivery, deliveryInitiated, delivered}
    event Received(address, uint);

    event ClientCheckpointChanged(uint8);
    event FreelancerCheckpointChanged(uint8);

    event FundsDisbursed(uint8 _from, uint8 _to);

    address payable public sellerAddress;
    address payable public buyerAddress;
    address public nftAddress;
    uint256 tokenID;
    bool buyerCancel = false;
    bool sellerCancel = false;
    ProjectState public projectState;

    struct currentCheckpointsStruct {
        uint8 client;
        uint8 freelancer;

        // smc denotes till which checkpoint have funds been disbursed
        uint8 smc;
    }

    currentCheckpointsStruct currentCheckpoints;



    // percentage of funds to be disbursed at each step.
    // NOTE: You NEED to use cumulative percentages.
    uint8[] checkpoints;

    // IERC20 public token; // Address of token contract
    // address public transferOperator; // Address to manage the Transfers

    constructor(uint8[] memory _checkpoints) payable
    {
        // token = IERC20(_token);
        // transferOperator = msg.sender;
        require(_checkpoints[_checkpoints.length-1]==100);
        sellerAddress = payable(msg.sender);
        projectState = ProjectState.newEscrow;
        checkpoints = _checkpoints;
    }

   	modifier condition(bool _condition) {
		require(_condition);
		_;
	}

	modifier onlySeller() {
		require(msg.sender == sellerAddress);
		_;
	}

	modifier onlyBuyer() {
		require(msg.sender == buyerAddress);
		_;
	}
	
	modifier noDispute(){
	    require(buyerCancel == false && sellerCancel == false);
	    _;
	}
	
	modifier BuyerOrSeller() {
		require(msg.sender == buyerAddress || msg.sender == sellerAddress);
		_;
	}
	
	modifier inProjectState(ProjectState _state) {
		require(projectState == _state);
		_;
	}    

    function getCheckpoints() external view returns (uint8[] memory) {
        return checkpoints;
    }

    function increaseFreelancerCheckpoint() external onlySeller {
        require(currentCheckpoints.freelancer < (checkpoints.length - 1));
        currentCheckpoints.freelancer++;
        emit FreelancerCheckpointChanged(currentCheckpoints.freelancer);
    }

    function setClientCheckpoint() external onlyBuyer {
        require(currentCheckpoints.client < (checkpoints.length - 1));
        currentCheckpoints.client++;
        emit ClientCheckpointChanged(currentCheckpoints.client);    
    }    

    function disburseFunds() public BuyerOrSeller {
        uint8 approvedCheckpoint = currentCheckpoints.client;
        if (currentCheckpoints.freelancer < currentCheckpoints.client) {
            approvedCheckpoint = currentCheckpoints.freelancer;
        }
        if (currentCheckpoints.smc < approvedCheckpoint) {
            uint8 percentageToBeTransferred = checkpoints[approvedCheckpoint] - checkpoints[currentCheckpoints.smc];
            // TODO: Transfer percentageToBeTransferred*totalAmount to freelancer
            emit FundsDisbursed(currentCheckpoints.smc, approvedCheckpoint);
            currentCheckpoints.smc = approvedCheckpoint;
        }
    }


    function balanceofERC20(address TokenAddress) public view returns ( uint256 ){
        return IERC20(TokenAddress).balanceOf(address(this));
    }
    
    function onERC721Received( address operator, address from, uint256 tokenId, bytes calldata data ) public override returns (bytes4) {
        return this.onERC721Received.selector;
    }
    
    function depositNFT(address _NFTAddress, uint256 _TokenID)
        public
        inProjectState(ProjectState.newEscrow)
        onlySeller
    {
        nftAddress = _NFTAddress;
        tokenID = _TokenID;
        ERC721(nftAddress).safeTransferFrom(msg.sender, address(this), tokenID);
        projectState = ProjectState.nftDeposited;
    }
    
    function cancelAtNFT()
        public
        inProjectState(ProjectState.nftDeposited)
        onlySeller
    {
        ERC721(nftAddress).safeTransferFrom(address(this), msg.sender, tokenID);
        projectState = ProjectState.cancelNFT;
    }
  
    function cancelBeforeDelivery(bool _state)
        public
        inProjectState(ProjectState.ethDeposited)
        payable
        BuyerOrSeller
    {
        if (msg.sender == sellerAddress){
            sellerCancel = _state;
        }
        else{
            buyerCancel = _state;
        }
        
        if (sellerCancel == true && buyerCancel == true){
            ERC721(nftAddress).safeTransferFrom(address(this), sellerAddress, tokenID);
            buyerAddress.transfer(address(this).balance);
            projectState = ProjectState.canceledBeforeDelivery;     
        }
    }
    
    function depositETH()
        public
        payable
        // inProjectState(ProjectState.nftDeposited)
    {
        buyerAddress = payable(msg.sender);
        projectState = ProjectState.ethDeposited;
    }
    
    function initiateDelivery()
        public
        inProjectState(ProjectState.ethDeposited)
        onlySeller
        noDispute
    {
        projectState = ProjectState.deliveryInitiated;
    }        
    
    function confirmDelivery()
        public
        payable
        inProjectState(ProjectState.deliveryInitiated)
        onlyBuyer
    {
        ERC721(nftAddress).safeTransferFrom(address(this), buyerAddress, tokenID);
        sellerAddress.transfer(address(this).balance);
        projectState = ProjectState.delivered;
    }
        




    function getBalance()
        public
        view
        returns (uint256 balance)
    {
        return address(this).balance;
    }

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }
} 
