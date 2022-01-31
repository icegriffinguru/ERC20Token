# NodeRewardManagement Structure

**All functions listed here are public or external functions which can be accessed from other contracts or dapps. 
These are API of NodeRewardManagement.
Private or internal functions will be implemented while development.**

## 1. NodeType
    struct NodeType {
        string nodeTypeName;
        uint256 nodePrice;
        uint256 claimTime;
        uint256 rewardAmount;
        uint256 claimTaxBeforeTime;
        string nextLevelNodeTypeName;
        uint256 levelUpCount;
    }

- **nodePrice**: the cost to buy a node
- **claimTime**: the length of an epoch. A user only can claim a reward after an epoch.
- **rewardAmount**: the amount of reward per an epoch.
- **claimTaxBeforeTime**: claim tax which a user should pay if he/she claims a reward before claimTime
- **nextLevelNodeTypeName**: the name of next-level NodeType. A user can upgrade low-level nodes to a one-level-higher node.
- **levelUpCount**: the number of nodes needed to level up to the next level


> function **addNodeType**(string memory _nodeTypeName, uint256 _nodePrice, uint256 _claimTime, uint256 _rewardAmount, uint256 _claimTaxBeforeTime)
> public **onlySentry**

Add a new NodeType.
Every NodeType is identified by nodeTypename and nodeTypename should be unique.
Only sentry can access.


> function **changeNodeType**(string memory nodeTypeName, uint256 nodePrice,
> uint256 claimTime, uint256 rewardAmount, uint256 claimTaxBeforeTime, string memory nextLevelNodeTypeName, uint256 levelUpCount)
>         public **onlySentry**

Change properties of a NodeType with given nodeTypename.
Find a NodeType with given nodeTypename and change properties.
Level-up rules of NodeTypes are defined by using **nextLevelNodeTypeName** and **levelUpCount** arguments.
If an argument is 0 or an empty string then it means no need to change that property.
Only sentry can access.


> function **getNodeTypes**() public view returns (string memory)

Get a concatenated string of properties of all NodeTypes.
Anyone can access.


> function **removeNodeType**(string memory nodeTypeName) public **onlySentry**

Remove a NodeType and all nodes of the NodeType that accouts have.
Only sentry can access.
**Warning: This will remove all existing nodes of accounts and can result a criticism. Thus, it should be considered more carefully.**



## 2. Node Management and Reward Management

    IterableMapping.Map private nodeOwners;
    mapping(address => NodeEntity[]) private _nodesOfUser;
    mapping(address => uint256) private deposits;

 - **nodeOwners**: store all Node owner addresses
 - **_nodesOfUser**: store all nodes of each account
 - **deposits**: store deposit of each account. If an account claims his/her reward, it will be deposited in this varaible. An account can buy nodes with the deposit or can cash it out.


> function **createNode**(address account, string memory nodeTypeName, uint256 count)
> public **onlySentry** returns (uint256)
> 
> function **createNodeInternal**(address account, string memory nodeTypeName, uint256 count)
> private returns (uint256)

Create **count** number of nodes of given nodeTypeName.
These functions will calculate the cost of creating nodes and check if the account has enough balance.
This function will check the account's deposit and the right amount will be deducted from deposit. If the account's deposit is not enough, the insufficient amount will be set as **totalCost**.
After success of creating nodes, these functions will return **totalCost** which the account has to pay.
Only sentry can access.


> function **getLeftTimeFromReward**(address account, uint256 _creationTime)
> public view returns (int256)

Get the left time to the next reward.
If the next reward time is passed, the funciton will return a negative value.
Anyone can access.


> function **claimReward**(address account, uint256 _creationTime)
> public returns (uint256)

Claim a reward of a node with **_creationTime** and returns the amount of the reward.
An account can claim reward of one node at one time.
It will reset **lastClaimTime** to current timestamp and the amount of reward will be added to the account's deposit.
Anyone can access.


> function **cashOut**(address account)
> public returns (uint256)

Cash out the account's deposit which is stored in **deposits** mapping.
The account's deposit  in **deposits** mapping will be set to 0 and the function return the amount of cash-out money.
Anyone can access.


> function **getDepositAmount**(address account)
> public view returns (uint256)

Return the account's deposit which is stored in **deposits** mapping.
Anyone can access.


> function **getNodes**(address account)
> **external** view returns (string memory)

Get a concatenated string of **nodeTypeName**, **creationTime** and **lastClaimTime** of all nodes belong to the account.
The output format is like this; "Axe#1234355#213435-Sladar#23413434#213435-Hunter#1234342#213435".
Anyone can access.


## 3. Misc

> function **moveAccount**(address account, uint nb) public

Move account's nodes in old NodeRewardManagement to new NodeRewardManagement.
Anyone can access.