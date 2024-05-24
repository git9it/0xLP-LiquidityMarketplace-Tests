

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
    uint256 ownerFee = 1000;
    address FEE_RECEIVER = makeAddr('feeReceiver');
    address BORROWER = makeAddr('borrower');
    address LENDER = makeAddr('lender');
    address RANDOMGUY = makeAddr('randomGuy');
    address LP_SELLER = makeAddr('lpSeller');
    address LP_BUYER = makeAddr('lpBuyer');
    address LP_BUYER_2 = makeAddr('lpBuyer2');
    
        bytes4 setUnsuccessfulPath = bytes4(keccak256("setUnsuccessfulPath()"));
        bytes4 setSuccessfulPath = bytes4(keccak256("setSuccessfulPath()"));


        address LpTokenAddr = makeAddr('LpTokenAddr');



    function setUp() public {

        liqLockMockSC = new LiqudityLockerMock();
        liqLockerSC = ILiquidityLocker(address(liqLockMockSC));

        liqMarketSC = new LiquidityMarketplace(
        liqLockerSC,
        ownerFee,
        FEE_RECEIVER
    );

            liqMarketSCBadReceiver = new LiquidityMarketplace(
        liqLockerSC,
        ownerFee,
        address(this)
    );

vm.deal(LENDER, 1 ether);
vm.deal(BORROWER, 1 ether);
vm.deal(LP_BUYER, 1 ether);
vm.deal(LP_BUYER_2, 1 ether);
    }


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

     (, , , , , address owner) = liqLockerSC.getUserLockForTokenAtIndex(
            address(this),
            address(0),
            0
        );

       assertNotEq(address(this), owner); 
    }

        function test_LiqLockerMockSuccessfulPath() public {

    utils_setSuccessfulPath();

     (, , , , , address owner) = liqLockerSC.getUserLockForTokenAtIndex(
            address(this),
            address(0),
            0
        );

       assertEq(address(this), owner); 
    }

    modifier useBorrower(){
        vm.startPrank(BORROWER);
        _;
        vm.stopPrank();
    }

        modifier useSeller(){
        vm.startPrank(LP_SELLER);
        _;
        vm.stopPrank();
    }

        modifier prankFrom(address user){
        vm.startPrank(user);
        _;
        vm.stopPrank();
    }

///////////////
//LOAN TESTS//
/////////////

///////////////////
//initializeDeal//
/////////////////
function test_WhenLoanDurationIsInvalid() public useBorrower {
vm.expectRevert("Loan duration must be greater than 0");
liqMarketSC.initializeDeal(LpTokenAddr, 0, 0, 0, 0);

}

function test_WhenCheckLiqudityOwnerFalse() public useBorrower {
utils_setUnsuccessfulPath();
vm.expectRevert("User does not owner of this lock");
liqMarketSC.initializeDeal(LpTokenAddr, 0, 0, 0, 1);
}

function test_WhenInterestRateIsInvalid() public useBorrower {
vm.expectRevert("interestRate must be greater than 0");
liqMarketSC.initializeDeal(LpTokenAddr, 0, 0, 0, 1);

}

function test_WhenDealAmountIsInvalid() public useBorrower {
vm.expectRevert("dealAmount must be greater than 0");
liqMarketSC.initializeDeal(LpTokenAddr, 0, 0, 1, 1);
}

function test_WhenDealAmountIsValidItShouldCreateDeal() public useBorrower {
liqMarketSC.initializeDeal(LpTokenAddr, 0, 1, 1, 1); 
(address borrower, , , , , , , , , ) = liqMarketSC.deals(0);
assertEq(borrower, BORROWER);
}

// function test_WhenDealAmountIsValidItShouldCreateEvent() public {

// liqMarketSC.initializeDeal(LpTokenAddr, 0, 1, 1, 1);

// (address borrower, , , , , , , , , ) = liqMarketSC.deals(0);

// assertEq(address(this), borrower);
// }

function test_WhenDealAmountIsValidItShouldAddDealId() public useBorrower{
liqMarketSC.initializeDeal(LpTokenAddr, 0, 1, 1, 1);
uint256[] memory userDeals = liqMarketSC.getUserDeals(BORROWER);
assertEq(userDeals.length, 1);
}

function test_WhenDealAmountIsValidItShouldIncreaseDealId() public useBorrower{
uint256 nextDealIdBefore = liqMarketSC.nextDealId();
liqMarketSC.initializeDeal(LpTokenAddr, 0, 1, 1, 1);
uint256 nextDealIdAfter = liqMarketSC.nextDealId();
assertEq(nextDealIdBefore, nextDealIdAfter-1);
}

///////////////////
//activateDeal////
/////////////////

function test_GivenDealBorrowerEqZeroAddress() public useBorrower{
vm.expectRevert("Deal is empty");
liqMarketSC.activateDeal(1);
}

function test_WhenCheckLiquidityOwnerFalse() public {
liqMarketSC.initializeDeal(LpTokenAddr, 0, 1, 1, 1);
utils_setUnsuccessfulPath();
vm.expectRevert("Contract does not owner of this liquidity");
liqMarketSC.activateDeal(0);
}

function test_WhenCheckLiquidityOwnerTrueItShouldSetActiveTrue() public useBorrower{
liqMarketSC.initializeDeal(LpTokenAddr, 0, 1, 1, 1);
liqMarketSC.activateDeal(0);
( , , , , , , , , ,bool isActive) = liqMarketSC.deals(0);
assertEq(isActive, true);
}

// function test_WhenCheckLiquidityOwnerTrueItShouldEmitEvent() public {
// liqMarketSC.initializeDeal(LpTokenAddr, 0, 1, 1, 1);
// liqMarketSC.activateDeal(0);
// }

///////////////////
//makeDeal////////
/////////////////
function test_givenDealIsNotActive() public useBorrower{
liqMarketSC.initializeDeal(LpTokenAddr, 0, 1, 1, 1);
vm.expectRevert("Deal inactive");
liqMarketSC.makeDeal(0);

}

function test_givenLenderNotEqZeroAddress() public {
vm.startPrank(BORROWER);
liqMarketSC.initializeDeal(LpTokenAddr, 0, 1, 1, 1);
liqMarketSC.activateDeal(0);
vm.startPrank(LENDER);
liqMarketSC.makeDeal{value:1}(0);
vm.expectRevert("Deal already has a lender");
liqMarketSC.makeDeal(0);
}
//why this test failed when prank from borrower?
function test_givenBorrowerEqCaller() public {
liqMarketSC.initializeDeal(LpTokenAddr, 0, 1, 1, 1);
liqMarketSC.activateDeal(0);
vm.expectRevert("Borrower cannot make loan for himself");
liqMarketSC.makeDeal{value:1}(0);

}

function test_whenMsgValueLessThanGivenDealAmount() public {
vm.startPrank(BORROWER);
liqMarketSC.initializeDeal(LpTokenAddr, 0, 2, 1, 1);
liqMarketSC.activateDeal(0);
vm.startPrank(LENDER);
vm.expectRevert("Insufficient funds");
liqMarketSC.makeDeal{value:1}(0);
}

function test_whenMsgValueEqItShouldSetDealLender() public {
vm.startPrank(BORROWER);
liqMarketSC.initializeDeal(LpTokenAddr, 0, 1, 1, 1);
liqMarketSC.activateDeal(0);
vm.startPrank(LENDER);
liqMarketSC.makeDeal{value:1}(0);
( , , , , , , ,address lenderFromDeals , , ) = liqMarketSC.deals(0);
assertEq(lenderFromDeals, LENDER);
}

function test_whenMsgValueEqItShouldRevertIfFeeTransferFailed() public {
vm.startPrank(BORROWER);
liqMarketSCBadReceiver.initializeDeal(LpTokenAddr, 0, 1, 1, 1);
liqMarketSCBadReceiver.activateDeal(0);
vm.stopPrank();
vm.expectRevert("Failed to send fee");
liqMarketSCBadReceiver.makeDeal{value:1}(0);
}

function test_whenMsgValueEqItShouldRevertIfBorrowerTransferFailed() public {
liqMarketSC.initializeDeal(LpTokenAddr, 0, 1, 1, 1);
liqMarketSC.activateDeal(0);
vm.startPrank(LENDER);
vm.expectRevert("Failed to send funds");
liqMarketSC.makeDeal{value:1}(0);
}

// function test_whenMsgValueEqItShouldEmitEvent() public {
// liqMarketSC.initializeDeal(LpTokenAddr, 0, 1, 1, 1);
// liqMarketSC.activateDeal(0);
// vm.startPrank(LenderAddr);
// liqMarketSC.makeDeal{value:1}(0);
// }

///////////////////
//cancelDeal///////
/////////////////

function test_whenCallerNotEqGivenBorrower() public {
vm.startPrank(BORROWER);
liqMarketSC.initializeDeal(LpTokenAddr, 0, 1, 1, 1);
liqMarketSC.activateDeal(0);
vm.startPrank(RANDOMGUY);
vm.expectRevert("Caller not lock owner");
liqMarketSC.cancelDeal(0);
}

function test_whenLenderNotEqZeroAddress() public {
vm.startPrank(BORROWER);
liqMarketSC.initializeDeal(LpTokenAddr, 0, 1, 1, 1);
liqMarketSC.activateDeal(0);
vm.startPrank(LENDER);
liqMarketSC.makeDeal{value:1}(0);
vm.startPrank(BORROWER);
vm.expectRevert("Cannot cancel processing deal");
liqMarketSC.cancelDeal(0);
}

function test_whenLenderNotEqZeroAddressItShouldDeleteDeal() public {
    vm.startPrank(BORROWER);
liqMarketSC.initializeDeal(LpTokenAddr, 0, 1, 1, 1);
liqMarketSC.activateDeal(0);
(address borrower , , , , , , , , ,bool isActive) = liqMarketSC.deals(0);
assertEq(borrower, BORROWER);
liqMarketSC.cancelDeal(0);
(borrower , , , , , , , , ,isActive) = liqMarketSC.deals(0);
assertNotEq(borrower, BORROWER);
}

///////////////////
//repayLoan///////
/////////////////

function test_repayLoan_GivenDealAlreadyPaid_Revert() public {
vm.startPrank(BORROWER);
liqMarketSC.initializeDeal(LpTokenAddr, 0, 2, 1, 1);
liqMarketSC.activateDeal(0);
vm.startPrank(LENDER);
liqMarketSC.makeDeal{value:2}(0);
vm.startPrank(BORROWER);
liqMarketSC.repayLoan{value:2}(0);
( , , , , , , , ,bool isRepaid, ) = liqMarketSC.deals(0);
assertEq(isRepaid, true);
vm.expectRevert("Deal already repaid");
liqMarketSC.repayLoan{value:2}(0);

}

function test_repayLoan_whenCallerNotEqGivenBorrower() public {
vm.startPrank(BORROWER);
liqMarketSC.initializeDeal(LpTokenAddr, 0, 1, 1, 1);
liqMarketSC.activateDeal(0);
vm.startPrank(LENDER);
liqMarketSC.makeDeal{value:1}(0);
vm.startPrank(RANDOMGUY);
vm.expectRevert("Sender is not a borrower");
liqMarketSC.repayLoan(0);
}

function test_repayLoan_whenNotEnoughEthValue_Revert() public {
vm.startPrank(BORROWER);
liqMarketSC.initializeDeal(LpTokenAddr, 0, 2, 1, 1);
liqMarketSC.activateDeal(0);
vm.startPrank(LENDER);
liqMarketSC.makeDeal{value:2}(0);
vm.startPrank(BORROWER);
vm.expectRevert("Insuffitient payable amount");
liqMarketSC.repayLoan{value:1}(0);
}

function test_repayLoan_ShouldSetIsRepaidTrue() public {
vm.startPrank(BORROWER);
liqMarketSC.initializeDeal(LpTokenAddr, 0, 2, 1, 1);
liqMarketSC.activateDeal(0);
vm.startPrank(LENDER);
liqMarketSC.makeDeal{value:2}(0);
vm.startPrank(BORROWER);
liqMarketSC.repayLoan{value:2}(0);
( , , , , , , , ,bool isRepaid, ) = liqMarketSC.deals(0);
assertEq(isRepaid, true);
}

function test_repayLoan_TransferToLenderFailed_Revert() public {
vm.startPrank(BORROWER);
liqMarketSC.initializeDeal(LpTokenAddr, 0, 2, 1, 1);
liqMarketSC.activateDeal(0);
vm.stopPrank();
liqMarketSC.makeDeal{value:2}(0);
vm.startPrank(BORROWER);
vm.expectRevert("Repay failed");
liqMarketSC.repayLoan{value:2}(0);
}
//given start time and loan duration is less than current timestamp_revert
//it should transfer locked LP ownership to caller
//it should emit DealMade event

////////////////////
//claimCollateral//
//////////////////

function test_claimCollateral_WhenCallerNotEqGivenLender_Revert() public {
vm.startPrank(BORROWER);
liqMarketSC.initializeDeal(LpTokenAddr, 0, 2, 1, 1);
liqMarketSC.activateDeal(0);
vm.startPrank(LENDER);
liqMarketSC.makeDeal{value:2}(0);
vm.startPrank(RANDOMGUY);
vm.expectRevert("Caller is not lender");
liqMarketSC.claimCollateral(0);
}

function test_claimCollateral_WhenDealStillActive_Revert() public {
vm.startPrank(BORROWER);
liqMarketSC.initializeDeal(LpTokenAddr, 0, 2, 1, 1);
liqMarketSC.activateDeal(0);
vm.startPrank(LENDER);
liqMarketSC.makeDeal{value:2}(0);
vm.expectRevert("Deal is active yet");
liqMarketSC.claimCollateral(0);
}

// function test_claimCollateral_WhenDealStillActive_RevertEd() public {
// vm.startPrank(BORROWER);
// liqMarketSC.initializeDeal(LpTokenAddr, 0, 2, 1, 1);
// liqMarketSC.activateDeal(0);
// vm.startPrank(LENDER);
// liqMarketSC.makeDeal{value:2}(0);
// vm.warp(200);
// //it should emit CollateralClaimed event
// liqMarketSC.claimCollateral(0);
// }

//////////////////
//AUCTION TESTS//
////////////////

//////////////////
//startAuction///
////////////////

function test_startAuction_WhenAuctionDurationIsInvalid() public {
vm.expectRevert("Duration must be greater than 0");
liqMarketSC.startAuction(LpTokenAddr, 0, 1, 10, 1, 0, true);
}

function test_startAuction_WhenImeddiatelySellPriceIsInvalid() public {
vm.expectRevert("imeddiatelySellPrice must be positive number");
liqMarketSC.startAuction(LpTokenAddr, 0, 1, 0, 1, 10, true);
}

function test_startAuction_WhenCheckLiqudityOwnerFalse() public {
utils_setUnsuccessfulPath();
vm.expectRevert("User does not owner of this lock");
liqMarketSC.startAuction(LpTokenAddr, 0, 1, 10, 1, 10, true);
}

function test_startAuction_ShouldCreateNewAuction() public useSeller {
liqMarketSC.startAuction(LpTokenAddr, 0, 1, 10, 1, 10, true);
( address owner, , , , , , , , , , , ) = liqMarketSC.auctions(0);
assertEq(owner, LP_SELLER);
}

//should emit event

function test_startAuction_ShouldAddAuctionId() public useSeller {
liqMarketSC.startAuction(LpTokenAddr, 0, 1, 10, 1, 10, true);
uint256[] memory userAuctions = liqMarketSC.getUserAuction(LP_SELLER);
assertEq(userAuctions.length, 1);
}

function test_startAuction_ShouldIncreaseAuctionId() public useSeller {
uint256 nextAuctionIdBefore = liqMarketSC.nextAuctionId();
liqMarketSC.startAuction(LpTokenAddr, 0, 1, 10, 1, 10, true);
uint256 nextAuctionIdAfter = liqMarketSC.nextAuctionId();
assertEq(nextAuctionIdBefore, nextAuctionIdAfter-1);
}

//given auction is active it should revert

/////////////////////
//activateAuction///
///////////////////
//name template
function test_activateAuction_GivenAuctionIsActiveTrue_Revert() public {
liqMarketSC.startAuction(LpTokenAddr, 0, 1, 10, 1, 10, true);
liqMarketSC.activateAuction(0);
( , , , , , , , , ,bool isActive , , ) = liqMarketSC.auctions(0);
assertEq(isActive, true);
vm.expectRevert("Auction already active");
liqMarketSC.activateAuction(0);
}

function test_activateAuction_GivenAuctionOwnerEqZeroAddress_Revert() public useBorrower{
vm.expectRevert("Auction is empty");
liqMarketSC.activateAuction(1);
}

function test_activateAuction_WhenCheckLiquidityOwnerFalse_Revert() public {
liqMarketSC.startAuction(LpTokenAddr, 0, 1, 10, 1, 10, true);
utils_setUnsuccessfulPath();
vm.expectRevert("Contract does not owner of this liquidity");
liqMarketSC.activateAuction(0);
}

function test_activateAuction_ShouldSetIsActiveToTrue() public {
liqMarketSC.startAuction(LpTokenAddr, 0, 1, 10, 1, 10, true);
liqMarketSC.activateAuction(0);
( , , , , , , , , ,bool isActive , , ) = liqMarketSC.auctions(0);
assertEq(isActive, true);
}

function test_activateAuction_ShouldSetAuctionStartTime() public {
liqMarketSC.startAuction(LpTokenAddr, 0, 1, 10, 1, 10, true);
liqMarketSC.activateAuction(0);
( , , , , , , , ,uint256 startTime , , , ) = liqMarketSC.auctions(0);
assertEq(startTime, block.timestamp);
}

//it should emit the AuctionActivated event

/////////////////////
//immediatelyBuy///
///////////////////
function test_immediatelyBuy_GivenImmediatelySellFalse_Revert() public {
liqMarketSC.startAuction(LpTokenAddr, 0, 1, 10, 1, 10, false);
liqMarketSC.activateAuction(0);
vm.expectRevert("Immediately selling is disabled for this lottery");
liqMarketSC.immediatelyBuy(0);
}

function test_immediatelyBuy_GivenAuctionOwnerEqCaller_Revert() public useSeller {
liqMarketSC.startAuction(LpTokenAddr, 0, 1, 10, 1, 10, true);
liqMarketSC.activateAuction(0);
vm.expectRevert("Sender is auction owner");
liqMarketSC.immediatelyBuy(0);
}

function test_immediatelyBuy_WhenNotEnoughEth_Revert() public {
vm.startPrank(LP_SELLER);    
liqMarketSC.startAuction(LpTokenAddr, 0, 1, 10, 1, 10, true);
liqMarketSC.activateAuction(0);
vm.startPrank(LP_BUYER);
vm.expectRevert("Insuffitient payable amount");
liqMarketSC.immediatelyBuy{value:9}(0);
}

function test_immediatelyBuy_AuctionNotActivated_Revert() public {
vm.startPrank(LP_SELLER);    
liqMarketSC.startAuction(LpTokenAddr, 0, 1, 10, 1, 10, true);
vm.startPrank(LP_BUYER);
vm.expectRevert("Auction inactive");
liqMarketSC.immediatelyBuy{value:10}(0);
}

function test_immediatelyBuy_AuctionEnded_Revert() public {
vm.startPrank(LP_SELLER);    
liqMarketSC.startAuction(LpTokenAddr, 0, 1, 10, 1, 10, true);
liqMarketSC.activateAuction(0);
vm.warp(100);
vm.startPrank(LP_BUYER);
vm.expectRevert("Auction inactive");
liqMarketSC.immediatelyBuy{value:10}(0);
}

function test_immediatelyBuy_AuctionAlredyFinishedImmediately_Revert() public {
vm.startPrank(LP_SELLER);    
liqMarketSC.startAuction(LpTokenAddr, 0, 1, 10, 1, 10, true);
liqMarketSC.activateAuction(0);
vm.startPrank(LP_BUYER);
liqMarketSC.immediatelyBuy{value:10}(0);
vm.expectRevert("Auction inactive");
liqMarketSC.immediatelyBuy{value:10}(0);
}


//Given the immediatelySell statement is false
// ....
// ....

/////////////
//makeBid///
///////////

//given auction.isFinishedImmediately is true

function test_makeBid_givenAuctionIsNotActive_Revert() public useBorrower{
liqMarketSC.startAuction(LpTokenAddr, 0, 1, 10, 1, 10, true);
vm.expectRevert("Auction inactive");
liqMarketSC.makeBid(0);

}

//given auction.startTime and auction.duration is less than current timestamp

function test_makeBid_givenAuctionOwnerEqToCaller_Revert() public useBorrower{
liqMarketSC.startAuction(LpTokenAddr, 0, 1, 10, 1, 10, true);
liqMarketSC.activateAuction(0);
vm.expectRevert("Sender is auction owner");
liqMarketSC.makeBid(0);

}

function test_makeBid_WhenEthValueNotEnough_Revert() public {
vm.startPrank(LP_SELLER);
liqMarketSC.startAuction(LpTokenAddr, 0, 0, 10, 2, 10, true);
liqMarketSC.activateAuction(0);
vm.startPrank(LP_BUYER);
vm.expectRevert("Bid must be greater than previous + bidStep");
liqMarketSC.makeBid{value:1}(0);

}

function test_makeBid_ShouldSetCallerBid() public {
vm.startPrank(LP_SELLER);
liqMarketSC.startAuction(LpTokenAddr, 0, 0, 10, 1, 10, true);
liqMarketSC.activateAuction(0);
vm.startPrank(LP_BUYER);
liqMarketSC.makeBid{value:1}(0);
uint256 userBid = liqMarketSC.bids(0, LP_BUYER);
assertEq(userBid, 1);
}

function test_makeBid_ShouldSetHighestBidOwner() public {
vm.startPrank(LP_SELLER);
liqMarketSC.startAuction(LpTokenAddr, 0, 0, 10, 1, 10, true);
liqMarketSC.activateAuction(0);
vm.startPrank(LP_BUYER);
liqMarketSC.makeBid{value:1}(0);
( ,address  highestBidOwner, , , , , , , , , , ) = liqMarketSC.auctions(0);
assertEq(highestBidOwner, LP_BUYER);
}

// it should emit the BidMade event


//////////////////////////////
//withdrawAuctionLiquidity///
////////////////////////////
//test should work but it's not becouse vuln in the codebase 
// function test_withdrawAuctionLiquidity_AuctionHighestBidOwnerNotEqZeroAddress_Revert() public {
// vm.startPrank(LP_SELLER);
// liqMarketSC.startAuction(LpTokenAddr, 0, 0, 10, 1, 10, true);
// liqMarketSC.activateAuction(0);
// vm.startPrank(LP_BUYER);
// liqMarketSC.makeBid{value:1}(0);
// vm.startPrank(LP_BUYER_2);
// liqMarketSC.makeBid{value:2}(0);
// vm.warp(100);
// vm.startPrank(LP_SELLER);
// vm.expectRevert("Not claimable");
// liqMarketSC.withdrawAuctionLiquidity(0);
// }

function test_withdrawAuctionLiquidity_AuctionStillActive_Revert() public {
vm.startPrank(LP_SELLER);
liqMarketSC.startAuction(LpTokenAddr, 0, 0, 10, 1, 10, true);
liqMarketSC.activateAuction(0);
vm.startPrank(LP_BUYER);
liqMarketSC.makeBid{value:1}(0);
vm.startPrank(LP_BUYER_2);
liqMarketSC.makeBid{value:2}(0);
vm.startPrank(LP_SELLER);
vm.expectRevert("Auction is active yet");
liqMarketSC.withdrawAuctionLiquidity(0);
}

function test_withdrawAuctionLiquidity_CallerIsNotOwner_Revert() public {
vm.startPrank(LP_SELLER);
liqMarketSC.startAuction(LpTokenAddr, 0, 0, 10, 1, 10, true);
liqMarketSC.activateAuction(0);
vm.startPrank(LP_BUYER);
liqMarketSC.makeBid{value:1}(0);
vm.startPrank(LP_BUYER_2);
liqMarketSC.makeBid{value:2}(0);
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
liqMarketSC.startAuction(LpTokenAddr, 0, 0, 10, 1, 10, true);
liqMarketSC.activateAuction(0);
vm.startPrank(LP_BUYER);
liqMarketSC.makeBid{value:1}(0);
vm.startPrank(LP_BUYER_2);
liqMarketSC.makeBid{value:2}(0);
vm.startPrank(LP_BUYER);
vm.expectRevert("Auction is active yet");
liqMarketSC.claimAuction(0);
}

function test_claimAuction_AuctionIsFinishedImmediatelyTrue_Revert() public {
vm.startPrank(LP_SELLER);    
liqMarketSC.startAuction(LpTokenAddr, 0, 1, 10, 1, 10, true);
liqMarketSC.activateAuction(0);
vm.startPrank(LP_BUYER);
liqMarketSC.immediatelyBuy{value:10}(0);
vm.expectRevert("Not eligible for claim");
liqMarketSC.claimAuction(0);
}

function test_claimAuction_CallerIsNotHighestBidOwner_Revert() public {
vm.startPrank(LP_SELLER);
liqMarketSC.startAuction(LpTokenAddr, 0, 0, 10, 1, 10, true);
liqMarketSC.activateAuction(0);
vm.startPrank(LP_BUYER);
liqMarketSC.makeBid{value:1}(0);
vm.startPrank(LP_BUYER_2);
liqMarketSC.makeBid{value:2}(0);
vm.warp(100);
vm.startPrank(LP_BUYER);
vm.expectRevert("Not eligible for claim");
liqMarketSC.claimAuction(0);
}


}
