var SystemContract = artifacts.require("./SystemContract.sol");

module.exports = function(deployer) {
    deployer.deploy(SystemContract);
};
