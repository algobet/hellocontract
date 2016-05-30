/* The Token is used as a voting shares */
contract Token {
    mapping (address => uint256) public balanceOf;
}

/* define 'Owned' */
contract Owned {
    address public owner;
    
    function Owned() {
        owner = msg.sender;
    }
    
    modifier onlyOwner {
        if (msg.sender != owner) throw;
        _
    }
    
    function transferOwnership(address newOwner) {
        owner = newOwner;
    }
}

/* the democracy contract itself */
contract Association is Owned {
    /* contract variables and events */
    uint public minimumQuorum;
    uint public debatingPeriodInMinutes;
    Proposal[] public proposals;
    uint public numProposals;
    Token public sharesTokenAddress;
    
    event ProposalAdded(uint proposalID, address recipient, uint amount, string description);
    event Voted(uint proposalID, bool position, address voter);
    event ProposalTallied(uint proposalID, int result, uint quorum, bool active);
    event ChangeOfRules(uint minimumQuorum, uint debatingPeriodInMinutes, address sharesTokenAddress);
    
    struct Proposal {
        address recipient;
        uint amount;
        string description;
        uint votingDeadline;
        bool executed;
        bool proposalPassed;
        uint numberOfVotes;
        bytes32 proposalHash;
        Vote[] votes;
        mapping (address => bool) voted;
    }
    
    struct Vote {
        bool inSupport;
        address voter;
    }
    
    /* modifier that allows only shareholders to vote and create new proposals */
    modifier onlyShareholders {
        if (sharesTokenAddress.balanceOf(msg.sender) == 0) throw;
        _
    }
    
    /* initial setup */
    function Association(Token sharesAddress, uint minimumSharesToPassAVote, uint minutesForDebate) {
        changeVotingRules(sharesAddress, minimumSharesToPassAVote, minutesForDebate);
    }
    
    /* change rules */
    function changeVotingRules(Token sharesAddress, uint minimumSharesToPassAVote, uint minutesForDebate) onlyOwner {
        sharesTokenAddress = Token(sharesAddress);
        if (minimumSharesToPassAVote == 0) minimumSharesToPassAVote = 1;
        minimumQuorum = minimumSharesToPassAVote;
        debatingPeriodInMinutes = minutesForDebate;
        ChangeOfRules(minimumQuorum, debatingPeriodInMinutes, sharesTokenAddress);
    }
    
    /* function to create a new proposal */
    function newProposal(
        address beneficiary,
        uint etherAmount,
        string jobDescription,
        bytes transactionBytecode
    ) onlyShareholders returns (uint proposalID) {
        proposalID = proposals.length++;
        Proposal p = proposals[proposalID];
        p.recipient = beneficiary;
        p.amount = etherAmount;
        p.description = jobDescription;
        p.proposalHash = sha3(beneficiary, etherAmount, transactionBytecode);
        p.votingDeadline = now + debatingPeriodInMinutes * 1 minutes;
        p.executed = false;
        p.proposalPassed = false;
        p.numberOfVotes = 0;
        
        ProposalAdded(proposalID, beneficiary, etherAmount, jobDescription);
        numProposals = proposalID + 1;
    }
    
    /* function to check if a proposal code matches */
    function checkProposalCode(
        uint proposalNumber,
        address beneficiary,
        uint etherAmount,
        bytes transactionBytecode
    ) constant returns (bool codeChecksOut) {
        Proposal p = proposals[proposalNumber];
        return p.proposalHash == sha3(beneficiary, etherAmount, transactionBytecode);
    }
    
    /* */
    function vote(uint proposalNumber, bool supportsProposal) onlyShareholders returns (uint voteID) {
        Proposal p = proposals[proposalNumber];
        if (p.voted[msg.sender]  == true) throw;
        voteID = p.votes.length++;
        p.votes[voteID] = Vote({inSupport: supportsProposal, voter: msg.sender});
        p.voted[msg.sender] = true;
        p.numberOfVotes = voteID + 1;
        Voted(proposalNumber, supportsProposal, msg.sender);
    }
    
    function executeProposal(uint proposalNumber, bytes transactionBytecode) returns (int result) {
        Proposal p = proposals[proposalNumber];
        // check if the proposal can be executed */
        if (now < p.votingDeadline || p.executed || p.proposalHash != sha3(p.recipient, p.amount, transactionBytecode))
            throw;
        // tally the votes
        uint quorum = 0;
        uint yea = 0;
        uint nay = 0;
        for (uint i = 0; i < p.votes.length; ++i) {
            Vote v = p.votes[i];
            uint voteWeight = sharesTokenAddress.balanceOf(v.voter);
            quorum += voteWeight;
            if (v.inSupport) {
                yea += voteWeight;
            } else {
                nay += voteWeight;
            }
        }
        
        /* execute result */
        if (quorum <= minimumQuorum) {
            // not enough significant voters
            throw;
        } else if (yea > nay) {
            // has quorum and was approved
            p.recipient.call.value(p.amount * 1 ether)(transactionBytecode);
            p.executed = true;
            p.proposalPassed = true;
        } else {
            p.executed = true;
            p.proposalPassed = false;
        }
        
        // fire events
        ProposalTallied(proposalNumber, result, quorum, p.proposalPassed);
    }
}