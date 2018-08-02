import { assertEquals, assertBigger } from "./help";

const CurrentSystemContract = artifacts.require("./CurrentSystemContract");
const SystemContract = artifacts.require("./SystemContract");

const BigNumber = web3.BigNumber;

contract("System Contract", function (accounts) {

    before(async function () {
        this.SystemContractIns = await SystemContract.new();
        this.CurrentSystemContractIns = await CurrentSystemContract.new(this.SystemContractIns.address);
        // Set contract address(only used in test)
        await this.SystemContractIns.setCurrentSystemContract(this.CurrentSystemContractIns.address);
    })

    it("should right init system contract", async function() {
        // Init system config
        const depositForJoinKey = web3.sha3("system.depositForJoin");
        const lockTimeForDepositKey = web3.sha3("system.lockTimeForDeposit");
        const lockTimeForVoteKey = web3.sha3("system.lockTimeForVote");
        const lengthOFEpochKey = web3.sha3("system.lengthOFEpoch");
        const initLockTime = 72 * 60 * 60;

        const acutalDepositForJoin = await this.SystemContractIns.getUint(depositForJoinKey);
        const acutalLockTimeForDepoist = await this.SystemContractIns.getUint(lockTimeForDepositKey);
        const acutalLockTimeForVote = await this.SystemContractIns.getUint(lockTimeForVoteKey);
        const acutalLengthOFEpoch = await this.SystemContractIns.getUint(lengthOFEpochKey);

        assertEquals(acutalDepositForJoin, web3.toWei(1, "ether"), "not right init depoist for join");
        assertEquals(acutalLockTimeForDepoist, new BigNumber(initLockTime), "not right init lock time for depoist")
        assertEquals(acutalLockTimeForVote, new BigNumber(initLockTime), "not right init lock time for vote")
        assertEquals(acutalLengthOFEpoch, new BigNumber(4), "not right init default length of epoch")
    })


    it("should right reg producer", async function () {
        const name = "test"
        const webUrl = "http://test"
        const p2pUrl = "encode://111"
        const deposit = web3.toWei(1, "ether")

        // Reg producer
        await this.CurrentSystemContractIns.regProducerCandidates(name, webUrl, p2pUrl, {from: accounts[1], value: deposit});
        const producers = await this.CurrentSystemContractIns.getTopProducers();
        assert.equal(producers.length, 4, "wrong producer's length");

        assert.equal(producers[0], accounts[1], "wrong producer's address");
    })

})