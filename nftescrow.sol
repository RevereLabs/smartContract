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

interface RGCNFTInterface {
    function mint(
        address _to,
        string memory tokenURI_
    ) external;
}
contract nftescrow is IERC721Receiver {
    
    enum ProjectState {newEscrow, nftDeposited, receivedFundsByClient, checkpointingStarted, checkpointsDone, done, cancelledByClient, cancelledByFreelancer}
    event Received(address, uint);

    event ClientCheckpointChanged(uint8);
    event FreelancerCheckpointChanged(uint8);

    event FundsDisbursed(uint8 _from, uint8 _to);

    event ProjectStateChanged(ProjectState _state);

// TODO: why public?
// TODO: token address can change ,rn hardcoded

    address public RTNAddress = 0x78BEA5a0907744CDd8b722038B5F15351dD9aF27;

    address payable public clientAddress;
    address payable public freelancerAddress;
    address public RNFTAddress;
    address public RGCNFTAddress;
    
    uint256 RNFTTokenID;

    uint clientAmount;
    uint freelancerStake;


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

    string RGCNFTArtURI;

    // IERC20 public token; // Address of token contract
    // address public transferOperator; // Address to manage the Transfers

    constructor(uint8[] memory _checkpoints, address _freelancer, uint _clientAmount , uint _freelancerStake ) payable
    {
        require(_checkpoints[_checkpoints.length-1]==100);
        clientAddress = payable(msg.sender);
        freelancerAddress = payable(_freelancer);
        checkpoints = _checkpoints;
        clientAmount = _clientAmount;
        freelancerStake = _freelancerStake;
        setProjectState(ProjectState.newEscrow);

        RGCNFTArtURI = '';
    }

   	modifier condition(bool _condition) {
		require(_condition);
		_;
	}

	modifier onlyClient() {
		require(msg.sender == clientAddress);
		_;
	}

	modifier onlyFreelancer() {
		require(msg.sender == freelancerAddress);
		_;
	}
	
	modifier inProjectState(ProjectState _state) {
		require(projectState == _state);
		_;
	}

    function setRGCNFTURI(string memory _RGCNFTArtURI) public {
        RGCNFTArtURI = _RGCNFTArtURI;
    }

    function setProjectState(ProjectState _state) private {
        projectState = _state;
        emit ProjectStateChanged(projectState);
    }

    function getProjectState() public view returns (ProjectState) {
        return projectState;
    }


    // Project Lifecycle

     function depositRNFT(address _RNFTAddress, uint256 _RNFTTokenID)
        public
        inProjectState(ProjectState.newEscrow)
        onlyClient
    {
        RNFTAddress = _RNFTAddress;
        RNFTTokenID = _RNFTTokenID;
        ERC721(RNFTAddress).safeTransferFrom(msg.sender, address(this), RNFTTokenID);
        setProjectState(ProjectState.nftDeposited);
    } 

    
    // The transfer should have been approved by the client.
    function depositFundsAsClient()
        public
        inProjectState(ProjectState.nftDeposited)
        onlyClient
    {
        IERC20(RTNAddress).transferFrom(msg.sender, address(this), clientAmount);
        setProjectState(ProjectState.receivedFundsByClient);
    }

    /// @dev The transfer should be approved by freelancer
    function depositFundsAsFreelancer()
        public
        inProjectState(ProjectState.receivedFundsByClient)
        onlyFreelancer
    {
        IERC20(RTNAddress).transferFrom(msg.sender, address(this), freelancerStake);
        setProjectState(ProjectState.checkpointingStarted);
    }

    function increaseFreelancerCheckpoint() 
    external 
    inProjectState(ProjectState.checkpointingStarted) 
    onlyFreelancer
    {
        require(currentCheckpoints.freelancer < (checkpoints.length - 1));
        currentCheckpoints.freelancer++;
        emit FreelancerCheckpointChanged(currentCheckpoints.freelancer);
    }

    function increaseClientCheckpoint() 
    external 
    inProjectState(ProjectState.checkpointingStarted) 
    onlyClient
    {
        require(currentCheckpoints.client < (checkpoints.length - 1));
        currentCheckpoints.client++;
        emit ClientCheckpointChanged(currentCheckpoints.client);    
    }    

    function disburseFunds() 
    public 
    onlyFreelancer
    {
        uint8 approvedCheckpoint = currentCheckpoints.client;
        if (currentCheckpoints.freelancer < currentCheckpoints.client) {
            approvedCheckpoint = currentCheckpoints.freelancer;
        }
        if (currentCheckpoints.smc < approvedCheckpoint) {
            uint8 percentageToBeTransferred = checkpoints[approvedCheckpoint] - checkpoints[currentCheckpoints.smc];
            // Transfer percentageToBeTransferred*totalAmount to freelancer
            IERC20(RTNAddress).transferFrom(address(this), freelancerAddress, percentageToBeTransferred*clientAmount/100);
            emit FundsDisbursed(currentCheckpoints.smc, approvedCheckpoint);
            currentCheckpoints.smc = approvedCheckpoint;
            if (approvedCheckpoint == checkpoints.length - 1) {
                checkpointingDone();
            }
        }
    }

    function checkpointingDone()
        private
        inProjectState(ProjectState.checkpointingStarted)
    {
        setProjectState(ProjectState.checkpointsDone);
        releaseStakedFunds();
        releaseGigNFTToClient();
        mintGigCompletionNFTForFreelancer();
        setProjectState(ProjectState.done);
    }

    function releaseStakedFunds()
    private
    inProjectState(ProjectState.checkpointsDone)
    {
        IERC20(RTNAddress).transferFrom(address(this), freelancerAddress, freelancerStake);
    }

    function releaseGigNFTToClient() 
    private 
    {
        ERC721(RNFTAddress).transferFrom(address(this), clientAddress, RNFTTokenID);
    }

    function mintGigCompletionNFTForFreelancer() private {
        RGCNFTInterface(RGCNFTAddress).mint(freelancerAddress, RGCNFTArtURI);
    }









    function getCheckpoints() external view returns (uint8[] memory) {
        return checkpoints;
    }






    // copied code from here

    function onERC721Received( address operator, address from, uint256 tokenId, bytes calldata data ) public override returns (bytes4) {
        return this.onERC721Received.selector;
    }
} 
