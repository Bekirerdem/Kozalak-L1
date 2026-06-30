// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {KozaGasToken} from "../src/KozaGasToken.sol";

/**
 * @title DeployERC20Gas
 * @notice Foundry deployment script for KozaGasToken (Phase 1, Template 1).
 *
 *         Usage (Fuji testnet, with .env populated):
 *
 *             forge script script/deploy/DeployERC20Gas.s.sol \
 *                 --rpc-url fuji \
 *                 --broadcast \
 *                 --verify
 *
 *         Required env (loaded by `forge` from .env):
 *           - PRIVATE_KEY                — deployer private key (testnet only!)
 *
 *         Optional env (defaults below if unset):
 *           - ERC20_NAME            ("Koza Gas Token")
 *           - ERC20_SYMBOL          ("KGAS")
 *           - ERC20_CAP             (1_000_000 ether)   — total supply hard cap
 *           - ERC20_INITIAL_MINT    (100_000 ether)     — minted to owner at deploy
 *           - ERC20_OWNER           (msg.sender)        — production: pass a multisig
 *
 *         Production checklist:
 *           - PRIVATE_KEY must be testnet-only OR replaced with cast-wallet/keystore
 *           - ERC20_OWNER must point to a Safe (Gnosis Safe) multisig, never an EOA
 *           - SNOWTRACE_API_KEY in .env (set to "verifyContract" for free Routescan tier)
 */
contract DeployERC20Gas is Script {
    /*//////////////////////////////////////////////////////////////
                                DEFAULTS
    //////////////////////////////////////////////////////////////*/

    string internal constant DEFAULT_NAME = "Koza Gas Token";
    string internal constant DEFAULT_SYMBOL = "KGAS";
    uint256 internal constant DEFAULT_CAP = 1_000_000 ether;
    uint256 internal constant DEFAULT_INITIAL_MINT = 100_000 ether;

    /*//////////////////////////////////////////////////////////////
                                  RUN
    //////////////////////////////////////////////////////////////*/

    /// @notice Entry point invoked by `forge script`. Reads parameters from env.
    function run() external returns (KozaGasToken token, address deployer) {
        string memory name = vm.envOr("ERC20_NAME", DEFAULT_NAME);
        string memory symbol = vm.envOr("ERC20_SYMBOL", DEFAULT_SYMBOL);
        uint256 cap = vm.envOr("ERC20_CAP", DEFAULT_CAP);
        uint256 initialMint = vm.envOr("ERC20_INITIAL_MINT", DEFAULT_INITIAL_MINT);

        address broadcaster = _resolveBroadcaster();
        address owner = vm.envOr("ERC20_OWNER", broadcaster);

        return deploy(name, symbol, cap, initialMint, owner, broadcaster);
    }

    /// @notice Test-friendly entry point. Takes explicit parameters instead of env.
    /// @dev Prefer this from Foundry tests so env state does not leak between cases.
    function deploy(
        string memory name,
        string memory symbol,
        uint256 cap,
        uint256 initialMint,
        address owner,
        address broadcaster
    )
        public
        returns (KozaGasToken token, address deployer)
    {
        _logPreDeploy(name, symbol, cap, initialMint, owner, broadcaster);

        vm.startBroadcast();
        token = new KozaGasToken(name, symbol, cap, initialMint, owner);
        vm.stopBroadcast();

        deployer = broadcaster;

        _logPostDeploy(token, owner);
    }

    /*//////////////////////////////////////////////////////////////
                              INTERNALS
    //////////////////////////////////////////////////////////////*/

    /// @dev Returns the address that will broadcast txs for this run.
    ///      Order: explicit DEPLOYER_ADDRESS > address derived from PRIVATE_KEY > tx.origin.
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
        uint256 cap,
        uint256 initialMint,
        address owner,
        address broadcaster
    )
        internal
        pure
    {
        console2.log("=== Deploying KozaGasToken ===");
        console2.log("  Broadcaster:    ", broadcaster);
        console2.log("  Owner:          ", owner);
        console2.log("  Name:           ", name);
        console2.log("  Symbol:         ", symbol);
        console2.log("  Cap (wei):      ", cap);
        console2.log("  Initial mint:   ", initialMint);
    }

    function _logPostDeploy(KozaGasToken token, address owner) internal view {
        console2.log("=== Deployed ===");
        console2.log("  Address:        ", address(token));
        console2.log("  Total supply:   ", token.totalSupply());
        console2.log("  Cap:            ", token.cap());
        console2.log("  Owner balance:  ", token.balanceOf(owner));
        console2.log("");
        console2.log("Verify on Snowtrace:");
        console2.log("  forge verify-contract <address> KozaGasToken --rpc-url fuji");
    }
}
