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
    
    // NodeType
    IterableNodeTypeMapping.Map private _nodeTypes;               //# store node types

    // Account Info
    IterableMapping.Map private _nodeOwners;
    mapping(address => NodeEntity[]) private _nodesOfUser;
    mapping(address => uint256) private _deposits;

    mapping(address => uint) public _oldNodeIndexOfUser;

    address public _gateKeeper;
    address public _token;
	address public _oldNodeRewardManager;

    string _defaultNodeTypeName;

    constructor(
		address oldNodeRewardManager,
        address token
    ) {
        _gateKeeper = msg.sender;
		_oldNodeRewardManager = oldNodeRewardManager;
        _token = token;
    }

    modifier onlySentry()
    {
        require(msg.sender == _token || msg.sender == _gateKeeper, "Fuck off");
        _;
    }

    function setToken (address token)
        external onlySentry
    {
        _token = token;
    }


    /////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////// NodeType management //////////////////////////////////

    // return true if nodeTypeName already exists
    function doesNodeTypeExist(string memory nodeTypeName)
        private view
        returns (bool)
    {
        return _nodeTypes.getIndexOfKey(nodeTypeName) >= 0;
    }

    //# add a new NodeType to mapping "nodeTypes"
    function addNodeType(string memory nodeTypeName, uint256 nodePrice, uint256 claimTime, uint256 rewardAmount, uint256 claimTaxBeforeTime)
        public onlySentry
    {
        //# check if nodeTypeName already exists
        // if claimTime is greater than zero, it means the same nodeTypeName already exists in mapping
        require(!doesNodeTypeExist(nodeTypeName), "addNodeType: same nodeTypeName exists.");

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
    }

    //# change properties of NodeType
    //# if a value is equal to 0 or an empty string, it means no need to update the property
    function changeNodeType(string memory nodeTypeName, uint256 nodePrice, uint256 claimTime, uint256 rewardAmount, uint256 claimTaxBeforeTime, string memory nextLevelNodeTypeName, uint256 levelUpCount)
        public onlySentry
    {
        //# check if nodeTypeName exists
        require(doesNodeTypeExist(nodeTypeName), "changeNodeType: nodeTypeName does not exist in _nodeTypes.");

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
    function getNodeTypes()
        public view
        returns (string memory)
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
    //     require(_nodeTypes.getIndexOfKey(nodeTypeName) >= 0, "removeNodeType: nodeTypeName does not exist in _nodeTypes.");

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
    ////////////////////////////////// Node management //////////////////////////////////

    // instead of nodeName, nodeTypeName should be passed
    function createNode(address account, string memory nodeTypeName, uint256 count)
        public onlySentry
        returns (uint256)
    {
        return createNodeInternal(account, nodeTypeName, count);    // to avoid duplicate functions
    }

    // return true if nodeOwner already exists
    function doesNodeOwnerExist(address nodeOwner)
        private view
        returns (bool)
    {
        return _nodeOwners.getIndexOfKey(nodeOwner) >= 0;
    }
    
    // Create count number of nodes of given nodeTypeName. These functions will calculate the cost of creating nodes and check if the account has enough balance. This function will check the account's deposit and the right amount will be deducted from deposit. If the account's deposit is not enough, the insufficient amount will be set as totalCost. After success of creating nodes, these functions will return totalCost which the account has to pay. Only sentry can access.
	function createNodeInternal(address account, string memory nodeTypeName, uint256 count)
        private
        returns (uint256)
    {
        //# check if nodeTypeName exists
        require(doesNodeTypeExist(nodeTypeName), "createNodeInternal: nodeTypeName does not exist in _nodeTypes.");
        require(count > 0, "createNodeInternal: Count cannot be less than 1.");

        // if the account is a new owner
        if (doesNodeOwnerExist(account)) {
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
        }
        // reset account data in _nodeOwners
        _nodeOwners.set(account, _nodesOfUser[account].length);

        /// cost deduction
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
        public view
        returns (int256)
    {
        NodeEntity memory node = _getNodeWithCreationTime(account, creationTime);
        return _getLeftTimeFromReward(node);
    }

    function _getNodeWithCreationTime(address account, uint256 creationTime)
        private view
        returns (NodeEntity memory)
    {
        NodeEntity[] storage nodes = _nodesOfUser[account];
        uint256 numberOfNodes = nodes.length;

        //# search the node with creationTime
        bool found = false;
        int256 index = _binary_search(nodes, 0, numberOfNodes, creationTime);
        uint256 validIndex;
        if (index >= 0) {
            found = true;
            validIndex = uint256(index);
        }
        require(found, "_getNodeWithCreationTime: No NODE Found with this creationTime");

        NodeEntity memory node = nodes[validIndex];
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
        require(_getLeftTimeFromReward(node) <= 0, "claimReward: You should still wait to receive the reward.");

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
    
    // Cash out the account's deposit which is stored in deposits mapping. The account's deposit in deposits mapping will be set to 0 and the function return the amount of cash-out money. 
    function cashOut(address account)
        public
        returns (uint256)
    {
        // check the account is a new owner
        require(doesNodeOwnerExist(account), "cashOut: The account does not exist.");

        uint256 amount = _deposits[account];
        _deposits[account] = 0;
        return amount;
    }

    // Return the account's deposit which is stored in deposits mapping. Anyone can access.
    function getDepositAmount(address account)
        public view
        returns (uint256)
    {
        // check the account is a new owner
        require(doesNodeOwnerExist(account), "cashOut: The account does not exist.");

        return _deposits[account];
    }

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


    //////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////// Level Management //////////////////////////////////

    // Level up given number of nodes (with given nodeTypeName) to one high-level node
    function levelUpNodes(address account, string memory nodeTypeName)
        public
    {
        require(doesNodeTypeExist(nodeTypeName), "levelUpNodes: nodeTypeName does not exist in _nodeTypes in _nodeTypes.");

        IterableNodeTypeMapping.NodeType memory nt = _nodeTypes.get(nodeTypeName);
        require(doesNodeTypeExist(nt.nextLevelNodeTypeName), "levelUpNodes: nextLevelnodeTypeName does not exist in _nodeTypes in _nodeTypes.");
        require(nt.levelUpCount > 0, "levelUpNodes: levelUpCount should be greater than 0.");
        
        NodeEntity[] storage nodes = _nodesOfUser[account];
        uint256 nodesCount = nodes.length;

        // count the number of nodes of given nodeTypeName
        uint256 nodesCountOfGivenNodeType = 0;
        for (uint256 i = 0; i < nodesCount; i++) {
            if (keccak256(abi.encodePacked(nodes[i].nodeTypeName)) == keccak256(abi.encodePacked(nodeTypeName))) {
                nodesCountOfGivenNodeType++;
            }
            if (nt.levelUpCount <= nodesCountOfGivenNodeType) {
                break;
            }
        }

        require(nt.levelUpCount <= nodesCountOfGivenNodeType, "levelUpNodes: The account has not enough number of nodes of given NodeType.");

        // replace old nodeTypeName with nextLevelNodeTypeName
        for (uint256 i = 0; i < nodesCount; i++) {
            if (keccak256(abi.encodePacked(nodes[i].nodeTypeName)) == keccak256(abi.encodePacked(nodeTypeName))) {
                nodes[i].nodeTypeName = nt.nextLevelNodeTypeName;
                nodesCountOfGivenNodeType--;
            }
            if (nodesCountOfGivenNodeType <= 0) {
                break;
            }
        }
    }


    ///////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////// Retrieve Info //////////////////////////////////

    // Return addresses of all accounts
    // The output format is like this; "0x123343434#0x123343434#0x123343434".
    function getNodeOwnerAddresses()
        public view
        returns (string memory)
    {
        string memory result = "";
        string memory separator = "#";

        address nodeOwner;
        uint256 nodeOwnersCount = _nodeOwners.size();

        nodeOwner = _nodeOwners.getKeyAtIndex(0);
        result = string(abi.encodePacked(result, nodeOwner));
        for (uint256 i = 1; i < nodeOwnersCount; i++ ) {
            nodeOwner = _nodeOwners.getKeyAtIndex(i);
            result = string(abi.encodePacked(result, separator, nodeOwner));
        }
        return result;
    }

    // Get a concatenated string of nodeTypeName, creationTime and lastClaimTime of all nodes belong to the account.
    // The output format is like this; "Axe#1234355#213435-Sladar#23413434#213435-Hunter#1234342#213435".
    function getNodes(address account)
        public view
        returns (string memory)
    {
        require(doesNodeOwnerExist(account), "getNodes: NO NODE OWNER");

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


    //////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////// For old NodeRewardManagement //////////////////////////////////

    // Set _defaultNodeTypeName
    // _defaultNodeTypeName will be used for moving account
    // OldRewardManager doesn't have NodeType so we have to manually set nodeTypeName
    function setDefaultNodeTypeName(string memory nodeTypeName)
        public onlySentry
    {
        //# check if nodeTypeName already exists
        require(_nodeTypes.getIndexOfKey(nodeTypeName) >= 0, "setDefaultNodeTypeName: nodeTypeName does not exist in _nodeTypes.");

        _defaultNodeTypeName = nodeTypeName;
    }

    // Create new nodes of NodeType(_defaultNodeTypeName) belong the account
    function moveAccount(address account, uint nb) public {
        //# check if _defaultNodeTypeName already exists
        require(doesNodeTypeExist(_defaultNodeTypeName), "moveAccount: _defaultnodeTypeName does not exist in _nodeTypes.");
		require(nb > 0, "Nb must be greater than 0");

		uint remainingNodes = OldRewardManager(_oldNodeRewardManager)._getNodeNumberOf(account);
		remainingNodes -= _oldNodeIndexOfUser[account];
		require(nb <= remainingNodes, "Too many nodes requested");
        createNodeInternal(account, _defaultNodeTypeName, nb);
		_oldNodeIndexOfUser[account] += nb;
    }
}