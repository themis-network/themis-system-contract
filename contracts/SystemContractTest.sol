pragma solidity ^0.4.24;

import "./SystemStorage.sol";
import "./ProducersOpInterface.sol";

// This contract is just a copy of SystemContract.sol to test it since
// system contract will set code and storage in genesis block directly,
// hence it will not execute constructor in contract. But this is not
// convenience for test.
contract SystemContractTest is SystemStorage, ProducersOpInterface {

    Proposal proposal;

    // Just for convenience to get all active producers
    address[] producers;

    uint proposalID = 0;

    enum ProposalType { Default, UpgradeContract, UpdateConfig, VoteOutProducer}

    // Proposal to update or upgrade system contract
    struct Proposal {
        // ID of proposal
        uint id;

        // Active or dead
        bool status;

        // proposer
        address proposer;

        // Time proposing
        uint proposeTime;

        // Address of malicious producer try to vote out
        address maliciousBP;

        // Key array of proposal
        bytes32[] keys;

        // Value array of proposal
        uint[] values;

        // Flag indicates type of proposal
        ProposalType flag;

        // Approve for proposal
        uint approveVoteCount;

        // Disapprove for proposal
        uint disapproveCount;

        // Check a producer vote for this proposal or not
        mapping(uint => mapping(address => bool)) voted;
    }

    event LogPropose(address indexed proposer, bytes32[] keys, uint[] values, address maliciousBP, uint flag);

    event LogVote(uint proposalID, address indexed voter, bool auth);

    event LogApproveProposal(uint proposalID);

    // Mapping key is not necessary since one can not get original name from key
    event LogUpgradeSystemContract(uint[] newAddresses);

    event LogUpdateConfig(uint[] values);

    event LogVoteOutMaliciousBP(address bp);

    // Can only be called by active producer
    modifier onlyActiveProducer() {
        require(uintStorage[keccak256("producer.status", msg.sender)] == 1);
        _;
    }

    // Can only be called by validate type
    modifier onlyValidateType(ProposalType flag) {
        require(flag == ProposalType.UpgradeContract || flag == ProposalType.UpdateConfig || flag == ProposalType.VoteOutProducer);
        _;
    }

    // TODO test purpose
    constructor() public {
        // Init variables
        uintStorage[keccak256("system.proposalPeriod")] = 1 weeks;
        uintStorage[keccak256("system.stakeForVote")] = 1 ether;
        uintStorage[keccak256("system.lockTimeForStake")] = 72 * 60 * 60;

        uintStorage[keccak256("system.depositForProducer")] = 1 ether;
        uintStorage[keccak256("system.lockTimeForDeposit")] = 72 * 60 * 60;
        uintStorage[keccak256("system.producerSize")] = 4;
    }

    /**
     * @dev // TODO just for test
     */
    function setSystemContract(string contractName, address systemContract) public returns(bool) {
        boolStorage[keccak256("system.address", systemContract)] = true;
        addressStorage[keccak256(contractName)] = systemContract;
    }


    /**
     * @dev Producer propose a new proposal for upgrading system contract or update/add
     * @dev system configs
     * @dev Upgrade system contract, keys: contract name, values: addresses converted from uint
     * @dev Update system config, keys: config variables name, values: uint values
     * @dev Flag indicates update config or upgrade contract
     */
    function propose(bytes32[] keys, uint[] values, address maliciousBP, ProposalType flag) public onlyValidateType(flag) onlyActiveProducer {
        // Length of keys and values should be same
        require(keys.length == values.length);
        // 30 variables is enough for contract update
        require(keys.length < 30);
        uint proposalPeriod = uintStorage[keccak256("system.proposalPeriod")];
        // ProposeTime will be zero when no proposal currently.
        require(now > proposal.proposeTime + proposalPeriod || proposal.status == false);

        proposal.proposer = msg.sender;
        proposal.proposeTime = now;
        // Count vote for proposer
        proposal.approveVoteCount = 1;
        proposal.disapproveCount = 0;
        // Set id
        proposalID = proposalID + 1;
        proposal.id = proposalID;
        proposal.status = true;
        // None check for variables which should be done by community
        proposal.keys = keys;
        proposal.values = values;
        proposal.flag = flag;
        proposal.maliciousBP = maliciousBP;

        emit LogPropose(msg.sender, keys, values, maliciousBP, uint(flag));
    }


    /**
     * @dev Producer vote for current proposal
     */
    function vote(bool auth) public onlyActiveProducer {
        // Vote of proposer have been counted
        // Also reject vote if there is not proposal currently(proposer = address(0)
        require(msg.sender != proposal.proposer);
        // Producer haven't vote for this before(can not update vote)
        require(proposal.voted[proposal.id][msg.sender] == false);

        proposal.voted[proposal.id][msg.sender] = true;
        // Record vote
        if (auth) {
            proposal.approveVoteCount = proposal.approveVoteCount + 1;

            uint leastApproveCount = producers.length * 2 / 3 + 1;
            if (proposal.approveVoteCount >= leastApproveCount && proposal.status == true) {
                updateContract();
                // Make next proposal accessible
                proposal.status = false;
            }
        } else {
            proposal.disapproveCount = proposal.disapproveCount + 1;
            uint leastDisapproveCount = producers.length / 3 + 1;
            if (proposal.disapproveCount >= leastDisapproveCount) {
                // Do nothing but make next proposal accessible
                proposal.status = false;
            }
        }

        emit LogVote(proposal.id, msg.sender, auth);
    }


    function addProducer(address producer) public onlyCurrentSystemContract {
        // Record index of producer: actualIndex + 1
        uintStorage[keccak256("producer.index", producer)] = producers.length;
        producers.push(producer);
    }

    /**
     * @dev Remove producer from array, use last item replace producer's index and reduce
     * @dev Array's length
     */
    function removeProducer(address producer) public onlyCurrentSystemContract {
        removeProducerInternal(producer);
    }

    function getProducers() external view returns(address[]) {
        return producers;
    }

    function getProducersLength() external view returns(uint) {
        return producers.length;
    }

    function getSystemContract(string contractName) public view returns(address) {
        return addressStorage[keccak256(contractName)];
    }


    /**
     * @dev Update contract related info based on current proposal
     */
    function updateContract() internal {
        uint i = 0;
        // Update reg system contract
        if (proposal.flag == ProposalType.UpgradeContract) {
            // Update system contract address
            for (; i < proposal.keys.length; i++) {
                address originalContract = addressStorage[proposal.keys[i]];
                boolStorage[keccak256("system.address", originalContract)] = false;
                address newAddress= address(proposal.values[i]);
                if (newAddress == address(0)) {
                    continue;
                }
                boolStorage[keccak256("system.address", newAddress)] = true;
                addressStorage[proposal.keys[i]] = newAddress;
            }

            emit LogUpgradeSystemContract(proposal.values);
            return;
        }

        if (proposal.flag == ProposalType.UpdateConfig) {
            // Update contract config variables
            for (i = 0; i < proposal.keys.length; i++) {
                // None check
                uintStorage[proposal.keys[i]] = proposal.values[i];
            }

            emit LogUpdateConfig(proposal.values);
            return;
        }

        if (proposal.flag == ProposalType.VoteOutProducer) {
            uint status = uintStorage[keccak256("producer.status", proposal.maliciousBP)];
            if (status == 1) {
                removeProducerInternal(proposal.maliciousBP);
            }
            // Set status to beenVotedOut, one can not do nothing after
            uintStorage[keccak256("producer.status", proposal.maliciousBP)] = 3;
            // TODO add deposit of maliciousBP to other bp

            emit LogVoteOutMaliciousBP(proposal.maliciousBP);
            return ;
        }

        revert();
    }


    /**
     * @dev Remove producer from array
     */
    function removeProducerInternal(address producer) internal {
        require(producers.length > 0);
        uint index = uintStorage[keccak256("producer.index", producer)];
        uint lastIndex = producers.length - 1;

        require(index >= 0 && index < producers.length);
        // Remove last item
        if (index == lastIndex) {
            producers.length = lastIndex;
            return;
        }

        // Replace index with last item and reduce length of producers
        // Will change some producer index
        producers[index] = producers[lastIndex];
        // Update index of producer
        uintStorage[keccak256("producer.index", producers[lastIndex])] = index;
        // Delete last item
        producers.length--;
    }
}
