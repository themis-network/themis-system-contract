pragma solidity ^0.4.24;

contract ProducersOpInterface {

    function addProducer(address producer) public;

    function removeProducer(address producer) public;

    function getProducers() external view returns(address[]);

    function getProducersLength() external view returns(uint);
}
