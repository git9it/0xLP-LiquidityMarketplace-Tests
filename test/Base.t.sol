

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
    address FEE_RECEIVER = makeAddr('feeReceiver'); //vm.addr(1234);
    address BORROWER = makeAddr('borrower');
    address LENDER = makeAddr('lender');
    address RANDOMGUY = makeAddr('randomGuy');
    
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

function test_repayLoan_ShouldSetIsRepaidTrueedit() public {
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

function test_startAuction_WhenAuctionDurationIsInvalid() public useBorrower {
vm.expectRevert("Duration must be greater than 0");
liqMarketSC.startAuction(LpTokenAddr, 0, 1, 10, 1, 0, true);

}

function test_startAuction_WhenCheckLiqudityOwnerFalse() public useBorrower {
utils_setUnsuccessfulPath();
vm.expectRevert("User does not owner of this lock");
liqMarketSC.startAuction(LpTokenAddr, 0, 1, 10, 1, 10, true);
}

function test_startAuction_WhenImeddiatelySellPriceIsInvalid() public useBorrower {
vm.expectRevert("imeddiatelySellPrice must be positive number");
liqMarketSC.startAuction(LpTokenAddr, 0, 1, 0, 1, 10, true);

}

}
