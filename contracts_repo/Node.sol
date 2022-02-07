
contract NODERewardManagement {
    using SafeMath for uint256;
    using IterableMapping for IterableMapping.Map;

    struct NodeEntity {
        uint256 creationTime;
        uint256 lastClaimTime;
    }

    IterableMapping.Map private nodeOwners;
    mapping(address => NodeEntity[]) private _nodesOfUser;
    mapping(address => uint) public oldNodeIndexOfUser;

    uint256 public nodePrice;
    uint256 public rewardPerNode;
    uint256 public claimTime;

    address public gateKeeper;
    address public token;
	address public oldNodeRewardManager;

    bool public autoDistri = true;
    bool public distribution = false;

    uint256 public gasForDistribution = 500000;
    uint256 public lastDistributionCount = 0;
    uint256 public lastIndexProcessed = 0;

    uint256 public totalNodesCreated = 0;
    uint256 public totalRewardStaked = 0;

    constructor(
        uint256 _nodePrice,
        uint256 _rewardPerNode,
        uint256 _claimTime,
		address _oldNodeRewardManager,
        address _token
    ) {
        nodePrice = _nodePrice;
        rewardPerNode = _rewardPerNode;
        claimTime = _claimTime;
        gateKeeper = msg.sender;
		oldNodeRewardManager = _oldNodeRewardManager;
        token = _token;
    }

    modifier onlySentry() {
        require(msg.sender == token || msg.sender == gateKeeper, "Fuck off");
        _;
    }

    function setToken (address token_) external onlySentry {
        token = token_;
    }

    function distributeRewards(uint256 gas, uint256 rewardNode)
    private
    returns (
        uint256,
        uint256,
        uint256
    )
    {
		return (0, 0, 0);
    }

    function createNode(address account, string memory nodeName) public onlySentry {
        _nodesOfUser[account].push(
            NodeEntity({
                creationTime: block.timestamp,
                lastClaimTime: block.timestamp
            })
        );
        totalNodesCreated++;
        nodeOwners.set(account, _nodesOfUser[account].length);
    }
    
	function createNodeInternal(address account, string memory nodeName) internal {
        _nodesOfUser[account].push(
            NodeEntity({
                creationTime: block.timestamp,
                lastClaimTime: block.timestamp
            })
        );
        totalNodesCreated++;
        nodeOwners.set(account, _nodesOfUser[account].length);
    }

    function _burn(uint256 index) internal {
        require(index < nodeOwners.size());
        nodeOwners.remove(nodeOwners.getKeyAtIndex(index));
    }

    function _getNodeWithCreatime(
        NodeEntity[] storage nodes,
        uint256 _creationTime
    ) private view returns (NodeEntity storage) {

        uint256 numberOfNodes = nodes.length;
        require(
            numberOfNodes > 0,
            "CASHOUT ERROR: You don't have nodes to cash-out"
        );
        bool found = false;
        int256 index = binary_search(nodes, 0, numberOfNodes, _creationTime);
        uint256 validIndex;
        if (index >= 0) {
            found = true;
            validIndex = uint256(index);
        }
        require(found, "NODE SEARCH: No NODE Found with this blocktime");
        return nodes[validIndex];
    }

    function binary_search(
        NodeEntity[] memory arr,
        uint256 low,
        uint256 high,
        uint256 x
    ) private view returns (int256) {
        if (high >= low) {
            uint256 mid = (high + low).div(2);
            if (arr[mid].creationTime == x) {
                return int256(mid);
            } else if (arr[mid].creationTime > x) {
                return binary_search(arr, low, mid - 1, x);
            } else {
                return binary_search(arr, mid + 1, high, x);
            }
        } else {
            return -1;
        }
    }

    function calculateRewardOfNode(NodeEntity memory node) private view returns (uint256) {
		if (block.timestamp - node.lastClaimTime < claimTime) {
			return 0;
		}
        uint256 reward = rewardPerNode * (block.timestamp - node.lastClaimTime) / claimTime;
        return reward;
    }

    function _cashoutNodeReward(address account, uint256 _creationTime)
    external onlySentry
    returns (uint256)
    {
        return 0; // all nodes same createtime
    }

    function _cashoutAllNodesReward(address account)
    external onlySentry
    returns (uint256)
    {
        NodeEntity[] storage nodes = _nodesOfUser[account];
        uint256 nodesCount = nodes.length;
        require(nodesCount > 0, "NODE: CREATIME must be higher than zero");
        NodeEntity storage _node;
        uint256 rewardsTotal = 0;
        for (uint256 i = 0; i < nodesCount; i++) {
            _node = nodes[i];
            rewardsTotal += calculateRewardOfNode(_node);
			_node.lastClaimTime = block.timestamp; // IMPORTANT
        }
        return rewardsTotal;
    }

    function claimable(NodeEntity memory node) private view returns (bool) {
        return node.lastClaimTime + claimTime >= block.timestamp;
    }

    function _getRewardAmountOf(address account)
    external
    view
    returns (uint256)
    {
        require(isNodeOwner(account), "GET REWARD OF: NO NODE OWNER");
        uint256 nodesCount;
        uint256 rewardCount = 0;

        NodeEntity[] storage nodes = _nodesOfUser[account];
        nodesCount = nodes.length;

        for (uint256 i = 0; i < nodesCount; i++) {
            rewardCount += calculateRewardOfNode(nodes[i]);
        }


        return rewardCount;
    }

    function _getRewardAmountOf(address account, uint256 _creationTime)
    external
    view
    returns (uint256)
    {
        return 0; // all node same create time
    }

    function _getNodeRewardAmountOf(address account, uint256 creationTime)
    external
    view
    returns (uint256)
    {
        return 0; // all nodes same create time
    }

    function _getNodesNames(address account)
    external
    view
    returns (string memory)
    {
        return "NONE";
    }

    function _getNodesCreationTime(address account)
    external
    view
    returns (string memory)
    {
        require(isNodeOwner(account), "GET CREATIME: NO NODE OWNER");
        NodeEntity[] memory nodes = _nodesOfUser[account];
        uint256 nodesCount = nodes.length;
        NodeEntity memory _node;
        string memory _creationTimes = uint2str(nodes[0].creationTime);
        string memory separator = "#";

        for (uint256 i = 1; i < nodesCount; i++) {
            _node = nodes[i];

            _creationTimes = string(
                abi.encodePacked(
                    _creationTimes,
                    separator,
                    uint2str(_node.creationTime)
                )
            );
        }
        return _creationTimes;
    }

    function _getNodesRewardAvailable(address account)
    external
    view
    returns (string memory)
    {
        require(isNodeOwner(account), "GET REWARD: NO NODE OWNER");
        NodeEntity[] memory nodes = _nodesOfUser[account];
        uint256 nodesCount = nodes.length;
        NodeEntity memory _node;

        string memory _rewardsAvailable = uint2str(calculateRewardOfNode(nodes[0]));

        string memory separator = "#";

        for (uint256 i = 1; i < nodesCount; i++) {
            _node = nodes[i];

            _rewardsAvailable = string(
                abi.encodePacked(
                    _rewardsAvailable,
                    separator,

                    calculateRewardOfNode(_node)
                )
            );
        }
        return _rewardsAvailable;
    }

    function _getNodesLastClaimTime(address account)
    external
    view
    returns (string memory)
    {
        require(isNodeOwner(account), "LAST CLAIME TIME: NO NODE OWNER");
        NodeEntity[] memory nodes = _nodesOfUser[account];
        uint256 nodesCount = nodes.length;
        NodeEntity memory _node;
        string memory _lastClaimTimes = uint2str(nodes[0].lastClaimTime);
        string memory separator = "#";

        for (uint256 i = 1; i < nodesCount; i++) {
            _node = nodes[i];

            _lastClaimTimes = string(
                abi.encodePacked(
                    _lastClaimTimes,
                    separator,
                    uint2str(_node.lastClaimTime)
                )
            );
        }
        return _lastClaimTimes;
    }

    function uint2str(uint256 _i)
    internal
    pure
    returns (string memory _uintAsString)
    {
        if (_i == 0) {
            return "0";
        }
        uint256 j = _i;
        uint256 len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint256 k = len;
        while (_i != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(_i - (_i / 10) * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }

    function _changeNodePrice(uint256 newNodePrice) external onlySentry {
        nodePrice = newNodePrice;
    }

    function _changeRewardPerNode(uint256 newPrice) external onlySentry {
        rewardPerNode = newPrice;
    }

    function _changeClaimTime(uint256 newTime) external onlySentry {
        claimTime = newTime;
    }

    function _changeAutoDistri(bool newMode) external onlySentry {
        autoDistri = newMode;
    }

    function _changeGasDistri(uint256 newGasDistri) external onlySentry {
        gasForDistribution = newGasDistri;
    }

    function _getNodeNumberOf(address account) public view returns (uint256) {
        return nodeOwners.get(account);
    }

    function isNodeOwner(address account) private view returns (bool) {
        return nodeOwners.get(account) > 0;
    }

    function _isNodeOwner(address account) external view returns (bool) {
        return isNodeOwner(account);
    }

    function _distributeRewards()
    external  onlySentry
    returns (
        uint256,
        uint256,
        uint256
    )
    {
        return distributeRewards(gasForDistribution, rewardPerNode);
    }

    function moveAccount(address account, uint nb) public {
		require(nb > 0, "Nb must be greater than 0");
		uint remainingNodes = OldRewardManager(oldNodeRewardManager)._getNodeNumberOf(account);
		remainingNodes -= oldNodeIndexOfUser[account];
		require(nb <= remainingNodes, "Too many nodes requested");
		for (uint i=0; i < nb; i++) {
			createNodeInternal(account, '');
		}
		oldNodeIndexOfUser[account] += nb;
    }
}