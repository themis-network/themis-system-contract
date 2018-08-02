pragma solidity ^0.4.24;

// Storage for upgradeable system contract
contract StorageInterface {

    // Getters
    function getAddress(bytes32 key) public view returns(address);
    function getAddressArray(bytes32 key) public view returns(address[]);
    function getUint(bytes32 key) public view returns(uint);
    function getString(bytes32 key) public view returns(string);
    function getBytes(bytes32 key) public view returns(bytes);
    function getBool(bytes32 key) public view returns(bool);
    function getInt(bytes32 key) public view returns(int);
    
    // Setters
    function setAddress(bytes32 key, address value) public returns(bool);
    function setAddressArray(bytes32 key, address[] value) public returns(bool);
    function setUint(bytes32 key, uint value) public returns(bool);
    function setString(bytes32 key, string value) public returns(bool);
    function setBytes(bytes32 key, bytes value) public returns(bool);
    function setBool(bytes32 key, bool value) public returns(bool);
    function setInt(bytes32 key, int value) public returns(bool);
    
    // Deleters
    function deleteAddress(bytes32 key) public returns(bool);
    function deleteAddressArray(bytes32 key) public returns(bool);
    function deleteUint(bytes32 key) public returns(bool);
    function deleteString(bytes32 key) public returns(bool);
    function deleteBytes(bytes32 key) public returns(bool);
    function deleteBool(bytes32 key) public returns(bool);
    function deleteInt(bytes32 key) public returns(bool);
}
