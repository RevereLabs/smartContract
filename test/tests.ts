import { expect } from "chai";
import hre, { ethers } from "hardhat";
import { time } from "@nomicfoundation/hardhat-network-helpers";
import { BigNumber } from "ethers";


const clientAddress = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266";
const clientPrivateKey = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80";

const freelancerAddress = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8";
const freelancerPrivateKey = "0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d";

describe("Test", function () {
  it("Testing the overall standard flow", async function () {
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
    const nftEscrow = await NFTEscrow.deploy([10, 25, 100], freelancerAddress, "10000000000000000000", "1000000000000000000");

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
    
  });
});


