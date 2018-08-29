pragma solidity ^0.4.0;

contract B {
    mapping(uint => bool) public t;
    mapping(bytes32 => bool) public boolStorage;
    mapping(bytes32 => uint) public uintStorage;

    event Test(bytes32 key);

    constructor() public {
        t[2] = true;
        emit Test(keccak256(uint256(2), uint256(0)));
        emit Test(keccak256(2, 0));
        emit Test(keccak256("system.address", msg.sender));
        boolStorage[keccak256("system.address", msg.sender)] = true;
        uintStorage[keccak256("system.address", msg.sender)] = 1;

        // 0x3a839613ef3a103c983e514d7eb361d176da8965
    }
}


contract C {

    function proposeNewConfigs(bytes32[] keys, uint[] values) {

    }
}
