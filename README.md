# themis-system-contract

In order to support functions such as block producer registration and voting 
, upgrading system contracts, the dpos consensus design of the THEMIS calls
for a number of system contract which will be set on genesis block. The dpos
consensus system will call for contract to get producer's info to select block
producers producing block.

This repository contains examples and test of this contracts. They are provided
for reference purposes: 
* [main contract](./contracts/SystemContract.sol)
* [registration contract](./contracts/RegSystemContract.sol)
* [vote contract](./contracts/VoteSystemContract.sol)

## Test

To build the test, pleasure you have installed [truffle](https://github.com/trufflesuite/truffle) 
, [ganache-cli](https://github.com/trufflesuite/ganache-cli), and all other dependencies.

execute: 
```bash
$ npm install -g truffle
$ npm install -g ganache-cli
$ npm install
```

After all things done:
start ganache-cli:
```bash
$ ganache-cli --gasLimit 16000000
```

Run test uint:
```bash
$ cd themis-system-contract
$ truffle test
```
