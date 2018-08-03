pragma solidity ^0.4.24;

import "./StorageInterface.sol";
import "./libraries/SafeMath.sol";
import "./ProducersOpInterface.sol";

//
contract RegSystemContractTest {

    using SafeMath for uint;

    // Just for test // TODO
    uint depositForJoin = 1 ether;
    // 72 hours lock for deposit
    uint lockTimeForDepoist = 72 * 60 * 60;
    // 72 hours lock for vote
    uint lockTimeForVote = 72 * 60 * 60;
    // Just for test // TODO
    uint lengthOFEpoch = 4;

    // 00:00:00 1/1/3000 for init out time
    uint initOutTime = 32503651200;

    StorageInterface systemStorage = StorageInterface(0);
    ProducersOpInterface producerOp = ProducersOpInterface(0);

    // Tmp record index of unreg producers
    uint[] unregIndex;

    event LogRegProducerCandidates(
        address indexed producer,
        string name,
        string webUrl,
        string p2pUrl,
        uint deposit
    );

    event LogUpdateProducerInfo(
        address indexed producer,
        string newName,
        string newWebUrl,
        string newP2PUrl
    );

    event LogRegProxy(address indexed proxy);

    event LogUnregProducer(address indexed producer, uint unregTime);

    event LogUnregProxy(address indexed proxy, uint unregTime);

    constructor(address systemStorageContract) public {
        require(systemStorageContract != address(0));
        systemStorage = StorageInterface(systemStorageContract);
        producerOp = ProducersOpInterface(systemStorageContract);
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
        require(depositForJoin == msg.value);
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

        // Push producer to producers array when there is not unreged producer now
        // If first producer unreg, it's place will not be replace
        if (unregIndex.length == 0 || unregIndex[0] == 0) {
            // Because 0 is the default value, so the index will be start from 1 not 0.
            // And the actual index = index - 1
            systemStorage.setUint(keccak256("producer.index", producer), producerOp.getProducers().length.add(1));
            // Update producers
            producerOp.pushProducers(producer);
            // Use unregIndex to avoid length of producer's array increase constantly
        } else {
            // Use producer's true index
            producerOp.updateProducer(producer, unregIndex[0].sub(1));
            systemStorage.setUint(keccak256("producer.index", producer), unregIndex[0]);
            // Replace last one to first and delete last one to keep unregIndex right
            if (unregIndex.length > 1) {
                unregIndex[0] = unregIndex[unregIndex.length-1];
                delete(unregIndex[unregIndex.length-1]);
            } else {
                unregIndex[0] = 0;
            }
            // Important to reduce the length of array since delete will not do this
            unregIndex.length--;
        }

        emit LogRegProducerCandidates(msg.sender, name, webUrl, p2pUrl, msg.value);
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

        emit LogUpdateProducerInfo(msg.sender, newName, newWebUrl, newP2PUrl);
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
        emit LogRegProxy(msg.sender);
        return true;
    }


    /**
     * @dev Producer unreg and can withdraw his deposit after lock time.
     * @dev producer can re reg after withdraw his depoist.
     */
    function unregProducer() external returns(bool) {
        // producer => 1; proxy => 2; voter => 3;
        require(systemStorage.getUint(keccak256("user.role", msg.sender)) == 1);
        // Status of producer: 1 => active, 2 => unreg, 3 => been voted out
        // Only active producer can unreg
        require(systemStorage.getUint(keccak256("producer.status", msg.sender)) == 1);

        // Delete producer's vote info but not update any related proxy or voter's info
        systemStorage.deleteUint(keccak256("producer.voteWeight", msg.sender));
        // Update producer's status
        systemStorage.setUint(keccak256("producer.status", msg.sender), 2);
        // Update unreg(out) time
        systemStorage.setUint(keccak256("producer.outTime", msg.sender), now);

        // Set producers to zero address, use producers' true index
        producerOp.updateProducer(address(0), systemStorage.getUint(keccak256("producer.index", msg.sender)).sub(1));
        // unregIndex will keep index + 1 of producer's true index
        unregIndex.push(systemStorage.getUint(keccak256("producer.index", msg.sender)));
        // Delete all producer's info after withdraw
        emit LogUnregProducer(msg.sender, now);
        return true;
    }


    /**
     * @dev Proxy unreg
     */
    function unregProxy() external returns(bool) {
        // User is a proxy
        // producer => 1; proxy => 2; voter => 3;
        require(systemStorage.getUint(keccak256("user.role", msg.sender)) == 2);
        // Proxy must unvote now or havn't vote before
        require(systemStorage.getUint(keccak256("vote.status", msg.sender)) != 1);

        // Delete proxy role and status
        systemStorage.deleteUint(keccak256("user.role", msg.sender));
        systemStorage.deleteUint(keccak256("vote.status", msg.sender));

        emit LogUnregProxy(msg.sender, now);
        return true;
    }


    /**
     * @dev Get top producers(may include empty address only when producer's length is less than defaultLength)
     */
    function getProducers() external view returns(address[]) {
        return producerOp.getProducers();
    }
}
