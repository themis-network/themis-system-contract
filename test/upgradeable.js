import assertRevert from "zeppelin-solidity/test/helpers/assertRevert";

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
        await RegProducers(this.RegSystemContractTestIns, accounts);
    })

    it("producer can propose a proposal for upgrading reg system contract", async function () {
        const producer = accounts[1];
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
        const producer = accounts[2];
        const auth = true;

        const { logs } = await this.SystemContractTestIns.vote(auth, {from: producer});
        const log = logs.find(e => e.event === "LogVote");
        log.args.voter.should.equal(producer);
        log.args.auth.should.equal(auth);
    })

    it("can not propose a new proposal if a proposal already exist and not after proposal period", async function () {
        const producer = accounts[2];
        const newAddress = accounts[1];
        const keys = [];
        keys.push(voteContractMappingKey);
        const value = [];
        value.push(newAddress);

        await assertRevert(this.SystemContractTestIns.propose(keys, value, 0, upgradeContract, {from: producer}));
    })

    it("only main contract can destruct system contract", async function () {
        // Use a test account to call destruct func
        const acc = accounts[3]
        const newAddress = accounts[4]
        await assertRevert(this.RegSystemContractTestIns.destructSelf(newAddress), {from: acc})
    })

    it("can update system contract address/send get coin to new contract when vote reach length*2/3 + 1", async function () {
        const producer2 = accounts[3];
        const auth = true;

        const oriBalance = await web3.eth.getBalance(this.RegSystemContractTestIns.address);

        // Update system contract if votes bigger than 2/3
        const { logs } = await this.SystemContractTestIns.vote(auth, {from: producer2});
        const log = logs.find(e => e.event === "LogUpgradeSystemContract");
        should.exist(log);

        const updatedContract = await this.SystemContractTestIns.getSystemContract(regContractName);
        updatedContract.should.equal(this.RegSystemContractTestIns2.address);

        const afterBalance = await web3.eth.getBalance(this.RegSystemContractTestIns.address);
        afterBalance.should.be.bignumber.equal(new BigNumber(0));

        const newBalance = await web3.eth.getBalance(this.RegSystemContractTestIns2.address);
        newBalance.should.be.bignumber.equal(oriBalance);
    })

    it("original system can not use", async function () {
        // Original system contract will be destructed
        // Original code should be deleted
        const code = web3.eth.getCode(this.RegSystemContractTestIns.address);
        code.should.equal("0x0");
    })

    it("can propose/pass update config once original passed", async function () {
        const producer = accounts[1];
        const keys = [];
        const var0 = web3.sha3("system.proposalPeriod");
        const var1 = web3.sha3("system.stakeForVote");
        const var2 = web3.sha3("system.lockTimeForStake");
        keys.push(var0);
        keys.push(var1);
        keys.push(var2);

        const values = [];
        const value0 = 2 * 72 * 60 * 60;
        const value1 = web3.toWei(2, "ether");
        const value2 = 3 * 72 * 60 * 60;
        values.push(value0);
        values.push(value1);
        values.push(value2);

        await this.SystemContractTestIns.propose(keys, values, 0, updateConfig, {from: producer});

        // vote for this proposal
        const producer1 = accounts[2];
        const producer2 = accounts[3];
        const producer3 = accounts[4];
        const auth = true;

        await this.SystemContractTestIns.vote(auth, {from: producer1});
        await this.SystemContractTestIns.vote(auth, {from: producer2});
        await this.SystemContractTestIns.vote(auth, {from: producer3});

        const newValue0 = await this.SystemContractTestIns.getUint(var0);
        const newValue1 = await this.SystemContractTestIns.getUint(var1);
        const newValue2 = await this.SystemContractTestIns.getUint(var2);

        newValue0.should.be.bignumber.equal(new BigNumber(value0));
        newValue1.should.be.bignumber.equal(value1);
        newValue2.should.be.bignumber.equal(new BigNumber(value2));
    })

    it("can propose/pass vote out malicious producer", async function () {
        const producer = accounts[1];
        const keys = [];
        const values = [];
        const maliciousBP = accounts[2];

        await this.SystemContractTestIns.propose(keys, values, maliciousBP, voteOutBP, {from: producer});

        const producer1 = accounts[3];
        const producer2 = accounts[4];
        const auth = true;

        await this.SystemContractTestIns.vote(auth, {from: producer1});
        const { logs } = await this.SystemContractTestIns.vote(auth, {from: producer2});
        const log = logs.find(e => e.event === "LogVoteOutMaliciousBP");
        should.exist(log);
        log.args.bp.should.equal(maliciousBP);
    })

    it("vote out producer can not unreg", async function () {
        const bp = accounts[2];
        await assertRevert(this.RegSystemContractTestIns2.unregProducer({from: bp}));
    })
})

async function RegProducers(regContract, accounts) {
    const producer0 = accounts[1];
    const producer1 = accounts[2];
    const producer2 = accounts[3];
    const producer3 = accounts[4];
    const name = "test";
    const webUrl = "http://test";
    const p2pUrl = "encode://111";
    const deposit = web3.toWei(1, "ether");

    await regContract.regProducerCandidates(name, webUrl, p2pUrl, {from: producer0, value: deposit});
    await regContract.regProducerCandidates(name, webUrl, p2pUrl, {from: producer1, value: deposit});
    await regContract.regProducerCandidates(name, webUrl, p2pUrl, {from: producer2, value: deposit});
    await regContract.regProducerCandidates(name, webUrl, p2pUrl, {from: producer3, value: deposit});
}