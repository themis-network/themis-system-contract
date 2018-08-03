var RegSystemContract = artifacts.require("./RegSystemContract.sol");

module.exports = function(deployer) {
    deployer.deploy(RegSystemContract);
};
