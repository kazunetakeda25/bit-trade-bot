pragma solidity 0.8.13;

import "./BaseTest.sol";

contract LockedManagedRewardTest is BaseTest {
    event NotifyReward(address indexed from, address indexed reward, uint256 epoch, uint256 amount);

    LockedManagedReward lockedManagedReward;
    uint256 mTokenId;

    function _setUp() public override {
        // ve
        VELO.approve(address(escrow), TOKEN_1);
        escrow.createLock(TOKEN_1, MAXTIME);
        vm.startPrank(address(owner2));
        VELO.approve(address(escrow), TOKEN_1);
        escrow.createLock(TOKEN_1, MAXTIME);
        vm.stopPrank();
        vm.startPrank(address(owner3));
        VELO.approve(address(escrow), TOKEN_1);
        escrow.createLock(TOKEN_1, MAXTIME);
        vm.stopPrank();

        vm.prank(address(governor));
        mTokenId = escrow.createManagedLockFor(address(owner4));
        lockedManagedReward = LockedManagedReward(escrow.managedToLocked(mTokenId));
        skip(1);
    }

    function testCannotNotifyRewardIfNotVotingEscrow() public {
        vm.prank(address(owner2));
        vm.expectRevert("LockedManagedReward: only voting escrow");
        lockedManagedReward.notifyRewardAmount(address(VELO), 0);
    }

    function testCannotNotifyRewardAmountIfNotEscrowToken() public {
        address token = address(new MockERC20("TEST", "TEST", 18));
        assertEq(voter.isWhitelistedToken(token), false);

        vm.prank(address(escrow));
        vm.expectRevert("LockedManagedReward: not escrow token");
        lockedManagedReward.notifyRewardAmount(token, TOKEN_1);
    }

    function testNotifyRewardAmount() public {
        VELO.approve(address(lockedManagedReward), TOKEN_1);
        uint256 pre = VELO.balanceOf(address(escrow));
        vm.prank(address(escrow));
        vm.expectEmit(true, false, false, true, address(lockedManagedReward));
        emit NotifyReward(address(escrow), address(VELO), 604800, TOKEN_1);
        lockedManagedReward.notifyRewardAmount(address(VELO), TOKEN_1);
        uint256 post = VELO.balanceOf(address(escrow));

        assertEq(lockedManagedReward.isReward(address(VELO)), true);
        assertEq(lockedManagedReward.tokenRewardsPerEpoch(address(VELO), 604800), TOKEN_1);
        assertEq(pre - post, TOKEN_1);
        assertEq(VELO.balanceOf(address(lockedManagedReward)), TOKEN_1);

        skip(1 hours);

        VELO.approve(address(lockedManagedReward), TOKEN_1 * 2);
        pre = VELO.balanceOf(address(escrow));
        vm.prank(address(escrow));
        vm.expectEmit(true, false, false, true, address(lockedManagedReward));
        emit NotifyReward(address(escrow), address(VELO), 604800, TOKEN_1 * 2);
        lockedManagedReward.notifyRewardAmount(address(VELO), TOKEN_1 * 2);
        post = VELO.balanceOf(address(escrow));

        assertEq(lockedManagedReward.tokenRewardsPerEpoch(address(VELO), 604800), TOKEN_1 * 3);
        assertEq(pre - post, TOKEN_1 * 2);
        assertEq(VELO.balanceOf(address(lockedManagedReward)), TOKEN_1 * 3);
    }

    function testCannotGetRewardIfNotSingleToken() public {
        skip(1 weeks / 2);

        escrow.depositManaged(1, mTokenId);
        _addLockedReward(TOKEN_1);

        skipToNextEpoch(1);

        address[] memory rewards = new address[](2);
        rewards[0] = address(VELO);
        rewards[1] = address(WETH);

        vm.prank(address(escrow));
        vm.expectRevert("LockedManagedReward: can only claim single token");
        lockedManagedReward.getReward(1, rewards);
    }

    function testCannotGetRewardIfNotEscrowToken() public {
        skip(1 weeks / 2);

        address token = address(new MockERC20("TEST", "TEST", 18));
        address[] memory rewards = new address[](1);
        rewards[0] = token;

        vm.prank(address(escrow));
        vm.expectRevert("LockedManagedReward: can only claim escrow token");
        lockedManagedReward.getReward(1, rewards);
    }

    function testCannotGetRewardIfNotVotingEscrow() public {
        skip(1 weeks / 2);

        escrow.depositManaged(1, mTokenId);
        _addLockedReward(TOKEN_1);

        skipToNextEpoch(1);

        address[] memory rewards = new address[](1);
        rewards[0] = address(VELO);

        vm.prank(address(owner2));
        vm.expectRevert("LockedManagedReward: not voting escrow");
        lockedManagedReward.getReward(1, rewards);
    }

    function testGetReward() public {
        skip(1 weeks / 2);

        uint256 pre = escrow.lockedAmount(1);
        escrow.depositManaged(1, mTokenId);
        _addLockedReward(TOKEN_1);

        skipToNextEpoch(1);

        escrow.withdrawManaged(1);
        uint256 post = escrow.lockedAmount(1);

        assertEq(post - pre, TOKEN_1);
    }

    function _addLockedReward(uint256 _amount) internal {
        deal(address(VELO), address(distributor), _amount);
        vm.startPrank(address(distributor));
        VELO.approve(address(escrow), _amount);
        escrow.depositFor(mTokenId, _amount);
        vm.stopPrank();
    }
}
