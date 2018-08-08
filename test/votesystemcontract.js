const SystemContractTest = artifacts.require("./SystemContractTest");
const VoteSystemContractTest = artifacts.require("./VoteSystemContractTest");
const RegSystemContractTest = artifacts.require("./RegSystemContractTest");


const BigNumber = web3.BigNumber;
const should = require('chai')
    .use(require('chai-as-promised'))
    .use(require('chai-bignumber')(BigNumber))
    .should();

const Address0 = "0x0000000000000000000000000000000000000000";

contract("Vote system contract", function (accounts) {

    before(async function () {
        this.SystemContractTestIns = await SystemContractTest.new();
        this.VoteSystemContractTestIns = await VoteSystemContractTest.new(this.SystemContractTestIns.address);
        this.RegSystemContractTestIns = await RegSystemContractTest.new(this.SystemContractTestIns.address);
        await this.SystemContractTestIns.setSystemContract(this.VoteSystemContractTestIns.address);
        await this.SystemContractTestIns.setSystemContract(this.RegSystemContractTestIns.address);
        await RegProducers(this.RegSystemContractTestIns, accounts);
    })

    it("user can vote for producer", async function () {
        const producer = accounts[1];
        const user = accounts[4];
        const deposit = web3.toWei(2, "ether");
        var producers = [];
        producers.push(producer);

        const votedWeightBefore = await this.RegSystemContractTestIns.getProducer(producer);

        const { logs } = await this.VoteSystemContractTestIns.userVote(0, producers, {from: user, value: deposit});
        const log = logs.find(e => e.event === "LogUserVote");
        should.exist(log);
        log.args.voter.should.equal(user);
        log.args.proxy.should.equal(Address0);
        log.args.producers[0].should.equal(producer);
        log.args.staked.should.be.bignumber.equal(deposit);

        // check for producer's vote weight
        const votedWeightAfter = await this.RegSystemContractTestIns.getProducer(producer);
        votedWeightAfter.sub(votedWeightBefore).should.be.bignumber.equal(calculateWeight(deposit));
    })

    it("user can vote for proxy", async function () {
        const proxy = accounts[3];
        const user = accounts[5];
        const deposit = web3.toWei(3, "ether");

        const weightKey = web3.sha3(contact("vote.weight", proxy), {encoding: 'hex'});
        const proxyWeightBefore = await this.SystemContractTestIns.getUint(weightKey, {encoding: 'hex'});

        const { logs } = await this.VoteSystemContractTestIns.userVote(proxy, [], {from: user, value: deposit});
        const log = logs.find(e => e.event === "LogUserVote");
        log.args.voter.should.equal(user);
        log.args.proxy.should.equal(proxy);
        compareArray(log.args.producers, []).should.equal(true);
        log.args.staked.should.be.bignumber.equal(deposit);

        // check proxy's weight
        // proxy not vote for producers, not need to check for related producer's weight
        const proxyWeightAfter = await this.SystemContractTestIns.getUint(weightKey, {encoding: 'hex'});
        proxyWeightAfter.sub(proxyWeightBefore).should.be.bignumber.equal(calculateWeight(deposit));
    })


    it("proxy can vote for producers", async function () {
        const proxy = accounts[3];
        const producer = accounts[1];
        const producers = [];
        producers.push(producer);

        const weightKey = web3.sha3(contact("producer.voteWeight", producer), {encoding: 'hex'});
        const weightBefore = await this.SystemContractTestIns.getUint(weightKey);

        const { logs } = await this.VoteSystemContractTestIns.proxyVote(producers, {from:proxy});
        const log = logs.find(e => e.event === "LogProxyVote");
        log.args.proxy.should.equal(proxy);
        compareArray(producers, log.args.producers).should.equal(true);

        // Use const weight
        const proxyWeight = web3.toWei(3, "ether");
        const weightAfter = await this.SystemContractTestIns.getUint(weightKey);
        weightAfter.sub(weightBefore).should.be.bignumber.equal(proxyWeight);
    })

    it("can get all producer's info", async function () {
        const producersInfo = await this.RegSystemContractTestIns.getAllProducersInfo();
        const producer0 = accounts[1];
        const producer1 = accounts[2];

        // Check producer address
        producersInfo[0][0].should.equal(producer0);
        producersInfo[0][1].should.equal(producer1);

        // Check for weight
        const producer0Weight = web3.toWei(5, "ether");
        const producer1Weight = new BigNumber(0);
        producersInfo[1][0].should.be.bignumber.equal(producer0Weight);
        producersInfo[1][1].should.be.bignumber.equal(producer1Weight);

        // Default length of producers will be used
        producersInfo[2].should.be.bignumber.equal(new BigNumber(4));
    })

    // Contract get the producers or proxy user voted automatically
    it("user can unvote", async function () {
        const user = accounts[4];
        const producer = accounts[1];

        const votedWeightBefore = await this.RegSystemContractTestIns.getProducer(producer);

        const { logs } = await this.VoteSystemContractTestIns.userUnvote({from: user});
        const log = logs.find(e => e.event === "LogUserUnvote");
        log.args.user.should.equal(user);

        // This voter vote for producer, so just check weight of producers
        // Use const weight
        const userWeight = web3.toWei(2, "ether");
        const votedWeightAfter = await this.RegSystemContractTestIns.getProducer(producer);
        votedWeightBefore.sub(votedWeightAfter).should.be.bignumber.equal(userWeight);
    })

    it("proxy can unvote", async function () {
        const proxy = accounts[3];
        const producer = accounts[1];
        const votedWeightBefore = await this.RegSystemContractTestIns.getProducer(producer);

        const { logs } = await this.VoteSystemContractTestIns.proxyUnvote({from: proxy});
        const log = logs.find(e => e.event === "LogProxyUnvote");
        log.args.proxy.should.equal(proxy);

        const votedWeightAfter = await this.RegSystemContractTestIns.getProducer(producer);
        // Use const weight
        const proxyWeight = web3.toWei(3, "ether");
        votedWeightBefore.sub(votedWeightAfter).should.be.bignumber.equal(proxyWeight);
    })

})

async function RegProducers(regContract, accounts) {
    const producer0 = accounts[1];
    const producer1 = accounts[2];
    const name = "test"
    const webUrl = "http://test"
    const p2pUrl = "encode://111"
    const deposit = web3.toWei(1, "ether")

    await regContract.regProducerCandidates(name, webUrl, p2pUrl, {from: producer0, value: deposit});
    await regContract.regProducerCandidates(name, webUrl, p2pUrl, {from: producer1, value: deposit});

    const proxy = accounts[3];
    await regContract.regProxy({from: proxy});
}

function compareArray(src, dst) {
    if (src.length != dst.length) {
        return false;
    }

    for (var i = 0; i < src.length; i++) {
        if (src[i] != dst[i]) {
            return false;
        }
    }

    return true;
}

function calculateWeight(staked) {
    return new BigNumber(1).mul(staked);
}

function contact(a, b) {
    var aHex = web3.toHex(a);
    var bHex = web3.toHex(b);

    return aHex.slice(2) + bHex.slice(2);
}
