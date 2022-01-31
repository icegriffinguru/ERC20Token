/**
 *Submitted for verification at snowtrace.io on 2021-12-23
*/

// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./IterableMapping.sol";
import "./IterableNodeTypeMapping.sol";
import "./OldRewardManager.sol";

import "hardhat/console.sol";

contract NODERewardManagement {
    using SafeMath for uint256;
    using IterableMapping for IterableMapping.Map;
    using IterableNodeTypeMapping for IterableNodeTypeMapping.Map;

    struct NodeEntity {
        string nodeTypeName;        //# name of this node's type 
        uint256 creationTime;
        uint256 lastClaimTime;
    }

    IterableNodeTypeMapping.Map private _nodeTypes;               //# store node types
    IterableMapping.Map private _nodeOwners;
    mapping(address => NodeEntity[]) private _nodesOfUser;
    mapping(address => uint) public _oldNodeIndexOfUser;
    mapping(address => uint256) private _deposits;               // store deposit of each account. If an account claims his/her reward, it will be deposited in this varaible. An account can buy nodes with the deposit or can cash it out.

    // uint256 public nodePrice;
    // uint256 public rewardPerNode;
    // uint256 public claimTime;

    address public _gateKeeper;
    address public _token;
	address public _oldNodeRewardManager;

    // bool public autoDistri = true;
    // bool public distribution = false;

    // uint256 public gasForDistribution = 500000;
    // uint256 public lastDistributionCount = 0;
    // uint256 public lastIndexProcessed = 0;

    // uint256 public totalNodesCreated = 0;
    // uint256 public totalRewardStaked = 0;

    string _defaultNodeTypeName;

    constructor(
        // uint256 _nodePrice,
        // uint256 _rewardPerNode,
        // uint256 _claimTime,
		address oldNodeRewardManager,
        address token
    ) {
        // nodePrice = _nodePrice;
        // rewardPerNode = _rewardPerNode;
        // claimTime = _claimTime;
        _gateKeeper = msg.sender;
		_oldNodeRewardManager = oldNodeRewardManager;
        _token = token;
    }

    modifier onlySentry() {
        require(msg.sender == _token || msg.sender == _gateKeeper, "Fuck off");
        _;
    }

    function setToken (address token) external onlySentry {
        _token = token;
    }

    // function distributeRewards(uint256 gas, uint256 rewardNode)
    // private
    // returns (
    //     uint256,
    //     uint256,
    //     uint256
    // )
    // {
	// 	return (0, 0, 0);
    // }

    /////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////// NodeType management //////////////////////////////////

    //# add a new NodeType to mapping "nodeTypes"
    function addNodeType(string memory nodeTypeName, uint256 nodePrice, uint256 claimTime, uint256 rewardAmount, uint256 claimTaxBeforeTime)
        public onlySentry
    {
        //# check if nodeTypeName already exists
        // if claimTime is greater than zero, it means the same nodeTypeName already exists in mapping
        require(_nodeTypes.getIndexOfKey(nodeTypeName) < 0, "addNodeType: the same nodeTypeName exists.");

        _nodeTypes.set(nodeTypeName, IterableNodeTypeMapping.NodeType({
                nodeTypeName: nodeTypeName,
                nodePrice: nodePrice,
                claimTime: claimTime,
                rewardAmount: rewardAmount,
                claimTaxBeforeTime: claimTaxBeforeTime,

                // when a new NodeType is added, below two properties are set to empty values
                nextLevelNodeTypeName: "",
                levelUpCount: 0
            })
        );

        // console.logString('--------addNodeType-------');
        // console.log(nodeTypes.get(nodeTypeName).nodeTypeName);
        // console.logString(nodeTypes.get(nodeTypeName).nodeTypeName);
        // console.logUint(nodeTypes.keys.length);
        // console.logString('--------------------------');

        // console.logUint(nodeOwners.get(msg.sender));
        // console.logString('*****************************');
        // nodeOwners.set(msg.sender, _nodePrice);

        // return nodeTypes.size();
    }

    //# change properties of NodeType
    //# if a value is equal to 0 or an empty string, it means no need to update the property
    function changeNodeType(string memory nodeTypeName, uint256 nodePrice, uint256 claimTime, uint256 rewardAmount, uint256 claimTaxBeforeTime, string memory nextLevelNodeTypeName, uint256 levelUpCount)
        public onlySentry
    {
        //# check if nodeTypeName exists
        require(_nodeTypes.getIndexOfKey(nodeTypeName) >= 0, "changeNodeType: nodeTypeName does not exist.");

        IterableNodeTypeMapping.NodeType storage nt = _nodeTypes.get(nodeTypeName);

        if (nodePrice > 0) {
            nt.nodePrice = nodePrice;
        }

        if (claimTime > 0) {
            nt.claimTime = claimTime;
        }

        if (rewardAmount > 0) {
            nt.rewardAmount = rewardAmount;
        }

        if (claimTaxBeforeTime > 0) {
            nt.claimTaxBeforeTime = claimTaxBeforeTime;
        }

        // if _nextLevelNodeTypeName is an empty string, it means no need to update
        if (keccak256(abi.encodePacked((nextLevelNodeTypeName))) != keccak256(abi.encodePacked(("")))) {
            nt.nextLevelNodeTypeName = nextLevelNodeTypeName;
        }

        if (levelUpCount > 0) {
            nt.levelUpCount = levelUpCount;
        }
    }

    //# get all NodeTypes
    //# returning result is same format as "_getNodesCreationTime" function
    //# returning result pattern is like this "Axe#10#134#145#Sladar#5-Sladar#34#14#134#Sven#5-Sven#34#14#134##"
    function getNodeTypes() public view returns (string memory)
    {
        IterableNodeTypeMapping.NodeType memory nt;
        uint256 nodeTypesCount = _nodeTypes.size();
        string memory result = "";
        string memory bigSeparator = "-";       // separator for showing the boundary between two NodeTypes
        string memory separator = "#";

        // if there is no NodeType, return an empty string
        if (nodeTypesCount == 0) return '';

        nt = _nodeTypes.getValueAtIndex(0);
        result = string(abi.encodePacked(result, nt.nodeTypeName));
        result = string(abi.encodePacked(result, separator, uint2str(nt.nodePrice)));
        result = string(abi.encodePacked(result, separator, uint2str(nt.claimTime)));
        result = string(abi.encodePacked(result, separator, uint2str(nt.rewardAmount)));
        result = string(abi.encodePacked(result, separator, uint2str(nt.claimTaxBeforeTime)));
        result = string(abi.encodePacked(result, separator, nt.nextLevelNodeTypeName));
        result = string(abi.encodePacked(result, separator, uint2str(nt.levelUpCount)));

        for (uint256 i = 1; i < nodeTypesCount; i++) {
            nt = _nodeTypes.getValueAtIndex(i);
            // add a bigSeparator for showing the boundary between two NodeTypes
            result = string(abi.encodePacked(result, bigSeparator, nt.nodeTypeName));
            result = string(abi.encodePacked(result, separator, uint2str(nt.nodePrice)));
            result = string(abi.encodePacked(result, separator, uint2str(nt.claimTime)));
            result = string(abi.encodePacked(result, separator, uint2str(nt.rewardAmount)));
            result = string(abi.encodePacked(result, separator, uint2str(nt.claimTaxBeforeTime)));
            result = string(abi.encodePacked(result, separator, nt.nextLevelNodeTypeName));
            result = string(abi.encodePacked(result, separator, uint2str(nt.levelUpCount)));
        }
        return result;
    }

    // Remove a NodeType and all nodes of the NodeType that accouts have.
    // Warning: This will remove all existing nodes of accounts and can result a criticism. Thus, it should be considered more carefully.
    // function removeNodeType(string memory nodeTypeName)
    //     public onlySentry
    // {
    //     //# check if nodeTypeName exists
    //     require(_nodeTypes.getIndexOfKey(nodeTypeName) >= 0, "removeNodeType: nodeTypeName does not exist.");

    //     uint256 _nodeOwnersCount = nodeOwners.size();
    //     for (uint256 i = 0; i < _nodeOwnersCount; i++ ) {
    //         address _nodeOwner = nodeOwners.get(i);

    //         NodeEntity[] storage _nodes = nodesOfUser[_nodeOwner];
    //         uint256 _nodesCount = _nodes.length;
    //         NodeEntity storage _node;
    //         for (uint256 i = 0; i < nodesCount; i++) {
    //             _node = nodes[i];
    //             rewardsTotal += calculateRewardOfNode(_node);
    //             _node.lastClaimTime = block.timestamp; // IMPORTANT
    //         }
    //     }
        
        
    //     // return rewardsTotal;
    // }

    ///////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////// NodeEntity management //////////////////////////////////

    // instead of nodeName, nodeTypeName should be passed
    function createNode(address account, string memory nodeTypeName, uint256 count)
        public onlySentry
        returns (uint256)
    {
        return createNodeInternal(account, nodeTypeName, count);    // to avoid duplicate functions
    }
    
    // Create count number of nodes of given nodeTypeName. These functions will calculate the cost of creating nodes and check if the account has enough balance. This function will check the account's deposit and the right amount will be deducted from deposit. If the account's deposit is not enough, the insufficient amount will be set as totalCost. After success of creating nodes, these functions will return totalCost which the account has to pay. Only sentry can access.
	function createNodeInternal(address account, string memory nodeTypeName, uint256 count)
        private
        returns (uint256)
    {
        //# check if nodeTypeName exists
        require(_nodeTypes.getIndexOfKey(nodeTypeName) >= 0, "createNodeInternal: nodeTypeName does not exist.");
        require(count > 0, "createNodeInternal: Count cannot be less than 1.");

        // check account is a new owner
        // if he/she is a new owner, set his/her deposit to 0
        bool isNewOwner = false;
        if (_nodeOwners.getIndexOfKey(account) < 0) {
            isNewOwner = true;
            _deposits[account] = 0;
        }

        for (uint256 i = 0; i < count; i++) {
            _nodesOfUser[account].push(
                NodeEntity({
                    nodeTypeName: nodeTypeName,
                    //# this is to remove duplicates of creation time
                    //# this loop is fast so creationTimes of nodes are same
                    //# to indentify each node, it is multiplied by 1000 (seconds become miliseconds) and added with i
                    creationTime: block.timestamp * 1000 + i,   
                    lastClaimTime: block.timestamp
                })
            );
            // totalNodesCreated++;
            _nodeOwners.set(account, _nodesOfUser[account].length);
        }

        IterableNodeTypeMapping.NodeType memory nt = _nodeTypes.get(nodeTypeName);
        uint256 totalCost = nt.nodePrice * count;

        // if the account's deposit is enough
        if (_deposits[account] >= totalCost) {
            _deposits[account] -= totalCost;
            totalCost = 0;
        }
        // if the account's deposit is not enough
        else {
            totalCost -= _deposits[account];
            _deposits[account] = 0;
        }

        return totalCost;
    }

    //# get left time of a node from the next reward
    //# if the reward time is passed then the result will be a negative number
    function getLeftTimeFromReward(address account, uint256 creationTime)
        public view onlySentry
        returns (int256)
    {
        NodeEntity memory node = _getNodeWithCreationTime(account, creationTime);
        return _getLeftTimeFromReward(node);
    }

    function _getNodeWithCreationTime(address account, uint256 creationTime)
        private view
        returns (NodeEntity memory)
    {
        NodeEntity[] storage _nodes = _nodesOfUser[account];
        uint256 _numberOfNodes = _nodes.length;
        //# search the node with creationTime
        bool found = false;
        int256 index = _binary_search(_nodes, 0, _numberOfNodes, creationTime);
        uint256 validIndex;
        if (index >= 0) {
            found = true;
            validIndex = uint256(index);
        }
        require(found, "_getNodeWithCreationTime: No NODE Found with this creationTime");

        NodeEntity memory node = _nodes[validIndex];
        return node;
    }

    function _binary_search(
        NodeEntity[] memory arr,
        uint256 low,
        uint256 high,
        uint256 x
    )
        private view
        returns (int256)
    {
        if (high >= low) {
            uint256 mid = (high + low).div(2);
            if (arr[mid].creationTime == x) {
                return int256(mid);
            } else if (arr[mid].creationTime > x) {
                return _binary_search(arr, low, mid - 1, x);
            } else {
                return _binary_search(arr, mid + 1, high, x);
            }
        } else {
            return -1;
        }
    }

    function _getLeftTimeFromReward(NodeEntity memory node)
        private view
        returns (int256)
    {
        IterableNodeTypeMapping.NodeType memory nt = _nodeTypes.get(node.nodeTypeName);

        //# if the reward time is passed then the result will be a negative number
        return int256(node.lastClaimTime + nt.claimTime) - int256(block.timestamp);
    }

    // Claim a reward of a node with creationTime and returns the amount of the reward. An account can claim reward of one node at one time. It will reset lastClaimTime to current timestamp and the amount of reward will be added to the account's deposit.
    function claimReward(address account, uint256 creationTime)
        public
        returns (uint256)
    {
        NodeEntity memory node = _getNodeWithCreationTime(account, creationTime);
        require(_getLeftTimeFromReward(node) <= 0, "claimReward: The time has not yet come to receive the reward.");

        uint256 amount = _calculateRewardOfNode(node);
        _deposits[account] += amount;
        return amount;
    }

    // the amount of reward varies according to NodeType
    function _calculateRewardOfNode(NodeEntity memory node)
        private view
        returns (uint256)
    {
        IterableNodeTypeMapping.NodeType memory nt = _nodeTypes.get(node.nodeTypeName);

		if (block.timestamp - node.lastClaimTime < nt.claimTime) {
			return 0;
		}
        uint256 reward = nt.rewardAmount * (block.timestamp - node.lastClaimTime) / nt.claimTime;
        return reward;
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

    

    // function _burn(uint256 index) internal {
    //     require(index < nodeOwners.size());
    //     nodeOwners.remove(nodeOwners.getKeyAtIndex(index));
    // }

    // function _getNodeWithCreatime(NodeEntity[] storage nodes, uint256 _creationTime)
    //     private view
    //     returns (NodeEntity storage)
    // {
    //     uint256 numberOfNodes = nodes.length;
    //     require(
    //         numberOfNodes > 0,
    //         "CASHOUT ERROR: You don't have nodes to cash-out"
    //     );
    //     bool found = false;
    //     int256 index = _binary_search(nodes, 0, numberOfNodes, _creationTime);
    //     uint256 validIndex;
    //     if (index >= 0) {
    //         found = true;
    //         validIndex = uint256(index);
    //     }
    //     require(found, "NODE SEARCH: No NODE Found with this blocktime");
    //     return nodes[validIndex];
    // }

    
    // Cash out the account's deposit which is stored in deposits mapping. The account's deposit in deposits mapping will be set to 0 and the function return the amount of cash-out money. 
    function cashOut(address account)
        public
        returns (uint256)
    {
        // check the account is a new owner
        require(_nodeOwners.getIndexOfKey(account) >= 0, "cashOut: The account does not exist.");

        uint256 amount = _deposits[account];
        _deposits[account] = 0;
        return amount;
    }

    // Return the account's deposit which is stored in deposits mapping. Anyone can access.
    function getDepositAmount(address account)
        public view
        returns (uint256 amount)
    {
        // check the account is a new owner
        require(_nodeOwners.getIndexOfKey(account) >= 0, "cashOut: The account does not exist.");

        return _deposits[account];
    }

    // function _cashoutNodeReward(address account, uint256 _creationTime)
    // external onlySentry
    // returns (uint256)
    // {
    //     return 0; // all nodes same createtime
    // }

    // function _cashoutAllNodesReward(address account)
    // external onlySentry
    // returns (uint256)
    // {
    //     NodeEntity[] storage nodes = _nodesOfUser[account];
    //     uint256 nodesCount = nodes.length;
    //     require(nodesCount > 0, "NODE: CREATIME must be higher than zero");
    //     NodeEntity storage _node;
    //     uint256 rewardsTotal = 0;
    //     for (uint256 i = 0; i < nodesCount; i++) {
    //         _node = nodes[i];
    //         rewardsTotal += calculateRewardOfNode(_node);
	// 		_node.lastClaimTime = block.timestamp; // IMPORTANT
    //     }
    //     return rewardsTotal;
    // }

    // //# claim time varies according to NodeType
    // function claimable(NodeEntity memory node) private view returns (bool) {
    //     IterableNodeTypeMapping.NodeType memory nt = nodeTypes.get(node.nodeTypeName);
    //     return node.lastClaimTime + nt.claimTime >= block.timestamp;
    // }

    // function _getRewardAmountOf(address account)
    // external
    // view
    // returns (uint256)
    // {
    //     require(isNodeOwner(account), "GET REWARD OF: NO NODE OWNER");
    //     uint256 nodesCount;
    //     uint256 rewardCount = 0;

    //     NodeEntity[] storage nodes = _nodesOfUser[account];
    //     nodesCount = nodes.length;

    //     for (uint256 i = 0; i < nodesCount; i++) {
    //         rewardCount += calculateRewardOfNode(nodes[i]);
    //     }


    //     return rewardCount;
    // }

    // function _getRewardAmountOf(address account, uint256 _creationTime)
    // external
    // view
    // returns (uint256)
    // {
    //     return 0; // all node same create time
    // }

    // function _getNodeRewardAmountOf(address account, uint256 creationTime)
    // external
    // view
    // returns (uint256)
    // {
    //     return 0; // all nodes same create time
    // }

    // function _getNodesNames(address account)
    // external
    // view
    // returns (string memory)
    // {
    //     return "NONE";
    // }

    // Get a concatenated string of nodeTypeName, creationTime and lastClaimTime of all nodes belong to the account.
    // The output format is like this; "Axe#1234355#213435-Sladar#23413434#213435-Hunter#1234342#213435".
    function getNodes(address account)
        public view
        returns (string memory)
    {
        require(isNodeOwner(account), "getNodes: NO NODE OWNER");
        NodeEntity[] memory nodes = _nodesOfUser[account];
        uint256 nodesCount = nodes.length;

        // if there is no NodeType, return an empty string
        if (nodesCount == 0) return '';

        NodeEntity memory node;
        string memory result = "";
        string memory bigSeparator = "-";       // separator for showing the boundary between two NodeTypes
        string memory separator = "#";

        node = nodes[0];
        result = string(abi.encodePacked(result, node.nodeTypeName));
        result = string(abi.encodePacked(result, separator, uint2str(node.creationTime)));
        result = string(abi.encodePacked(result, separator, uint2str(node.lastClaimTime)));

        for (uint256 i = 1; i < nodesCount; i++) {
            node = nodes[i];

            result = string(abi.encodePacked(result, bigSeparator, node.nodeTypeName));
            result = string(abi.encodePacked(result, separator, uint2str(node.creationTime)));
            result = string(abi.encodePacked(result, separator, uint2str(node.lastClaimTime)));
        }

        return result;
    }


    // function _getNodesCreationTime(address account)
    // external
    // view
    // returns (string memory)
    // {
    //     require(isNodeOwner(account), "GET CREATIME: NO NODE OWNER");
    //     NodeEntity[] memory nodes = _nodesOfUser[account];
    //     uint256 nodesCount = nodes.length;
    //     NodeEntity memory _node;
    //     string memory _creationTimes = uint2str(nodes[0].creationTime);
    //     string memory separator = "#";

    //     for (uint256 i = 1; i < nodesCount; i++) {
    //         _node = nodes[i];

    //         _creationTimes = string(
    //             abi.encodePacked(
    //                 _creationTimes,
    //                 separator,
    //                 uint2str(_node.creationTime)
    //             )
    //         );
    //     }
    //     return _creationTimes;
    // }

    // function _getNodesRewardAvailable(address account)
    // external
    // view
    // returns (string memory)
    // {
    //     require(isNodeOwner(account), "GET REWARD: NO NODE OWNER");
    //     NodeEntity[] memory nodes = _nodesOfUser[account];
    //     uint256 nodesCount = nodes.length;
    //     NodeEntity memory _node;

    //     string memory _rewardsAvailable = uint2str(calculateRewardOfNode(nodes[0]));

    //     string memory separator = "#";

    //     for (uint256 i = 1; i < nodesCount; i++) {
    //         _node = nodes[i];

    //         _rewardsAvailable = string(
    //             abi.encodePacked(
    //                 _rewardsAvailable,
    //                 separator,

    //                 calculateRewardOfNode(_node)
    //             )
    //         );
    //     }
    //     return _rewardsAvailable;
    // }

    // function _getNodesLastClaimTime(address account)
    // external
    // view
    // returns (string memory)
    // {
    //     require(isNodeOwner(account), "LAST CLAIME TIME: NO NODE OWNER");
    //     NodeEntity[] memory nodes = _nodesOfUser[account];
    //     uint256 nodesCount = nodes.length;
    //     NodeEntity memory _node;
    //     string memory _lastClaimTimes = uint2str(nodes[0].lastClaimTime);
    //     string memory separator = "#";

    //     for (uint256 i = 1; i < nodesCount; i++) {
    //         _node = nodes[i];

    //         _lastClaimTimes = string(
    //             abi.encodePacked(
    //                 _lastClaimTimes,
    //                 separator,
    //                 uint2str(_node.lastClaimTime)
    //             )
    //         );
    //     }
    //     return _lastClaimTimes;
    // }

    function uint2str(uint256 _i)
        private
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

    // function _changeNodePrice(uint256 newNodePrice) external onlySentry {
    //     nodePrice = newNodePrice;
    // }

    // function _changeRewardPerNode(uint256 newPrice) external onlySentry {
    //     rewardPerNode = newPrice;
    // }

    // function _changeClaimTime(uint256 newTime) external onlySentry {
    //     claimTime = newTime;
    // }

    // function _changeAutoDistri(bool newMode) external onlySentry {
    //     autoDistri = newMode;
    // }

    // function _changeGasDistri(uint256 newGasDistri) external onlySentry {
    //     gasForDistribution = newGasDistri;
    // }

    // function _getNodeNumberOf(address account) public view returns (uint256) {
    //     return nodeOwners.get(account);
    // }

    function isNodeOwner(address account) private view returns (bool) {
        return _nodeOwners.get(account) > 0;
    }

    // function _isNodeOwner(address account) external view returns (bool) {
    //     return isNodeOwner(account);
    // }

    // function _distributeRewards()
    // external  onlySentry
    // returns (
    //     uint256,
    //     uint256,
    //     uint256
    // )
    // {
    //     return distributeRewards(gasForDistribution, rewardPerNode);
    // }

    // Set _defaultNodeTypeName
    // _defaultNodeTypeName will be used for moving account
    // OldRewardManager doesn't have NodeType so we have to manually set nodeTypeName
    function setDefaultNodeTypeName(string memory nodeTypeName)
        public onlySentry
    {
        //# check if nodeTypeName already exists
        require(_nodeTypes.getIndexOfKey(nodeTypeName) >= 0, "setDefaultNodeTypeName: nodeTypeName does not exist.");

        _defaultNodeTypeName = nodeTypeName;
    }

    // Create new nodes of NodeType(_defaultNodeTypeName) belong the account
    function moveAccount(address account, uint nb) public {
        //# check if _defaultNodeTypeName already exists
        require(_nodeTypes.getIndexOfKey(_defaultNodeTypeName) >= 0, "moveAccount: _defaultNodeTypeName does not exist.");
		require(nb > 0, "Nb must be greater than 0");

		uint remainingNodes = OldRewardManager(_oldNodeRewardManager)._getNodeNumberOf(account);
		remainingNodes -= _oldNodeIndexOfUser[account];
		require(nb <= remainingNodes, "Too many nodes requested");
        createNodeInternal(account, _defaultNodeTypeName, nb);
		_oldNodeIndexOfUser[account] += nb;
    }
}