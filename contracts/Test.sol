pragma solidity ^0.4.23;

contract B {

    bytes32 public localKey;


    constructor() public {
//        emit Test(keccak256("producer.status", "0x6da64C8436287B3BDe42C04AB2452BfaFEa8a4c6"));
//        emit Test(keccak256("producer.outTime", "0x6da64C8436287B3BDe42C04AB2452BfaFEa8a4c6"));
    }

    function cal(string key, address sender) public {
        localKey = keccak256(key, sender);
    }
}
