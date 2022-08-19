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

interface RevereGigCompletionNFTInterface {
    function mint(address _to, string memory tokenURI_) external;
}

contract NFTEscrow is IERC721Receiver {
    enum ProjectState {
        newEscrow,
        nftDeposited,
        receivedFundsByClient,
        checkpointingStarted,
        checkpointsDone,
        done,
        cancelledByClient,
        cancelledByFreelancer
    }
    event Received(address, uint);

    event ClientCheckpointChanged(uint8);
    event FreelancerCheckpointChanged(uint8);

    event FundsDisbursed(uint8 _from, uint8 _to);

    event ProjectStateChanged(ProjectState _state);

    // TODO: why public?
    // TODO: token address can change ,rn hardcoded

    address public RTNAddress; // = 0xd9145CCE52D386f254917e481eB44e9943F39138;
    address public RGCNFTAddress; // = 0xf8e81D47203A594245E36C48e151709F0C19fBe8;

    address public RNFTAddress;
    address payable public clientAddress;
    address payable public freelancerAddress;

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
    // NOTE: You NEED to use cumulative percentages. And the first percentage is 0.
    // Example: [0, 10, 25, 100]
    uint8[] checkpoints;

    string RGCNFTArtURI;

    uint freelancerCompensationIfClientCancels;

    // IERC20 public token; // Address of token contract
    // address public transferOperator; // Address to manage the Transfers

    constructor(
        uint8[] memory _checkpoints,
        address _freelancer,
        uint _clientAmount,
        uint _freelancerStake,
        address _RGCNFTAddress,
        address _RTNAddress,
        uint _freelancerCompensationIfClientCancels
    ) payable {
        require(_checkpoints[_checkpoints.length - 1] == 100);
        require(_checkpoints[0] == 0);
        clientAddress = payable(msg.sender);
        freelancerAddress = payable(_freelancer);
        checkpoints = _checkpoints;
        clientAmount = _clientAmount;
        freelancerStake = _freelancerStake;
        RGCNFTAddress = _RGCNFTAddress;
        RTNAddress = _RTNAddress;
        freelancerCompensationIfClientCancels = _freelancerCompensationIfClientCancels;
        setProjectState(ProjectState.newEscrow);

        RGCNFTArtURI = "";
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
        ERC721(RNFTAddress).safeTransferFrom(
            msg.sender,
            address(this),
            RNFTTokenID
        );
        setProjectState(ProjectState.nftDeposited);
    }

    // The transfer should have been approved by the client.
    function depositFundsAsClient()
        public
        inProjectState(ProjectState.nftDeposited)
        onlyClient
    {
        IERC20(RTNAddress).transferFrom(
            msg.sender,
            address(this),
            clientAmount
        );
        setProjectState(ProjectState.receivedFundsByClient);
    }

    /// @dev The transfer should be approved by freelancer
    function depositFundsAsFreelancer()
        public
        inProjectState(ProjectState.receivedFundsByClient)
        onlyFreelancer
    {
        IERC20(RTNAddress).transferFrom(
            msg.sender,
            address(this),
            freelancerStake
        );
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

    function disburseFunds() external onlyFreelancer {
        _disburseFunds();
    }

    function _disburseFunds() private {
        uint8 approvedCheckpoint = currentCheckpoints.client;
        if (currentCheckpoints.freelancer < currentCheckpoints.client) {
            approvedCheckpoint = currentCheckpoints.freelancer;
        }
        if (currentCheckpoints.smc < approvedCheckpoint) {
            uint8 percentageToBeTransferred = checkpoints[approvedCheckpoint] -
                checkpoints[currentCheckpoints.smc];
            // Transfer percentageToBeTransferred*totalAmount to freelancer
            uint amountToBeTransferred = (percentageToBeTransferred *
                clientAmount) / 100;
            // return (amountToBeTransferred);
            IERC20(RTNAddress).transfer(
                freelancerAddress,
                amountToBeTransferred
            );
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
        releaseStakedFundsToFreelancer();
        releaseGigNFTToClient();
        mintGigCompletionNFTForFreelancer();
        setProjectState(ProjectState.done);
    }

    function releaseStakedFundsToFreelancer() private {
        IERC20(RTNAddress).transfer(freelancerAddress, freelancerStake);
    }

    function releaseStakedFundsToClient()
        private
        inProjectState(ProjectState.cancelledByFreelancer)
    {
        IERC20(RTNAddress).transfer(clientAddress, freelancerStake);
    }

    function releaseGigNFTToClient() private {
        ERC721(RNFTAddress).transferFrom(
            address(this),
            clientAddress,
            RNFTTokenID
        );
    }

    function mintGigCompletionNFTForFreelancer() private {
        RevereGigCompletionNFTInterface(RGCNFTAddress).mint(
            freelancerAddress,
            RGCNFTArtURI
        );
    }

    function getCheckpointStatus()
        external
        view
        returns (
            uint8 client,
            uint8 freelancer,
            uint8 smc
        )
    {
        return (
            currentCheckpoints.client,
            currentCheckpoints.freelancer,
            currentCheckpoints.smc
        );
    }

    function getCheckpoints() external view returns (uint8[] memory) {
        return checkpoints;
    }

    function clientCancel() external onlyClient {
        _disburseFunds();
        setProjectState(ProjectState.cancelledByClient);
        releaseStakedFundsToFreelancer();
        // No NFTs will be released as the client cancelled the project.
        releaseCancellationCompensation();
        // transfer left over funds to client
        IERC20(RTNAddress).transfer(
            clientAddress,
            IERC20(RTNAddress).balanceOf(address(this))
        );
    }

    function freelancerCancel() external onlyFreelancer {
        _disburseFunds();
        setProjectState(ProjectState.cancelledByFreelancer);
        releaseStakedFundsToClient();
        // transfer left over funds to freelancer
        IERC20(RTNAddress).transfer(
            freelancerAddress,
            IERC20(RTNAddress).balanceOf(address(this))
        );
    }

    function releaseCancellationCompensation()
        private
        inProjectState(ProjectState.cancelledByClient)
    {
        IERC20(RTNAddress).transfer(
            freelancerAddress,
            (freelancerCompensationIfClientCancels *
                IERC20(RTNAddress).balanceOf(address(this))/100)
        );
    }

    // copied code from here

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) public pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
