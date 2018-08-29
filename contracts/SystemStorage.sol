pragma solidity ^0.4.24;

import "./StorageInterface.sol";

contract SystemStorage is StorageInterface {

    // Public data
    mapping(bytes32 => address) public addressStorage;
    mapping(bytes32 => address[]) public addressArrayStorage;
    mapping(bytes32 => uint) public uintStorage;
    mapping(bytes32 => string) public stringStorage;
    mapping(bytes32 => bytes) public bytesStorage;
    mapping(bytes32 => bool) public boolStorage;
    mapping(bytes32 => int) public intStorage;

    // Only current system contract can call this function.
    modifier onlyCurrentSystemContract() {
        // System contract address
        require(boolStorage[keccak256("system.address", msg.sender)]);
        _;
    }

    // Getters
    // @param key The key of the record
    function getAddress(bytes32 key) public view returns(address){
        return addressStorage[key];
    }

    // @param key The key of the record
    function getAddressArray(bytes32 key) public view returns(address[]){
        return addressArrayStorage[key];
    }

    // @param key The key of the record
    function getUint(bytes32 key) public view returns(uint){
        return uintStorage[key];
    }

    // @param key The key of the record
    function getString(bytes32 key) public view returns(string){
        return stringStorage[key];
    }

    // @param key The key of the record
    function getBytes(bytes32 key) public view returns(bytes){
        return bytesStorage[key];
    }

    // @param key The key of the record
    function getBool(bytes32 key) public view returns(bool){
        return boolStorage[key];
    }

    // @param key The key of the record
    function getInt(bytes32 key) public view returns(int){
        return intStorage[key];
    }


    // Setters
    // @param key The key of the record
    // @param value The value of the record
    function setAddress(bytes32 key, address value) public onlyCurrentSystemContract returns(bool){
        addressStorage[key] = value;
        return true;
    }

    // @param key The key of the record
    // @param value The value of the record
    function setAddressArray(bytes32 key, address[] value) public onlyCurrentSystemContract returns(bool){
        addressArrayStorage[key] = value;
        return true;
    }

    // @param key The key of the record
    // @param value The value of the record
    function setUint(bytes32 key, uint value) public onlyCurrentSystemContract returns(bool){
        uintStorage[key] = value;
        return true;
    }

    // @param key The key of the record
    // @param value The value of the record
    function setString(bytes32 key, string value) public onlyCurrentSystemContract returns(bool){
        stringStorage[key] = value;
        return true;
    }

    // @param key The key of the record
    // @param value The value of the record
    function setBytes(bytes32 key, bytes value) public onlyCurrentSystemContract returns(bool){
        bytesStorage[key] = value;
        return true;
    }

    // @param key The key of the record
    // @param value The value of the record
    function setBool(bytes32 key, bool value) public onlyCurrentSystemContract returns(bool){
        boolStorage[key] = value;
        return true;
    }

    // @param key The key of the record
    // @param value The value of the record
    function setInt(bytes32 key, int value) public onlyCurrentSystemContract returns(bool){
        intStorage[key] = value;
        return true;
    }


    // Deleters
    // @param key The key of the record
    function deleteAddress(bytes32 key) public onlyCurrentSystemContract returns(bool){
        delete addressStorage[key];
        return true;
    }

    // @param key The key of the record
    function deleteAddressArray(bytes32 key) public onlyCurrentSystemContract returns(bool){
        delete addressArrayStorage[key];
        return true;
    }

    // @param key The key of the record
    function deleteUint(bytes32 key) public onlyCurrentSystemContract returns(bool){
        delete uintStorage[key];
        return true;
    }

    // @param key The key of the record
    function deleteString(bytes32 key) public onlyCurrentSystemContract returns(bool){
        delete stringStorage[key];
        return true;
    }

    // @param key The key of the record
    function deleteBytes(bytes32 key) public onlyCurrentSystemContract returns(bool){
        delete bytesStorage[key];
        return true;
    }

    // @param key The key of the record
    function deleteBool(bytes32 key) public onlyCurrentSystemContract returns(bool){
        delete boolStorage[key];
        return true;
    }

    // @param key The key of the record
    function deleteInt(bytes32 key) public onlyCurrentSystemContract returns(bool){
        delete intStorage[key];
        return true;
    }

    // @param contractAddr Address of contract want to check
    function isSystemContract(address contractAddr) public view returns(bool) {
        return boolStorage[keccak256("system.address", contractAddr)];
    }
}
