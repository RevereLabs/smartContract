import '@nomiclabs/hardhat-ethers'
import { ethers } from "hardhat";

async function main() {

  const RTN = await ethers.getContractFactory("RevereToken");
  const rtn = await RTN.deploy();

  await rtn.deployed();

  console.log(`RTN deployed to ${rtn.address}`);

  const RNFT = await ethers.getContractFactory("RNFT");
  const rnft = await RNFT.deploy();

  await rnft.deployed();

  console.log(`RNFT deployed to ${rnft.address}`);

  const RGCNFT = await ethers.getContractFactory("RGCNFT");
  const rgcnft = await RGCNFT.deploy();

  await rgcnft.deployed();

  console.log(`RGCNFT deployed to ${rgcnft.address}`);



}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
