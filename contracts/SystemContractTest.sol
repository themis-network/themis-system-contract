pragma solidity ^0.4.24;

import "./SystemStorage.sol";
import "./ProducersOpInterface.sol";

// This contract is just a copy of SystemContract.sol to test it since
// system contract will set code and storage in genesis block directly,
// hence it will not execute constructor in contract. But this is not
// convenience for test.
contract SystemContractTest is SystemStorage, ProducersOpInterface {


    // Just for convenience to get all producers
    address[] producers;


    /**
     * @dev // TODO just for test, will remove later
     */
    function setSystemContract(address systemContract) public returns(bool) {
        boolStorage[keccak256("system.address", systemContract)] = true;
    }

    function pushProducers(address producer) public  {
        producers.push(producer);
    }

    function updateProducer(address producer, uint index) public onlyCurrentSystemContract {
        producers[index] = producer;
    }

    function getProducers() public returns(address[]) {
        return producers;
    }

    function deleteProducer(uint index) public onlyCurrentSystemContract {
        delete producers[index];
    }
    // TODO implement upgradeable
}
