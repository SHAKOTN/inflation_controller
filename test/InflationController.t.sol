// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/InflationController.sol";
import "./Fixture.t.sol";
import "./utils.sol";

contract TestInflationController is Fixture {
    InflationController public inflationController;

    IERC20 public constant GOLD =
        IERC20(0xbeFD5C25A59ef2C1316c5A4944931171F30Cd3E4);

    function setUp() public override {
        super.setUp();
        // Create a new InflationController with a start timestamp of now and a duration of 1 year
        inflationController = new InflationController(
            uint64(block.timestamp),
            // 3 years
            uint64(3 * 365 days)
        );
    }

    function testSetBeneficiaryHappy() public {
        inflationController.setBeneficiary(alice);
        assertEq(inflationController.beneficiary(), alice);
    }

    function testSetBeneficiaryFail() public {
        vm.startPrank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        inflationController.setBeneficiary(alice);
        vm.stopPrank();

        // Try to set the beneficiary to address(0)
        vm.expectRevert("InflationController: zero address");
        inflationController.setBeneficiary(address(0));
    }

    /// @dev Happy case when owner wants to sweep all timelocked tokens
    function testSweepTimelockHappy() public {
        uint256 arbitraryAmount = 1000e18;
        // Make sure timelock is 0 now
        (, uint256 timelockEnd) = inflationController.timelock();
        assertEq(timelockEnd, 0);
        // Make alice owner of the contract
        inflationController.transferOwnership(alice);

        // Generate some ERC20 tokens to sweep
        setStorage(
            address(inflationController),
            GOLD.balanceOf.selector,
            address(GOLD),
            arbitraryAmount
        );
        // Now alice wants to sweep the ERC20 tokens
        vm.prank(alice);
        inflationController.sweepTimelock(address(GOLD), alice);

        // Make sure timelock is set to 14 days from now
        (, timelockEnd) = inflationController.timelock();
        assertEq(
            timelockEnd,
            block.timestamp + inflationController.SWEEP_TIMELOCK_DURATION()
        );

        // Warp 14 days into the future
        vm.warp(
            block.timestamp + inflationController.SWEEP_TIMELOCK_DURATION()
        );

        // Now alice wants to sweep the ERC20 tokens
        vm.prank(alice);
        inflationController.sweepTimelock(address(GOLD), alice);

        // Make sure alice now has the ERC20 tokens
        assertEq(GOLD.balanceOf(alice), arbitraryAmount);
        // Make sure timelock is set to 0
        (, timelockEnd) = inflationController.timelock();
        assertEq(timelockEnd, 0);
    }

    /// @dev Happy case when owner wants to sweep all timelocked tokens multiple times
    function testSweepTimelockHappyMulTimes() public {
        uint256 arbitraryAmount = 1000e18;
        // Make sure timelock is 0 now
        (, uint256 timelockEnd) = inflationController.timelock();
        assertEq(timelockEnd, 0);
        // Make alice owner of the contract
        inflationController.transferOwnership(alice);

        // Generate some ERC20 tokens to sweep
        setStorage(
            address(inflationController),
            GOLD.balanceOf.selector,
            address(GOLD),
            arbitraryAmount
        );
        // Now alice wants to sweep the ERC20 tokens
        vm.prank(alice);
        inflationController.sweepTimelock(address(GOLD), alice);

        // Warp 14 days into the future
        vm.warp(
            block.timestamp + inflationController.SWEEP_TIMELOCK_DURATION()
        );

        // Now alice wants to sweep the ERC20 tokens
        vm.prank(alice);
        inflationController.sweepTimelock(address(GOLD), alice);

        // Make sure alice now has the ERC20 tokens
        assertEq(GOLD.balanceOf(alice), arbitraryAmount);

        // Now alice wants to sweep more ERC20 tokens, let's make sure Timelock struct is updated properly
        // Generate some ERC20 tokens to sweep
        setStorage(
            address(inflationController),
            GOLD.balanceOf.selector,
            address(GOLD),
            arbitraryAmount
        );
        // Now alice wants to sweep the ERC20 tokens
        vm.prank(alice);
        inflationController.sweepTimelock(address(GOLD), alice);
        // Warp another 14 days into the future
        vm.warp(
            block.timestamp + inflationController.SWEEP_TIMELOCK_DURATION()
        );
        // Now alice wants to sweep the ERC20 tokens again after 14 days. Let's make sure she has double the amount
        uint256 balanceSnapshot = GOLD.balanceOf(alice);
        vm.prank(alice);
        inflationController.sweepTimelock(address(GOLD), alice);
        assertEq(GOLD.balanceOf(alice), balanceSnapshot + arbitraryAmount);
    }

    /// @dev Check timelock reset by owner
    function testSweepTimeLockReset() public {
        uint256 arbitraryAmount = 1000e18;
        // Make sure timelock is 0 now
        (, uint256 timelockEnd) = inflationController.timelock();
        assertEq(timelockEnd, 0);
        // Make alice owner of the contract
        inflationController.transferOwnership(alice);

        // Generate some ERC20 tokens to sweep
        setStorage(
            address(inflationController),
            GOLD.balanceOf.selector,
            address(GOLD),
            arbitraryAmount
        );

        // Now alice wants to sweep the ERC20 tokens
        vm.prank(alice);
        inflationController.sweepTimelock(address(GOLD), alice);

        // Make sure timelock is set to 14 days from now
        (, timelockEnd) = inflationController.timelock();
        assertEq(
            timelockEnd,
            block.timestamp + inflationController.SWEEP_TIMELOCK_DURATION()
        );

        // Now reset timelock
        vm.prank(alice);
        inflationController.resetTimelock();

        // Make sure timelock is set to 0
        (address receiver, uint256 newTimelockEnd) = inflationController
            .timelock();
        assertEq(newTimelockEnd, 0);
    }

    /// @dev Case when owner tries to sweep timelocked tokens before timelock is over
    function testSweepTimelockTooEarly() public {
        uint256 arbitraryAmount = 1000e18;
        // Make sure timelock is 0 now
        (, uint256 timelockEnd) = inflationController.timelock();
        assertEq(timelockEnd, 0);
        // Make alice owner of the contract
        inflationController.transferOwnership(alice);

        // Generate some ERC20 tokens to sweep
        setStorage(
            address(inflationController),
            GOLD.balanceOf.selector,
            address(GOLD),
            arbitraryAmount
        );

        // Now alice wants to sweep the ERC20 tokens
        vm.prank(alice);
        inflationController.sweepTimelock(address(GOLD), alice);

        // Make sure timelock is set to 14 days from now
        (, timelockEnd) = inflationController.timelock();
        assertEq(
            timelockEnd,
            block.timestamp + inflationController.SWEEP_TIMELOCK_DURATION()
        );

        // Warp 13 days into the future
        vm.warp(
            block.timestamp +
                inflationController.SWEEP_TIMELOCK_DURATION() -
                1 days
        );

        // Now alice wants to sweep the ERC20 tokens
        vm.prank(alice);
        vm.expectRevert("InflationController: timelock not over");
        inflationController.sweepTimelock(address(GOLD), alice);

        // Make sure alice has no ERC20 tokens
        assertEq(GOLD.balanceOf(alice), 0);
        // Make sure timelock is not 0
        (, timelockEnd) = inflationController.timelock();
        assertNotEq(timelockEnd, 0);
    }

    /// @dev Case when owner tries to sweep timelocked tokens before timelock is over
    function testSweepTimelockReceiverChanged() public {
        // Make sure timelock is 0 now
        (, uint256 timelockEnd) = inflationController.timelock();
        assertEq(timelockEnd, 0);
        // Make alice owner of the contract
        inflationController.transferOwnership(alice);

        // Now alice wants to sweep the ERC20 tokens
        vm.prank(alice);
        inflationController.sweepTimelock(address(GOLD), alice);

        // Warp 13 days into the future
        vm.warp(
            block.timestamp +
                inflationController.SWEEP_TIMELOCK_DURATION() +
                1 days
        );

        // Now alice wants to sweep the ERC20 tokens
        vm.prank(alice);
        // Change the address of the receiver which should revert
        vm.expectRevert("InflationController: timelock receiver mismatch");
        inflationController.sweepTimelock(address(GOLD), bob);
    }

    /// @dev Test when owner tries to sweep non-protected tokens
    function testSweepTimelockNotProtectedToken() public {
        // Make alice owner of the contract
        inflationController.transferOwnership(alice);
        // Now alice wants to sweep the ERC20 tokens
        vm.startPrank(alice);
        vm.expectRevert("InflationController: not protected token");
        inflationController.sweepTimelock(address(BPT), alice);
        vm.stopPrank();
    }

    function testSweepNormal() public {
        uint256 arbitraryAmount = 1000e18;
        // Make alice owner of the contract
        inflationController.transferOwnership(alice);

        // Generate some ERC20 tokens to sweep
        setStorage(
            address(inflationController),
            BPT.balanceOf.selector,
            address(BPT),
            arbitraryAmount
        );
        // Sweep and check that alice has the ERC20 tokens
        vm.prank(alice);
        inflationController.sweep(address(BPT), alice);
        assertEq(BPT.balanceOf(alice), arbitraryAmount);
    }

    function testSweepFails() public {
        // Make alice owner of the contract
        inflationController.transferOwnership(alice);
        // Tries to sweep ERC20 tokens that are timelocked and fails
        vm.startPrank(alice);
        vm.expectRevert("InflationController: protected token");
        inflationController.sweep(address(GOLD), alice);
        vm.stopPrank();
    }

    function testsweepGasToken() public {
        uint256 aliceBalanceBefore = address(alice).balance;
        // Deal some eth to the contract
        uint256 arbitraryAmount = 1000e18;
        vm.deal(address(inflationController), 1000e18);
        // Make alice owner of the contract
        inflationController.transferOwnership(alice);
        vm.startPrank(alice);
        inflationController.sweepGasToken(payable(alice));
        vm.stopPrank();

        // Make sure alice has the eth
        assertEq(address(alice).balance - aliceBalanceBefore, arbitraryAmount);
    }
}
