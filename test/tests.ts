import { expect } from "chai";
import hre, { ethers } from "hardhat";
import { BigNumber } from "ethers";


const clientAddress = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266";

const freelancerAddress = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8";

describe("Test", function () {
  it("Testing the overall standard flow", async function () {
    const [client, freelancer] = await ethers.getSigners();

    const RevereToken = await ethers.getContractFactory("RevereToken");
    const revere_token_contract = await RevereToken.deploy();
  
    await revere_token_contract.deployed();
  
    console.log(`RevereToken deployed to ${revere_token_contract.address}`);

    const RevereNFT = await ethers.getContractFactory("RevereNFT");
    const revere_nft_contract = await RevereNFT.deploy();

    await revere_nft_contract.deployed();

    console.log(`RevereNFT deployed to ${revere_nft_contract.address}`);

    const RevereGigCompletionNFT = await ethers.getContractFactory("RevereGigCompletionNFT");
    const revere_gig_completion_nft_contract = await RevereGigCompletionNFT.deploy();
    
    await revere_gig_completion_nft_contract.deployed();

    console.log(`RevereGigCompletionNFT deployed to ${revere_gig_completion_nft_contract.address}`);

    const NFTEscrow = await ethers.getContractFactory("NFTEscrow");
    const nftEscrow = await NFTEscrow.deploy(
      [0, 10, 25, 100], 
      freelancerAddress, 
      "10000000000000000000", 
      "1000000000000000000",
      revere_gig_completion_nft_contract.address,
      revere_token_contract.address
      );

    await nftEscrow.deployed();

    console.log(`NFTEscrow deployed to ${nftEscrow.address}`);

    expect(await nftEscrow.clientAddress()).to.equal(clientAddress);

    expect((await nftEscrow.functions.getProjectState())[0]).to.equal(0);


    // Mint RNFT to client
    await revere_nft_contract.functions.mint(clientAddress, 1);

    // Approve RNFT to escrow
    await revere_nft_contract.functions.approve(nftEscrow.address.toString(), 0);

    // Transfer RNFT to escrow
    await nftEscrow.functions.depositRNFT(revere_nft_contract.address, 0);

    expect((await nftEscrow.functions.getProjectState())[0]).to.equal(1);

    // Mint RTN to client
    await revere_token_contract.functions.mintToken("10000000000000000000");

    // Approve RTN to escrow
    await revere_token_contract.functions.approve(nftEscrow.address.toString(), "10000000000000000000");

    // Transfer RTN to escrow
    await nftEscrow.functions.depositFundsAsClient();

    expect((await nftEscrow.functions.getProjectState())[0]).to.equal(2);

    // Mint RTN to freelancer
    await revere_token_contract.connect(freelancer).functions.mintToken("1000000000000000000");

    // Approve RTN to escrow from freelancer
    await revere_token_contract.connect(freelancer).functions.approve(nftEscrow.address.toString(), "1000000000000000000");

    // Transfer RTN to escrow from freelancer
    await nftEscrow.connect(freelancer).functions.depositFundsAsFreelancer();

    expect((await nftEscrow.functions.getProjectState())[0]).to.equal(3);

    // First checkpoint done by freelancer
    await nftEscrow.connect(freelancer).functions.increaseFreelancerCheckpoint();

    expect((await nftEscrow.functions.getCheckpointStatus()).freelancer).to.equal(1);
    expect((await nftEscrow.functions.getCheckpointStatus()).client).to.equal(0);
    expect((await nftEscrow.functions.getCheckpointStatus()).smc).to.equal(0);
    
    // await nftEscrow.connect(freelancer).functions.disburseFunds();

    expect((await nftEscrow.functions.getCheckpointStatus()).freelancer).to.equal(1);
    expect((await nftEscrow.functions.getCheckpointStatus()).client).to.equal(0);
    expect((await nftEscrow.functions.getCheckpointStatus()).smc).to.equal(0);

    // First checkpoint done by client
    await nftEscrow.functions.increaseClientCheckpoint();

    expect((await nftEscrow.functions.getCheckpointStatus()).freelancer).to.equal(1);
    expect((await nftEscrow.functions.getCheckpointStatus()).client).to.equal(1);
    expect((await nftEscrow.functions.getCheckpointStatus()).smc).to.equal(0);
    
    await nftEscrow.connect(freelancer).disburseFunds();

    expect((await nftEscrow.functions.getCheckpointStatus()).freelancer).to.equal(1);
    expect((await nftEscrow.functions.getCheckpointStatus()).client).to.equal(1);
    expect((await nftEscrow.functions.getCheckpointStatus()).smc).to.equal(1);    
  });
});


