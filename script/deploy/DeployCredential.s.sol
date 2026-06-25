// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {KozaCredential} from "../../src/templates/soulbound-credential/KozaCredential.sol";

/**
 * @title DeployCredential
 * @notice Foundry deployment script for KozaCredential (Phase 1, Template 4).
 *
 *         Usage (Fuji testnet, with .env populated):
 *
 *             forge script script/deploy/DeployCredential.s.sol \
 *                 --rpc-url fuji \
 *                 --broadcast \
 *                 --verify
 *
 *         Required env (loaded by `forge` from .env):
 *           - PRIVATE_KEY              — deployer private key (testnet only!)
 *
 *         Optional env (defaults below if unset):
 *           - CREDENTIAL_NAME          ("ARIA Hub Credential")
 *           - CREDENTIAL_SYMBOL        ("ARIA")
 *           - CREDENTIAL_ADMIN         (broadcaster)  — production: multisig
 *           - CREDENTIAL_ISSUER        (broadcaster)  — sertifika veren/iptal eden
 *
 *         Production checklist:
 *           - PRIVATE_KEY testnet-only veya cast-wallet/keystore ile değiştirilmeli
 *           - CREDENTIAL_ADMIN bir Safe (Gnosis) multisig olmalı (rol yönetimi)
 *           - CREDENTIAL_ISSUER kurum/eğitmen cüzdanı; çoklu issuer admin tarafından
 *             `grantRole(ISSUER_ROLE, ...)` ile eklenir
 *           - SNOWTRACE_API_KEY `.env`'de set'li olmalı (Routescan verify)
 */
contract DeployCredential is Script {
    /*//////////////////////////////////////////////////////////////
                                DEFAULTS
    //////////////////////////////////////////////////////////////*/

    string internal constant DEFAULT_NAME = "ARIA Hub Credential";
    string internal constant DEFAULT_SYMBOL = "ARIA";

    /*//////////////////////////////////////////////////////////////
                                  RUN
    //////////////////////////////////////////////////////////////*/

    /// @notice Entry point invoked by `forge script`. Reads parameters from env.
    function run() external returns (KozaCredential cred, address deployer) {
        string memory name = vm.envOr("CREDENTIAL_NAME", DEFAULT_NAME);
        string memory symbol = vm.envOr("CREDENTIAL_SYMBOL", DEFAULT_SYMBOL);

        address broadcaster = _resolveBroadcaster();
        address admin = vm.envOr("CREDENTIAL_ADMIN", broadcaster);
        address issuer = vm.envOr("CREDENTIAL_ISSUER", broadcaster);

        return deploy(name, symbol, admin, issuer, broadcaster);
    }

    /// @notice Test-friendly entry point. Takes explicit parameters instead of env.
    /// @dev Prefer this from Foundry tests so env state does not leak between cases.
    function deploy(
        string memory name,
        string memory symbol,
        address admin,
        address issuer,
        address broadcaster
    )
        public
        returns (KozaCredential cred, address deployer)
    {
        _logPreDeploy(name, symbol, admin, issuer, broadcaster);

        vm.startBroadcast();
        cred = new KozaCredential(name, symbol, admin, issuer);
        vm.stopBroadcast();

        deployer = broadcaster;

        _logPostDeploy(cred, admin, issuer);
    }

    /*//////////////////////////////////////////////////////////////
                              INTERNALS
    //////////////////////////////////////////////////////////////*/

    /// @dev Order: explicit DEPLOYER_ADDRESS > derived from PRIVATE_KEY > tx.origin.
    function _resolveBroadcaster() internal view returns (address) {
        address explicitDeployer = vm.envOr("DEPLOYER_ADDRESS", address(0));
        if (explicitDeployer != address(0)) return explicitDeployer;

        uint256 pk = vm.envOr("PRIVATE_KEY", uint256(0));
        if (pk != 0) return vm.addr(pk);

        return tx.origin;
    }

    function _logPreDeploy(
        string memory name,
        string memory symbol,
        address admin,
        address issuer,
        address broadcaster
    )
        internal
        pure
    {
        console2.log("=== Deploying KozaCredential ===");
        console2.log("  Broadcaster: ", broadcaster);
        console2.log("  Name:        ", name);
        console2.log("  Symbol:      ", symbol);
        console2.log("  Admin:       ", admin);
        console2.log("  Issuer:      ", issuer);
    }

    function _logPostDeploy(KozaCredential cred, address admin, address issuer) internal view {
        console2.log("=== Deployed ===");
        console2.log("  Address:     ", address(cred));
        console2.log("  Admin set:   ", cred.hasRole(cred.DEFAULT_ADMIN_ROLE(), admin));
        console2.log("  Issuer set:  ", cred.hasRole(cred.ISSUER_ROLE(), issuer));
        console2.log("");
        console2.log("Next steps:");
        console2.log("  1) cast send <addr> 'issue(address,string)' <to> 'Course Name' --rpc-url fuji ...");
        console2.log("  2) cast call <addr> 'isValid(uint256)' 1 --rpc-url fuji");
        console2.log("  3) admin: cast send <addr> 'grantRole(bytes32,address)' <ISSUER_ROLE> <newIssuer>");
    }
}
