pragma solidity ^0.4.24;

contract ProducersOpInterface {
    //
    function pushProducers(address producer) public;

    function updateProducer(address producer, uint index) public;

    function deleteProducer(uint index) public;

    function getProducers() public returns(address[]);
}
