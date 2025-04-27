// Script that deploys a given contract to a network
import { ethers, network } from 'hardhat';

async function main() {
  const UniswapBatchQuery = 'UniswapBatchQuery';
  const ARGS = ['Hi there!'];
  console.log(`Deploying ${UniswapBatchQuery} contract to ${network.name}`);
  const contract = await ethers.deployContract(UniswapBatchQuery, ARGS, {});
  await contract.waitForDeployment();
  const contractAddress = await contract.getAddress();
  console.log(`${UniswapBatchQuery} deployed to ${contractAddress}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
