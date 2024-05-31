// SPDX-License-Identifier: MIT

// File: @openzeppelin/contracts@4.9.3/utils/Context.sol

// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

pragma solidity ^0.8.0;
import {Test, console} from "forge-std/Test.sol";
/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

// File: @openzeppelin/contracts@4.9.3/access/Ownable.sol

// OpenZeppelin Contracts (last updated v4.9.0) (access/Ownable.sol)

pragma solidity ^0.8.0;

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// File: liquidity.sol

pragma solidity ^0.8.0;

interface ILiquidityLocker {
    function transferLockOwnership(
        address _lpToken,
        uint256 _index,
        uint256 _lockID,
        address payable _newOwner
    ) external;

    function getUserLockForTokenAtIndex(
        address _user,
        address _lpToken,
        uint256 _index
    )
        external
        view
        returns (uint256, uint256, uint256, uint256, uint256, address);
}

contract LiquidityMarketplace is Ownable {
    ILiquidityLocker public liquidityLocker;

    struct Deal {
        address borrower;
        address lpToken;
        uint256 lockIndex;
        uint256 dealAmount;
        uint256 interestRate;
        uint256 loanDuration;
        uint256 startTime;
        address lender;
        bool isRepaid;
        bool isActive;
    }

//@audit: startPrice not used
    struct Auction {
        address owner;
        address highestBidOwner;
        address lpToken;
        uint256 lockIndex;
        uint256 startPrice;
        uint256 imeddiatelySellPrice;
        uint256 bidStep;
        uint256 duration;
        uint256 startTime;
        bool isActive;
        bool isFinishedImmediately;
        bool immediatelySell;
    }

    mapping(address => uint256[]) private userDeals;
    mapping(address => uint256[]) private userAuction;

    mapping(uint256 => mapping(address => uint256)) public bids; //why not public?
    mapping(uint256 => Auction) public auctions;
    mapping(uint256 => Deal) public deals;
    uint256 public nextAuctionId;
    uint256 public nextDealId;
    uint256 public ownerFee;
    address public feeReceiver;

    // События
    event DealInitialized(
        uint256 indexed dealId,
        address indexed borrower,
        address lpToken,
        uint256 lockIndex,
        uint256 dealAmount,
        uint256 interestRate,
        uint256 loanDuration
    );
    event DealActivated(uint256 indexed dealId, address indexed activator);
    event DealMade(uint256 indexed dealId, address indexed lender);
    event LoanRepaid(uint256 indexed dealId, address indexed repayer);
    event CollateralClaimed(uint256 indexed dealId, address indexed claimer);
    event AuctionStarted(
        uint256 indexed auctionId,
        address indexed owner,
        address lpToken,
        uint256 lockIndex,
        uint256 startPrice,
        uint256 imeddiatelySellPrice,
        uint256 bidStep,
        uint256 duration,
        bool immediatelySell
    );
    event AuctionActivated(
        uint256 indexed auctionId,
        address indexed activator
    );
    event BidMade(
        uint256 indexed auctionId,
        address indexed bidder,
        uint256 amount,
        uint256 timestamp
    );
    event AuctionWon(uint256 indexed auctionId, address indexed winner);
    event AuctionRewardClaimed(
        uint256 indexed auctionId,
        address indexed owner,
        uint256 amount,
        uint256 timestamp
    );
    event BidWithdrawn(
        uint256 indexed auctionId,
        address indexed bidder,
        uint256 amount,
        uint256 timestamp
    );
    event ImmediatelyBought(
        uint256 indexed auctionId,
        uint256 amount,
        uint256 timestamp
    );

    constructor(
        ILiquidityLocker _liquidityLocker,
        uint256 _ownerFee,
        address _feeReceiver
    ) {
        require(_ownerFee < 10000, "Owner fee must be less than 10000");
        require(
            _feeReceiver != address(0),
            "Fee receiver cannot be zero address"
        );
        liquidityLocker = _liquidityLocker;
        ownerFee = _ownerFee;
        feeReceiver = _feeReceiver;
    }

    function setOwnerFee(uint256 _ownerFee) external onlyOwner {
        //#when the caller is not the admin it should revert
         //#when the _ownerFee more than 9999 it should revert
        require(_ownerFee < 10000, "Owner fee must be less than 10000");

        ownerFee = _ownerFee;
    }

    function setFeeReceiver(address _feeReceiver) external onlyOwner {
        //#when the caller is not the admin it should revert
                //#when the _feeReceiver equal zero address it should revert
        require(
            _feeReceiver != address(0),
            "Fee receiver cannot be zero address"
        );

        feeReceiver = _feeReceiver;
    }

    function checkLiquidityOwner(
        address expectedOwner,
        address lpToken,
        uint256 index
    ) public view returns (bool) {
        (, , , , , address owner) = liquidityLocker.getUserLockForTokenAtIndex(
            expectedOwner,
            lpToken,
            index
        );
        //#when the expectedOwner equal owner it should return true
        //#when the expectedOwner not equal owner it should return false
        return owner == expectedOwner;
    }

    function getUserDeals(
        address _address
    ) external view returns (uint256[] memory) {
        return userDeals[_address];
    }
//why not userAuctionS
    function getUserAuction(
        address _address
    ) external view returns (uint256[] memory) {
        return userAuction[_address];
    }

    function initializeDeal(
        address lpToken,
        uint256 lockIndex,
        uint256 dealAmount,
        uint256 interestRate,
        uint256 loanDuration
    ) public {
        //#when the loanDuration is less than 1 it should revert
        require(loanDuration > 0, "Loan duration must be greater than 0");

        //#when the checkLiquidityOwner returns false it should revert
        require(
            checkLiquidityOwner(msg.sender, lpToken, lockIndex),
            "User does not owner of this lock"
        );
        //#when the interestRate is less than 1 it should revert
        require(interestRate > 0, "interestRate must be greater than 0");
        //#when the dealAmount is less than 1 it should revert
        require(dealAmount > 0, "dealAmount must be greater than 0");

//## when the dealAmount is more than 0 it should create new Deal
        deals[nextDealId] = Deal({
            borrower: msg.sender,
            lpToken: lpToken,
            lockIndex: lockIndex,
            dealAmount: dealAmount,
            interestRate: interestRate,
            loanDuration: loanDuration,
            startTime: 0,
            lender: address(0),
            isRepaid: false,
            isActive: false
        });

//## it should emit DealInitialized event
        emit DealInitialized(
            nextDealId,
            msg.sender,
            lpToken,
            lockIndex,
            dealAmount,
            interestRate,
            loanDuration
        );
//## it should add created dealId to user deals mapping
        userDeals[msg.sender].push(nextDealId);

//## it should increase dealId
        nextDealId++;
    }

    function activateDeal(uint256 dealId) external {
        Deal storage deal = deals[dealId];
        //#when the deal.borrower is equal zero address it should revert
        require(deal.borrower != address(0), "Deal is empty");
        //#when the checkLiquidityOwner returns false it should revert
        require(
            checkLiquidityOwner(address(this), deal.lpToken, deal.lockIndex),
            "Contract does not owner of this liquidity"
        );
        //#when the checkLiquidityOwner returns true it should set the deal.isActive to true
        deal.isActive = true;
        //## it should emit DealActivated event
        emit DealActivated(dealId, msg.sender);
    }

    function makeDeal(uint256 dealId) external payable {
        Deal storage deal = deals[dealId];
        //## Given deal is return false it should revert

        require(deal.isActive, "Deal inactive");
        //## Given lender not equals zero address it should revert
        require(deal.lender == address(0), "Deal already has a lender");
        //## Given borrower equals to caller it should revert
        require(
            deal.borrower != msg.sender,
            "Borrower cannot make loan for himself"
        );
        //#when the msg.value less than given dealAmount it should revert
        require(msg.value >= deal.dealAmount, "Insufficient funds");
//#when the msg.value more on equal given dealAmount 
// it should set deal lender to msg.sender
        deal.lender = msg.sender;
        // it should set deal startime to current timestamp
        deal.startTime = block.timestamp;
        // it should set feeAmount
        uint256 feeAmount = (deal.dealAmount * ownerFee) / 10000;
        // it should transfer feeAmount to the fee receiver
        //@audit: it should skip fee transfer if fee == 0
        (bool feeSent, ) = payable(feeReceiver).call{value: feeAmount}("");
        // it should revert if transfer to the fee receiver failed
        require(feeSent, "Failed to send fee");
        // it should transfer the lent ETH (except the fee) to the borrower
        (bool sent, ) = payable(deal.borrower).call{
            value: msg.value - feeAmount
        }("");
        // it should revert if transfer to the borrower failed
        require(sent, "Failed to send funds");
        //## it should emit DealMade event
        emit DealMade(dealId, msg.sender);
    }

    function cancelDeal(uint256 dealId) public {
        Deal storage deal = deals[dealId];
        //#when the caller is not equal given borrower it should revert
        require(deal.borrower == msg.sender, "Caller not lock owner");
        //#given lender is not equal to address zero it should revert
        require(deal.lender == address(0), "Cannot cancel processing deal");
        
        //## it should get the lockId from call to liquidityLocker
        (, , , , uint256 lockId, ) = liquidityLocker.getUserLockForTokenAtIndex(
            address(this),
            deal.lpToken,
            deal.lockIndex
        );

        //## it should transfer locked LP ownership to caller
        liquidityLocker.transferLockOwnership(
            deal.lpToken,
            deal.lockIndex,
            lockId,
            payable(msg.sender)
        );
        //## it should delete deal
        delete deals[dealId];
    }
//what if deal not active???
    function repayLoan(uint256 dealId) public payable {
        Deal storage deal = deals[dealId];
        // it should set repayAmount
        uint256 repayAmount = deal.dealAmount +
            (deal.dealAmount * deal.interestRate) /
            10000;
        
        //#when the deal is alredy paid it should revert
        require(!deal.isRepaid, "Deal already repaid");
        //#when the caller is not equal given borrower it should revert
        require(msg.sender == deal.borrower, "Sender is not a borrower");
        //#when the input value is not equal or more than given repay amount it should revert
        console.log(msg.value);
        console.log(repayAmount);
        require(msg.value >= repayAmount, "Insuffitient payable amount");
        //given start time and loan duration is less than current timestamp it should revert !!! CHECK THIS AGAIM
        require(
            deal.startTime + deal.loanDuration > block.timestamp,
            "Loan duration exceed"
        );
        //## it should set repaid status to true
        deal.isRepaid = true;
        //## it should get the lockId from call to liquidityLocker
        (, , , , uint256 lockId, ) = liquidityLocker.getUserLockForTokenAtIndex(
            address(this),
            deal.lpToken,
            deal.lockIndex
        );
        //## it should transfer locked LP ownership to caller
        liquidityLocker.transferLockOwnership(
            deal.lpToken,
            deal.lockIndex,
            lockId,
            payable(msg.sender)
        );
        // it should transfer input ETH value to the lender
        (bool sent, ) = payable(deal.lender).call{value: msg.value}("");
        // it should revert if transfer to the lender failed
        require(sent, "Repay failed");
        //## it should emit DealMade event
        emit LoanRepaid(dealId, msg.sender);
    }

    function claimCollateral(uint256 dealId) public {
        Deal storage deal = deals[dealId];
        //#when the caller is not equal given lender it should revert
        require(deal.lender == msg.sender, "Caller is not lender");
        // given start time and loan duration is more than current timestamp it should revert
        require(
            deal.startTime + deal.loanDuration < block.timestamp,
            "Deal is active yet"
        );
        //## it should get the lockId from call to liquidityLocker
        (, , , , uint256 lockId, ) = liquidityLocker.getUserLockForTokenAtIndex(
            address(this),
            deal.lpToken,
            deal.lockIndex
        );
        //## it should transfer locked LP ownership to caller
        liquidityLocker.transferLockOwnership(
            deal.lpToken,
            deal.lockIndex,
            lockId,
            payable(msg.sender)
        );
        //## it should emit CollateralClaimed event
        emit CollateralClaimed(dealId, msg.sender);
    }

    function startAuction(
        address lpToken,
        uint256 lockIndex,
        uint256 startPrice,
        uint256 imeddiatelySellPrice,
        uint256 bidStep,
        uint256 duration,
        bool immediatelySell
    ) public {
         // #when the duration less than 1 it should revert
        require(duration > 0, "Duration must be greater than 0");
        //#when the checkLiquidityOwner returns false it should revert
        require(
            checkLiquidityOwner(msg.sender, lpToken, lockIndex),
            "User does not owner of this lock"
        );
        // #when the imeddiatelySellPrice less than 1 it should revert
        require(
            imeddiatelySellPrice > 0,
            "imeddiatelySellPrice must be positive number"
        );

        auctions[nextAuctionId] = Auction({
            owner: msg.sender,
            highestBidOwner: address(0),
            lpToken: lpToken,
            lockIndex: lockIndex,
            startPrice: startPrice,
            imeddiatelySellPrice: imeddiatelySellPrice,
            bidStep: bidStep,
            duration: duration,
            startTime: block.timestamp,
            isActive: false,
            isFinishedImmediately: false,
            immediatelySell: immediatelySell
        });

        //## it should emit AuctionStarted event
        emit AuctionStarted(
            nextAuctionId,
            msg.sender,
            lpToken,
            lockIndex,
            startPrice,
            imeddiatelySellPrice,
            bidStep,
            duration,
            immediatelySell
        );



        //## it should add created dealId to user deals mapping
        userAuction[msg.sender].push(nextAuctionId);
        //## it should increase AuctionId
        nextAuctionId++;
    }

    function activateAuction(uint256 auctionId) external {
        Auction storage auction = auctions[auctionId];
        //# when auction is active it should revert
        require(!auction.isActive, "Auction already active");
        //# when auction owner is not equal zero address it should revert
        require(auction.owner != address(0), "Auction is empty");
        //#when the checkLiquidityOwner returns false it should revert
        require(
            checkLiquidityOwner(
                address(this),
                auction.lpToken,
                auction.lockIndex
            ),
            "Contract does not owner of this liquidity"
        );
        // ## it should set the auction.isActive to true
        auction.isActive = true;
        // ## it should set the auction.startTime to current timestamp
        auction.startTime = block.timestamp;
        // ## it should emit the AuctionActivated event
        emit AuctionActivated(auctionId, msg.sender);
    }

    function immediatelyBuy(uint256 auctionId) external payable {
        Auction storage auction = auctions[auctionId];
        //# Given the immediatelySell statement is false it should revert
        require(
            auction.immediatelySell,
            "Immediately selling is disabled for this lottery"
        );
        //# Given the auction.owner is equal to caller
        require(auction.owner != msg.sender, "Sender is auction owner");
        //# When ether amount less than auction.imeddiatelySellPrice it should revert
        require(
            msg.value >= auction.imeddiatelySellPrice,
            "Insuffitient payable amount"
        );
        //# Given auction.isFinishedImmediately is true it should revert
        //# Given auction.isActive is false it should revert
        //# Given auction.startTime and auction.duration is less than current timestamp it should revert
        require(
            !auction.isFinishedImmediately &&
                auction.isActive &&
                auction.startTime + auction.duration > block.timestamp,
            "Auction inactive"
        );
        // ## it should set the auction.isFinishedImmediately to true
        auction.isFinishedImmediately = true;
        // ## it should set the auction.highestBidOwner to address zero
        auction.highestBidOwner = address(0);
        (, , , , uint256 lockId, ) = liquidityLocker.getUserLockForTokenAtIndex(
            address(this),
            auction.lpToken,
            auction.lockIndex
        );
        liquidityLocker.transferLockOwnership(
            auction.lpToken,
            auction.lockIndex,
            lockId,
            payable(msg.sender)
        );

        uint256 feeAmount = (msg.value * ownerFee) / 10000;       
        (bool feeSent, ) = payable(feeReceiver).call{value: feeAmount}("");
        //## it should revert if transfer to the fee receiver is failed
        require(feeSent, "Failed to send fee");

        (bool sent, ) = payable(auction.owner).call{
            value: msg.value - feeAmount
        }("");
        //## it should revert if transfer to the auction owner is failed
        require(sent, "Failed to send funds");
        // ## it should emit the ImmediatelyBought event
        emit ImmediatelyBought(auctionId, msg.value, block.timestamp);
    }

    function makeBid(uint256 auctionId) public payable {
        Auction storage auction = auctions[auctionId];
        //# given auction.isFinishedImmediately is true it should revert
        //# given auction.isActive is false it should revert
        //# given auction.startTime and auction.duration is less than current timestamp it should revert
        require(
            !auction.isFinishedImmediately &&
                auction.isActive &&
                auction.startTime + auction.duration > block.timestamp,
            "Auction inactive"
        );
        //# given the auction.owner is equal to caller it should revert
        require(auction.owner != msg.sender, "Sender is auction owner");
        //# when bid lower than previous bid plus bid step it should revert
        // console.log(bids[auctionId][msg.sender]);
        // console.log(bids[auctionId][msg.sender] + msg.value);
        // console.log(bids[auctionId][auction.highestBidOwner]);
        // console.log(bids[auctionId][auction.highestBidOwner] + auction.bidStep);
        require(
            bids[auctionId][msg.sender] + msg.value >=
                bids[auctionId][auction.highestBidOwner] + auction.bidStep,
            "Bid must be greater than previous + bidStep"
        );
        // ## it should set caller bid
        bids[auctionId][msg.sender] += msg.value;
        // ## it should set auction.highestBidOwner to the caller
        auction.highestBidOwner = msg.sender;
        // ## it should emit the BidMade event
        emit BidMade(auctionId, msg.sender, msg.value, block.timestamp);
    }
    //owner gets lock back - nobody bets and auc ends
    function withdrawAuctionLiquidity(uint256 auctionId) public {
        Auction storage auction = auctions[auctionId];
        //# given auction.startTime and auction.duration is more than current timestamp it should revert
        require(
            auction.startTime + auction.duration < block.timestamp,
            "Auction is active yet"
        );
        //# given auction.highestBidOwner is not equal to address zero it should revert
        //# given auction.isFinishedImmediately is true it should revert
        require(
            auction.highestBidOwner == address(0) ||
                !auction.isFinishedImmediately,
            "Not claimable"
        ); //@audit: exploit here, auction owner can withdraw LP and Funds from top bidder

        //# given the auction.owner is not equal to caller it should revert
        require(msg.sender == auction.owner, "Caller is not auction owner");

        (, , , , uint256 lockId, ) = liquidityLocker.getUserLockForTokenAtIndex(
            address(this),
            auction.lpToken,
            auction.lockIndex
        );
        liquidityLocker.transferLockOwnership(
            auction.lpToken,
            auction.lockIndex,
            lockId,
            payable(msg.sender)
        );
    }
//why don't have claimed state?
//highest bid user gets his LP after auc ends
    function claimAuction(uint256 auctionId) public {
        Auction memory auction = auctions[auctionId];
        //# given auction.isFinishedImmediately is false it should revert or
        //# given auction.startTime and auction.duration is more than current timestamp it should revert
        require(
            auction.isFinishedImmediately ||
                auction.startTime + auction.duration < block.timestamp,
            "Auction is active yet"
        );
        //# given auction.highestBidOwner not equals to caller it should revert
        //# given auction.isFinishedImmediately is true it should revert
        require(
            msg.sender == auction.highestBidOwner &&
                !auction.isFinishedImmediately,
            "Not eligible for claim"
        );
        (, , , , uint256 lockId, ) = liquidityLocker.getUserLockForTokenAtIndex(
            address(this),
            auction.lpToken,
            auction.lockIndex
        );
        liquidityLocker.transferLockOwnership(
            auction.lpToken,
            auction.lockIndex,
            lockId,
            payable(msg.sender)
        );
        // ## it should emit the AuctionWon event
        emit AuctionWon(auctionId, msg.sender);
    }

    //owner get highest bet
    //@audit: it should have require checking and revert if auction doesn't have bets
    function claimAuctionReward(uint256 auctionId) external {
        Auction memory auction = auctions[auctionId];
        //# given auction.isFinishedImmediately is true it should revert or
        //# given auction.startTime and auction.duration is more than current timestamp it should revert
        require(
            !auction.isFinishedImmediately &&
                auction.startTime + auction.duration < block.timestamp,
            "Auction active yet"
        );

        //# given the auction.owner is not equal to caller it should revert
        require(msg.sender == auction.owner, "Not eligible for claim"); // The error message is unclear, causing confusion about the eligibility requirement.
        uint256 bidAmount = bids[auctionId][auction.highestBidOwner];

        uint256 feeAmount = (bidAmount * ownerFee) / 10000;
        (bool feeSent, ) = payable(feeReceiver).call{value: feeAmount}("");
        //## it should revert if transfer to the fee receiver is failed
        require(feeSent, "Failed to send fee");
        (bool sent, ) = payable(msg.sender).call{value: bidAmount - feeAmount}(
            ""
        );
        //## it should revert if transfer to the caller is failed
        require(sent, "Withdraw failed");
        // ## it should emit the AuctionRewardClaimed event
        emit AuctionRewardClaimed(
            auctionId,
            msg.sender,
            bidAmount,
            block.timestamp
        );
    }

    //user claim his not highest bet after auc ends
    function withdrawBid(uint256 auctionId) external {
        Auction storage auction = auctions[auctionId];
        uint256 bidAmount = bids[auctionId][msg.sender];
        //# given auction.highestBidOwner equals to caller it should revert
        //# given bidAmount less than 1 it should revert
        require(
            msg.sender != auction.highestBidOwner && bidAmount > 0,
            "No eligible to withdraw"
        );
        (bool sent, ) = payable(msg.sender).call{value: bidAmount}("");
        //## it should revert if transfer to the caller is failed
        require(sent, "Withdraw failed");
        //## it should set caller bid to 0
        bids[auctionId][msg.sender] = 0;
        // ## it should emit the BidWithdrawn event
        emit BidWithdrawn(auctionId, msg.sender, bidAmount, block.timestamp);
    }
}
