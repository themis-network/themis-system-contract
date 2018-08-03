var VoteSystemContract = artifacts.require("./VoteSystemContract.sol");

module.exports = function(deployer) {
    deployer.deploy(VoteSystemContract);
};
