import assertRevert from "zeppelin-solidity/test/helpers/assertRevert";

const SystemContractTest = artifacts.require("./SystemContractTest");
const VoteSystemContractTest = artifacts.require("./VoteSystemContractTest");
const RegSystemContractTest = artifacts.require("./RegSystemContractTest");

const BigNumber = web3.BigNumber;
const should = require('chai')
    .use(require('chai-as-promised'))
    .use(require('chai-bignumber')(BigNumber))
    .should();

contract("Upgradeable contract", function (accounts) {

    before(async function () {
        this.SystemContractTestIns = await SystemContractTest.new();
        this.VoteSystemContractTestIns = await VoteSystemContractTest.new(this.SystemContractTestIns.address);
        this.RegSystemContractTestIns = await RegSystemContractTest.new(this.SystemContractTestIns.address);
        await this.SystemContractTestIns.setSystemContract(1, this.VoteSystemContractTestIns.address);
        await this.SystemContractTestIns.setSystemContract(0, this.RegSystemContractTestIns.address);
        // Reg 4 producers
        await RegProducers(this.RegSystemContractTestIns, accounts);
    })

    it("producer can propose a proposal for upgrading reg system contract", async function () {
        const producer = accounts[1];
        // Reg contract
        const contractType = 0;
        // Just pass a address (the validation for contract will be done by community offline)
        const newAddress = accounts[0];

        const { logs } = await this.SystemContractTestIns.propose(contractType, newAddress, {from: producer});
        const log = logs.find(e => e.event === "LogPropose");
        should.exist(log);
        log.args.proposer.should.equal(producer);
        log.args.contractType.should.be.bignumber.equal(new BigNumber(contractType));
        log.args.newContract.should.equal(newAddress);
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

    it("can update system contract address when vote reach length*2/3 + 1", async function () {
        const producer2 = accounts[3];
        const auth = true;

        // Reg contract
        const contractType = 0;
        // Just pass a address (the validation for contract will be done by community offline)
        const newAddress = accounts[0];

        // Reach least vote amount and should update system contract
        const { logs } = await this.SystemContractTestIns.vote(auth, {from: producer2});
        const log = logs.find(e => e.event === "LogUpdateSystemContract");
        should.exist(log);
        log.args.contractType.should.be.bignumber.equal(new BigNumber(contractType));
        log.args.newContract.should.equal(newAddress);

        const updatedContract = await this.SystemContractTestIns.getRegSystemContract();
        updatedContract.should.equal(newAddress);
    })

    it("original reg system can not use", async function () {
        // Original system contract will be disabled and can not reg producer
        const producer4 = accounts[5];
        const name = "test"
        const webUrl = "http://test"
        const p2pUrl = "encode://111"
        const deposit = web3.toWei(1, "ether")
        await assertRevert(this.RegSystemContractTestIns.regProducerCandidates(name, webUrl, p2pUrl, {from: producer4, value: deposit}));
    })

    it("producer can propose a proposal for upgrading vote system contract", async function () {
        const producer = accounts[1];
        // Reg contract
        const contractType = 1;
        // Just pass a address (the validation for contract will be done by community offline)
        const newAddress = accounts[0];

        const { logs } = await this.SystemContractTestIns.propose(contractType, newAddress, {from: producer});
        const log = logs.find(e => e.event === "LogPropose");
        should.exist(log);
        log.args.proposer.should.equal(producer);
        log.args.contractType.should.be.bignumber.equal(new BigNumber(contractType));
        log.args.newContract.should.equal(newAddress);
    })

    it("other producers can vote for this proposal", async function() {
        const producer = accounts[2];
        const producer2 = accounts[3];
        const auth = true;

        // Vote contract
        const contractType = 1;
        // Just pass a address (the validation for contract will be done by community offline)
        const newAddress = accounts[0];

        await this.SystemContractTestIns.vote(auth, {from: producer});
        const { logs } = await this.SystemContractTestIns.vote(auth, {from: producer2});
        const log = logs.find(e => e.event === "LogUpdateSystemContract");
        should.exist(log);
        log.args.contractType.should.be.bignumber.equal(new BigNumber(contractType));
        log.args.newContract.should.equal(newAddress);
    })

    it("origianl vote system contract can not use", async function () {
        const voter = accounts[9];
        const stake = web3.toWei(3, "ether");

        var producers = [];
        const producer = accounts[1];
        producers.push(producer);

        await assertRevert(this.VoteSystemContractTestIns.userVote(0, producers, {from: voter, value: stake}));
    })

})

async function RegProducers(regContract, accounts) {
    const producer0 = accounts[1];
    const producer1 = accounts[2];
    const producer2 = accounts[3];
    const producer3 = accounts[4];
    const name = "test"
    const webUrl = "http://test"
    const p2pUrl = "encode://111"
    const deposit = web3.toWei(1, "ether")

    await regContract.regProducerCandidates(name, webUrl, p2pUrl, {from: producer0, value: deposit});
    await regContract.regProducerCandidates(name, webUrl, p2pUrl, {from: producer1, value: deposit});
    await regContract.regProducerCandidates(name, webUrl, p2pUrl, {from: producer2, value: deposit});
    await regContract.regProducerCandidates(name, webUrl, p2pUrl, {from: producer3, value: deposit});
}