pragma solidity ^0.4.24;

import "./SystemStorage.sol";
import "./ProducersOpInterface.sol";


contract SystemContract is SystemStorage, ProducersOpInterface {

    uint proposalWaitTime = 1 weeks;

    Proposal proposal;

    // Just for convenience to get all producers
    address[] producers;

    // Proposal to update vote or reg system contract
    struct Proposal {
        // proposer
        address proposer;

        // Time proposing
        uint proposeTime;

        // 0 => reg system contract; 1 => vote system contract
        uint contractType;

        // Address of new system contract
        address newContractAddress;

        // Approve for upgrading system contract
        uint approveVoteCount;

        // Check a producer voted or not
        mapping(address => bool) voted;

        // Array of all voters
        address[] voters;
    }

    event LogPropose(address indexed proposer, uint contractType, address newContract);

    event LogVote(address indexed voter, bool auth);

    event LogUpdateSystemContract(uint contractType, address newContract);

    // Can only be called by active producer
    modifier onlyActiveProducer() {
        require(uintStorage[keccak256("producer.status", msg.sender)] == 1);
        _;
    }


    /**
     * @dev Producer propose a new proposal for upgrading system contract
     */
    function propose(uint contractType, address newSystemContract) public onlyActiveProducer {
        require(newSystemContract != address(0));
        require(contractType == 0 || contractType == 1);
        // It's ok when no proposal currently. proposeTime will be zero
        require(proposalWaitTime + now > proposal.proposeTime);

        proposal.proposer = msg.sender;
        proposal.proposeTime = now;
        proposal.contractType = contractType;
        proposal.newContractAddress = newSystemContract;
        // Count vote for proposer
        proposal.approveVoteCount = 1;

        // Reset all vote flag
        address[] memory voters = proposal.voters;
        for (uint i = 0; i < voters.length; i++) {
            proposal.voted[voters[i]] = false;
        }
        // Delete all original voters
        delete proposal.voters;

        emit LogPropose(msg.sender, contractType, newSystemContract);
    }


    /**
     * @dev Producer vote for current proposal
     */
    function vote(bool auth) public onlyActiveProducer {
        // Vote of proposer have been counted
        // Also reject vote if there is not proposal currently(proposer = address(0)
        require(msg.sender != proposal.proposer);
        // Producer haven't vote for this before(can not update vote)
        require(proposal.voted[msg.sender] == false);

        proposal.voted[msg.sender] = true;
        proposal.voters.push(msg.sender);
        // Only record approbation for this proposal
        if (auth) {
            proposal.approveVoteCount = proposal.approveVoteCount + 1;

            uint leastApproveCount = producers.length * 2 / 3 + 1;
            if (proposal.approveVoteCount >= leastApproveCount) {
                updateSystemContract(proposal.contractType, proposal.newContractAddress);
            }
        }

        emit LogVote(msg.sender, auth);
    }

    function addProducer(address producer) public  {
        // Record index of producer: actualIndex + 1
        uintStorage[keccak256("producer.index", producer)] = producers.length;
        producers.push(producer);
    }

    /**
     * @dev Remove producer from array, use last item replace producer's index and reduce
     * @dev Array's length
     */
    function removeProducer(address producer) public onlyCurrentSystemContract {
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

    function getProducers() external view returns(address[]) {
        return producers;
    }

    function getProducersLength() external view returns(uint) {
        return producers.length;
    }

    function getVoteSystemContract() public returns(address) {
        return addressStorage[keccak256("system.voteSystemContract")];
    }

    function getRegSystemContract() public returns(address) {
        return addressStorage[keccak256("system.regSystemContract")];
    }


    /**
     * @dev Set new system contract
     */
    function updateSystemContract(uint contractType, address newContractAddress) internal {
        // Update reg system contract
        if (contractType == 0) {
            address originalRegContract = addressStorage[keccak256("system.regSystemContract")];
            boolStorage[keccak256("system.address", originalRegContract)] = false;
            addressStorage[keccak256("system.regSystemContract")] = newContractAddress;
        }

        if (contractType == 1) {
            address originalVoteContract = addressStorage[keccak256("system.voteSystemContract")];
            boolStorage[keccak256("system.address", originalVoteContract)] = false;
            addressStorage[keccak256("system.voteSystemContract")] = newContractAddress;
        }

        emit LogUpdateSystemContract(contractType, newContractAddress);
    }
}
