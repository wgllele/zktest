import type { HardhatUserConfig } from "hardhat/config";

import "@matterlabs/hardhat-zksync";
import "hardhat-contract-sizer";
import dotenv from "dotenv";
dotenv.config();

const config: HardhatUserConfig = {
  defaultNetwork: "ZKsyncEraSepolia",
  networks: {
    ZKsyncEraSepolia: {
      url: "https://sepolia.era.zksync.dev",
      ethNetwork: "sepolia",
      zksync: true,
      verifyURL: "https://explorer.sepolia.era.zksync.dev/contract_verification",
      accounts: process.env.WALLET_PRIVATE_KEY ? [process.env.WALLET_PRIVATE_KEY] : [],
    },
    ZKsyncEraMainnet: {
      url: "https://mainnet.era.zksync.io",
      ethNetwork: "mainnet",
      zksync: true,
      verifyURL: "https://zksync2-mainnet-explorer.zksync.io/contract_verification",
      accounts: process.env.WALLET_PRIVATE_KEY ? [process.env.WALLET_PRIVATE_KEY] : [],
    },
    SophonMainnet: {
      url: "https://rpc.sophon.xyz",
      ethNetwork: "mainnet",
      verifyURL: "https://verification-explorer.sophon.xyz/contract_verification",
      zksync: true,
      accounts: process.env.WALLET_PRIVATE_KEY ? [process.env.WALLET_PRIVATE_KEY] : [],
    },
    SophonTestnet: {
      url: "https://rpc.testnet.sophon.xyz",
      ethNetwork: "sepolia",
      verifyURL: "https://api-explorer-verify.testnet.sophon.xyz/contract_verification",
      zksync: true,
      accounts: process.env.WALLET_PRIVATE_KEY ? [process.env.WALLET_PRIVATE_KEY] : [],
    },
    dockerizedNode: {
      url: "http://localhost:3050",
      ethNetwork: "http://localhost:8545",
      zksync: true,
      accounts: process.env.WALLET_PRIVATE_KEY ? [process.env.WALLET_PRIVATE_KEY] : [],
    },
    anvilZKsync: {
      url: "http://127.0.0.1:8011",
      ethNetwork: "localhost", // anvil doesn't support eth node; removing this line will cause an error
      zksync: true,
      accounts: process.env.WALLET_PRIVATE_KEY ? [process.env.WALLET_PRIVATE_KEY] : [],
    },
    hardhat: {
      zksync: true,
    },
  },
  zksolc: {
    version: "1.5.12",
    compilerSource: "binary",
    settings: {
     // compilerPath: "/Users/hpblabs/go/zksolc",
      forceEVMLA: false, // optional. Falls back to EVM legacy assembly if there is a bug with Yul
      optimizer: {
        enabled: true, // optional. True by default
        mode: 'z', // optional. 3 by default, z to optimize bytecode size
        fallback_to_optimizing_for_size: false
      },
      // ERA VM Settings
      enableEraVMExtensions: false,
    },
  },
  contractSizer: {
    alphaSort: true,
    disambiguatePaths: false,
    runOnCompile: true,
    strict: true,
    only: [],
  },
  solidity: {
    version: "0.8.28",
    eraVersion : "1.0.0",
    settings: {
      optimizer: {
        enabled: true,
        mode: 'z',
        runs: 200,
      },
      evmVersion:"cancun",
      viaIR: false, // for the reason of :CompilerError: Stack too deep. Try compiling with `--via-ir` (cli) or the equivalent `viaIR: true`
    },
  },
};

export default config;
