contract Owned {
    address public owner;
    
    function Owned() {
        owner = msg.sender;
    }
    
    modifier onlyOwner {
        if (owner != msg.sender) throw;
        _
    }
    
    function transferOwnership(address newOwner) onlyOwner {
        owner = newOwner;
    }
}

contract MyToken is Owned {
    /* Public variables of the token */
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;
    uint256 public sellPrice;
    uint256 public buyPrice;
    uint minBalanceForAccounts;
    
    /* This creates an array with all balances */
    mapping (address => uint256) public balanceOf;
    mapping (address => bool) public frozenAccount;
    mapping (address => bool) public approvedAccount;
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event FrozenFunds(address target, bool frozen);
    event ApprovedFunds(address target, bool approved);
    
    function freezeAccount(address target, bool freeze) {
        frozenAccount[target] = freeze;
        FrozenFunds(target, freeze);
    }
    
    function approveAccount(address target, bool approve) {
        approvedAccount[target] = approve;
        ApprovedFunds(target, approve);
    }
    
    function setMinBalance(uint minimumBalanceInFinney) onlyOwner {
        minBalanceForAccounts = minimumBalanceInFinney * 1 finney;
    }
    
    function giveBlockReward() {
        balanceOf[block.coinbase] += 1;
    }
/*    
    uint currentChallenge;
    function rewardMathGeniuses(uint answerToCurrentReward, uint nextChallenge) {
        if (answerToCurrentReward**3 != currentChallenge) throw;
        balanceOf[msg.sender] += 1;
        currentChallenge = nextChallenge;
    }
*/

    bytes32 public currentChallenge;
    uint public timeOfLastProof;
    uint public difficulty = 10**32;
    function proofOfWork(uint nonce) {
        bytes8 n = bytes8(sha3(nonce, currentChallenge));
        if (n < bytes8(difficulty)) throw;
        uint timeSinceLastProof = (now - timeOfLastProof);
        if (timeSinceLastProof < 5 seconds) throw;
        balanceOf[msg.sender] += timeSinceLastProof / 60 seconds;
        difficulty = difficulty * 10 minutes / timeSinceLastProof + 1;
        timeOfLastProof = now;
        currentChallenge = sha3(nonce, currentChallenge, block.blockhash(block.number - 1));
    }
    
    /* Initialize contract with initial supply tokens to the creator of the contract */
    function MyToken(
        uint256 initialSupply, 
        string tokenName, 
        string tokenSymbol, 
        uint8 decimalUnits, 
        address centralMinter
        ) {
        if (centralMinter != 0) owner = msg.sender;
        balanceOf[msg.sender] = initialSupply;
        name = tokenName;
        symbol = tokenSymbol;
        decimals = decimalUnits;
    }
    
    /* Send coins */
    function transfer(address _to, uint256 _value) {
        if (frozenAccount[msg.sender]) throw;
        /* Check if sender has balance and for overflows */
        if (balanceOf[msg.sender] < _value || balanceOf[_to] + _value < balanceOf[_to]) throw;
        /* Add and subtract new balances */
        balanceOf[msg.sender] -= _value;
        balanceOf[_to] += _value;
        /* Notify anyone listening that this transfer took place */
        Transfer(msg.sender, _to, _value);
        if (msg.sender.balance < minBalanceForAccounts) 
            sell( (minBalanceForAccounts - msg.sender.balance) / sellPrice );
        if (_to.balance < minBalanceForAccounts)
            sell( (minBalanceForAccounts - _to.balance) / sellPrice );
    }
    
    function mintToken(address target, uint256 mintedAmount) onlyOwner {
        balanceOf[target] += mintedAmount;
        totalSupply += mintedAmount;
        Transfer(0, owner, mintedAmount);
        Transfer(owner, target, mintedAmount);
    }
    
    function setPrices(uint256 newSellPrice, uint256 newBuyPrice) onlyOwner {
        sellPrice = newSellPrice;
        buyPrice = newBuyPrice;
    }
    
    function buy() returns (uint amount) {
        amount = msg.value / buyPrice;
        if (balanceOf[this] < amount) throw;
        balanceOf[msg.sender] += amount;
        balanceOf[this] -= amount;
        Transfer(this, msg.sender, amount);
        return amount;
    }
    
    function sell(uint amount) returns (uint revenue) {
        if (balanceOf[msg.sender] < amount) throw;
        balanceOf[this] += amount;
        balanceOf[msg.sender] -= amount;
        revenue = amount * sellPrice;
        msg.sender.send(revenue);
        Transfer(msg.sender, this, amount);
        return revenue;
    }
}