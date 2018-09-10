import assertRevert from "zeppelin-solidity/test/helpers/assertRevert";
import { increaseTimeTo, duration } from "zeppelin-solidity/test/helpers/increaseTime"

const SystemContractTest = artifacts.require("./SystemContractTest");
const VoteSystemContractTest = artifacts.require("./VoteSystemContractTest");
const RegSystemContractTest = artifacts.require("./RegSystemContractTest");

const BigNumber = web3.BigNumber;
const should = require('chai')
    .use(require('chai-as-promised'))
    .use(require('chai-bignumber')(BigNumber))
    .should();

const voteContractName = "system.voteContract";
const regContractName = "system.regContract";
const voteContractMappingKey = web3.sha3(voteContractName);
const regContractMappingKey = web3.sha3(regContractName);
const upgradeContract = 1;
const updateConfig = 2;
const voteOutBP = 3;

contract("Upgradeable contract", function (accounts) {

    before(async function () {
        this.SystemContractTestIns = await SystemContractTest.new();
        this.VoteSystemContractTestIns = await VoteSystemContractTest.new(this.SystemContractTestIns.address);
        this.RegSystemContractTestIns = await RegSystemContractTest.new(this.SystemContractTestIns.address);
        this.RegSystemContractTestIns2 = await RegSystemContractTest.new(this.SystemContractTestIns.address);
        await this.SystemContractTestIns.setSystemContract(voteContractName, this.VoteSystemContractTestIns.address);
        await this.SystemContractTestIns.setSystemContract(regContractName, this.RegSystemContractTestIns.address);

        // Reg 4 producers
        this.producers = [];
        this.producers.push(accounts[0]);
        this.producers.push(accounts[1]);
        this.producers.push(accounts[2]);
        this.producers.push(accounts[3]);
        await RegProducers(this.RegSystemContractTestIns, this.producers);
    })

    it("producer can propose a proposal for upgrading reg system contract", async function () {
        const producer = this.producers[1];
        // Reg contract
        // Just pass a address (the validation for contract will be done by community offline)
        const newAddress = this.RegSystemContractTestIns2.address;
        const keys = [];
        keys.push(regContractMappingKey);
        const value = [];
        value.push(newAddress);

        const { logs } = await this.SystemContractTestIns.propose(keys, value, 0, upgradeContract, {from: producer});
        const log = logs.find(e => e.event === "LogPropose");
        should.exist(log);
        log.args.proposer.should.equal(producer);

        const proposal = await this.SystemContractTestIns.getProposal();
        proposal[1].should.equal(true);
        proposal[2].should.equal(producer);
        proposal[4].should.equal("0x0000000000000000000000000000000000000000");
        proposal[7].should.be.bignumber.equal(new BigNumber(upgradeContract));
        proposal[8].should.be.bignumber.equal(new BigNumber(1));
        proposal[9].should.be.bignumber.equal(new BigNumber(0));
    })

    it("only active producer can vote for proposal", async function () {
        const producer = accounts[5];
        const auth = true;

        await assertRevert(this.SystemContractTestIns.vote(auth, {from: producer}));
    })

    it("other producers can vote for this proposal", async function () {
        const producer = this.producers[2];
        const auth = true;

        const { logs } = await this.SystemContractTestIns.vote(auth, {from: producer});
        const log = logs.find(e => e.event === "LogVote");
        log.args.voter.should.equal(producer);
        log.args.auth.should.equal(auth);
    })

    it("can not propose a new proposal if a proposal already exist and not after proposal period", async function () {
        const producer = this.producers[2];
        const newAddress = this.RegSystemContractTestIns2.address;
        const keys = [];
        keys.push(voteContractMappingKey);
        const value = [];
        value.push(newAddress);

        await assertRevert(this.SystemContractTestIns.propose(keys, value, 0, upgradeContract, {from: producer}));
    })

    it("only main contract can destruct system contract", async function () {
        // Use a test account to call destruct func
        const acc = accounts[3];
        const newAddress = this.RegSystemContractTestIns2.address;
        await assertRevert(this.RegSystemContractTestIns.destructSelf(newAddress), {from: acc})
    })

    it("can update system contract address/send get coin to new contract when vote reach length*2/3 + 1", async function () {
        const producer = this.producers[3];
        const auth = true;

        const oriBalance = await web3.eth.getBalance(this.RegSystemContractTestIns.address);

        // Update system contract if votes bigger than 2/3
        const { logs } = await this.SystemContractTestIns.vote(auth, {from: producer});
        const log = logs.find(e => e.event === "LogUpgradeSystemContract");
        should.exist(log);

        const updatedContract = await this.SystemContractTestIns.getSystemContract(regContractName);
        updatedContract.should.equal(this.RegSystemContractTestIns2.address);

        const afterBalance = await web3.eth.getBalance(this.RegSystemContractTestIns.address);
        afterBalance.should.be.bignumber.equal(new BigNumber(0));

        const newBalance = await web3.eth.getBalance(this.RegSystemContractTestIns2.address);
        newBalance.should.be.bignumber.equal(oriBalance);
    })

    it("original system should be destructed", async function () {
        // Original system contract will be destructed
        // Original code should be deleted
        const code = web3.eth.getCode(this.RegSystemContractTestIns.address);
        code.should.equal("0x0");
    })

    it("can propose/pass update config once original passed", async function () {
        const producer = this.producers[0];
        const keys = [];
        const var0 = web3.sha3("system.proposalPeriod");
        const var1 = web3.sha3("system.stakeForVote");
        const var2 = web3.sha3("system.maxProducerSize");
        keys.push(var0);
        keys.push(var1);
        keys.push(var2);

        const values = [];
        const value0 = 2 * 72 * 60 * 60;
        const value1 = web3.toWei(2, "ether");
        const value2 = 5;
        values.push(value0);
        values.push(value1);
        values.push(value2);

        await this.SystemContractTestIns.propose(keys, values, 0, updateConfig, {from: producer});

        // vote for this proposal
        const auth = true;

        await this.SystemContractTestIns.vote(auth, {from: this.producers[1]});
        await this.SystemContractTestIns.vote(auth, {from: this.producers[2]});
        await this.SystemContractTestIns.vote(auth, {from: this.producers[3]});

        const newValue0 = await this.SystemContractTestIns.getUint(var0);
        const newValue1 = await this.SystemContractTestIns.getUint(var1);
        const newValue2 = await this.SystemContractTestIns.getUint(var2);

        newValue0.should.be.bignumber.equal(new BigNumber(value0));
        newValue1.should.be.bignumber.equal(value1);
        newValue2.should.be.bignumber.equal(new BigNumber(value2));
    })

    it("can use new system contract to reg producer", async function () {
        const producer = accounts[9];
        const name = "test"
        const webUrl = "http://test"
        const p2pUrl = "encode://123123"
        const deposit = web3.toWei(5, "ether");

        const { logs } = await this.RegSystemContractTestIns2.regProducerCandidates(name, webUrl, p2pUrl, {from: producer, value: deposit});
        const log = logs.find(e => e.event === "LogRegProducerCandidates");
        should.exist(log);
        log.args.producer.should.equal(producer);
        log.args.name.should.equal(name);
        log.args.webUrl.should.equal(webUrl);
        log.args.p2pUrl.should.equal(p2pUrl);
        log.args.deposit.should.be.bignumber.equal(deposit);
        const voteWeight = await this.RegSystemContractTestIns2.getProducer(producer);
        voteWeight.should.be.bignumber.equal(deposit);
    })

    it("can not reg when producer's length reach threshold", async function () {
        const producerLength = await this.SystemContractTestIns.getProducersLength();
        const key = web3.sha3("system.maxProducerSize");
        const threshold = await this.SystemContractTestIns.getUint(key);

        threshold.sub(producerLength).should.be.bignumber.equal(new BigNumber(0));

        // Can't reg
        const producer = accounts[8];
        const name = "test"
        const webUrl = "http://test"
        const p2pUrl = "encode://123123"
        const deposit = web3.toWei(5, "ether");
        await assertRevert(this.RegSystemContractTestIns2.regProducerCandidates(name, webUrl, p2pUrl, {from: producer, value: deposit}));
    })

    it("can propose/pass vote out malicious producer", async function () {
        const producer = this.producers[0];
        const keys = [];
        const values = [];
        const maliciousBP = accounts[9];

        await this.SystemContractTestIns.propose(keys, values, maliciousBP, voteOutBP, {from: producer});

        const auth = true;
        await this.SystemContractTestIns.vote(auth, {from: this.producers[1]});
        await this.SystemContractTestIns.vote(auth, {from: this.producers[2]});
        const { logs } = await this.SystemContractTestIns.vote(auth, {from: this.producers[3]});
        const log = logs.find(e => e.event === "LogVoteOutMaliciousBP");
        should.exist(log);
        log.args.bp.should.equal(maliciousBP);
    })

    it("normal producers can get reward of voting out malicious bp", async function () {
        const producer = this.producers[0];
        const producersLength = await this.SystemContractTestIns.getProducersLength();
        const deposit = web3.toWei(1, "ether");
        const maliciousDeposit = web3.toWei(5, "ether");
        const exceptReward = maliciousDeposit / producersLength;

        const { logs } = await this.RegSystemContractTestIns2.unregProducer();

        const log = logs.find(e => e.event === "LogUnregProducer");
        should.exist(log);
        log.args.producer.should.equal(producer);
        log.args.maliciousDeposit.should.be.bignumber.equal(maliciousDeposit);
        log.args.producersLen.should.be.bignumber.equal(producersLength);
        const unregTime = log.args.unregTime;
        const afterLockTime = unregTime.toNumber() + duration.hours(72) + duration.minutes(2);
        await increaseTimeTo(afterLockTime);

        const logInfo = await this.RegSystemContractTestIns2.withdrawDeposit({from: producer});
        const withdrawLog = logInfo.logs.find(e => e.event === "LogWithdrawDeposit");
        should.exist(withdrawLog);
        withdrawLog.args.producer.should.equal(producer);
        withdrawLog.args.deposit.should.be.bignumber.equal(deposit);
        withdrawLog.args.rewards.should.be.bignumber.equal(new BigNumber(exceptReward));
    })

    it("vote out producer can not unreg", async function () {
        const bp = accounts[9];
        await assertRevert(this.RegSystemContractTestIns2.unregProducer({from: bp}));
    })

    it("malicious can back to normal if proposal haven't pass", async function () {
        const keys = [];
        const values = [];
        const maliciousBP = this.producers[1];
        const proposer = this.producers[2];

        await this.SystemContractTestIns.propose(keys, values, maliciousBP, voteOutBP, {from: proposer});
        // Malicious bp can not unreg
        await assertRevert(this.RegSystemContractTestIns2.unregProducer({from: maliciousBP}));

        const auth = false;
        await this.SystemContractTestIns.vote(auth, {from: this.producers[3]});
        // await this.SystemContractTestIns.vote(auth, {from: this.producers[3]});

        const { logs } = await this.RegSystemContractTestIns2.unregProducer({from: maliciousBP});
        const log = logs.find(e => e.event = "LogUnregProducer");
        should.exist(log);
    })
})

async function RegProducers(regContract, producers) {
    const name = "test";
    const webUrl = "http://test";
    const p2pUrl = "encode://111";
    const deposit = web3.toWei(1, "ether");

    for (var i = 0; i < producers.length; i++) {
        await regContract.regProducerCandidates(name, webUrl, p2pUrl, {from: producers[i], value: deposit});
    }
}