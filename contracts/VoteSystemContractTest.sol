pragma solidity ^0.4.0;

import "./StorageInterface.sol";
import "./libraries/SafeMath.sol";

contract VoteSystemContractTest {

    using SafeMath for uint256;

    // 00:00:00 1/1/3000 for init out time
    uint initOutTime = 32503651200;

    // TODO event
    StorageInterface systemStorage = StorageInterface(0);

    constructor(address mainStorage) public {
        require(mainStorage != address(0));
        systemStorage = StorageInterface(mainStorage);
    }

    /**
     * @dev User vote for producer or proxy, if proxy is set, the producer's address will be ignored
     * @param proxy Proxy user want to vote for
     * @param accounts Producer user want to vote for
     */
    function userVote(address proxy, address[] accounts) external payable returns(bool) {
        // producer => 1; proxy => 2; voter => 3;
        // User haven't vote before
        require(systemStorage.getUint(keccak256("user.role", msg.sender)) == 0);
        // User should stake GET for vote at first time
        require(msg.value >= systemStorage.getUint(keccak256("system.leastDepositForVote")));
        // Producer/Proxy should have reg and be active
        if (proxy != address(0)) {
            // Check proxy
            require(systemStorage.getUint(keccak256("user.role", proxy)) == 2);
            require(systemStorage.getUint(keccak256("proxy.status", proxy)) == 1);
            systemStorage.setAddress(keccak256("vote.voteProxy", msg.sender), proxy);
        } else {
            validateProducers(accounts);
            systemStorage.setAddressArray(keccak256("vote.voteProducers", msg.sender), accounts);
        }

        /**
         * Update vote info, check after
         */
        // Update role of voter
        systemStorage.setUint(keccak256("user.role", msg.sender), 3);
        // Update amount of get coin staked by this voter
        systemStorage.setUint(keccak256("vote.staked", msg.sender), msg.value);
        // Set vote weight
        uint weight = calculateWeight(msg.value);
        systemStorage.setUint(keccak256("vote.weight", msg.sender), weight);
        // Set status of vote
        systemStorage.setUint(keccak256("vote.status", msg.sender), 1);
        // Set init unreachable unvote time
        systemStorage.setUint(keccak256("vote.unvoteTime", msg.sender), initOutTime);


        /**
         * Update related vote info
         */
        // Vote for proxy
        if (proxy != address(0)) {
            // Update proxy's vote weight delegated by votes
            systemStorage.setUint(keccak256("vote.weight", proxy), systemStorage.getUint(keccak256("vote.weight", proxy)).add(weight));

            // If proxy have vote for producers, update related weight of producers. otherwise, do nothing
            // Not necessary to check status of proxy's vote, because unvote will delete voted producers
            updateReleatedProducersVoteWeight(proxy, weight, true);
            return true;
            // Vote for producers
        } else {
            // Update producer's vote weight
            for(uint i = 0; i < accounts.length; i++) {
                systemStorage.setUint(keccak256("producer.voteWeight", accounts[i]), systemStorage.getUint(keccak256("producer.voteWeight", accounts[i])).add(weight));
            }
        }

        return true;
    }


    /**
     * @dev Proxy vote for producer. If proxy have vote before, just update it to new one.
     * @param accounts Address of producers proxy want to vote
     */
    function proxyVote(address[] accounts) external returns(bool) {

        // producer => 1; proxy => 2; voter => 3;
        require(systemStorage.getUint(keccak256("user.role", msg.sender)) == 2);
        // Every producer should have reg and active
        validateProducers(accounts);

        /**
         * Update vote info for proxy and related producer
         */
        uint proxyWeight = systemStorage.getUint(keccak256("vote.weight", msg.sender));
        address[] memory votedProducers = systemStorage.getAddressArray(keccak256("vote.voteProducers", msg.sender));
        if (votedProducers.length == 0) {
            // Proxy vote for producer at first time
            for(i = 0; i < accounts.length; i++) {
                systemStorage.setUint(keccak256("producer.voteWeight", accounts[i]), systemStorage.getUint(keccak256("producer.voteWeight", accounts[i])).add(proxyWeight));
            }
        } else {
            // Proxy have voted before
            for(uint i = 0; i < votedProducers.length; i++) {
                systemStorage.setUint(keccak256("producer.voteWeight", votedProducers[i]), systemStorage.getUint(keccak256("producer.voteWeight", votedProducers[i])).sub(proxyWeight));
            }

            for(i = 0; i < accounts.length; i++) {
                systemStorage.setUint(keccak256("producer.voteWeight", accounts[i]), systemStorage.getUint(keccak256("producer.voteWeight", accounts[i])).add(proxyWeight));
            }
        }
        // Update status of proxy vote
        systemStorage.setUint(keccak256("vote.status", msg.sender), 1);
        systemStorage.setAddressArray(keccak256("vote.voteProducers", msg.sender), accounts);

        return true;
    }


    /**
     * @dev Normal voter cancel all votes and can get his deposit after lock time
     */
    function userUnvote() external returns(bool) {
        // Only voter can un vote
        // producer => 1; proxy => 2; voter => 3;
        require(systemStorage.getUint(keccak256("user.role", msg.sender)) == 3);
        // Vote must be active now
        require(systemStorage.getUint(keccak256("vote.status", msg.sender)) == 1);

        uint weight = systemStorage.getUint(keccak256("vote.weight", msg.sender));

        // Vote for proxy before
        address votedProxy = systemStorage.getAddress(keccak256("vote.voteProxy", msg.sender));
        if (votedProxy != address(0)) {
            // Reduce proxy vote weight
            systemStorage.setUint(keccak256("vote.weight", votedProxy), systemStorage.getUint(keccak256("vote.weight", votedProxy)).sub(weight));

            // If proxy have vote for producers, update related weight of producers. otherwise, do nothing
            // Not necessary to check status of proxy's vote, because unvote will delete voted producers
            updateReleatedProducersVoteWeight(votedProxy, weight, false);
            return true;
        } else {
            // Vote for producer before
            updateReleatedProducersVoteWeight(msg.sender, weight, false);
        }

        /**
         * Update vote info
         */
        // Update status of vote
        systemStorage.setUint(keccak256("vote.status", msg.sender), 2);
        // Update unvote unvote time
        systemStorage.setUint(keccak256("vote.unvoteTime", msg.sender), now);
        // Delete vote producers
        systemStorage.deleteAddressArray(keccak256("vote.voteProducers", msg.sender));
        // Delete proxy
        systemStorage.deleteAddress(keccak256("vote.voteProxy", msg.sender));
        return true;
    }


    /**
     * @dev Proxy unvote, update proxy vote info, and change related producers's info
     */
    function proxyUnvote() external returns(bool) {
        // producer => 1; proxy => 2; voter => 3;
        require(systemStorage.getUint(keccak256("user.role", msg.sender)) == 2);
        // Vote must be active now
        require(systemStorage.getUint(keccak256("vote.status", msg.sender)) == 1);

        // Reduce related producer's weight
        uint weight = systemStorage.getUint(keccak256("vote.weight", msg.sender));
        updateReleatedProducersVoteWeight(msg.sender, weight, false);


        // Delete vote info for this proxy(proxy don't have real deposit, so not necessary to keep this info)
        systemStorage.deleteAddressArray(keccak256("vote.voteProducers", msg.sender));
        // Delete status of vote
        systemStorage.setUint(keccak256("vote.status", msg.sender), 2);
        // Delete weight
        systemStorage.deleteUint(keccak256("vote.weight", msg.sender));
        return true;
    }

    /**
     * @dev Validate producers: producers should be sorted, unique, reg and active
     * @dev Throw when not pass validation
     * @param accounts Address of producers to be validated
     */
    function validateProducers(address[] accounts) internal {
        // One can vote for 30 producers
        require(accounts.length <= 30);

        // Check for first producer alone.
        require(systemStorage.getUint(keccak256("user.role", accounts[0])) == 1);
        require(systemStorage.getUint(keccak256("producer.status", accounts[0])) == 1);

        // Check producers
        for(uint i = 1; i < accounts.length; i++) {
            require(systemStorage.getUint(keccak256("user.role", accounts[i])) == 1);
            require(systemStorage.getUint(keccak256("producer.status", accounts[i])) == 1);
            // Producers should sorted and unique
            require(uint(accounts[i-1]) < uint(accounts[i]));
        }
    }


    /**
     * @dev Calculate weight of vote with GET staked
     * @param staked Amount of GET coin staked
     */
    function calculateWeight(uint staked) internal pure returns(uint) {
        // TODO change way calculating
        return staked.mul(1);
    }

    /**
     * @dev Update vote weight of producers voted by voter
     * @param voter Whose producers should be updated
     * @param weight The amount of vote weight will add or sub
     * @param flag True means add, otherwise sub
     */
    function updateReleatedProducersVoteWeight(address voter, uint weight, bool flag) internal {
        address[] memory votedProducers = systemStorage.getAddressArray(keccak256("vote.voteProducers", voter));
        uint newWeight;
        if (flag) {
            systemStorage.getUint(keccak256("producer.voteWeight", votedProducers[i])).add(weight);
        } else {
            systemStorage.getUint(keccak256("producer.voteWeight", votedProducers[i])).sub(weight);
        }
        for(uint i = 0; i < votedProducers.length; i++) {
            systemStorage.setUint(keccak256("producer.voteWeight", votedProducers[i]), newWeight);
        }
    }
}
