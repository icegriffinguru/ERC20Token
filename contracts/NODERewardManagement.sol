// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.0;

import "./PaymentSplitter.sol";
import "./IJoeRouter02.sol";
import "./IJoeFactory.sol";
import "./IERC20.sol";
import "./IterableMapping.sol";
import "./IterableNodeTypeMapping.sol";
import "./OldRewardManager.sol";

// import "hardhat/console.sol";

contract NODERewardManagement is PaymentSplitter {
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
    mapping(string => mapping(address => uint256)) private _nodeCountOfType;    // number of nodes of accounts for each NodeType

    mapping(address => uint) public _oldNodeIndexOfUser;

    address public _gateKeeper;
    address public _polarTokenAddress;
	address public _oldNodeRewardManager;

    string _defaultNodeTypeName;

    //////////////////////// Liqudity Management ////////////////////////
    IJoeRouter02 public _uniswapV2Router;

    // address public uniswapV2Pair;
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
        //////////////////////// Liqudity Management ////////////////////////
        futurUsePool = addresses[1];
        distributionPool = addresses[2];
		poolHandler = addresses[3];

        require(futurUsePool != address(0) && distributionPool != address(0) && poolHandler != address(0), "FUTUR, REWARD & POOL ADDRESS CANNOT BE ZERO");
        require(uniV2Router != address(0), "ROUTER CANNOT BE ZERO");
        _uniswapV2Router = IJoeRouter02(uniV2Router);

        require(
            fees[0] != 0 && fees[1] != 0 && fees[2] != 0 && fees[3] != 0 && fees[4] != 0,
            "CONSTR: Fees equal 0"
        );
        futurFee = fees[0];
        rewardsFee = fees[1];
        liquidityPoolFee = fees[2];
        cashoutFee = fees[3];
        rwSwap = fees[4];

        totalFees = rewardsFee + liquidityPoolFee + futurFee;

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
    function addNodeType(string memory nodeTypeName, uint256 nodePrice, uint256 claimTime, uint256 rewardAmount, uint256 claimTaxBeforeTime)
        public onlySentry
    {
        //# check if nodeTypeName already exists
        // if claimTime is greater than zero, it means the same nodeTypeName already exists in mapping
        require(!_doesNodeTypeExist(nodeTypeName), "addNodeType: same nodeTypeName exists.");

        _nodeTypes.set(nodeTypeName, IterableNodeTypeMapping.NodeType({
                nodeTypeName: nodeTypeName,
                nodePrice: nodePrice,
                claimTime: claimTime,
                rewardAmount: rewardAmount,
                claimTaxBeforeTime: claimTaxBeforeTime
            })
        );
    }

    //# change properties of NodeType
    //# if a value is equal to 0 or an empty string, it means no need to update the property
    function changeNodeType(string memory nodeTypeName, uint256 nodePrice, uint256 claimTime, uint256 rewardAmount, uint256 claimTaxBeforeTime)
        public onlySentry
    {
        //# check if nodeTypeName exists
        require(_doesNodeTypeExist(nodeTypeName), "changeNodeType: nodeTypeName does not exist");

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
    }

    //# get all NodeTypes
    //# returning result is same format as "_getNodesCreationTime" function
    //# returning result pattern is like this "-Axe#10#134#145-Sladar#34#14#134-Sven#34#14#134"
    function getNodeTypes()
        public view
        returns (string memory)
    {
        IterableNodeTypeMapping.NodeType memory nt;
        string memory result = "";
        string memory bigSeparator = "-";
        string memory separator = "#";

        for (uint256 i = 0; i < _nodeTypes.size(); i++) {
            nt = _nodeTypes.getValueAtIndex(i);
            result = string(abi.encodePacked(result, bigSeparator, nt.nodeTypeName));
            result = string(abi.encodePacked(result, separator, _uint2str(nt.nodePrice)));
            result = string(abi.encodePacked(result, separator, _uint2str(nt.claimTime)));
            result = string(abi.encodePacked(result, separator, _uint2str(nt.rewardAmount)));
            result = string(abi.encodePacked(result, separator, _uint2str(nt.claimTaxBeforeTime)));
        }
        return result;
    }


    ///////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////// Node management //////////////////////////////////

    //# get left time of a node from the next reward
    //# if the reward time is passed then the result will be a negative number
    function getLeftTimeFromReward(address account, uint256 creationTime)
        public view
        returns (int256)
    {
        NodeEntity memory node = _getNodeWithCreationTime(account, creationTime);
        return _getLeftTimeFromReward(node);
    }

    // return available reward of all nodes of an account
    // return format "-123243#100-13455#200"
    function getRewardAvailable(address account)
        public view
        returns (string memory)
    {
        // check the account is a new owner
        require(_doesNodeOwnerExist(account), "cashOut: The account does not exist.");

        NodeEntity[] memory nodes = _nodesOfUser[account];

        string memory result = "";
        string memory separator = "#";
        string memory bigSeparator = "-";
        for (uint256 i = 0; i < nodes.length; i++) {
            result = string(
                abi.encodePacked(
                    bigSeparator,
                    nodes[i].creationTime,
                    separator,
                    _calculateRewardOfNode(nodes[i])
                )
            );
        }

        return result;
    }


    //////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////// Level Management //////////////////////////////////

    // Level up given number of nodes (with given nodeTypeName) to one high-level node
    function levelUpNodes(string memory currentNodeTypeName, string memory nextNodeTypeName)
        public
    {
        require(_doesNodeTypeExist(currentNodeTypeName), "currentNodeTypeName does not exist");
        require(_doesNodeTypeExist(nextNodeTypeName), "nextNodeTypeName does not exist");

        IterableNodeTypeMapping.NodeType memory currentNodeType = _nodeTypes.get(currentNodeTypeName);
        IterableNodeTypeMapping.NodeType memory nextNodeType = _nodeTypes.get(nextNodeTypeName);
        require(currentNodeType.nodePrice < nextNodeType.nodePrice, "currentNodeType.nodePrice should be greater than nextNodeType.nodePrice");
        
        uint256 levelUpCount = nextNodeType.nodePrice / currentNodeType.nodePrice;
        if (nextNodeType.nodePrice > currentNodeType.nodePrice * levelUpCount) {
            levelUpCount++;
        }

        // replace currentNodeTypeName with nextNodeTypeName
        NodeEntity[] storage nodes = _nodesOfUser[msg.sender];
        uint256 newPos = 0;
        uint256 nodesCountOfGivenNodeType = 0;
        for (uint256 i = 0; i < nodes.length; i++) {
            if (keccak256(abi.encodePacked(nodes[i].nodeTypeName)) == keccak256(abi.encodePacked(currentNodeTypeName))) {
                nodesCountOfGivenNodeType++;
                if (nodesCountOfGivenNodeType + levelUpCount <= _nodeCountOfType[currentNodeTypeName][msg.sender]) {
                    newPos++;
                }
            }
            else {
                nodes[newPos] = nodes[i];
                newPos++;
            }
        }

        // remove left NodeEntitys
        for (uint256 i = 0; i < levelUpCount; i++) {
            nodes.pop();
        }

        // add a new NodeEntity of next-level NodeType
        nodes.push(NodeEntity(nextNodeTypeName, block.timestamp * 1000, block.timestamp));
    }


    ///////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////// Retrieve Info //////////////////////////////////

    // Return addresses of all accounts
    // The output format is like this; "0x123343434#0x123343434".
    function getNodeOwners(uint256 startIndex, uint256 endIndex)
        public view onlySentry
        returns (string memory)
    {
        if (_nodeOwners.size() == 0) return "";

        string memory result = "";
        string memory separator = "#";

        if (_nodeOwners.size() < endIndex) endIndex = _nodeOwners.size() - 1;

        address nodeOwner;
        for (uint256 i = startIndex; i <= endIndex; i++ ) {
            nodeOwner = _nodeOwners.getKeyAtIndex(i);
            result = string(abi.encodePacked(result, separator, _addressToString(nodeOwner)));
        }
        return result;
    }

    // Get a concatenated string of nodeTypeName, creationTime and lastClaimTime of all nodes belong to the account.
    // The output format is like this; "Axe#1234355#213435-Sladar#23413434#213435-Hunter#1234342#213435".
    function getNodes(address account, uint256 startIndex, uint256 endIndex)
        public view
        returns (string memory)
    {
        require(_doesNodeOwnerExist(account), "getNodes: NO NODE OWNER");        

        NodeEntity[] memory nodes = _nodesOfUser[account];
        if (nodes.length == 0) return "";
        if (nodes.length < endIndex) endIndex = nodes.length - 1;

        NodeEntity memory node;
        string memory result = "";
        string memory bigSeparator = "-";
        string memory separator = "#";
        for (uint256 i = startIndex; i <= endIndex; i++) {
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
        require(_nodeTypes.getIndexOfKey(nodeTypeName) >= 0, "setDefaultNodeTypeName: nodeTypeName does not exist");

        _defaultNodeTypeName = nodeTypeName;
    }

    // Create new nodes of NodeType(_defaultNodeTypeName) belong the account
    function moveAccount(address account, uint nb) public {
        //# check if _defaultNodeTypeName already exists
        require(_doesNodeTypeExist(_defaultNodeTypeName), "moveAccount: _defaultnodeTypeName does not exist");
		require(nb > 0, "Nb must be greater than 0");

		uint remainingNodes = OldRewardManager(_oldNodeRewardManager)._getNodeNumberOf(account);
		remainingNodes -= _oldNodeIndexOfUser[account];
		require(nb <= remainingNodes, "Too many nodes requested");
        _createNodes(account, _defaultNodeTypeName, nb);
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
            uint256 mid = (high + low) / 2;
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
            // reward = nt.rewardAmount;
            reward = nt.rewardAmount * (block.timestamp - node.lastClaimTime) / nt.claimTime;
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
        require(newAddress != address(_uniswapV2Router), "TKN: The router already has that address");
        emit UpdateUniswapV2Router(newAddress, address(_uniswapV2Router));
        _uniswapV2Router = IJoeRouter02(newAddress);
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
        totalFees = rewardsFee + liquidityPoolFee + futurFee;
    }

    function updateLiquiditFee(uint256 value)
        external onlySentry
    {
        liquidityPoolFee = value;
        totalFees = rewardsFee + liquidityPoolFee + futurFee;
    }

    function updateFuturFee(uint256 value)
        external onlySentry
    {
        futurFee = value;
        totalFees = rewardsFee + liquidityPoolFee + futurFee;
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
        uint256 newBalance = (address(this).balance) - initialETHBalance;

        IERC20(_polarTokenAddress).transferFrom(address(this), destination, newBalance);
    }

    function swapAndLiquify(uint256 tokens) private {
        uint256 half = tokens / 2;
        uint256 otherHalf = tokens - half;

        uint256 initialBalance = address(this).balance;

        swapTokensForEth(half);

        uint256 newBalance = address(this).balance - initialBalance;

        addLiquidity(otherHalf, newBalance);

        emit SwapAndLiquify(half, newBalance, otherHalf);
    }

    function swapTokensForEth(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = _uniswapV2Router.WAVAX();

        IERC20(_polarTokenAddress).approve(address(_uniswapV2Router), tokenAmount);

        _uniswapV2Router.swapExactTokensForAVAXSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        // approve token transfer to cover all possible scenarios
        IERC20(_polarTokenAddress).approve(address(_uniswapV2Router), tokenAmount);

        // add the liquidity
        _uniswapV2Router.addLiquidityAVAX{value: ethAmount}(
            address(this),                  // token address
            tokenAmount,                    // amountTokenDesired
            0, // slippage is unavoidable   // amountTokenMin
            0, // slippage is unavoidable   // amountAVAXMin
            poolHandler,                    // to address
            block.timestamp                 // deadline
        );
    }

    function createNodeWithTokens(string memory nodeTypeName, uint256 count)
        public payable
    {
        //# check if nodeTypeName exists
        require(_doesNodeTypeExist(nodeTypeName), "nodeTypeName does not exist");
        require(count > 0, "count cannot be less than 1.");

        address sender = _msgSender();
        require(sender != address(0), " creation from the zero address");
        require(!_isBlacklisted[sender], "Blacklisted address");
        require(
            sender != futurUsePool && sender != distributionPool,
            "futur and rewardsPool cannot create node"
        );

        // calculate total cost of creating "count" number of nodes
        uint256 nodePrice = _getNodePrice(nodeTypeName) * count;
        require(
            IERC20(_polarTokenAddress).balanceOf(sender) >= nodePrice,
            "Balance too low for creation."
        );

        IERC20(_polarTokenAddress).transfer(address(this), nodePrice);

        _sendTokensToUniswap();     // after transferring polar from a client to NodeRewardManagement

        _createNodes(sender, nodeTypeName, count);
    }

    function createNodeWithPending(string memory nodeTypeName, uint256 count)
        public
    {
        //# check if nodeTypeName exists
        require(_doesNodeTypeExist(nodeTypeName), "nodeTypeName does not exist");
        require(count > 0, "count cannot be less than 1.");

        address sender = _msgSender();
        require(sender != address(0), " creation from the zero address");
        require(!_isBlacklisted[sender], "Blacklisted address");
        require(
            sender != futurUsePool && sender != distributionPool,
            "futur and rewardsPool cannot create node"
        );

        // calculate total cost of creating "count" number of nodes
        uint256 nodePrice = _getNodePrice(nodeTypeName) * count;
        
        NodeEntity[] memory nodes = _nodesOfUser[sender];
        uint256 rewardAmount = 0;
        for (uint256 i = 0; i < nodes.length; i++) {
            rewardAmount += _calculateRewardOfNode(nodes[i]);
        }

        require(
            rewardAmount >= nodePrice,
            "Reward is too low for creation."
        );

        // reset lastClaimTime
        for (uint256 i = 0; i < nodes.length; i++) {
            nodes[i].lastClaimTime = block.timestamp;
        }
        rewardAmount -= nodePrice;

        _createNodes(sender, nodeTypeName, count);

        // convert pending reward to the first node's lastClaimTime
        IterableNodeTypeMapping.NodeType memory nt = _nodeTypes.get(nodes[0].nodeTypeName);
        nodes[0].lastClaimTime = block.timestamp - nt.claimTime * rewardAmount / nt.nodePrice;
    }


    function _sendTokensToUniswap()
        private
    {
        address sender = _msgSender();
        uint256 contractTokenBalance = IERC20(_polarTokenAddress).balanceOf(address(this));
        bool swapAmountOk = contractTokenBalance >= swapTokensAmount;
        if (
            swapAmountOk &&
            swapLiquify &&
            !swapping
            && !automatedMarketMakerPairs[sender]
        ) {
            swapping = true;

            uint256 futurTokens = contractTokenBalance * futurFee / 100;

            swapAndSendToFee(futurUsePool, futurTokens);

            uint256 rewardsPoolTokens = contractTokenBalance * rewardsFee / 100;

            uint256 rewardsTokenstoSwap = rewardsPoolTokens * rwSwap / 100;

            swapAndSendToFee(distributionPool, rewardsTokenstoSwap);

            IERC20(_polarTokenAddress).transferFrom(
                address(this),
                distributionPool,
                rewardsPoolTokens - rewardsTokenstoSwap
            );

            uint256 swapTokens = contractTokenBalance * liquidityPoolFee / 100;

            swapAndLiquify(swapTokens);

            swapTokensForEth(IERC20(_polarTokenAddress).balanceOf(address(this)));

            swapping = false;
        }
    }

    function _createNodes(address account, string memory nodeTypeName, uint256 count)
        private
    {
        //# check if nodeTypeName exists
        require(_doesNodeTypeExist(nodeTypeName), "_createNodes: nodeTypeName does not exist");
        require(count > 0, "_createNodes: count cannot be less than 1.");

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
        _nodeCountOfType[nodeTypeName][account] += count;
    }

    function _getNodePrice(string memory nodeTypeName)
        private view
        returns (uint256)
    {
        IterableNodeTypeMapping.NodeType memory nt = _nodeTypes.get(nodeTypeName);
        return nt.nodePrice;
    }

    function cashoutReward(uint256 creationTime)
        public
    {
        address sender = _msgSender();
        require(sender != address(0), "creation from the zero address");
        require(!_isBlacklisted[sender], "Blacklisted address");
        require(
            sender != futurUsePool && sender != distributionPool,
            "CSHT: futur and rewardsPool cannot cashout rewards"
        );
        NodeEntity storage node = _getNodeWithCreationTime(sender, creationTime);
        uint256 rewardAmount = _calculateRewardOfNode(node);
        
        require(
            rewardAmount > 0,
            "You don't have enough reward to cash out"
        );
        node.lastClaimTime = block.timestamp;

        if (swapLiquify) {
            uint256 feeAmount;
            if (cashoutFee > 0) {
                feeAmount = rewardAmount * cashoutFee / 100;
                swapAndSendToFee(futurUsePool, feeAmount);
            }
            rewardAmount -= feeAmount;
        }

        IERC20(_polarTokenAddress).transferFrom(distributionPool, sender, rewardAmount);
    }

    // if force is true then cash out reward of all nodes whether or not claimTime is passed
    // if force is false then check claimTime. if claimTime is not passed, cancel cash out
    function cashoutAllReward(bool force)
        public
    {
        address sender = _msgSender();
        require(sender != address(0), "creation from the zero address");
        require(!_isBlacklisted[sender], "Blacklisted address");
        require(
            sender != futurUsePool && sender != distributionPool,
            "CSHT: futur and rewardsPool cannot cashout rewards"
        );

        NodeEntity[] memory nodes = _nodesOfUser[sender];
        uint256 rewardAmount = 0;
        for (uint256 i = 0; i < nodes.length; i++) {
            // if claimTime is not passed and force is false
            if (!force && _getLeftTimeFromReward(nodes[i]) > 0) continue;
            rewardAmount += _calculateRewardOfNode(nodes[i]);
        }

        require(
            rewardAmount > 0,
            "You don't have enough reward to cash out"
        );

        // reset lastClaimTime
        for (uint256 i = 0; i < nodes.length; i++) {
            if (!force && _getLeftTimeFromReward(nodes[i]) > 0) continue;
            nodes[i].lastClaimTime = block.timestamp;
        }

        if (swapLiquify) {
            uint256 feeAmount;
            if (cashoutFee > 0) {
                feeAmount = rewardAmount * cashoutFee / 100;
                swapAndSendToFee(futurUsePool, feeAmount);
            }
            rewardAmount -= feeAmount;
        }

        IERC20(_polarTokenAddress).transferFrom(distributionPool, sender, rewardAmount);
    }
}