pragma solidity ^0.4.24;

import "./SystemStorage.sol";
import "./ProducersOpInterface.sol";


contract SystemContract is SystemStorage, ProducersOpInterface {


    // Just for convenience to get all producers
    address[] producers;


    function pushProducers(address producer) public  {
        producers.push(producer);
    }

    function updateProducer(address producer, uint index) public onlyCurrentSystemContract {
        producers[index] = producer;
    }

    function getProducers() external view returns(address[]) {
        return producers;
    }

    function deleteProducer(uint index) public onlyCurrentSystemContract {
        delete producers[index];
    }

    function getVoteSystemContract() public returns(address) {
        return addressStorage[keccak256("system.voteSystemContract")];
    }

    function getRegSystemContract() public returns(address) {
        return addressStorage[keccak256("system.regSystemContract")];
    }
    // TODO implement upgradeable
}
