/**
 *Submitted for verification at snowtrace.io on 2021-12-23
*/

// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./IterableMapping.sol";

contract NODERewardManagement {
    using SafeMath for uint256;
    using IterableMapping for IterableMapping.Map;

    //# types of node tiers
    //# each node type's properties are different
    struct NodeType {
        string nodeTypeName;
        uint256 nodePrice;          //# cost to buy a node
        uint256 claimTime;          //# length of an epoch
        uint256 rewardAmount;       //# reward per an epoch
    }

    struct NodeEntity {
        string nodeTypeName;        //# name of this node's type 
        uint256 creationTime;
        uint256 lastClaimTime;
    }

    mapping(string => NodeType) public nodeTypes;               //# store node types
    uint256 nodeTypesCount = 0;
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

    //# add a new NodeType to mapping "nodeTypes"
    function addNodeType(string memory nodeTypeName, uint256 nodePrice, uint256 claimTime, uint256 rewardAmount)
        public onlySentry
    {
        //# check if nodeTypeName already exists
        // if claimTime is greater than zero, it means the same nodeTypeName already exists in mapping
        require(nodeTypes[nodeTypeName].claimTime > 0, "same nodeTypeName exists.");
        nodeTypes[nodeTypeName] = NodeType({
                nodeTypeName: nodeTypeName,
                nodePrice: nodePrice,
                claimTime: claimTime,
                rewardAmount: rewardAmount
        });
        nodeTypesCount++;
    }

    //# change properties of NodeType
    function changeNodeType(string memory nodeTypeName, uint256 nodePrice, uint256 claimTime, uint256 rewardAmount)
        public onlySentry
    {
        //# check if nodeTypeName exists
        require(nodeTypes[nodeTypeName].claimTime > 0, "nodeTypeName does not exist.");
        NodeType memory nt = nodeTypes[nodeTypeName];
        nt.nodePrice = nodePrice;
        nt.claimTime = claimTime;
        nt.rewardAmount = rewardAmount;
    }

    //# get all NodeTypes
    //# returning result is same format as "_getNodesCreationTime" function
    function getNodeTypes() public onlySentry returns (string memory)
    {
        NodeType memory _nt;
        string memory _result = "";
        string memory bigSeparator = "-";       // separator for showing the boundary between two NodeTypes
        string memory separator = "#";

        for (uint256 i = 0; i < nodeTypesCount; i++) {
            _nt = nodeTypes[i];
            _result = string(abi.encodePacked(_result, separator, _nt.nodeTypeName));
            _result = string(abi.encodePacked(_result, separator, uint2str(_nt.nodePrice)));
            _result = string(abi.encodePacked(_result, separator, uint2str(_nt.claimTime)));
            _result = string(abi.encodePacked(_result, separator, uint2str(_nt.rewardAmount)));
            _result = string(abi.encodePacked(_result, bigSeparator));      // add a bigSeparator for showing the boundary between two NodeTypes
        }
        return _result;
    }

    //# get left time of a node from the next reward
    //# if the reward time is passed then the result will be a negative number
    function getLeftTimeFromReward(address account, uint256 _creationTime)
        public onlySentry
        returns (int256)
    {
        NodeEntity[] storage nodes = _nodesOfUser[account];
        uint256 numberOfNodes = nodes.length;
        //# search the node with _creationTime
        bool found = false;
        int256 index = binary_search(nodes, 0, numberOfNodes, _creationTime);
        uint256 validIndex;
        if (index >= 0) {
            found = true;
            validIndex = uint256(index);
        }
        require(found, "NODE SEARCH: No NODE Found with this blocktime");

        NodeEntity memory node = nodes[validIndex];
        NodeType memory nt = nodeTypes[node.nodeTypeName];

        //# if the reward time is passed then the result will be a negative number
        return int256(node.lastClaimTime + nt.claimTime - block.timestamp);
    }

    // function createNode(address account, string memory nodeName) public onlySentry {
    //     _nodesOfUser[account].push(
    //         NodeEntity({
    //             creationTime: block.timestamp,
    //             lastClaimTime: block.timestamp
    //         })
    //     );
    //     totalNodesCreated++;
    //     nodeOwners.set(account, _nodesOfUser[account].length);
    // }
    // function createNodeInternal(address account, string memory nodeName) internal {
    //     _nodesOfUser[account].push(
    //         NodeEntity({
    //             creationTime: block.timestamp,
    //             lastClaimTime: block.timestamp
    //         })
    //     );
    //     totalNodesCreated++;
    //     nodeOwners.set(account, _nodesOfUser[account].length);
    // }

    // instead of nodeName, nodeTypeName should be passed
    function createNode(address account, string memory nodeTypeName, uint256 count) public onlySentry {
        createNodeInternal(account, nodeTypeName, count);          // to avoid duplicate functions
    }
    
	function createNodeInternal(address account, string memory nodeTypeName, uint256 count) internal {
        //# check if nodeTypeName exists
        require(nodeTypes[nodeTypeName].claimTime > 0, "Non-existing NodeType name.");
        require(count > 0, "Count cannot be less than 1.");

        for (uint256 i = 0; i < count; i++) {
            _nodesOfUser[account].push(
                NodeEntity({
                    nodeTypeName: nodeTypeName,
                    creationTime: block.timestamp,
                    lastClaimTime: block.timestamp
                })
            );
            totalNodesCreated++;
            nodeOwners.set(account, _nodesOfUser[account].length);
        }
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

    //# rewarding amount varies according to NodeType
    function calculateRewardOfNode(NodeEntity memory node) private view returns (uint256) {
        NodeType memory nt = nodeTypes[node.nodeTypeName];

		if (block.timestamp - node.lastClaimTime < nt.claimTime) {
			return 0;
		}
        uint256 reward = nt.rewardAmount * (block.timestamp - node.lastClaimTime) / nt.claimTime;
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

    //# claim time varies according to NodeType
    function claimable(NodeEntity memory node) private view returns (bool) {
        NodeType memory nt = nodeTypes[node.nodeTypeName];
        return node.lastClaimTime + nt.claimTime >= block.timestamp;
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
			createNodeInternal(account, '', 1);
		}
		oldNodeIndexOfUser[account] += nb;
    }
}