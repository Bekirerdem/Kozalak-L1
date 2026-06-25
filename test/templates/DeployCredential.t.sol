// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {Test} from "forge-std/Test.sol";
import {DeployCredential} from "../../script/deploy/DeployCredential.s.sol";
import {KozaCredential} from "../../src/templates/soulbound-credential/KozaCredential.sol";

/**
 * @title DeployCredentialTest
 * @notice Smoke tests for the Soulbound deploy script. Calls `deploy(...)` directly
 *         with explicit parameters; env-driven `run()` exercised on Fuji integration.
 */
contract DeployCredentialTest is Test {
    bytes32 internal constant ISSUER_ROLE = keccak256("ISSUER_ROLE");
    bytes32 internal constant ADMIN_ROLE = 0x00; // DEFAULT_ADMIN_ROLE

    function test_Deploy_DefaultRolesToBroadcaster() public {
        DeployCredential deployer = new DeployCredential();
        address broadcaster = makeAddr("broadcaster");

        (KozaCredential cred, address returnedDeployer) =
            deployer.deploy("ARIA Hub Credential", "ARIA", broadcaster, broadcaster, broadcaster);

        assertEq(cred.name(), "ARIA Hub Credential");
        assertEq(cred.symbol(), "ARIA");
        assertEq(cred.totalIssued(), 0);
        assertTrue(cred.hasRole(ADMIN_ROLE, broadcaster));
        assertTrue(cred.hasRole(ISSUER_ROLE, broadcaster));
        assertEq(returnedDeployer, broadcaster);
    }

    function test_Deploy_SeparateAdminAndIssuer() public {
        DeployCredential deployer = new DeployCredential();
        address admin = makeAddr("admin");
        address issuer = makeAddr("issuer");
        address broadcaster = makeAddr("broadcaster");

        (KozaCredential cred,) = deployer.deploy("Custom Cred", "CC", admin, issuer, broadcaster);

        assertEq(cred.name(), "Custom Cred");
        assertTrue(cred.hasRole(ADMIN_ROLE, admin));
        assertTrue(cred.hasRole(ISSUER_ROLE, issuer));
        assertFalse(cred.hasRole(ISSUER_ROLE, broadcaster));
        assertFalse(cred.hasRole(ADMIN_ROLE, issuer));
    }
}
