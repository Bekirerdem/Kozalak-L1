// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {Test} from "forge-std/Test.sol";
import {KozaTreasury} from "../src/KozaTreasury.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

/**
 * @title TreasuryTest
 * @notice Smoke tests for KozaTreasury (Phase 1, Template 5) — TimelockController wrapper.
 * @dev Wrapper olduğu için TimelockController'ın iç mantığını yeniden test etmiyoruz;
 *      sadece constructor forwarding'in doğru rolleri/delay'i kurduğunu ve uçtan uca bir
 *      schedule→bekle→execute akışının çalıştığını doğruluyoruz (audited library trust).
 */
contract TreasuryTest is Test {
    KozaTreasury internal treasury;

    address internal admin;
    address internal proposer;
    address internal executor;
    address internal alice;
    address payable internal recipient;

    uint256 internal constant MIN_DELAY = 2 days;

    bytes32 internal PROPOSER_ROLE;
    bytes32 internal EXECUTOR_ROLE;
    bytes32 internal CANCELLER_ROLE;

    function setUp() public {
        admin = makeAddr("admin");
        proposer = makeAddr("proposer");
        executor = makeAddr("executor");
        alice = makeAddr("alice");
        recipient = payable(makeAddr("recipient"));

        address[] memory proposers = new address[](1);
        proposers[0] = proposer;
        address[] memory executors = new address[](1);
        executors[0] = executor;

        treasury = new KozaTreasury(MIN_DELAY, proposers, executors, admin);

        PROPOSER_ROLE = treasury.PROPOSER_ROLE();
        EXECUTOR_ROLE = treasury.EXECUTOR_ROLE();
        CANCELLER_ROLE = treasury.CANCELLER_ROLE();
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    function test_Constructor_SetsRolesAndDelay() public view {
        assertEq(treasury.getMinDelay(), MIN_DELAY);
        assertTrue(treasury.hasRole(PROPOSER_ROLE, proposer));
        assertTrue(treasury.hasRole(CANCELLER_ROLE, proposer));
        assertTrue(treasury.hasRole(EXECUTOR_ROLE, executor));
        assertTrue(treasury.hasRole(treasury.DEFAULT_ADMIN_ROLE(), admin));
        assertFalse(treasury.hasRole(PROPOSER_ROLE, alice));
    }

    function test_Constructor_AcceptsNativeFunds() public {
        vm.deal(address(this), 5 ether);
        (bool ok,) = address(treasury).call{value: 1 ether}("");
        assertTrue(ok);
        assertEq(address(treasury).balance, 1 ether);
    }

    /*//////////////////////////////////////////////////////////////
                          SCHEDULE → EXECUTE
    //////////////////////////////////////////////////////////////*/

    function test_ScheduleThenExecute_ReleasesFundsAfterDelay() public {
        vm.deal(address(treasury), 10 ether);

        bytes memory data = "";
        bytes32 predecessor = bytes32(0);
        bytes32 salt = bytes32(uint256(1));

        vm.prank(proposer);
        treasury.schedule(recipient, 3 ether, data, predecessor, salt, MIN_DELAY);

        // delay dolmadan execute → revert
        vm.expectRevert();
        vm.prank(executor);
        treasury.execute(recipient, 3 ether, data, predecessor, salt);

        // delay sonrası execute → fonlar serbest
        vm.warp(block.timestamp + MIN_DELAY);
        vm.prank(executor);
        treasury.execute(recipient, 3 ether, data, predecessor, salt);

        assertEq(recipient.balance, 3 ether);
        assertEq(address(treasury).balance, 7 ether);
    }

    function test_RevertWhen_ScheduleNotProposer() public {
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, PROPOSER_ROLE)
        );
        vm.prank(alice);
        treasury.schedule(recipient, 1 ether, "", bytes32(0), bytes32(0), MIN_DELAY);
    }

    function test_RevertWhen_ExecuteNotExecutor() public {
        vm.deal(address(treasury), 1 ether);
        vm.prank(proposer);
        treasury.schedule(recipient, 1 ether, "", bytes32(0), bytes32(0), MIN_DELAY);
        vm.warp(block.timestamp + MIN_DELAY);

        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, EXECUTOR_ROLE)
        );
        vm.prank(alice);
        treasury.execute(recipient, 1 ether, "", bytes32(0), bytes32(0));
    }

    function test_RevertWhen_ScheduleDelayBelowMinimum() public {
        vm.expectRevert();
        vm.prank(proposer);
        treasury.schedule(recipient, 1 ether, "", bytes32(0), bytes32(0), MIN_DELAY - 1);
    }

    /*//////////////////////////////////////////////////////////////
                                 CANCEL
    //////////////////////////////////////////////////////////////*/

    function test_Cancel_ByCanceller() public {
        bytes32 salt = bytes32(uint256(7));
        vm.prank(proposer);
        treasury.schedule(recipient, 1 ether, "", bytes32(0), salt, MIN_DELAY);

        bytes32 id = treasury.hashOperation(recipient, 1 ether, "", bytes32(0), salt);
        assertTrue(treasury.isOperationPending(id));

        vm.prank(proposer); // proposer also holds CANCELLER_ROLE
        treasury.cancel(id);
        assertFalse(treasury.isOperation(id));
    }

    function test_RevertWhen_CancelNotCanceller() public {
        bytes32 salt = bytes32(uint256(9));
        vm.prank(proposer);
        treasury.schedule(recipient, 1 ether, "", bytes32(0), salt, MIN_DELAY);
        bytes32 id = treasury.hashOperation(recipient, 1 ether, "", bytes32(0), salt);

        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, CANCELLER_ROLE)
        );
        vm.prank(alice);
        treasury.cancel(id);
    }
}
