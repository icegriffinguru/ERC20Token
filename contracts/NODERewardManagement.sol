// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/finance/PaymentSplitter.sol";
import "@traderjoe-xyz/core/contracts/traderjoe/interfaces/IJoeRouter02.sol";
import "@traderjoe-xyz/core/contracts/traderjoe/interfaces/IJoeFactory.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IterableMapping.sol";
import "./IterableNodeTypeMapping.sol";
import "./OldRewardManager.sol";

import "hardhat/console.sol";

contract NODERewardManagement is Ownable, PaymentSplitter {
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
    address public _polarTokenAddress;
	address public _oldNodeRewardManager;
    IERC20 public _polarTokenContract;

    string _defaultNodeTypeName;

    //////////////////////// Liqudity Management ////////////////////////
    IJoeRouter02 public uniswapV2Router;

    address public uniswapV2Pair;
    address public futurUsePool;
    address public distributionPool;
    address public poolHandler;

    uint256 public rewardsFee;
    uint256 public liquidityPoolFee;
    uint256 public futurFee;
    uint256 public totalFees;

    uint256 public cashoutFee;

    uint256 public rwSwap;
    bool private swapping = false;
    bool private swapLiquify = true;
    uint256 public swapTokensAmount;

    mapping(address => bool) public _isBlacklisted;
    mapping(address => bool) public automatedMarketMakerPairs;
	mapping(address => bool) public _isSuper;

    event UpdateUniswapV2Router(
        address indexed newAddress,
        address indexed oldAddress
    );

    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);

    event LiquidityWalletUpdated(
        address indexed newLiquidityWallet,
        address indexed oldLiquidityWallet
    );

    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity
    );

    constructor(
		address oldNodeRewardManager,
        address token,
        address[] memory payees,
        uint256[] memory shares,
        address[] memory addresses,
        uint256[] memory fees,
        uint256 swapAmount,
        address uniV2Router
    ) PaymentSplitter(payees, shares) {
        _gateKeeper = msg.sender;
		_oldNodeRewardManager = oldNodeRewardManager;
        _polarTokenAddress = token;
        _polarTokenContract = IERC20(_polarTokenAddress);     // get the instance of Polar token contract as IERC20 interface

        //////////////////////// Liqudity Management ////////////////////////
        futurUsePool = addresses[1];
        distributionPool = addresses[2];
		poolHandler = addresses[3];

        require(futurUsePool != address(0) && distributionPool != address(0) && poolHandler != address(0), "FUTUR, REWARD & POOL ADDRESS CANNOT BE ZERO");

        require(uniV2Router != address(0), "ROUTER CANNOT BE ZERO");
        IJoeRouter02 _uniswapV2Router = IJoeRouter02(uniV2Router);

        address _uniswapV2Pair = IJoeFactory(_uniswapV2Router.factory())
            // Polar token and WAVAX token
            .createPair(_polarTokenAddress, _uniswapV2Router.WAVAX());

        uniswapV2Router = _uniswapV2Router;
        uniswapV2Pair = _uniswapV2Pair;

        _setAutomatedMarketMakerPair(_uniswapV2Pair, true);

        require(
            fees[0] != 0 && fees[1] != 0 && fees[2] != 0 && fees[3] != 0,
            "CONSTR: Fees equal 0"
        );
        futurFee = fees[0];
        rewardsFee = fees[1];
        liquidityPoolFee = fees[2];
        cashoutFee = fees[3];
        rwSwap = fees[4];

        totalFees = rewardsFee.add(liquidityPoolFee).add(futurFee);

        require(swapAmount > 0, "CONSTR: Swap amount incorrect");
        swapTokensAmount = swapAmount * (10**18);
    }

    modifier onlySentry()
    {
        require(msg.sender == _polarTokenAddress || msg.sender == _gateKeeper, "Fuck off");
        _;
    }

    function setToken (address token)
        external onlySentry
    {
        _polarTokenAddress = token;
    }


    /////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////// NodeType management //////////////////////////////////

    //# add a new NodeType to mapping "nodeTypes"
    function addNodeType(string memory nodeTypeName, uint256 nodePrice, uint256 claimTime, uint256 rewardAmount, uint256 claimTaxBeforeTime, string memory nextLevelNodeTypeName, uint256 levelUpCount)
        public onlySentry
    {
        //# check if nodeTypeName already exists
        // if claimTime is greater than zero, it means the same nodeTypeName already exists in mapping
        require(!_doesNodeTypeExist(nodeTypeName), "addNodeType: same nodeTypeName exists.");

        // if nextLevelNodeTypeName is not an empty string, it means it has next-level node
        if (keccak256(abi.encodePacked((nextLevelNodeTypeName))) != keccak256(abi.encodePacked(("")))) {
            require(_doesNodeTypeExist(nextLevelNodeTypeName), "addNodeType: nextLevelnodeTypeName does not exist in _nodeTypes in _nodeTypes.");
            require(levelUpCount > 0, "addNodeType: levelUpCount should be greater than 0.");
        }
        // // if nextLevelNodeTypeName is an empty string, it means it has not a next-level node
        else {
            nextLevelNodeTypeName = "";
            levelUpCount = 0;
        }

        _nodeTypes.set(nodeTypeName, IterableNodeTypeMapping.NodeType({
                nodeTypeName: nodeTypeName,
                nodePrice: nodePrice,
                claimTime: claimTime,
                rewardAmount: rewardAmount,
                claimTaxBeforeTime: claimTaxBeforeTime,
                nextLevelNodeTypeName: nextLevelNodeTypeName,
                levelUpCount: levelUpCount
            })
        );
    }

    //# change properties of NodeType
    //# if a value is equal to 0 or an empty string, it means no need to update the property
    function changeNodeType(string memory nodeTypeName, uint256 nodePrice, uint256 claimTime, uint256 rewardAmount, uint256 claimTaxBeforeTime, string memory nextLevelNodeTypeName, uint256 levelUpCount)
        public onlySentry
    {
        //# check if nodeTypeName exists
        require(_doesNodeTypeExist(nodeTypeName), "changeNodeType: nodeTypeName does not exist in _nodeTypes.");

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
        result = string(abi.encodePacked(result, separator, _uint2str(nt.nodePrice)));
        result = string(abi.encodePacked(result, separator, _uint2str(nt.claimTime)));
        result = string(abi.encodePacked(result, separator, _uint2str(nt.rewardAmount)));
        result = string(abi.encodePacked(result, separator, _uint2str(nt.claimTaxBeforeTime)));
        result = string(abi.encodePacked(result, separator, nt.nextLevelNodeTypeName));
        result = string(abi.encodePacked(result, separator, _uint2str(nt.levelUpCount)));

        for (uint256 i = 1; i < nodeTypesCount; i++) {
            nt = _nodeTypes.getValueAtIndex(i);
            // add a bigSeparator for showing the boundary between two NodeTypes
            result = string(abi.encodePacked(result, bigSeparator, nt.nodeTypeName));
            result = string(abi.encodePacked(result, separator, _uint2str(nt.nodePrice)));
            result = string(abi.encodePacked(result, separator, _uint2str(nt.claimTime)));
            result = string(abi.encodePacked(result, separator, _uint2str(nt.rewardAmount)));
            result = string(abi.encodePacked(result, separator, _uint2str(nt.claimTaxBeforeTime)));
            result = string(abi.encodePacked(result, separator, nt.nextLevelNodeTypeName));
            result = string(abi.encodePacked(result, separator, _uint2str(nt.levelUpCount)));
        }
        return result;
    }


    ///////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////// Node management //////////////////////////////////

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
        require(_doesNodeTypeExist(nodeTypeName), "createNodeInternal: nodeTypeName does not exist in _nodeTypes.");
        require(count > 0, "createNodeInternal: Count cannot be less than 1.");

        // if the account is a new owner
        if (_doesNodeOwnerExist(account)) {
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

    // Claim a reward of a node with creationTime and returns the amount of the reward. An account can claim reward of one node at one time. It will reset lastClaimTime to current timestamp and the amount of reward will be added to the account's deposit.
    function claimReward(address account, uint256 creationTime)
        public
        returns (uint256)
    {
        NodeEntity storage node = _getNodeWithCreationTime(account, creationTime);
        // require(_getLeftTimeFromReward(node) <= 0, "claimReward: You should still wait to receive the reward.");

        uint256 amount = _calculateRewardOfNode(node);
        _deposits[account] += amount;

        // reset lastClaimTime of NodeEntity
        node.lastClaimTime = block.timestamp;

        return amount;
    }
    
    // Cash out the account's deposit which is stored in deposits mapping. The account's deposit in deposits mapping will be set to 0 and the function return the amount of cash-out money. 
    function cashOut(address account)
        public
        returns (uint256)
    {
        // check the account is a new owner
        require(_doesNodeOwnerExist(account), "cashOut: The account does not exist.");

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
        require(_doesNodeOwnerExist(account), "cashOut: The account does not exist.");

        return _deposits[account];
    }


    //////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////// Level Management //////////////////////////////////

    // Level up given number of nodes (with given nodeTypeName) to one high-level node
    function levelUpNodes(address account, string memory nodeTypeName)
        public
    {
        require(_doesNodeTypeExist(nodeTypeName), "levelUpNodes: nodeTypeName does not exist in _nodeTypes in _nodeTypes.");

        IterableNodeTypeMapping.NodeType memory nt = _nodeTypes.get(nodeTypeName);
        require(_doesNodeTypeExist(nt.nextLevelNodeTypeName), "levelUpNodes: nextLevelnodeTypeName does not exist in _nodeTypes in _nodeTypes.");
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
        uint256 newPos = 0;
        for (uint256 i = 0; i < nodesCount; i++) {
            if (nodesCountOfGivenNodeType > 0 && keccak256(abi.encodePacked(nodes[i].nodeTypeName)) == keccak256(abi.encodePacked(nodeTypeName))) {
                nodesCountOfGivenNodeType--;
            }
            else {
                nodes[newPos] = nodes[i];
                newPos++;
            }
        }

        // remove left NodeEntitys
        for (uint256 i = 0; i < nt.levelUpCount; i++) {
            nodes.pop();
        }

        // add a new NodeEntity of next-level NodeType
        nodes.push(NodeEntity(nt.nextLevelNodeTypeName, block.timestamp, block.timestamp));
    }


    ///////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////// Retrieve Info //////////////////////////////////

    // Return addresses of all accounts
    // The output format is like this; "0x123343434#100-0x123343434#200-0x123343434#300".
    function getNodeOwners()
        public view onlySentry
        returns (string memory)
    {
        string memory result = "";
        string memory bigSeparator = "-";
        string memory separator = "#";

        address nodeOwner;
        uint256 nodeOwnersCount = _nodeOwners.size();

        nodeOwner = _nodeOwners.getKeyAtIndex(0);
        result = _addressToString(nodeOwner);
        result = string(abi.encodePacked(result, separator, _uint2str(_deposits[nodeOwner])));
        for (uint256 i = 1; i < nodeOwnersCount; i++ ) {
            nodeOwner = _nodeOwners.getKeyAtIndex(i);
            result = string(abi.encodePacked(result, bigSeparator, _addressToString(nodeOwner)));
            result = string(abi.encodePacked(result, separator, _uint2str(_deposits[nodeOwner])));
        }
        return result;
    }

    // Get a concatenated string of nodeTypeName, creationTime and lastClaimTime of all nodes belong to the account.
    // The output format is like this; "Axe#1234355#213435-Sladar#23413434#213435-Hunter#1234342#213435".
    function getNodes(address account)
        public view onlySentry
        returns (string memory)
    {
        require(_doesNodeOwnerExist(account), "getNodes: NO NODE OWNER");

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
        result = string(abi.encodePacked(result, separator, _uint2str(node.creationTime)));
        result = string(abi.encodePacked(result, separator, _uint2str(node.lastClaimTime)));

        for (uint256 i = 1; i < nodesCount; i++) {
            node = nodes[i];

            result = string(abi.encodePacked(result, bigSeparator, node.nodeTypeName));
            result = string(abi.encodePacked(result, separator, _uint2str(node.creationTime)));
            result = string(abi.encodePacked(result, separator, _uint2str(node.lastClaimTime)));
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
        require(_doesNodeTypeExist(_defaultNodeTypeName), "moveAccount: _defaultnodeTypeName does not exist in _nodeTypes.");
		require(nb > 0, "Nb must be greater than 0");

		uint remainingNodes = OldRewardManager(_oldNodeRewardManager)._getNodeNumberOf(account);
		remainingNodes -= _oldNodeIndexOfUser[account];
		require(nb <= remainingNodes, "Too many nodes requested");
        createNodeInternal(account, _defaultNodeTypeName, nb);
		_oldNodeIndexOfUser[account] += nb;
    }


    ///////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////// Private Functions //////////////////////////////////

    // return true if nodeTypeName already exists
    function _doesNodeTypeExist(string memory nodeTypeName)
        private view
        returns (bool)
    {
        return _nodeTypes.getIndexOfKey(nodeTypeName) >= 0;
    }

    // return true if nodeOwner already exists
    function _doesNodeOwnerExist(address nodeOwner)
        private view
        returns (bool)
    {
        return _nodeOwners.getIndexOfKey(nodeOwner) >= 0;
    }

    function _getNodeWithCreationTime(address account, uint256 creationTime)
        private view
        returns (NodeEntity storage)
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

        NodeEntity storage node = nodes[validIndex];
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

    // the amount of reward varies according to NodeType
    function _calculateRewardOfNode(NodeEntity memory node)
        private view
        returns (uint256)
    {
        IterableNodeTypeMapping.NodeType memory nt = _nodeTypes.get(node.nodeTypeName);

        uint256 reward = 0;

        // if claimed before cliamTime, claimTaxBeforeTime should be charged
		if (block.timestamp - node.lastClaimTime < nt.claimTime) {
            reward = nt.rewardAmount * (block.timestamp - node.lastClaimTime) * (100 - nt.claimTaxBeforeTime) / (nt.claimTime * 100);
		}
        // after claimTime
        else {
            reward = nt.rewardAmount;
        }

        return reward;
    }

    function _uint2str(uint256 _i)
        private pure
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

    // convert address to string
    function _addressToString(address account)
        private pure
        returns(string memory)
    {
        bytes memory data = abi.encodePacked(account);
        bytes memory alphabet = "0123456789abcdef";

        bytes memory str = new bytes(2 + data.length * 2);
        str[0] = "0";
        str[1] = "x";
        for (uint i = 0; i < data.length; i++) {
            str[2+i*2] = alphabet[uint(uint8(data[i] >> 4))];
            str[3+i*2] = alphabet[uint(uint8(data[i] & 0x0f))];
        }
        return string(str);
    }


    //////////////////////// Liqudity Management ////////////////////////

    function updateUniswapV2Router(address newAddress)
        public onlySentry
    {
        require(newAddress != address(uniswapV2Router), "TKN: The router already has that address");
        emit UpdateUniswapV2Router(newAddress, address(uniswapV2Router));
        uniswapV2Router = IJoeRouter02(newAddress);
        address _uniswapV2Pair = IJoeFactory(uniswapV2Router.factory())
            // Polar token and WAVAX token
            .createPair(_polarTokenAddress, uniswapV2Router.WAVAX());
        uniswapV2Pair = _uniswapV2Pair;
    }

    function updateSwapTokensAmount(uint256 newVal)
        external onlySentry
    {
        swapTokensAmount = newVal;
    }

    function updateFuturWall(address payable wall)
        external onlySentry
    {
        futurUsePool = wall;
    }

    function updateRewardsWall(address payable wall)
        external onlySentry
    {
        distributionPool = wall;
    }

    function updateRewardsFee(uint256 value)
        external onlySentry
    {
        rewardsFee = value;
        totalFees = rewardsFee.add(liquidityPoolFee).add(futurFee);
    }

    function updateLiquiditFee(uint256 value)
        external onlySentry
    {
        liquidityPoolFee = value;
        totalFees = rewardsFee.add(liquidityPoolFee).add(futurFee);
    }

    function updateFuturFee(uint256 value)
        external onlySentry
    {
        futurFee = value;
        totalFees = rewardsFee.add(liquidityPoolFee).add(futurFee);
    }

    function updateCashoutFee(uint256 value)
        external onlySentry
    {
        cashoutFee = value;
    }

    function updateRwSwapFee(uint256 value)
        external onlySentry
    {
        rwSwap = value;
    }

    function setAutomatedMarketMakerPair(address pair, bool value)
        public onlySentry
    {
        require(
            pair != uniswapV2Pair,
            "TKN: The PancakeSwap pair cannot be removed from automatedMarketMakerPairs"
        );

        _setAutomatedMarketMakerPair(pair, value);
    }

    function _setAutomatedMarketMakerPair(address pair, bool value)
        private onlySentry
    {
        require(
            automatedMarketMakerPairs[pair] != value,
            "TKN: Automated market maker pair is already set to that value"
        );
        automatedMarketMakerPairs[pair] = value;

        emit SetAutomatedMarketMakerPair(pair, value);
    }

    function blacklistMalicious(address account, bool value)
        external onlySentry
    {
        _isBlacklisted[account] = value;
    }

    function swapAndSendToFee(address destination, uint256 tokens) private {
        uint256 initialETHBalance = address(this).balance;
        swapTokensForEth(tokens);
        uint256 newBalance = (address(this).balance).sub(initialETHBalance);

        _polarTokenContract.transferFrom(address(this), destination, newBalance);
        // payable(destination).transfer(newBalance);
    }

    function swapAndLiquify(uint256 tokens) private {
        uint256 half = tokens.div(2);
        uint256 otherHalf = tokens.sub(half);

        uint256 initialBalance = address(this).balance;

        swapTokensForEth(half);

        uint256 newBalance = address(this).balance.sub(initialBalance);

        addLiquidity(otherHalf, newBalance);

        emit SwapAndLiquify(half, newBalance, otherHalf);
    }

    function swapTokensForEth(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WAVAX();

        _polarTokenContract.approve(address(uniswapV2Router), tokenAmount);
        // _approve(address(this), address(uniswapV2Router), tokenAmount);

        uniswapV2Router.swapExactTokensForAVAXSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        // approve token transfer to cover all possible scenarios
        _polarTokenContract.approve(address(uniswapV2Router), tokenAmount);
        // _approve(address(this), address(uniswapV2Router), tokenAmount);

        // add the liquidity
        uniswapV2Router.addLiquidityAVAX{value: ethAmount}(
            address(this),                  // token address
            tokenAmount,                    // amountTokenDesired
            0, // slippage is unavoidable   // amountTokenMin
            0, // slippage is unavoidable   // amountAVAXMin
            poolHandler,                    // to address
            block.timestamp                 // deadline
        );
    }

    function createNodeWithTokens(string memory nodeTypeName, uint256 count)
        public
    {
        //# check if nodeTypeName exists
        require(_doesNodeTypeExist(nodeTypeName), "createNodeWithTokens: nodeTypeName does not exist in _nodeTypes.");
        require(count > 0, "createNodeWithTokens: count cannot be less than 1.");

        address sender = _msgSender();
        require(sender != address(0), "createNodeWithTokens:  creation from the zero address");
        require(!_isBlacklisted[sender], "createNodeWithTokens: Blacklisted address");
        require(
            sender != futurUsePool && sender != distributionPool,
            "createNodeWithTokens: futur and rewardsPool cannot create node"
        );

        // calculate total cost of creating "count" number of nodes
        uint256 nodePrice = _getNodePrice(nodeTypeName).mul(count);
        require(
            _polarTokenContract.balanceOf(sender) >= nodePrice,
            "createNodeWithTokens: Balance too low for creation."
        );

        _polarTokenContract.transferFrom(sender, address(this), nodePrice);

        _sendTokensToUniswap();     // after transferring polar from a client to NodeRewardManagement

        _createNodes(sender, nodeTypeName, count);
    }

    function _sendTokensToUniswap()
        private
    {
        address sender = _msgSender();
        uint256 contractTokenBalance = _polarTokenContract.balanceOf(address(this));
        bool swapAmountOk = contractTokenBalance >= swapTokensAmount;
        if (
            swapAmountOk &&
            swapLiquify &&
            !swapping &&
            !automatedMarketMakerPairs[sender]
        ) {
            swapping = true;

            uint256 futurTokens = contractTokenBalance.mul(futurFee).div(100);

            swapAndSendToFee(futurUsePool, futurTokens);

            uint256 rewardsPoolTokens = contractTokenBalance
            .mul(rewardsFee)
            .div(100);

            uint256 rewardsTokenstoSwap = rewardsPoolTokens.mul(rwSwap).div(
                100
            );

            swapAndSendToFee(distributionPool, rewardsTokenstoSwap);
            _polarTokenContract.transferFrom(
                address(this),
                distributionPool,
                rewardsPoolTokens.sub(rewardsTokenstoSwap)
            );

            uint256 swapTokens = contractTokenBalance.mul(liquidityPoolFee).div(100);

            swapAndLiquify(swapTokens);

            swapTokensForEth(_polarTokenContract.balanceOf(address(this)));

            swapping = false;
        }
    }

    function _createNodes(address account, string memory nodeTypeName, uint256 count)
        private
    {
        //# check if nodeTypeName exists
        require(_doesNodeTypeExist(nodeTypeName), "_createNodes: nodeTypeName does not exist in _nodeTypes.");
        require(count > 0, "_createNodes: count cannot be less than 1.");

        // if the account is a new owner
        if (_doesNodeOwnerExist(account)) {
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
    }

    function _getNodePrice(string memory nodeTypeName)
        private view
        returns (uint256)
    {
        IterableNodeTypeMapping.NodeType memory nt = _nodeTypes.get(nodeTypeName);
        return nt.nodePrice;
    }

    function cashoutReward()
        public
    {
        address sender = _msgSender();
        require(sender != address(0), "cashoutReward:  creation from the zero address");
        require(!_isBlacklisted[sender], "cashoutReward: Blacklisted address");
        require(
            sender != futurUsePool && sender != distributionPool,
            "CSHT: futur and rewardsPool cannot cashout rewards"
        );
        uint256 rewardAmount = _deposits[sender];
        require(
            rewardAmount > 0,
            "cashoutReward: You don't have enough reward to cash out"
        );

        if (swapLiquify) {
            uint256 feeAmount;
            if (cashoutFee > 0) {
                feeAmount = rewardAmount.mul(cashoutFee).div(100);
                swapAndSendToFee(futurUsePool, feeAmount);
            }
            rewardAmount -= feeAmount;
        }

        _deposits[sender] = 0;          // reset the account's deposit as 0
        _polarTokenContract.transferFrom(distributionPool, sender, rewardAmount);
    }
}