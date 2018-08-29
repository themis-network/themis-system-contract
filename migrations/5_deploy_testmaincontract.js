var SystemContractTest = artifacts.require("./SystemContractTest.sol");

module.exports = function(deployer) {
    deployer.deploy(SystemContractTest);
};
