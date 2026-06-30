// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {Test} from "forge-std/Test.sol";
import {DeployTreasury} from "../script/DeployTreasury.s.sol";
import {KozaTreasury} from "../src/KozaTreasury.sol";

/**
 * @title DeployTreasuryTest
 * @notice Smoke tests for the Treasury deploy script. Calls `deploy(...)` directly;
 *         env-driven `run()` exercised on Fuji integration.
 */
contract DeployTreasuryTest is Test {
    function test_Deploy_SetsDelayAndRoles() public {
        DeployTreasury deployer = new DeployTreasury();
        address broadcaster = makeAddr("broadcaster");
        address admin = makeAddr("admin");

        address[] memory proposers = new address[](1);
        proposers[0] = makeAddr("proposer");
        address[] memory executors = new address[](1);
        executors[0] = makeAddr("executor");

        (KozaTreasury treasury, address returnedDeployer) =
            deployer.deploy(48 hours, proposers, executors, admin, broadcaster);

        assertEq(treasury.getMinDelay(), 48 hours);
        assertTrue(treasury.hasRole(treasury.PROPOSER_ROLE(), proposers[0]));
        assertTrue(treasury.hasRole(treasury.CANCELLER_ROLE(), proposers[0]));
        assertTrue(treasury.hasRole(treasury.EXECUTOR_ROLE(), executors[0]));
        assertTrue(treasury.hasRole(treasury.DEFAULT_ADMIN_ROLE(), admin));
        assertEq(returnedDeployer, broadcaster);
    }

    function test_Deploy_OpenExecutor() public {
        DeployTreasury deployer = new DeployTreasury();
        address broadcaster = makeAddr("broadcaster");

        address[] memory proposers = new address[](1);
        proposers[0] = makeAddr("proposer");
        address[] memory executors = new address[](1);
        executors[0] = address(0); // açık execute

        (KozaTreasury treasury,) = deployer.deploy(1 days, proposers, executors, broadcaster, broadcaster);

        // address(0) executor → herkes EXECUTOR_ROLE'a sahip sayılır (onlyRoleOrOpenRole)
        assertTrue(treasury.hasRole(treasury.EXECUTOR_ROLE(), address(0)));
        assertEq(treasury.getMinDelay(), 1 days);
    }
}
