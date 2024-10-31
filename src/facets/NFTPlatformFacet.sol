// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// NFTBorrower.sol
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract NFTPlatform is ReentrancyGuard, Ownable {
    NFTBorrower public borrowerContract;
    NFTLender public lenderContract;

    struct Loan {
        address borrower;
        address lender;
        address nftContract;
        uint256 tokenId;
        uint256 amount;
        uint256 interest;
        uint256 duration;
        uint256 startTime;
        uint256 valuation;
        LoanStatus status;
    }

    enum LoanStatus {
        PENDING,
        ACTIVE,
        REPAID,
        DEFAULTED,
        REJECTED
    }

    mapping(uint256 => Loan) public loans;
    mapping(address => mapping(uint256 => uint256)) public nftValuations;
    uint256 public loanCounter;

    event NFTValuated(address indexed nftContract, uint256 tokenId, uint256 valuation);
    event LoanCreated(uint256 indexed loanId, address borrower, uint256 amount);
    event LoanFunded(uint256 indexed loanId, address lender);
    event LoanRepaid(uint256 indexed loanId);
    event LoanDefaulted(uint256 indexed loanId);

    constructor(
        address _borrowerContract,
        address _lenderContract
    ) Ownable(msg.sender) {
        borrowerContract = NFTBorrower(_borrowerContract);
        lenderContract = NFTLender(_lenderContract);
    }

    function valuateNFT(address _nftContract, uint256 _tokenId) public returns (uint256) {
        // Simplified valuation logic - in production, implement proper valuation mechanism
        uint256 valuation = 1 ether;
        nftValuations[_nftContract][_tokenId] = valuation;
        emit NFTValuated(_nftContract, _tokenId, valuation);
        return valuation;
    }

    function createLoan(
        address _nftContract,
        uint256 _tokenId,
        uint256 _amount,
        uint256 _duration
    ) external nonReentrant {
        uint256 valuation = valuateNFT(_nftContract, _tokenId);
        require(_amount <= valuation * 70 / 100, "Loan amount too high");

        IERC721(_nftContract).safeTransferFrom(msg.sender, address(this), _tokenId);

        loans[loanCounter] = Loan({
            borrower: msg.sender,
            lender: address(0),
            nftContract: _nftContract,
            tokenId: _tokenId,
            amount: _amount,
            interest: 0,
            duration: _duration,
            startTime: 0,
            valuation: valuation,
            status: LoanStatus.PENDING
        });

        emit LoanCreated(loanCounter, msg.sender, _amount);
        loanCounter++;
    }

    function fundLoan(uint256 _loanId, uint256 _interest) external payable nonReentrant {
        Loan storage loan = loans[_loanId];
        require(loan.status == LoanStatus.PENDING, "Loan not available");
        require(msg.value == loan.amount, "Incorrect amount");

        loan.lender = msg.sender;
        loan.interest = _interest;
        loan.startTime = block.timestamp;
        loan.status = LoanStatus.ACTIVE;

        payable(loan.borrower).transfer(msg.value);
        emit LoanFunded(_loanId, msg.sender);
    }

    function repayLoan(uint256 _loanId) external payable nonReentrant {
        Loan storage loan = loans[_loanId];
        require(loan.status == LoanStatus.ACTIVE, "Loan not active");
        require(msg.sender == loan.borrower, "Not borrower");
        require(msg.value == loan.amount + loan.interest, "Incorrect amount");

        payable(loan.lender).transfer(msg.value);
        IERC721(loan.nftContract).safeTransferFrom(address(this), loan.borrower, loan.tokenId);

        loan.status = LoanStatus.REPAID;
        borrowerContract.updateCreditScore(loan.borrower, true);
        emit LoanRepaid(_loanId);
    }

    function handleDefault(uint256 _loanId) external nonReentrant {
        Loan storage loan = loans[_loanId];
        require(loan.status == LoanStatus.ACTIVE, "Loan not active");
        require(block.timestamp > loan.startTime + loan.duration, "Not overdue");

        IERC721(loan.nftContract).safeTransferFrom(address(this), loan.lender, loan.tokenId);

        loan.status = LoanStatus.DEFAULTED;
        borrowerContract.updateCreditScore(loan.borrower, false);
        emit LoanDefaulted(_loanId);
    }
}