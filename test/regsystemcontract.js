import assertRevert from "zeppelin-solidity/test/helpers/assertRevert";
import { increaseTimeTo, duration } from "zeppelin-solidity/test/helpers/increaseTime"

const RegSystemContractTest = artifacts.require("./RegSystemContractTest");
const SystemContractTest = artifacts.require("./SystemContractTest");

const BigNumber = web3.BigNumber;
const should = require('chai')
    .use(require('chai-as-promised'))
    .use(require('chai-bignumber')(BigNumber))
    .should();

contract("Reg System Contract", function (accounts) {

    before(async function () {
        this.SystemContractTestIns = await SystemContractTest.new();
        this.RegSystemContractTestIns = await RegSystemContractTest.new(this.SystemContractTestIns.address);
        // Set contract address(only used in test)
        await this.SystemContractTestIns.setSystemContract(0, this.RegSystemContractTestIns.address);
    })


    it("producer can reg", async function () {
        const producer = accounts[1];
        const name = "test"
        const webUrl = "http://test"
        const p2pUrl = "encode://111"
        const deposit = web3.toWei(1, "ether")

        // Reg producer
        const { logs } = await this.RegSystemContractTestIns.regProducerCandidates(name, webUrl, p2pUrl, {from: producer, value: deposit});
        const log = logs.find(e => e.event === "LogRegProducerCandidates");
        should.exist(log);
        log.args.producer.should.equal(producer);
        log.args.name.should.equal(name);
        log.args.webUrl.should.equal(webUrl);
        log.args.p2pUrl.should.equal(p2pUrl);
        log.args.deposit.should.be.bignumber.equal(deposit);

        const producer2 = accounts[0];
        const logs2 = await this.RegSystemContractTestIns.regProducerCandidates(name, webUrl, p2pUrl, {from: producer2, value: deposit});
        const log2 = logs2.logs.find(e => e.event === "LogRegProducerCandidates");
        should.exist(log2);
        log2.args.producer.should.equal(producer2);
        log2.args.name.should.equal(name);
        log2.args.webUrl.should.equal(webUrl);
        log2.args.p2pUrl.should.equal(p2pUrl);
        log2.args.deposit.should.be.bignumber.equal(deposit);


        const newProducers = await this.RegSystemContractTestIns.getProducers();
        newProducers.length.should.equal(2);
    })

    it("producer can't reg twice", async function () {
        const producer = accounts[1];
        const name = "test"
        const webUrl = "http://test"
        const p2pUrl = "encode://111"
        const deposit = web3.toWei(1, "ether")

        // Can't reg twice
        await assertRevert(this.RegSystemContractTestIns.regProducerCandidates(name, webUrl, p2pUrl, {from: producer, value: deposit}));
    })

    it("producer can't reg if amount of deposited GET is not same with default", async function () {
        const producer = accounts[3];
        const name = "test"
        const webUrl = "http://test"
        const p2pUrl = "encode://111"
        const deposit = web3.toWei(0.5, "ether");

        // Can't reg is deposit is not same with default amount(1 GET)
        await assertRevert(this.RegSystemContractTestIns.regProducerCandidates(name, webUrl, p2pUrl, {from: producer, value: deposit}));
    })


    it("producer can update producer's info", async function () {
        const producer = accounts[1];
        const newName = "newNamePro";
        const newWebUrl = "http://newWeb";
        const newP2PUrl = "encode://newEncode";

        const { logs } = await this.RegSystemContractTestIns.updateProducerCandidatesInfo(newName, newWebUrl, newP2PUrl, {from: producer});
        const log = logs.find(e => e.event === "LogUpdateProducerInfo");
        should.exist(log);
        log.args.producer.should.equal(producer);
        log.args.newName.should.equal(newName);
        log.args.newWebUrl.should.equal(newWebUrl);
        log.args.newP2PUrl.should.equal(newP2PUrl);
    })


    it("proxy can reg", async function () {
        const proxy = accounts[2];

        const { logs } = await this.RegSystemContractTestIns.regProxy({from: proxy});
        const log = logs.find(e => e.event === "LogRegProxy");
        should.exist(log);
        log.args.proxy.should.equal(proxy);
    })

    it("proxy can't reg twice", async function () {
        const proxy = accounts[2];

        // Can't reg twice
        await assertRevert(this.RegSystemContractTestIns.regProxy({from: proxy}));
    })


    it("producer can unreg", async function () {
        const producer = accounts[1];
        const producer2 = accounts[0];

        const { logs } = await this.RegSystemContractTestIns.unregProducer({from: producer});
        const log = logs.find(e => e.event === "LogUnregProducer");
        should.exist(log);
        log.args.producer.should.equal(producer);

        await this.RegSystemContractTestIns.unregProducer({from: producer2});
        const producers = await this.RegSystemContractTestIns.getProducers();
        producers.length.should.equal(0);
    })


    it("producer can be right removed from array", async function () {
        const producer = accounts[3];
        const name = "producerName";
        const webUrl = "http://themis"
        const p2pUrl = "encode://"
        const deposit = web3.toWei(1, "ether")

        await this.RegSystemContractTestIns.regProducerCandidates(name, webUrl, p2pUrl, {from: producer, value: deposit});
        const producers = await this.RegSystemContractTestIns.getProducers();
        producers.length.should.equal(1);

        const producer_2 = accounts[4];
        await this.RegSystemContractTestIns.regProducerCandidates(name, webUrl, p2pUrl, {from: producer_2, value: deposit});
        const producer_3 = accounts[5];
        await this.RegSystemContractTestIns.regProducerCandidates(name, webUrl, p2pUrl, {from: producer_3, value: deposit});
        const newProducers = await this.RegSystemContractTestIns.getProducers();
        newProducers.length.should.equal(3);

        await this.RegSystemContractTestIns.unregProducer({from: producer});
        await this.RegSystemContractTestIns.unregProducer({from: producer_2});
        await this.RegSystemContractTestIns.unregProducer({from: producer_3});

        const producer4 = accounts[6];
        const producer5 = accounts[7];
        const producer6 = accounts[8];
        const producer7 = accounts[9];

        await this.RegSystemContractTestIns.regProducerCandidates(name, webUrl, p2pUrl, {from: producer4, value: deposit});
        await this.RegSystemContractTestIns.regProducerCandidates(name, webUrl, p2pUrl, {from: producer5, value: deposit});
        await this.RegSystemContractTestIns.regProducerCandidates(name, webUrl, p2pUrl, {from: producer6, value: deposit});
        await this.RegSystemContractTestIns.regProducerCandidates(name, webUrl, p2pUrl, {from: producer7, value: deposit});

        const finalProducers = await this.RegSystemContractTestIns.getProducers();
        finalProducers.length.should.equal(4);
        inArray(finalProducers, producer4).should.equal(true);
        inArray(finalProducers, producer5).should.equal(true);
        inArray(finalProducers, producer6).should.equal(true);
        inArray(finalProducers, producer7).should.equal(true);
    })

    it("producer can't withdraw deposit when not unreg", async function () {
        const producer = accounts[8];

        await assertRevert(this.RegSystemContractTestIns.withdrawDeposit({from: producer}));
    })

    it("producer can't withdraw deposit when not after lock time", async function () {
        const producer = accounts[8];

        const { logs } = await this.RegSystemContractTestIns.unregProducer({from: producer});
        const log = logs.find(e => e.event === "LogUnregProducer");
        const unregTime = log.args.unregTime;
        const beforeLockTime = unregTime.toNumber() + duration.hours(71) + duration.minutes(58);
        await increaseTimeTo(beforeLockTime);

        await assertRevert(this.RegSystemContractTestIns.withdrawDeposit({from: producer}));
    })


    it("producer can withdraw deposit after lock time", async function () {
        const producer = accounts[9];
        const deposit = web3.toWei(1, "ether");

        // Unreg and increase time to when after lock time
        const { logs } = await this.RegSystemContractTestIns.unregProducer({from: producer});
        const log = logs.find(e => e.event === "LogUnregProducer");
        const unregTime = log.args.unregTime;
        const afterLockTime = unregTime.toNumber() + duration.hours(72) + duration.minutes(2);
        await increaseTimeTo(afterLockTime);

        const logInfo = await this.RegSystemContractTestIns.withdrawDeposit({from: producer});
        const withdrawLog = logInfo.logs.find(e => e.event === "LogWithdrawDeposit");
        should.exist(withdrawLog);
        withdrawLog.args.producer.should.equal(producer);
        withdrawLog.args.deposit.should.be.bignumber.equal(deposit);
    })


    it("producer can reg again after withdraw deposit", async function () {
        const producer = accounts[9];
        const name = "test"
        const webUrl = "http://test"
        const p2pUrl = "encode://111"
        const deposit = web3.toWei(1, "ether")

        // Reg producer
        const { logs } = await this.RegSystemContractTestIns.regProducerCandidates(name, webUrl, p2pUrl, {from: producer, value: deposit});
        const log = logs.find(e => e.event === "LogRegProducerCandidates");
        should.exist(log);
        log.args.producer.should.equal(producer);
        log.args.name.should.equal(name);
        log.args.webUrl.should.equal(webUrl);
        log.args.p2pUrl.should.equal(p2pUrl);
        log.args.deposit.should.be.bignumber.equal(deposit);

        // All other's info should be updated.
        const voteWeight = await this.RegSystemContractTestIns.getProducer(producer);
        voteWeight.should.be.bignumber.equal(new BigNumber(0));
    })


    it("proxy can unreg", async function () {
        const proxy = accounts[2];

        const { logs } = await this.RegSystemContractTestIns.unregProxy({from: proxy});
        const log = logs.find(e => e.event === "LogUnregProxy");
        should.exist(log);
        log.args.proxy.should.equal(proxy);
    })

})

// check the item is in datas or not
function inArray(datas, item) {
    for (var i = 0; i < datas.length; i++) {
        if (datas[i] == item) {
            return true;
        }
    }
    return false;
}