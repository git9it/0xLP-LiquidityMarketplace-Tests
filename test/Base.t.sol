// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {LiquidityMarketplace, ILiquidityLocker} from "../contracts/LiquidityMarketplace.sol";
import {LiqudityLockerMock} from "../contracts/liquidityLockerMock.sol";

contract LiquidityMarketplaceTest is Test {
    LiquidityMarketplace public liqMarketSC;
    LiquidityMarketplace public liqMarketSCBadReceiver;
    LiqudityLockerMock public liqLockMockSC;
    ILiquidityLocker public liqLockerSC;

    address FEE_RECEIVER = makeAddr("feeReceiver");
    address LP_TOKEN = makeAddr("lpToken");
    address BORROWER = makeAddr("borrower");
    address LENDER = makeAddr("lender");
    address RANDOMGUY = makeAddr("randomGuy");
    address LP_SELLER = makeAddr("lpSeller");
    address LP_BUYER = makeAddr("lpBuyer");
    address LP_BUYER_2 = makeAddr("lpBuyer2");

    bytes4 setUnsuccessfulPath = bytes4(keccak256("setUnsuccessfulPath()"));
    bytes4 setSuccessfulPath = bytes4(keccak256("setSuccessfulPath()"));

    uint256 ownerFee = 1000;

    function setUp() public {
        liqLockMockSC = new LiqudityLockerMock();
        liqLockerSC = ILiquidityLocker(address(liqLockMockSC));

        liqMarketSC = new LiquidityMarketplace(liqLockerSC, ownerFee, FEE_RECEIVER);

        liqMarketSCBadReceiver = new LiquidityMarketplace(liqLockerSC, ownerFee, address(this));

        vm.deal(LENDER, 1 ether);
        vm.deal(BORROWER, 1 ether);
        vm.deal(LP_BUYER, 1 ether);
        vm.deal(LP_BUYER_2, 1 ether);
    }

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
    event AuctionActivated(uint256 indexed auctionId, address indexed activator);
    event BidMade(uint256 indexed auctionId, address indexed bidder, uint256 amount, uint256 timestamp);
    event AuctionWon(uint256 indexed auctionId, address indexed winner);
    event AuctionRewardClaimed(uint256 indexed auctionId, address indexed owner, uint256 amount, uint256 timestamp);
    event BidWithdrawn(uint256 indexed auctionId, address indexed bidder, uint256 amount, uint256 timestamp);
    event ImmediatelyBought(uint256 indexed auctionId, uint256 amount, uint256 timestamp);

    function utils_setUnsuccessfulPath() public {
        address(liqLockerSC).call(abi.encodeWithSelector(setUnsuccessfulPath));
    }

    function utils_setSuccessfulPath() public {
        address(liqLockerSC).call(abi.encodeWithSelector(setSuccessfulPath));
    }

    function test_ownerFee() public view {
        assertEq(liqMarketSC.ownerFee(), ownerFee);
    }

    function test_LiqLockerMockUnsuccessfulPath() public {
        utils_setUnsuccessfulPath();

        (,,,,, address owner) = liqLockerSC.getUserLockForTokenAtIndex(address(this), address(0), 0);

        assertNotEq(address(this), owner);
    }

    function test_LiqLockerMockSuccessfulPath() public {
        utils_setSuccessfulPath();

        (,,,,, address owner) = liqLockerSC.getUserLockForTokenAtIndex(address(this), address(0), 0);

        assertEq(address(this), owner);
    }

    modifier useBorrower() {
        vm.startPrank(BORROWER);
        _;
        vm.stopPrank();
    }

    modifier useSeller() {
        vm.startPrank(LP_SELLER);
        _;
        vm.stopPrank();
    }

    ///////////////
    //LOAN TESTS//
    /////////////

    ///////////////////
    //initializeDeal//
    /////////////////
    function test_initializeDeal_WhenLoanDurationIsInvalid_Revert() public useBorrower {
        vm.expectRevert("Loan duration must be greater than 0");
        liqMarketSC.initializeDeal(LP_TOKEN, 0, 0, 0, 0);
    }

    function test_initializeDeal_WhenCheckLiqudityOwnerFalse_Revert() public useBorrower {
        utils_setUnsuccessfulPath();
        vm.expectRevert("User does not owner of this lock");
        liqMarketSC.initializeDeal(LP_TOKEN, 0, 0, 0, 1);
    }

    function test_initializeDeal_WhenInterestRateIsInvalid_Revert() public useBorrower {
        vm.expectRevert("interestRate must be greater than 0");
        liqMarketSC.initializeDeal(LP_TOKEN, 0, 0, 0, 1);
    }

    function test_initializeDeal_WhenDealAmountIsInvalid_Revert() public useBorrower {
        vm.expectRevert("dealAmount must be greater than 0");
        liqMarketSC.initializeDeal(LP_TOKEN, 0, 0, 1, 1);
    }

    function test_initializeDeal_ItShouldCreateDeal() public useBorrower {
        liqMarketSC.initializeDeal(LP_TOKEN, 0, 1, 1, 1);
        (address borrower,,,,,,,,,) = liqMarketSC.deals(0);
        assertEq(borrower, BORROWER);
    }

    function test_initializeDeal_ItShouldCreateEvent() public useBorrower {
        uint256 DealId = liqMarketSC.nextDealId();
        vm.expectEmit(true, true, false, true);
        emit DealInitialized(DealId, BORROWER, LP_TOKEN, 0, 1, 1, 1);
        liqMarketSC.initializeDeal(LP_TOKEN, 0, 1, 1, 1);
    }

    function test_initializeDeal_ItShouldAddDealId() public useBorrower {
        liqMarketSC.initializeDeal(LP_TOKEN, 0, 1, 1, 1);
        uint256[] memory userDeals = liqMarketSC.getUserDeals(BORROWER);
        assertEq(userDeals.length, 1);
    }

    function test_initializeDeal_ItShouldIncreaseDealId() public useBorrower {
        uint256 nextDealIdBefore = liqMarketSC.nextDealId();
        liqMarketSC.initializeDeal(LP_TOKEN, 0, 1, 1, 1);
        uint256 nextDealIdAfter = liqMarketSC.nextDealId();
        assertEq(nextDealIdBefore, nextDealIdAfter - 1);
    }

    ///////////////////
    //activateDeal////
    /////////////////

    function test_activateDeal_GivenDealBorrowerEqZeroAddress_Revert() public useBorrower {
        vm.expectRevert("Deal is empty");
        liqMarketSC.activateDeal(1);
    }

    function test_activateDeal_WhenCheckLiquidityOwnerFalse_Revert() public {
        liqMarketSC.initializeDeal(LP_TOKEN, 0, 1, 1, 1);
        utils_setUnsuccessfulPath();
        vm.expectRevert("Contract does not owner of this liquidity");
        liqMarketSC.activateDeal(0);
    }

    function test_activateDeal_ItShouldSetActiveTrue() public useBorrower {
        liqMarketSC.initializeDeal(LP_TOKEN, 0, 1, 1, 1);
        liqMarketSC.activateDeal(0);
        (,,,,,,,,, bool isActive) = liqMarketSC.deals(0);
        assertEq(isActive, true);
    }

    function test_activateDeal_ItShouldEmitEvent() public useBorrower {
        uint256 DealId = liqMarketSC.nextDealId();
        liqMarketSC.initializeDeal(LP_TOKEN, 0, 1, 1, 1);
        vm.expectEmit(true, true, false, true);
        emit DealActivated(DealId, BORROWER);
        liqMarketSC.activateDeal(0);
    }

    ///////////////////
    //makeDeal////////
    /////////////////

    function test_makeDeal_givenDealIsNotActive_Revert() public useBorrower {
        liqMarketSC.initializeDeal(LP_TOKEN, 0, 1, 1, 1);
        vm.expectRevert("Deal inactive");
        liqMarketSC.makeDeal(0);
    }

    function test_makeDeal_givenLenderNotEqZeroAddress_Revert() public {
        vm.startPrank(BORROWER);
        liqMarketSC.initializeDeal(LP_TOKEN, 0, 1, 1, 1);
        liqMarketSC.activateDeal(0);
        vm.startPrank(LENDER);
        liqMarketSC.makeDeal{value: 1}(0);
        vm.expectRevert("Deal already has a lender");
        liqMarketSC.makeDeal{value: 1}(0);
    }

    function test_makeDeal_givenBorrowerEqCaller_Revert() public useBorrower {
        liqMarketSC.initializeDeal(LP_TOKEN, 0, 1, 1, 1);
        liqMarketSC.activateDeal(0);
        vm.expectRevert("Borrower cannot make loan for himself");
        liqMarketSC.makeDeal{value: 1}(0);
    }

    function test_makeDeal_WhenEthValueNotEnough_Revert() public {
        vm.startPrank(BORROWER);
        liqMarketSC.initializeDeal(LP_TOKEN, 0, 2, 1, 1);
        liqMarketSC.activateDeal(0);
        vm.startPrank(LENDER);
        vm.expectRevert("Insufficient funds");
        liqMarketSC.makeDeal{value: 1}(0);
    }

    function test_makeDeal_ItShouldSetDealLender() public {
        vm.startPrank(BORROWER);
        liqMarketSC.initializeDeal(LP_TOKEN, 0, 1, 1, 1);
        liqMarketSC.activateDeal(0);
        vm.startPrank(LENDER);
        liqMarketSC.makeDeal{value: 1}(0);
        (,,,,,,, address lenderFromDeals,,) = liqMarketSC.deals(0);
        assertEq(lenderFromDeals, LENDER);
    }

    function test_makeDeal_FeeTransferFailed_Revert() public {
        vm.startPrank(BORROWER);
        liqMarketSCBadReceiver.initializeDeal(LP_TOKEN, 0, 1, 1, 1);
        liqMarketSCBadReceiver.activateDeal(0);
        vm.stopPrank();
        vm.expectRevert("Failed to send fee");
        liqMarketSCBadReceiver.makeDeal{value: 1}(0);
    }

    //it's revert bc it trying to send funds to this contract(init from test sc)
    function test_makeDeal_IfBorrowerTransferFailed_Revert() public {
        liqMarketSC.initializeDeal(LP_TOKEN, 0, 1, 1, 1);
        liqMarketSC.activateDeal(0);
        vm.startPrank(LENDER);
        vm.expectRevert("Failed to send funds");
        liqMarketSC.makeDeal{value: 1}(0);
    }

    function test_makeDeal_ItShouldEmitEvent() public {
        vm.startPrank(BORROWER);
        uint256 DealId = liqMarketSC.nextDealId();
        liqMarketSC.initializeDeal(LP_TOKEN, 0, 1, 1, 1);
        liqMarketSC.activateDeal(0);
        vm.startPrank(LENDER);
        vm.expectEmit(true, true, false, true);
        emit DealMade(DealId, LENDER);
        liqMarketSC.makeDeal{value: 1}(0);
    }

    ///////////////////
    //cancelDeal//////
    /////////////////

    function test_cancelDeal_whenCallerNotEqGivenBorrower() public {
        vm.startPrank(BORROWER);
        liqMarketSC.initializeDeal(LP_TOKEN, 0, 1, 1, 1);
        liqMarketSC.activateDeal(0);
        vm.startPrank(RANDOMGUY);
        vm.expectRevert("Caller not lock owner");
        liqMarketSC.cancelDeal(0);
    }

    function test_cancelDeal_whenLenderNotEqZeroAddress() public {
        vm.startPrank(BORROWER);
        liqMarketSC.initializeDeal(LP_TOKEN, 0, 1, 1, 1);
        liqMarketSC.activateDeal(0);
        vm.startPrank(LENDER);
        liqMarketSC.makeDeal{value: 1}(0);
        vm.startPrank(BORROWER);
        vm.expectRevert("Cannot cancel processing deal");
        liqMarketSC.cancelDeal(0);
    }

    function test_cancelDeal_ItShouldDeleteDeal() public {
        vm.startPrank(BORROWER);
        liqMarketSC.initializeDeal(LP_TOKEN, 0, 1, 1, 1);
        liqMarketSC.activateDeal(0);
        (address borrower,,,,,,,,, bool isActive) = liqMarketSC.deals(0);
        assertEq(borrower, BORROWER);
        liqMarketSC.cancelDeal(0);
        (borrower,,,,,,,,, isActive) = liqMarketSC.deals(0);
        assertNotEq(borrower, BORROWER);
    }

    ///////////////////
    //repayLoan///////
    /////////////////

    function test_repayLoan_GivenDealAlreadyPaid_Revert() public {
        vm.startPrank(BORROWER);
        liqMarketSC.initializeDeal(LP_TOKEN, 0, 2, 1, 1);
        liqMarketSC.activateDeal(0);
        vm.startPrank(LENDER);
        liqMarketSC.makeDeal{value: 2}(0);
        vm.startPrank(BORROWER);
        liqMarketSC.repayLoan{value: 2}(0);
        (,,,,,,,, bool isRepaid,) = liqMarketSC.deals(0);
        assertEq(isRepaid, true);
        vm.expectRevert("Deal already repaid");
        liqMarketSC.repayLoan{value: 2}(0);
    }

    function test_repayLoan_whenCallerNotEqGivenBorrower() public {
        vm.startPrank(BORROWER);
        liqMarketSC.initializeDeal(LP_TOKEN, 0, 1, 1, 1);
        liqMarketSC.activateDeal(0);
        vm.startPrank(LENDER);
        liqMarketSC.makeDeal{value: 1}(0);
        vm.startPrank(RANDOMGUY);
        vm.expectRevert("Sender is not a borrower");
        liqMarketSC.repayLoan(0);
    }

    function test_repayLoan_whenNotEnoughEthValue_Revert() public {
        vm.startPrank(BORROWER);
        liqMarketSC.initializeDeal(LP_TOKEN, 0, 2, 1, 1);
        liqMarketSC.activateDeal(0);
        vm.startPrank(LENDER);
        liqMarketSC.makeDeal{value: 2}(0);
        vm.startPrank(BORROWER);
        vm.expectRevert("Insuffitient payable amount");
        liqMarketSC.repayLoan{value: 1}(0);
    }

    function test_repayLoan_LoanDurationExpired_Revert() public {
        vm.startPrank(BORROWER);
        liqMarketSC.initializeDeal(LP_TOKEN, 0, 2, 1, 1);
        liqMarketSC.activateDeal(0);
        vm.startPrank(LENDER);
        liqMarketSC.makeDeal{value: 2}(0);
        vm.startPrank(BORROWER);
        vm.warp(100);
        vm.expectRevert("Loan duration exceed");
        liqMarketSC.repayLoan{value: 2}(0);
    }

    function test_repayLoan_ShouldSetIsRepaidTrue() public {
        vm.startPrank(BORROWER);
        liqMarketSC.initializeDeal(LP_TOKEN, 0, 2, 1, 1);
        liqMarketSC.activateDeal(0);
        vm.startPrank(LENDER);
        liqMarketSC.makeDeal{value: 2}(0);
        vm.startPrank(BORROWER);
        liqMarketSC.repayLoan{value: 2}(0);
        (,,,,,,,, bool isRepaid,) = liqMarketSC.deals(0);
        assertEq(isRepaid, true);
    }

    function test_repayLoan_TransferToLenderFailed_Revert() public {
        vm.startPrank(BORROWER);
        liqMarketSC.initializeDeal(LP_TOKEN, 0, 2, 1, 1);
        liqMarketSC.activateDeal(0);
        vm.stopPrank();
        liqMarketSC.makeDeal{value: 2}(0);
        vm.startPrank(BORROWER);
        vm.expectRevert("Repay failed");
        liqMarketSC.repayLoan{value: 2}(0);
    }

    function test_repayLoan_ShouldEmitEvent() public {
        vm.startPrank(BORROWER);
        uint256 DealId = liqMarketSC.nextDealId();
        liqMarketSC.initializeDeal(LP_TOKEN, 0, 2, 1, 1);
        liqMarketSC.activateDeal(0);
        vm.startPrank(LENDER);
        liqMarketSC.makeDeal{value: 2}(0);
        vm.startPrank(BORROWER);
        vm.expectEmit(true, true, false, true);
        emit LoanRepaid(DealId, BORROWER);
        liqMarketSC.repayLoan{value: 2}(0);
    }

    ////////////////////
    //claimCollateral//
    //////////////////

    function test_claimCollateral_WhenCallerNotEqGivenLender_Revert() public {
        vm.startPrank(BORROWER);
        liqMarketSC.initializeDeal(LP_TOKEN, 0, 2, 1, 1);
        liqMarketSC.activateDeal(0);
        vm.startPrank(LENDER);
        liqMarketSC.makeDeal{value: 2}(0);
        vm.startPrank(RANDOMGUY);
        vm.expectRevert("Caller is not lender");
        liqMarketSC.claimCollateral(0);
    }

    function test_claimCollateral_WhenDealStillActive_Revert() public {
        vm.startPrank(BORROWER);
        liqMarketSC.initializeDeal(LP_TOKEN, 0, 2, 1, 1);
        liqMarketSC.activateDeal(0);
        vm.startPrank(LENDER);
        liqMarketSC.makeDeal{value: 2}(0);
        vm.expectRevert("Deal is active yet");
        liqMarketSC.claimCollateral(0);
    }

    function test_claimCollateral_WhenDealStillActive_RevertEd() public {
        vm.startPrank(BORROWER);
        uint256 DealId = liqMarketSC.nextDealId();
        liqMarketSC.initializeDeal(LP_TOKEN, 0, 2, 1, 1);
        liqMarketSC.activateDeal(0);
        vm.startPrank(LENDER);
        liqMarketSC.makeDeal{value: 2}(0);
        vm.warp(200);
        vm.expectEmit(true, true, false, true);
        emit CollateralClaimed(DealId, LENDER);
        liqMarketSC.claimCollateral(0);
    }

    //////////////////
    //AUCTION TESTS//
    ////////////////

    //////////////////
    //startAuction///
    ////////////////

    function test_startAuction_WhenAuctionDurationIsInvalid() public {
        vm.expectRevert("Duration must be greater than 0");
        liqMarketSC.startAuction(LP_TOKEN, 0, 1, 10, 1, 0, true);
    }

    function test_startAuction_WhenImeddiatelySellPriceIsInvalid() public {
        vm.expectRevert("imeddiatelySellPrice must be positive number");
        liqMarketSC.startAuction(LP_TOKEN, 0, 1, 0, 1, 10, true);
    }

    function test_startAuction_WhenCheckLiqudityOwnerFalse() public {
        utils_setUnsuccessfulPath();
        vm.expectRevert("User does not owner of this lock");
        liqMarketSC.startAuction(LP_TOKEN, 0, 1, 10, 1, 10, true);
    }

    function test_startAuction_ShouldCreateNewAuction() public useSeller {
        liqMarketSC.startAuction(LP_TOKEN, 0, 1, 10, 1, 10, true);
        (address owner,,,,,,,,,,,) = liqMarketSC.auctions(0);
        assertEq(owner, LP_SELLER);
    }

    function test_startAuction_ShouldEmitEvent() public useSeller {
        liqMarketSC.startAuction(LP_TOKEN, 0, 1, 10, 1, 10, true);
        (address owner,,,,,,,,,,,) = liqMarketSC.auctions(0);
        assertEq(owner, LP_SELLER);
    }

    function test_startAuction_ShouldAddAuctionId() public useSeller {
        uint256 auctionId = liqMarketSC.nextAuctionId();
        vm.expectEmit(true, true, false, true);
        emit AuctionStarted(auctionId, LP_SELLER, LP_TOKEN, 0, 1, 10, 1, 10, true);
        liqMarketSC.startAuction(LP_TOKEN, 0, 1, 10, 1, 10, true);
    }

    function test_startAuction_ShouldIncreaseAuctionId() public useSeller {
        uint256 nextAuctionIdBefore = liqMarketSC.nextAuctionId();
        liqMarketSC.startAuction(LP_TOKEN, 0, 1, 10, 1, 10, true);
        uint256 nextAuctionIdAfter = liqMarketSC.nextAuctionId();
        assertEq(nextAuctionIdBefore, nextAuctionIdAfter - 1);
    }

    /////////////////////
    //activateAuction///
    ///////////////////

    function test_activateAuction_GivenAuctionIsActiveTrue_Revert() public {
        liqMarketSC.startAuction(LP_TOKEN, 0, 1, 10, 1, 10, true);
        liqMarketSC.activateAuction(0);
        (,,,,,,,,, bool isActive,,) = liqMarketSC.auctions(0);
        assertEq(isActive, true);
        vm.expectRevert("Auction already active");
        liqMarketSC.activateAuction(0);
    }

    function test_activateAuction_GivenAuctionOwnerEqZeroAddress_Revert() public useBorrower {
        vm.expectRevert("Auction is empty");
        liqMarketSC.activateAuction(1);
    }

    function test_activateAuction_WhenCheckLiquidityOwnerFalse_Revert() public {
        liqMarketSC.startAuction(LP_TOKEN, 0, 1, 10, 1, 10, true);
        utils_setUnsuccessfulPath();
        vm.expectRevert("Contract does not owner of this liquidity");
        liqMarketSC.activateAuction(0);
    }

    function test_activateAuction_ShouldSetIsActiveToTrue() public {
        liqMarketSC.startAuction(LP_TOKEN, 0, 1, 10, 1, 10, true);
        liqMarketSC.activateAuction(0);
        (,,,,,,,,, bool isActive,,) = liqMarketSC.auctions(0);
        assertEq(isActive, true);
    }

    function test_activateAuction_ShouldSetAuctionStartTime() public {
        liqMarketSC.startAuction(LP_TOKEN, 0, 1, 10, 1, 10, true);
        liqMarketSC.activateAuction(0);
        (,,,,,,,, uint256 startTime,,,) = liqMarketSC.auctions(0);
        assertEq(startTime, block.timestamp);
    }

    function test_activateAuction_ShouldEmitEvent() public useSeller {
        uint256 auctionId = liqMarketSC.nextAuctionId();
        liqMarketSC.startAuction(LP_TOKEN, 0, 1, 10, 1, 10, true);
        vm.expectEmit(true, true, false, true);
        emit AuctionActivated(auctionId, LP_SELLER);
        liqMarketSC.activateAuction(0);
    }

    /////////////////////
    //immediatelyBuy///
    ///////////////////
    function test_immediatelyBuy_GivenImmediatelySellFalse_Revert() public {
        liqMarketSC.startAuction(LP_TOKEN, 0, 1, 10, 1, 10, false);
        liqMarketSC.activateAuction(0);
        vm.expectRevert("Immediately selling is disabled for this lottery");
        liqMarketSC.immediatelyBuy(0);
    }

    function test_immediatelyBuy_GivenAuctionOwnerEqCaller_Revert() public useSeller {
        liqMarketSC.startAuction(LP_TOKEN, 0, 1, 10, 1, 10, true);
        liqMarketSC.activateAuction(0);
        vm.expectRevert("Sender is auction owner");
        liqMarketSC.immediatelyBuy(0);
    }

    function test_immediatelyBuy_WhenNotEnoughEth_Revert() public {
        vm.startPrank(LP_SELLER);
        liqMarketSC.startAuction(LP_TOKEN, 0, 1, 10, 1, 10, true);
        liqMarketSC.activateAuction(0);
        vm.startPrank(LP_BUYER);
        vm.expectRevert("Insuffitient payable amount");
        liqMarketSC.immediatelyBuy{value: 9}(0);
    }

    function test_immediatelyBuy_AuctionNotActivated_Revert() public {
        vm.startPrank(LP_SELLER);
        liqMarketSC.startAuction(LP_TOKEN, 0, 1, 10, 1, 10, true);
        vm.startPrank(LP_BUYER);
        vm.expectRevert("Auction inactive");
        liqMarketSC.immediatelyBuy{value: 10}(0);
    }

    function test_immediatelyBuy_AuctionEnded_Revert() public {
        vm.startPrank(LP_SELLER);
        liqMarketSC.startAuction(LP_TOKEN, 0, 1, 10, 1, 10, true);
        liqMarketSC.activateAuction(0);
        vm.warp(100);
        vm.startPrank(LP_BUYER);
        vm.expectRevert("Auction inactive");
        liqMarketSC.immediatelyBuy{value: 10}(0);
    }

    function test_immediatelyBuy_AuctionAlredyFinishedImmediately_Revert() public {
        vm.startPrank(LP_SELLER);
        liqMarketSC.startAuction(LP_TOKEN, 0, 1, 10, 1, 10, true);
        liqMarketSC.activateAuction(0);
        vm.startPrank(LP_BUYER);
        liqMarketSC.immediatelyBuy{value: 10}(0);
        vm.expectRevert("Auction inactive");
        liqMarketSC.immediatelyBuy{value: 10}(0);
    }

    function test_makeBid_givenAuctionIsNotActive_Revert() public useBorrower {
        liqMarketSC.startAuction(LP_TOKEN, 0, 1, 10, 1, 10, true);
        vm.expectRevert("Auction inactive");
        liqMarketSC.makeBid(0);
    }

    function test_makeBid_givenAuctionOwnerEqToCaller_Revert() public useBorrower {
        liqMarketSC.startAuction(LP_TOKEN, 0, 1, 10, 1, 10, true);
        liqMarketSC.activateAuction(0);
        vm.expectRevert("Sender is auction owner");
        liqMarketSC.makeBid(0);
    }

    function test_makeBid_WhenEthValueNotEnough_Revert() public {
        vm.startPrank(LP_SELLER);
        liqMarketSC.startAuction(LP_TOKEN, 0, 0, 10, 2, 10, true);
        liqMarketSC.activateAuction(0);
        vm.startPrank(LP_BUYER);
        vm.expectRevert("Bid must be greater than previous + bidStep");
        liqMarketSC.makeBid{value: 1}(0);
    }

    function test_makeBid_ShouldSetCallerBid() public {
        vm.startPrank(LP_SELLER);
        liqMarketSC.startAuction(LP_TOKEN, 0, 0, 10, 1, 10, true);
        liqMarketSC.activateAuction(0);
        vm.startPrank(LP_BUYER);
        liqMarketSC.makeBid{value: 1}(0);
        uint256 userBid = liqMarketSC.bids(0, LP_BUYER);
        assertEq(userBid, 1);
    }

    function test_makeBid_ShouldSetHighestBidOwner() public {
        vm.startPrank(LP_SELLER);
        liqMarketSC.startAuction(LP_TOKEN, 0, 0, 10, 1, 10, true);
        liqMarketSC.activateAuction(0);
        vm.startPrank(LP_BUYER);
        liqMarketSC.makeBid{value: 1}(0);
        (, address highestBidOwner,,,,,,,,,,) = liqMarketSC.auctions(0);
        assertEq(highestBidOwner, LP_BUYER);
    }

    function test_makeBid_ItShouldEmitEvent() public {
        vm.startPrank(LP_SELLER);
        uint256 auctionId = liqMarketSC.nextAuctionId();
        liqMarketSC.startAuction(LP_TOKEN, 0, 0, 10, 1, 10, true);
        liqMarketSC.activateAuction(0);
        vm.startPrank(LP_BUYER);
        vm.expectEmit(true, true, false, true);
        emit BidMade(auctionId, LP_BUYER, 1, block.timestamp);
        liqMarketSC.makeBid{value: 1}(0);
    }

    //////////////////////////////
    //withdrawAuctionLiquidity///
    ////////////////////////////
    //test should work but it's not because there is high vulnerability in the codebase
    function test_withdrawAuctionLiquidity_AuctionHighestBidOwnerNotEqZeroAddress_Revert() public {
        vm.startPrank(LP_SELLER);
        liqMarketSC.startAuction(LP_TOKEN, 0, 0, 10, 1, 10, true);
        liqMarketSC.activateAuction(0);
        vm.startPrank(LP_BUYER);
        liqMarketSC.makeBid{value: 1}(0);
        vm.startPrank(LP_BUYER_2);
        liqMarketSC.makeBid{value: 2}(0);
        vm.warp(100);
        vm.startPrank(LP_SELLER);
        liqMarketSC.withdrawAuctionLiquidity(0);
        vm.expectRevert("Not claimable");
        liqMarketSC.claimAuctionReward(0);
    }

    function test_withdrawAuctionLiquidity_AuctionStillActive_Revert() public {
        vm.startPrank(LP_SELLER);
        liqMarketSC.startAuction(LP_TOKEN, 0, 0, 10, 1, 10, true);
        liqMarketSC.activateAuction(0);
        vm.startPrank(LP_BUYER);
        liqMarketSC.makeBid{value: 1}(0);
        vm.startPrank(LP_BUYER_2);
        liqMarketSC.makeBid{value: 2}(0);
        vm.startPrank(LP_SELLER);
        vm.expectRevert("Auction is active yet");
        liqMarketSC.withdrawAuctionLiquidity(0);
    }

    function test_withdrawAuctionLiquidity_CallerIsNotOwner_Revert() public {
        vm.startPrank(LP_SELLER);
        liqMarketSC.startAuction(LP_TOKEN, 0, 0, 10, 1, 10, true);
        liqMarketSC.activateAuction(0);
        vm.startPrank(LP_BUYER);
        liqMarketSC.makeBid{value: 1}(0);
        vm.startPrank(LP_BUYER_2);
        liqMarketSC.makeBid{value: 2}(0);
        vm.warp(100);
        vm.startPrank(LP_BUYER_2);
        vm.expectRevert("Caller is not auction owner");
        liqMarketSC.withdrawAuctionLiquidity(0);
    }

    //////////////////
    //claimAuction///
    ////////////////

    function test_claimAuction_AuctionStillActive_Revert() public {
        vm.startPrank(LP_SELLER);
        liqMarketSC.startAuction(LP_TOKEN, 0, 0, 10, 1, 10, true);
        liqMarketSC.activateAuction(0);
        vm.startPrank(LP_BUYER);
        liqMarketSC.makeBid{value: 1}(0);
        vm.startPrank(LP_BUYER_2);
        liqMarketSC.makeBid{value: 2}(0);
        vm.startPrank(LP_BUYER);
        vm.expectRevert("Auction is active yet");
        liqMarketSC.claimAuction(0);
    }

    function test_claimAuction_AuctionIsFinishedImmediatelyTrue_Revert() public {
        vm.startPrank(LP_SELLER);
        liqMarketSC.startAuction(LP_TOKEN, 0, 1, 10, 1, 10, true);
        liqMarketSC.activateAuction(0);
        vm.startPrank(LP_BUYER);
        liqMarketSC.immediatelyBuy{value: 10}(0);
        vm.expectRevert("Not eligible for claim");
        liqMarketSC.claimAuction(0);
    }

    function test_claimAuction_CallerIsNotHighestBidOwner_Revert() public {
        vm.startPrank(LP_SELLER);
        liqMarketSC.startAuction(LP_TOKEN, 0, 0, 10, 1, 10, true);
        liqMarketSC.activateAuction(0);
        vm.startPrank(LP_BUYER);
        liqMarketSC.makeBid{value: 1}(0);
        vm.startPrank(LP_BUYER_2);
        liqMarketSC.makeBid{value: 2}(0);
        vm.warp(100);
        vm.startPrank(LP_BUYER);
        vm.expectRevert("Not eligible for claim");
        liqMarketSC.claimAuction(0);
    }

    function test_claimAuction_ShouldEmitEvent() public {
        vm.startPrank(LP_SELLER);
        uint256 auctionId = liqMarketSC.nextAuctionId();
        liqMarketSC.startAuction(LP_TOKEN, 0, 0, 10, 1, 10, true);
        liqMarketSC.activateAuction(0);
        vm.startPrank(LP_BUYER);
        liqMarketSC.makeBid{value: 1}(0);
        vm.startPrank(LP_BUYER_2);
        liqMarketSC.makeBid{value: 2}(0);
        vm.warp(100);
        vm.startPrank(LP_BUYER_2);
        vm.expectEmit(true, true, false, true);
        emit AuctionWon(auctionId, LP_BUYER_2);
        liqMarketSC.claimAuction(0);
    }

    ////////////////////////
    //claimAuctionReward///
    //////////////////////

    function test_claimAuctionReward_AuctionIsFinishedImmediatelyTrue_Revert() public {
        vm.startPrank(LP_SELLER);
        liqMarketSC.startAuction(LP_TOKEN, 0, 1, 10, 1, 10, true);
        liqMarketSC.activateAuction(0);
        vm.startPrank(LP_BUYER);
        liqMarketSC.immediatelyBuy{value: 10}(0);
        vm.warp(100);
        vm.startPrank(LP_SELLER);
        vm.expectRevert("Auction active yet");
        liqMarketSC.claimAuctionReward(0);
    }

    function test_claimAuctionReward_AuctionDurationNotExpired_Revert() public {
        vm.startPrank(LP_SELLER);
        liqMarketSC.startAuction(LP_TOKEN, 0, 1, 10, 1, 10, true);
        liqMarketSC.activateAuction(0);
        vm.startPrank(LP_SELLER);
        vm.expectRevert("Auction active yet");
        liqMarketSC.claimAuctionReward(0);
    }

    function test_claimAuctionReward_GivenAuctionOwnerIsNotEqCaller_Revert() public {
        vm.startPrank(LP_SELLER);
        liqMarketSC.startAuction(LP_TOKEN, 0, 1, 10, 1, 10, true);
        liqMarketSC.activateAuction(0);
        vm.warp(100);
        vm.startPrank(RANDOMGUY);
        vm.expectRevert("Not eligible for claim");
        liqMarketSC.claimAuctionReward(0);
    }

    function test_claimAuctionReward_TransferFeeFailed_Revert() public {
        vm.startPrank(LP_SELLER);
        liqMarketSCBadReceiver.startAuction(LP_TOKEN, 0, 1, 10, 1, 10, true);
        liqMarketSCBadReceiver.activateAuction(0);
        vm.warp(100);
        vm.expectRevert("Failed to send fee");
        liqMarketSCBadReceiver.claimAuctionReward(0);
    }

    function test_claimAuctionReward_TransferToOwnerFailed_Revert() public {
        liqMarketSC.startAuction(LP_TOKEN, 0, 1, 10, 1, 10, true);
        liqMarketSC.activateAuction(0);
        vm.warp(100);
        vm.expectRevert("Withdraw failed");
        liqMarketSC.claimAuctionReward(0);
    }

    function test_claimAuctionReward_ShouldEmitEvent() public {
        vm.startPrank(LP_SELLER);
        uint256 auctionId = liqMarketSC.nextAuctionId();
        liqMarketSC.startAuction(LP_TOKEN, 0, 1, 10, 1, 10, true);
        liqMarketSC.activateAuction(0);
        vm.startPrank(LP_BUYER);
        liqMarketSC.makeBid{value: 1}(0);
        vm.warp(100);
        vm.startPrank(LP_SELLER);
        vm.expectEmit(true, true, false, true);
        emit AuctionRewardClaimed(auctionId, LP_SELLER, 1, block.timestamp);
        liqMarketSC.claimAuctionReward(0);
    }

    // function test_claimAuctionReward_WhenNoBets_Revert() public {
    // vm.startPrank(LP_SELLER);
    // liqMarketSC.startAuction(LP_TOKEN, 0, 1, 10, 1, 10, true);
    // liqMarketSC.activateAuction(0);
    // vm.warp(100);
    // vm.expectRevert("No bets to withdraw");
    // liqMarketSC.claimAuctionReward(0);
    // }

    ////////////////////////
    //withdrawBid///
    //////////////////////

    function test_withdrawBid_AuctionHighestBidOwnerEqToCaller_Revert() public {
        vm.startPrank(LP_SELLER);
        liqMarketSC.startAuction(LP_TOKEN, 0, 0, 10, 1, 10, true);
        liqMarketSC.activateAuction(0);
        vm.startPrank(LP_BUYER);
        liqMarketSC.makeBid{value: 1}(0);
        vm.startPrank(LP_BUYER_2);
        liqMarketSC.makeBid{value: 2}(0);
        vm.warp(100);
        vm.expectRevert("No eligible to withdraw");
        liqMarketSC.withdrawBid(0);
    }

    function test_withdrawBid_BidAmountEqToZero_Revert() public {
        vm.startPrank(LP_SELLER);
        liqMarketSC.startAuction(LP_TOKEN, 0, 0, 10, 0, 10, true);
        liqMarketSC.activateAuction(0);
        vm.startPrank(LP_BUYER);
        liqMarketSC.makeBid{value: 0}(0);
        vm.startPrank(LP_BUYER_2);
        liqMarketSC.makeBid{value: 2}(0);
        vm.warp(100);
        vm.startPrank(LP_BUYER);
        vm.expectRevert("No eligible to withdraw");
        liqMarketSC.withdrawBid(0);
    }

    function test_withdrawBid_TransferToCallerFailed_Revert() public {
        vm.startPrank(LP_SELLER);
        liqMarketSC.startAuction(LP_TOKEN, 0, 0, 10, 0, 10, true);
        liqMarketSC.activateAuction(0);
        vm.stopPrank();
        liqMarketSC.makeBid{value: 1}(0);
        vm.startPrank(LP_BUYER_2);
        liqMarketSC.makeBid{value: 2}(0);
        vm.warp(100);
        vm.stopPrank();
        vm.expectRevert("Withdraw failed");
        liqMarketSC.withdrawBid(0);
    }

    function test_withdrawBid_ShouldSetCallerBidToZero_AssertEq() public {
        vm.startPrank(LP_SELLER);
        liqMarketSC.startAuction(LP_TOKEN, 0, 0, 10, 0, 10, true);
        liqMarketSC.activateAuction(0);
        vm.startPrank(LP_BUYER);
        liqMarketSC.makeBid{value: 1}(0);
        vm.startPrank(LP_BUYER_2);
        liqMarketSC.makeBid{value: 2}(0);
        vm.warp(100);
        vm.startPrank(LP_BUYER);
        uint256 userBid = liqMarketSC.bids(0, LP_BUYER);
        assertEq(userBid, 1);
        liqMarketSC.withdrawBid(0);
        uint256 userBidAfter = liqMarketSC.bids(0, LP_BUYER);
        assertEq(userBidAfter, 0);
    }

    function test_withdrawBid_ShouldEmitEvent() public {
        vm.startPrank(LP_SELLER);
        uint256 auctionId = liqMarketSC.nextAuctionId();
        liqMarketSC.startAuction(LP_TOKEN, 0, 0, 10, 0, 10, true);
        liqMarketSC.activateAuction(0);
        vm.startPrank(LP_BUYER);
        liqMarketSC.makeBid{value: 1}(0);
        vm.startPrank(LP_BUYER_2);
        liqMarketSC.makeBid{value: 2}(0);
        vm.warp(100);
        vm.startPrank(LP_BUYER);
        uint256 userBid = liqMarketSC.bids(0, LP_BUYER);
        vm.expectEmit(true, true, false, true);
        emit BidWithdrawn(auctionId, LP_BUYER, userBid, block.timestamp);
        liqMarketSC.withdrawBid(0);
    }
}
