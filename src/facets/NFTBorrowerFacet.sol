// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// NFTBorrower.sol
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract NFTBorrower is ReentrancyGuard {
    struct BorrowerProfile {
        string name;
        uint256 creditScore;
        uint256 activeLoans;
        uint256 totalBorrowed;
        uint256 defaultCount;
        bool isRegistered;
    }

    mapping(address => BorrowerProfile) public borrowerProfiles;
    address public platform;

    event BorrowerProfileCreated(address indexed borrower, string name);
    event LoanRequested(address indexed borrower, address nftContract, uint256 tokenId, uint256 amount);
    event CollateralDeposited(address indexed borrower, address nftContract, uint256 tokenId);

    modifier onlyPlatform() {
        require(msg.sender == platform, "Only platform can call");
        _;
    }

    constructor(address _platform) {
        platform = _platform;
    }

    function createProfile(string memory _name) external {
        require(!borrowerProfiles[msg.sender].isRegistered, "Profile already exists");
        
        borrowerProfiles[msg.sender] = BorrowerProfile({
            name: _name,
            creditScore: 100,
            activeLoans: 0,
            totalBorrowed: 0,
            defaultCount: 0,
            isRegistered: true
        });
        
        emit BorrowerProfileCreated(msg.sender, _name);
    }

    function requestLoan(
        address _nftContract,
        uint256 _tokenId,
        uint256 _amount
    ) external nonReentrant {
        require(borrowerProfiles[msg.sender].isRegistered, "Profile not registered");
        require(IERC721(_nftContract).ownerOf(_tokenId) == msg.sender, "Not NFT owner");
        require(borrowerProfiles[msg.sender].activeLoans < 3, "Too many active loans");

        emit LoanRequested(msg.sender, _nftContract, _tokenId, _amount);
    }

    function updateCreditScore(address _borrower, bool _positive) external onlyPlatform {
        if (_positive) {
            borrowerProfiles[_borrower].creditScore = min(
                borrowerProfiles[_borrower].creditScore + 5,
                100
            );
        } else {
            borrowerProfiles[_borrower].creditScore = max(
                borrowerProfiles[_borrower].creditScore - 10,
                0
            );
            borrowerProfiles[_borrower].defaultCount++;
        }
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }
}