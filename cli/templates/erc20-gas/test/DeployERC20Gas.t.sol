// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {Test} from "forge-std/Test.sol";
import {DeployERC20Gas} from "../script/DeployERC20Gas.s.sol";
import {KozaGasToken} from "../src/KozaGasToken.sol";

/**
 * @title DeployERC20GasTest
 * @notice Smoke tests for the deploy script. Calls `deploy(...)` directly with
 *         explicit parameters so each test is order-independent and immune to
 *         leaking env state between Foundry cases.
 *
 *         The env-driven `run()` entry point is intentionally not unit-tested here;
 *         it is exercised via the actual `forge script ... --broadcast` flow on
 *         Fuji testnet (integration test).
 */
contract DeployERC20GasTest is Test {
    function test_Deploy_WithDefaultParameters() public {
        DeployERC20Gas deployer = new DeployERC20Gas();
        address broadcaster = makeAddr("broadcaster");

        (KozaGasToken token, address returnedDeployer) =
            deployer.deploy("Koza Gas Token", "KGAS", 1_000_000 ether, 100_000 ether, broadcaster, broadcaster);

        assertEq(token.name(), "Koza Gas Token");
        assertEq(token.symbol(), "KGAS");
        assertEq(token.cap(), 1_000_000 ether);
        assertEq(token.totalSupply(), 100_000 ether);
        assertEq(token.owner(), broadcaster);
        assertEq(token.balanceOf(broadcaster), 100_000 ether);
        assertEq(returnedDeployer, broadcaster);
    }

    function test_Deploy_WithCustomParameters() public {
        DeployERC20Gas deployer = new DeployERC20Gas();
        address customOwner = makeAddr("customOwner");
        address customBroadcaster = makeAddr("customBroadcaster");

        (KozaGasToken token,) =
            deployer.deploy("Custom Token", "CUST", 2_000_000 ether, 50_000 ether, customOwner, customBroadcaster);

        assertEq(token.name(), "Custom Token");
        assertEq(token.symbol(), "CUST");
        assertEq(token.cap(), 2_000_000 ether);
        assertEq(token.totalSupply(), 50_000 ether);
        assertEq(token.owner(), customOwner);
        assertEq(token.balanceOf(customOwner), 50_000 ether);
    }

    function test_Deploy_NoInitialMint() public {
        DeployERC20Gas deployer = new DeployERC20Gas();
        address broadcaster = makeAddr("broadcaster");

        (KozaGasToken token,) = deployer.deploy("Koza Gas Token", "KGAS", 1_000_000 ether, 0, broadcaster, broadcaster);

        assertEq(token.totalSupply(), 0);
        assertEq(token.balanceOf(broadcaster), 0);
    }
}
