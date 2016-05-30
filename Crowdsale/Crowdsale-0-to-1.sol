contract Token {
    function transfer(address receiver, uint amount) {
        
    }
}

contract Crowdsale {
    address public beneficiary;
    uint public fundingGoal; uint public amountRaised; uint public deadline; uint public price;
    bool crowdsaleClosed = false;
    Token public tokenReward;
    Funder[] public funders;
    
    /* data structure to hold information about campaign contributors */
    struct Funder {
        address addr;
        uint amount;
    }
    
    event FundTransfer(address backer, uint amount, bool isContribution);
    
    /* at initialization, setup the owner */
    function Crowdsale(
        address ifSucessfulSendTo,
        uint fundingGoalInEthers,
        uint durationInMinutes,
        uint etherCostOfEachToken,
        Token addressOfTokenUsedAsReward
    ) {
        beneficiary = ifSucessfulSendTo;
        fundingGoal = fundingGoalInEthers * 1 ether;
        deadline = durationInMinutes * 1 minutes;
        price = etherCostOfEachToken * 1 ether;
        tokenReward = Token(addressOfTokenUsedAsReward); // instantiate a contract at a given address
    }
    
    /* The function without name is the default function that is called whenever anyone sends funds to a contract */
    function() {
        if (crowdsaleClosed) throw;
        uint amount = msg.value;
        funders[funders.length++] = Funder({addr: msg.sender; amount: amount});
        amountRaised += amount;
        tokenReward.transfer(msg.sender, amount / price);
        FundTransfer(msg.sender, amount, true);
    }
    
    modifier afterDeadline() {
        if (now >= deadline) _
    }
    
    /* check if the goal or time limit has been reached and end the campaign */
    function checkGoalReached() afterDeadline {
        if (amountRaised >= fundingGoal) {
            beneficiary.send(amountRaised);
            FundTransfer(beneficiary, amountRaised, false);
        } else {
            for (uint i = 0; i < funders.length; ++i) {
                funders[i].addr.send(funders[i].amount);
                FundTransfer(funders[i].addr, funders[i].amount, false);
            }
        }
        
        beneficiary.send(this.balance);
        crowdsaleClosed = true;
    }
}