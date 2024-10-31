// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// NFTBorrower.sol
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract NFTLender is ReentrancyGuard {
    struct LenderProfile {
        string name;
        uint256 totalLent;
        uint256 activeLoans;
        uint256 successfulLoans;
        bool isRegistered;
    }

    mapping(address => LenderProfile) public lenderProfiles;
    address public platform;

    event LenderProfileCreated(address indexed lender, string name);
    event LoanOffered(address indexed lender, uint256 loanId, uint256 amount, uint256 interest);

    modifier onlyPlatform() {
        require(msg.sender == platform, "Only platform can call");
        _;
    }

    constructor(address _platform) {
        platform = _platform;
    }

    function createProfile(string memory _name) external {
        require(!lenderProfiles[msg.sender].isRegistered, "Profile already exists");
        
        lenderProfiles[msg.sender] = LenderProfile({
            name: _name,
            totalLent: 0,
            activeLoans: 0,
            successfulLoans: 0,
            isRegistered: true
        });
        
        emit LenderProfileCreated(msg.sender, _name);
    }

    function provideLoan(uint256 _loanId, uint256 _interest) external payable nonReentrant {
        require(lenderProfiles[msg.sender].isRegistered, "Profile not registered");
        emit LoanOffered(msg.sender, _loanId, msg.value, _interest);
    }

    function updateLoanMetrics(address _lender, bool _isNewLoan, bool _isSuccessful) external onlyPlatform {
        if (_isNewLoan) {
            lenderProfiles[_lender].activeLoans++;
            lenderProfiles[_lender].totalLent += msg.value;
        } else {
            lenderProfiles[_lender].activeLoans--;
            if (_isSuccessful) {
                lenderProfiles[_lender].successfulLoans++;
            }
        }
    }
}
