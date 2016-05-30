contract Owned {
    address public owner;
    
    function Owned() {
        owner = msg.sender;
    }
    
    modifier onlyOwner {
        if (msg.sender != owner) throw;
        _
    }
    
    function transferOwnership(address newOwner) onlyOwner {
        owner = newOwner;
    }
}

contract Congress is Owned {
    /* contract variables and events */
    uint public minimumQuorum;
    uint public debatingPeriodInMinutes;
    int public majorityMargin;
    Member[] public members;
    Proposal[] public proposals;
    uint public numProposals;
    
    mapping (address => uint) public memberId;
    
    event ProposalAdded(uint proposalID, address recipient, uint amount, string description);
    event Voted(uint proposalID, bool position, address voter, string justification);
    event ProposalTallied(uint ProposalID, int result, uint quorum, bool active);
    event MembershipChanged(address member, bool isMember);
    event ChangeOfRules(uint minimumQuorum, uint debatingPeriodInMinutes, int majorityMargin);
    
    struct Proposal {
        address recipient;
        uint amount;
        string description;
        uint votingDeadline;
        bool executed;
        bool proposalPassed;
        uint numberOfVotes;
        int currentResult;
        bytes32 proposalHash;
        Vote[] votes;
        mapping (address => bool) voted;
    }
    
    struct Member {
        address member;
        bool canVote;
        string name;
        uint memberSince;
    }
    
    struct Vote {
        bool inSupport;
        address voter;
        string justification;
    }
    
    /* modifier that allows only shareholders to vote and create new proposals */
    modifier onlyMembers {
        if (memberId[msg.sender] == 0 || !members[memberId[msg.sender]].canVote)
        throw;
        _
    }
    
    /* initial setup */
    function Congress(
        uint minimumQuorumForProposals,
        uint minutesForDebate,
        int marginOfVotesForMajority,
        address congressLeader
    ) {
        changeVotingRules(minimumQuorumForProposals, minutesForDebate, marginOfVotesForMajority);
        members.length++;
        members[0] = Member({member: 0, canVote: false, memberSince: now, name: ''});
        if (congressLeader != 0) owner = congressLeader;
    }
    
    /* make member */
    function changeMembership(address targetMember, bool canVote, string memberName) onlyOwner {
        uint id;
        if (memberId[targetMember] == 0) {
            memberId[targetMember] = members.length;
            id = members.length++;
            members[id] = Member({member: targetMember, canVote: canVote, memberSince: now, name: memberName});
        } else {
            id = memberId[targetMember];
            Member m = members[id];
            m.canVote = canVote;
        }
        
        MembershipChanged(targetMember, canVote);
        
    }
    
    /* change rules */
    function changeVotingRules(
        uint minimumQuorumForProposals,
        uint minutesForDebate,
        int marginOfVotesForMajority
    ) onlyOwner {
        minimumQuorum = minimumQuorumForProposals;
        debatingPeriodInMinutes = minutesForDebate;
        majorityMargin = marginOfVotesForMajority;
        
        ChangeOfRules(minimumQuorum, debatingPeriodInMinutes, majorityMargin);
    }
    
    /* function to create a new proposal */
    function newProposal(
        address beneficiary,
        uint etherAmount,
        string jobDescription,
        bytes transactionBytecode
    ) onlyMembers returns (uint proposalID) {
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
    
    function vote(
        uint proposalNumber,
        bool supportsProposal,
        string justificationText
    ) onlyMembers returns (uint voteID) {
        Proposal p = proposals[proposalNumber];
        if (p.voted[msg.sender] == true) throw;
        p.voted[msg.sender] = true;
        p.numberOfVotes++;
        if (supportsProposal) {
            p.currentResult++;
        } else {
            p.currentResult--;
        }
        // create a log of this event
        Voted(proposalNumber, supportsProposal, msg.sender, justificationText);
    }
    
    function executeProposal(uint proposalNumber, bytes transactionBytecode) returns (int result) {
        Proposal p = proposals[proposalNumber];
        // check if the proposal can be executed
        if (now < p.votingDeadline
            || p.executed
            || p.proposalHash != sha3(p.recipient, p.amount, transactionBytecode)
            || p.numberOfVotes < minimumQuorum
        ) throw;
        // execute result
        if (p.currentResult > majorityMargin) {
            // if difference between support and opposition is larger than margin
            p.recipient.call.value(p.amount * 1 ether)(transactionBytecode);
            p.executed = true;
            p.proposalPassed = true;
        } else {
            p.executed = true;
            p.proposalPassed = false;
        }
        // fire events
        ProposalTallied(proposalNumber, p.currentResult, p.numberOfVotes, p.proposalPassed);
    }
}