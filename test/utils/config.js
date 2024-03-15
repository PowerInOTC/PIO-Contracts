// config.js
const fs = require('fs');
const ethers = require('ethers');
const dotenv = require('dotenv');

// Load environment variables from .env file
dotenv.config();

// Read the rpc.json file
const rpcData = JSON.parse(fs.readFileSync('./rpc.json', 'utf8'));

// Filter active chains
const activeChains = rpcData.filter(chain => chain.active === 'true');

// Initialize configs for each active chain
const configs = {};

for (const chain of activeChains) {
  const pionerChainId = chain.pionerChainId;

  configs[pionerChainId] = {
    network: {
      rpcUrl: chain.rpc[0],
      chainId: chain.chainId,
      privateKeys: process.env.PRIVATE_KEYS.split(',')
    },
    contracts: {
      // Define contract configurations here
      // Add new contracts or update existing ones as needed
      fakeUSD: {
        address: chain.contracts.FakeUSDAddress,
        abi: JSON.parse(fs.readFileSync("./abis/FakeUSD.sol/fakeUSD.json")).abi
      },
      pionerV1: {
        address: chain.contracts.PionerV1Address,
        abi: JSON.parse(fs.readFileSync("./abis/Functions/PionerV1.sol/PionerV1.json")).abi
      },
      pionerV1Compliance: {
        address: chain.contracts.PionerV1ComplianceAddress,
        abi: JSON.parse(fs.readFileSync("./abis/Functions/PionerV1Compliance.sol/PionerV1Compliance.json")).abi
      },
      pionerV1Open: {
        address: chain.contracts.PionerV1OpenAddress,
        abi: JSON.parse(fs.readFileSync("./abis/Functions/PionerV1Open.sol/PionerV1Open.json")).abi
      },
      pionerV1Close: {
        address: chain.contracts.PionerV1CloseAddress,
        abi: JSON.parse(fs.readFileSync("./abis/Functions/PionerV1Close.sol/PionerV1Close.json")).abi
      },
      pionerV1Default: {
        address: chain.contracts.PionerV1DefaultAddress,
        abi: JSON.parse(fs.readFileSync("./abis/Functions/PionerV1Default.sol/PionerV1Default.json")).abi
      },
      pionerV1View: {
        address: chain.contracts.PionerV1ViewAddress,
        abi: JSON.parse(fs.readFileSync("./abis/Libs/PionerV1View.sol/PionerV1View.json")).abi
      },
      pionerV1Oracle: {
        address: chain.contracts.PionerV1OracleAddress,
        abi: JSON.parse(fs.readFileSync("./abis/Functions/PionerV1Oracle.sol/PionerV1Oracle.json")).abi
      },
      pionerV1Warper: {
        address: chain.contracts.PionerV1WarperAddress,
        abi: JSON.parse(fs.readFileSync("./abis/Functions/PionerV1Warper.sol/PionerV1Warper.json")).abi
      }
    },
    functions: {
      // Define function configurations here
      // Add new functions or update existing ones as needed
      mint: 'fakeUSD',
      approve: 'fakeUSD',
      deposit: 'pionerV1Compliance',
      initiateWithdraw: 'pionerV1Compliance',
      withdraw: 'pionerV1Compliance',
      warperOpenQuoteMM: 'pionerV1Warper',
      warperCloseLimitMM: 'pionerV1Warper',
      warpperUpdatePriceAndCloseMarket: 'pionerV1Warper',
      warpperUpdatePriceAndDefault: 'pionerV1Warper',
      warperOpenQuoteMM: 'pionerV1Warper'
    },
    events: {
      // Define event configurations here
      // Add new events or update existing ones as needed
      pionerV1Compliance: {
        DepositEvent: {
          name: 'DepositEvent',
          args: ['user', 'amount']
        },
        InitiateWithdrawEvent: {
          name: 'InitiateWithdrawEvent',
          args: ['user', 'amount']
        },
        WithdrawEvent: {
          name: 'WithdrawEvent',
          args: ['user', 'amount']
        },
        CancelWithdrawEvent: {
          name: 'CancelWithdrawEvent',
          args: ['user', 'amount']
        }
      },
      pionerV1Open: {
        openQuoteEvent: {
          name: 'openQuoteEvent',
          args: ['bContractId']
        },
        openQuoteSignedEvent: {
          name: 'openQuoteSignedEvent',
          args: ['bContractId', 'fillAPIEventId']
        },
        cancelSignedMessageOpenEvent: {
          name: 'cancelSignedMessageOpenEvent',
          args: ['sender', 'messageHash']
        },
        acceptQuoteEvent: {
          name: 'acceptQuoteEvent',
          args: ['bContractId']
        },
        cancelOpenQuoteEvent: {
          name: 'cancelOpenQuoteEvent',
          args: ['bContractId']
        }
      },
      pionerV1Default: {
        settledEvent: {
          name: 'settledEvent',
          args: ['bContractId']
        },
        liquidatedEvent: {
          name: 'liquidatedEvent',
          args: ['bContractId']
        },
        flashAuctionBuyBackEvent: {
          name: 'flashAuctionBuyBackEvent',
          args: ['bContractId']
        }
      },
      pionerV1Close: {
        openCloseQuoteEvent: {
          name: 'openCloseQuoteEvent',
          args: ['bCloseQuoteId']
        },
        acceptCloseQuoteEvent: {
          name: 'acceptCloseQuoteEvent',
          args: ['bCloseQuoteId']
        },
        expirateBContractEvent: {
          name: 'expirateBContractEvent',
          args: ['bContractId']
        },
        closeMarketEvent: {
          name: 'closeMarketEvent',
          args: ['bCloseQuoteId']
        },
        cancelOpenCloseQuoteContractEvent: {
          name: 'cancelOpenCloseQuoteContractEvent',
          args: ['bContractId']
        },
        cancelSignedMessageCloseEvent: {
          name: 'cancelSignedMessageCloseEvent',
          args: ['sender', 'messageHash']
        }
      }
    }
  };

  const provider = new ethers.JsonRpcProvider(configs[pionerChainId].network.rpcUrl);
  const signers = configs[pionerChainId].network.privateKeys.map((privateKey) => {
    const signer = new ethers.Wallet(privateKey, provider);
    signer.address = signer.getAddress();
    return signer;
  });

  for (const contractName in configs[pionerChainId].contracts) {
    const { address, abi } = configs[pionerChainId].contracts[contractName];
    const contractInstance = new ethers.Contract(address, abi, signers[0]);
    configs[pionerChainId].contracts[contractName].instance = contractInstance;
  }

  for (const signer of signers) {
    for (const functionName in configs[pionerChainId].functions) {
      const contractName = configs[pionerChainId].functions[functionName];
      signer[functionName] = async function (...args) {
        const contractInstance = configs[pionerChainId].contracts[contractName].instance;
        const result = await contractInstance.connect(this)[functionName](...args);
        console.log(`Executed ${functionName} on ${contractName} with args:`, args);
        return result;
      };
    }
  }

  configs[pionerChainId].signers = signers;
}

async function getEvents(pionerChainId, contractName, eventName, startBlock, endBlock) {
  const config = configs[pionerChainId];
  const contract = config.contracts[contractName].instance;
  const eventConfig = config.events[contractName][eventName];

  const filter = contract.filters[eventName]();
  const events = await contract.queryFilter(filter, startBlock, endBlock);

  const parsedEvents = events.map(event => {
    const parsedArgs = {};
    eventConfig.args.forEach((arg, index) => {
      parsedArgs[arg] = event.args[index];
    });
    return {
      ...event,
      parsedArgs
    };
  });

  return parsedEvents;
}

async function getAllEvents(pionerChainIds, startBlock, endBlock) {
  const allEvents = {};

  for (const pionerChainId of pionerChainIds) {
    const config = configs[pionerChainId];
    allEvents[pionerChainId] = {};

    for (const contractName in config.events) {
      allEvents[pionerChainId][contractName] = {};

      for (const eventName in config.events[contractName]) {
        const events = await getEvents(pionerChainId, contractName, eventName, startBlock, endBlock);
        allEvents[pionerChainId][contractName][eventName] = events;
      }
    }
  }

  return allEvents;
}

module.exports = {
  configs,
  getEvents,
  getAllEvents
};