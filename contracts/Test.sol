pragma solidity ^0.4.23;

contract Test {

    address producer0;
    address producer1;
    address producer2;
    address producer3;

    function getTopProducers() public view returns(address[]) {
        address[] memory res = new address[](4);
        res[0] = producer0;
        res[1] = producer1;
        res[2] = producer2;
        res[3] = producer3;
        return res;
    }

    function getProducer0() public view returns(address) {
        return producer0;
    }

    function getProducer1() public view returns(address) {
        return producer1;
    }

    function getProducer2() public view returns(address) {
        return producer2;
    }

    function getProducer3() public view returns(address) {
        return producer3;
    }
}

contract UpgradeableTest {

    function getCurrentSystemContractAddress() public pure returns(address) {
        return address(10);
    }
}

