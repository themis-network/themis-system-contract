pragma solidity ^0.4.24;

import "./SystemStorage.sol";

contract SystemContract is SystemStorage {

    // Just for test // TODO
    uint depositForJoin = 1 ether;
    // 72 hours lock for deposit
    uint lockTimeForDepoist = 72 * 60 * 60;
    // 72 hours lock for vote
    uint lockTimeForVote = 72 * 60 * 60;
    // Just for test // TODO
    uint lengthOFEpoch = 4;

    // Set current system contract address
    constructor() public {
        // Set init data
        uintStorage[keccak256("system.depositForJoin")]= depositForJoin;
        uintStorage[keccak256("system.lockTimeForDeposit")] =lockTimeForDepoist;
        uintStorage[keccak256("system.lockTimeForVote")] = lockTimeForVote;
        uintStorage[keccak256("system.lengthOFEpoch")] = lengthOFEpoch;
        uintStorage[keccak256("linkTable.currentIndex")] = 1;
    }

    /**
     * @dev // TODO just for test, will remove later
     */
    function setCurrentSystemContract(address currentSystemContract) public returns(bool) {
        addressStorage[CSCA] = currentSystemContract;
    }

    // TODO implement upgradeable
}
