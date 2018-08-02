pragma solidity ^0.4.24;

import "./StorageInterface.sol";
import "./libraries/SafeMath.sol";

//
contract CurrentSystemContract {

    using SafeMath for uint;

    StorageInterface systemStorage = StorageInterface(0);

    // TODO event

    // 00:00:00 1/1/3000 for init out time
    uint initOutTime = 32503651200;


    constructor(address systemStorageContract) public {
        require(systemStorageContract != address(0));
        systemStorage = StorageInterface(systemStorageContract);
    }


    /**
     * @dev User send default amount of GET coin to reg producer candidates.
     * @param name Name of producer
     * @param webUrl Web url of producer's office site
     * @param p2pUrl P2P url of producer's themis node
     */
    function regProducerCandidates(string name, string webUrl, string p2pUrl) external payable returns(bool) {
        address producer = msg.sender;
        // To be a producer, one must not be a producer/proxy/voter
        // producer => 1; proxy => 2; voter => 3;
        require(systemStorage.getUint(keccak256("user.role", producer)) == 0);
        // User should send default GET coin to be a producer
        require(systemStorage.getUint(keccak256("system.depositForJoin")) == msg.value);
        // TODO add length limit of producers

        // Set producer role
        systemStorage.setUint(keccak256("user.role", producer), 1);

        // Set producer personal info
        systemStorage.setString(keccak256("producer.name", producer), name);
        systemStorage.setString(keccak256("producer.webUrl", producer), webUrl);
        systemStorage.setString(keccak256("producer.p2pUrl", producer), p2pUrl);
        systemStorage.setUint(keccak256("producer.deposit", producer), msg.value);

        // Set producer init info
        // Status of producer: 1 => active, 2 => unreg, 3 => been voted out
        systemStorage.setUint(keccak256("producer.status", producer), 1);
        systemStorage.setUint(keccak256("producer.outTime", producer), initOutTime);

        // Index of current last node
        uint lastNodeIndex = systemStorage.getUint(keccak256("linkTable.lastNodeIndex"));
        // Current index should be used
        uint currentIndex = systemStorage.getUint(keccak256("linkTable.currentIndex"));

        require(insertToNextOFNode(lastNodeIndex, currentIndex) == true);
        // Set data of node
        systemStorage.setAddress(keccak256("linkTable.node.data", currentIndex), producer);
        // Update current index
        systemStorage.setUint(keccak256("linkTable.currentIndex"), currentIndex.add(1));

        return true;
    }


    /**
     * @dev Producer update his info
     * @param newName New name of producer
     * @param newWebUrl New web url of producer
     * @param newP2PUrl New p2p url of producer
     */
    function updateProducerCandidatesInfo(string newName, string newWebUrl, string newP2PUrl) external returns(bool) {
        // Msg.sender is a producer
        // producer => 1; proxy => 2; voter => 3;
        require(systemStorage.getUint(keccak256("user.role", msg.sender)) == 1);

        // Set producer new personal info
        systemStorage.setString(keccak256("producer.name", msg.sender), newName);
        systemStorage.setString(keccak256("producer.webUrl", msg.sender), newWebUrl);
        systemStorage.setString(keccak256("producer.p2pUrl", msg.sender), newP2PUrl);
        return true;
    }


    /**
     * @dev User reg to be a proxy
     */
    function regProxy() external returns(bool) {
        // To be a proxy, user must not be a producer/proxy/voter
        // producer => 1; proxy => 2; voter => 3;
        require(systemStorage.getUint(keccak256("user.role", msg.sender)) == 0);

        // Set proxy role
        systemStorage.setUint(keccak256("user.role", msg.sender), 2);

        // Set proxy personal info
        // 1 => active; 2 => unreg
        systemStorage.setUint(keccak256("proxy.status", msg.sender), 1);
        return true;
    }


    /**
     * @dev User vote for producer or proxy, if proxy is set, the producer's address will be ignored
     * @param proxy Proxy user want to vote for
     * @param accounts Producer user want to vote for
     */
    function userVote(address proxy, address[] accounts) external payable returns(bool) {
        // One can vote for 30 producers
        require(accounts.length <= 30);
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
            // Check producers
            for(uint i = 0; i < accounts.length; i++) {
                require(systemStorage.getUint(keccak256("user.role", accounts[i])) == 1);
                require(systemStorage.getUint(keccak256("producer.status", accounts[i])) == 1);
            }
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
        systemStorage.setUint(keccak256("vote.weight", msg.sender), calculateWeight(msg.value));
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
            systemStorage.setUint(keccak256("proxy.proxyVoteWeight", proxy), systemStorage.getUint(keccak256("proxy.proxyVoteWeight", proxy)).add(calculateWeight(msg.value)));
            // Add voter for proxy
            addVoterForAccount(msg.sender, proxy, true);
            // Update flag
            systemStorage.setBool(keccak256("proxy.isThisVoter", proxy, msg.sender), true);

            // If proxy have vote for producers, update related weight of producers. otherwise, do nothing
            // Not necessary to check status of proxy's vote, because unvote will delete voted producers
            address[] memory proxyVotedProducers = systemStorage.getAddressArray(keccak256("vote.voteProducers", proxy));
            for(i = 0; i < proxyVotedProducers.length; i++) {
                systemStorage.setUint(keccak256("producer.voteWeight", proxyVotedProducers[i]), systemStorage.getUint(keccak256("producer.voteWeight", proxyVotedProducers[i])).add(calculateWeight(msg.value)));
            }
            return true;
        }

        // Add voter for producers
        for(i = 0; i < accounts.length; i++) {
            addVoterForAccount(msg.sender, accounts[i], false);
            // Update flag of producer
            systemStorage.setBool(keccak256("producer.isThisVoters", accounts[i], msg.sender), true);
            systemStorage.setUint(keccak256("producer.voteWeight", accounts[i]), systemStorage.getUint(keccak256("producer.voteWeight", accounts[i])).add(calculateWeight(msg.value)));
        }

        return true;
    }


    /**
     * @dev Proxy vote for producer. If proxy have vote before, just update it to new one.
     * @param accounts Address of producers proxy want to vote
     */
    function proxyVote(address[] accounts) external returns(bool) {
        // One can vote for 30 producers
        require(accounts.length <= 30);
        // producer => 1; proxy => 2; voter => 3;
        require(systemStorage.getUint(keccak256("user.role", msg.sender)) == 2);
        // Every producer should have reg and active
        for(uint i = 0; i < accounts.length; i++) {
            require(systemStorage.getUint(keccak256("user.role", accounts[i])) == 1);
            require(systemStorage.getUint(keccak256("producer.status", accounts[i])) == 1);
        }


        /**
         * Update vote info for proxy and related producer
         */
        uint proxyWeight = systemStorage.getUint(keccak256("proxy.proxyVoteWeight", msg.sender));
        address[] memory votedProducers = systemStorage.getAddressArray(keccak256("vote.voteProducers", msg.sender));
        if (votedProducers.length == 0) {
            // Proxy vote for producer at first time
            for(i = 0; i < accounts.length; i++) {
                systemStorage.setUint(keccak256("producer.voteWeight", accounts[i]), systemStorage.getUint(keccak256("producer.voteWeight", accounts[i])).add(proxyWeight));
                addVoterForAccount(msg.sender, accounts[i], false);
                // Update flag
                systemStorage.setBool(keccak256("producer.isThisVoters", accounts[i], msg.sender), true);
            }
        } else {
            // Proxy have voted before
            for(i = 0; i < votedProducers.length; i++) {
                systemStorage.setUint(keccak256("producer.voteWeight", votedProducers[i]), systemStorage.getUint(keccak256("producer.voteWeight", votedProducers[i])).sub(proxyWeight));
                deleteVoterForAccount(msg.sender, votedProducers[i], false);
                // Update flag
                systemStorage.setBool(keccak256("producer.isThisVoters", votedProducers[i], msg.sender), false);
            }

            for(i = 0; i < accounts.length; i++) {
                if (!systemStorage.getBool(keccak256("producer.isThisVoters", accounts[i], msg.sender))) {
                    systemStorage.setUint(keccak256("producer.voteWeight", accounts[i]), systemStorage.getUint(keccak256("producer.voteWeight", accounts[i])).add(proxyWeight));
                    addVoterForAccount(msg.sender, accounts[i], false);
                    // Uppdate flag
                    systemStorage.setBool(keccak256("producer.isThisVoters", accounts[i], msg.sender), true);
                }
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
            systemStorage.setUint(keccak256("proxy.proxyVoteWeight", votedProxy), systemStorage.getUint(keccak256("proxy.proxyVoteWeight", votedProxy)).sub(weight));
            // Delete vote for proxy
            deleteVoterForAccount(msg.sender, votedProxy, true);
            // Update flag
            systemStorage.setBool(keccak256("proxy.isThisVoter", votedProxy, msg.sender), false);

            // If proxy have vote for producers, update related weight of producers. otherwise, do nothing
            // Not necessary to check status of proxy's vote, because unvote will delete voted producers
            address[] memory proxyVotedProducers = systemStorage.getAddressArray(keccak256("vote.voteProducers", votedProxy));
            for(i = 0; i < proxyVotedProducers.length; i++) {
                systemStorage.setUint(keccak256("producer.voteWeight", proxyVotedProducers[i]), systemStorage.getUint(keccak256("producer.voteWeight", proxyVotedProducers[i])).sub(weight));
            }
            return true;
        } else {
            // Vote for producer before
            address[] memory votedProducers = systemStorage.getAddressArray(keccak256("vote.voteProducers", msg.sender));
            // Reduce the weight of producer and delete vote for producer
            for(uint i = 0; i < votedProducers.length; i++) {
                deleteVoterForAccount(msg.sender, votedProducers[i], false);
                // Update flag
                systemStorage.setBool(keccak256("producer.isThisVoters", votedProducers[i], msg.sender), false);
                systemStorage.setUint(keccak256("producer.voteWeight", votedProducers[i]), systemStorage.getUint(keccak256("producer.voteWeight", votedProducers[i])).sub(weight));
            }
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
        address[] memory votedProducers = systemStorage.getAddressArray(keccak256("vote.voteProducers", msg.sender));
        uint proxyWeight = systemStorage.getUint(keccak256("proxy.proxyVoteWeight", msg.sender));
        for(uint i = 0; i < votedProducers.length; i++) {
            systemStorage.setUint(keccak256("producer.voteWeight", votedProducers[i]), systemStorage.getUint(keccak256("producer.voteWeight", votedProducers[i])).sub(proxyWeight));
            deleteVoterForAccount(msg.sender, votedProducers[i], false);
            // Update flag
            systemStorage.setBool(keccak256("producer.isThisVoters", votedProducers[i], msg.sender), false);
        }

        // Delete vote info for this proxy(proxy don't have real deposit, so not necessary to keep this info)
        systemStorage.deleteAddressArray(keccak256("vote.voteProducers", msg.sender));
        // Delete status of vote
        systemStorage.deleteUint(keccak256("vote.status", msg.sender));
        return true;
    }


    /**
     * @dev Producer unreg // TODO
     */
    function unregProducer() external returns(bool) {
        //
    }


    /**
     * @dev Proxy unreg
     */
    function unregProxy() external returns(bool) {
        // User is a proxy
        // producer => 1; proxy => 2; voter => 3;
        require(systemStorage.getUint(keccak256("user.role", msg.sender)) == 2);

        // Delete proxy role
        systemStorage.deleteUint(keccak256("user.role", msg.sender));

        // Delete vote info of proxy
        // Delete totalStaked of this proxy
        systemStorage.deleteUint(keccak256("proxy.totalStaked", msg.sender));
        // Delete voters of this proxy
        address[] memory votes = systemStorage.getAddressArray(keccak256("proxy.voters", msg.sender));
        // TODO Set max amount of voters for a proxy
        require(votes.length < 10000);
        for(uint i = 0; i < votes.length; i++) {
            systemStorage.deleteBool(keccak256("proxy.isThisVoter", msg.sender, votes[i]));
        }
        systemStorage.deleteAddressArray(keccak256("proxy.voters", msg.sender));

        // Delete vote for producer
        // TODO

        return true;
    }


    /**
     * @dev Get top producers(may include empty address only when producer's length is less than defaultLength)
     */
    function getTopProducers() external view returns(address[]) {
        uint defaultLength = systemStorage.getUint(keccak256("system.lengthOFEpoch"));
        address[] memory res = new address[](defaultLength);
        uint node = systemStorage.getUint(keccak256("linkTable.startNode.next"));

        uint num = 0;
        while(node != 0 && num < defaultLength) {
            res[num] = systemStorage.getAddress(keccak256("linkTable.node.data", node));
            node = systemStorage.getUint(keccak256("linkTable.node.next", node));
            num++;
        }

        // Result may include empty address
        return res;
    }


    /**
     * @dev Get producer info //TODO just for test
     * @param producer Address of producer
     */
    function getAccountRole(uint producer) external view returns(address) {
        return systemStorage.getAddress(keccak256("linkTable.node.data", producer));
    }


    /**
     * @dev Add a voter to account(proxy/producer)
     */
    function addVoterForAccount(address voter, address account, bool isProxy) internal {
        bytes32 key;
        bytes32 alreadyInKey;
        if (isProxy) {
            key = keccak256("proxy.voters", account);
            alreadyInKey = keccak256("proxy.isThisVoter", account, voter);
        } else {
            key = keccak256("producer.voters", account);
            alreadyInKey = keccak256("producer.isThisVoters", account, voter);
        }
        // Already in voters
        if (systemStorage.getBool(alreadyInKey)) {
            return;
        }
        address[] memory voters = systemStorage.getAddressArray(key);
        address[] memory newVoters = new address[](voters.length.add(1));
        newVoters[voters.length] = voter;
        systemStorage.setAddressArray(key, newVoters);
    }


    function deleteVoterForAccount(address voter, address account, bool isProxy) internal {
        bytes32 key;
        bytes32 alreadyInKey;
        if (isProxy) {
            key = keccak256("proxy.voters", account);
            alreadyInKey = keccak256("proxy.isThisVoter", account, voter);
        } else {
            key = keccak256("producer.voters", account);
            alreadyInKey = keccak256("producer.isThisVoters", account, voter);
        }
        // Not already in voters
        if (!systemStorage.getBool(alreadyInKey)) {
            return;
        }
        address[] memory voters = systemStorage.getAddressArray(key);
        address[] memory newVoters = new address[](voters.length.sub(1));

        uint num = 0;
        for(uint i = 0; i < voters.length; i++) {
            if (voters[i] == voter) {
                continue;
            }

            // Only occur when try to delete an address not in array
            if(num > newVoters.length) {
                revert();
            }
            newVoters[num] = voters[i];
            num++;
        }

        systemStorage.setAddressArray(key, newVoters);
    }


    /**
     * @dev Calculate weight of vote with GET staked
     * @param staked Amount of GET coin staked
     */
    function calculateWeight(uint staked) internal returns(uint) {
        // TODO change way calculating
        return staked.mul(1);
    }


    /**
     * @dev Insert a node to the prev of index node
     */
    function insertToPrevOFNode(uint insertIndex, uint newNodeIndex) internal returns(bool) {
        // Insert to next of head node
        if (insertIndex == 0 || insertIndex == 1) {
            // Get first node
            uint firstNode = systemStorage.getUint(keccak256("linkTable.startNode.next"));
            systemStorage.setUint(keccak256("linkTable.node.prev", firstNode), newNodeIndex);
            systemStorage.setUint(keccak256("linkTable.startNode.next"), newNodeIndex);
            systemStorage.setUint(keccak256("linkTable.node.next", newNodeIndex), firstNode);
        } else {
            // Get prev node
            uint prevNode = systemStorage.getUint(keccak256("linkTable.node.prev", insertIndex));
            // Set prev node of new node
            systemStorage.setUint(keccak256("linkTable.node.prev", newNodeIndex), prevNode);
            // Set next node of new node
            systemStorage.setUint(keccak256("linkTable.node.next", newNodeIndex), insertIndex);
            // Set next node of prev node to new node
            systemStorage.setUint(keccak256("linkTable.node.next", prevNode), newNodeIndex);
            // Set prev node of original node to new node
            systemStorage.setUint(keccak256("linkTable.node.prev", insertIndex), newNodeIndex);
        }

        // Update length of link table
        uint totalLength = systemStorage.getUint(keccak256("linkTable.totalLength"));
        systemStorage.setUint(keccak256("linkTable.totalLength"), totalLength.add(1));

        return true;
    }


    /**
     * @dev Insert a node to the next of index node
     */
    function insertToNextOFNode(uint insertIndex, uint newNodeIndex) internal returns(bool) {
        // Update length of link table
        uint totalLength = systemStorage.getUint(keccak256("linkTable.totalLength"));
        systemStorage.setUint(keccak256("linkTable.totalLength"), totalLength.add(1));

        uint lastNodeIndex = systemStorage.getUint(keccak256("linkTable.lastNodeIndex"));
        // Insert behind last node
        // Last node can not be zero(means empty list)
        if (lastNodeIndex == insertIndex && lastNodeIndex != 0) {
            // Set next node of original last node
            systemStorage.setUint(keccak256("linkTable.node.next", insertIndex), newNodeIndex);
            systemStorage.setUint(keccak256("linkTable.node.prev", newNodeIndex), insertIndex);

            // Update last node index
            systemStorage.setUint(keccak256("linkTable.lastNodeIndex"), newNodeIndex);
            return true;
        }

        // Insert after head node
        if (insertIndex == 0) {
            // Get first node
            uint firstNode = systemStorage.getUint(keccak256("linkTable.startNode.next"));
            systemStorage.setUint(keccak256("linkTable.node.prev", firstNode), newNodeIndex);
            systemStorage.setUint(keccak256("linkTable.startNode.next"), newNodeIndex);
            systemStorage.setUint(keccak256("linkTable.node.next", newNodeIndex), firstNode);
            // Empty link table(should update lastNodeIndex)
            if (totalLength == 0) {
                systemStorage.setUint(keccak256("linkTable.lastNodeIndex"), newNodeIndex);
            }
            return true;
        }

        uint afterNode = systemStorage.getUint(keccak256("linkTable.node.next", insertIndex));
        // Set next of original insert node
        systemStorage.setUint(keccak256("linkTable.node.next", insertIndex), newNodeIndex);
        // Set prev of new node
        systemStorage.setUint(keccak256("linkTable.node.prev", newNodeIndex), insertIndex);
        // Set next of new node
        systemStorage.setUint(keccak256("linkTable.node.next", newNodeIndex), afterNode);
        // Set prev of original after node
        systemStorage.setUint(keccak256("linkTable.node.prev", afterNode), newNodeIndex);

        return true;
    }


    /**
     * @dev Get position to insert given a weight of a node
     */
    function getPositionToInsertAfter(uint weight) internal returns(uint) {
        uint currentNode = systemStorage.getUint(keccak256("linkTable.startNode.next"));
        // Empty link table
        if (currentNode == 0) {
            return 0;
        }

        // Weight is bigger or equal than first node
        uint currentWeight = systemStorage.getUint(keccak256("linkTable.node.weight", currentNode));
        if (weight >= currentWeight) {
            return 0;
        }

        // Only one node current
        uint nextNode = systemStorage.getUint(keccak256("linkTable.node.next", currentNode));
        if (nextNode == 0) {
            return currentNode;
        }

        // Try to find insert position
        while(nextNode != 0) {
            uint nextWeight = systemStorage.getUint(keccak256("linkTable.node.weight", nextNode));
            if (weight >= nextWeight && weight < currentWeight) {
                break;
            }

            currentWeight = nextWeight;
            currentNode = nextNode;
            nextNode = systemStorage.getUint(keccak256("linkTable.node.next", currentNode));
        }

        return currentNode;
    }
}
