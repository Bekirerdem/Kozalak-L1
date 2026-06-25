// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {KozaTreasury} from "../../src/templates/treasury-multisig/KozaTreasury.sol";

/**
 * @title DeployTreasury
 * @notice Foundry deployment script for KozaTreasury (Phase 1, Template 5).
 *
 *         Usage (Fuji testnet, with .env populated):
 *
 *             forge script script/deploy/DeployTreasury.s.sol:DeployTreasury \
 *                 --rpc-url fuji --broadcast --verify
 *
 *         Required env:
 *           - PRIVATE_KEY              — deployer private key (testnet only!)
 *
 *         Optional env (defaults below if unset):
 *           - TREASURY_MIN_DELAY       (172800 = 48h)
 *           - TREASURY_PROPOSER        (broadcaster)  — production: Safe multisig
 *           - TREASURY_EXECUTOR        (broadcaster)  — `address(0)` → açık execute
 *           - TREASURY_ADMIN           (broadcaster)  — production: address(0) (self-administered)
 *
 *         Production checklist:
 *           - TREASURY_MIN_DELAY kritik hazine için 48h+ olmalı
 *           - TREASURY_PROPOSER / TREASURY_EXECUTOR birer Safe (Gnosis) multisig olmalı
 *           - TREASURY_ADMIN = address(0) (self-administered) en güvenli; deployer verilirse
 *             kurulum sonrası renounceRole(DEFAULT_ADMIN_ROLE, deployer)
 *           - Korunan kontratların ownership'i bu timelock'a devredilmeli
 */
contract DeployTreasury is Script {
    /*//////////////////////////////////////////////////////////////
                                DEFAULTS
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant DEFAULT_MIN_DELAY = 48 hours; // 172800 s

    /*//////////////////////////////////////////////////////////////
                                  RUN
    //////////////////////////////////////////////////////////////*/

    /// @notice Entry point invoked by `forge script`. Reads parameters from env.
    function run() external returns (KozaTreasury treasury, address deployer) {
        uint256 minDelay = vm.envOr("TREASURY_MIN_DELAY", DEFAULT_MIN_DELAY);

        address broadcaster = _resolveBroadcaster();
        address proposer = vm.envOr("TREASURY_PROPOSER", broadcaster);
        address executor = vm.envOr("TREASURY_EXECUTOR", broadcaster);
        address admin = vm.envOr("TREASURY_ADMIN", broadcaster);

        address[] memory proposers = new address[](1);
        proposers[0] = proposer;
        address[] memory executors = new address[](1);
        executors[0] = executor;

        return deploy(minDelay, proposers, executors, admin, broadcaster);
    }

    /// @notice Test-friendly entry point. Takes explicit parameters instead of env.
    function deploy(
        uint256 minDelay,
        address[] memory proposers,
        address[] memory executors,
        address admin,
        address broadcaster
    )
        public
        returns (KozaTreasury treasury, address deployer)
    {
        _logPreDeploy(minDelay, proposers, executors, admin, broadcaster);

        vm.startBroadcast();
        treasury = new KozaTreasury(minDelay, proposers, executors, admin);
        vm.stopBroadcast();

        deployer = broadcaster;

        _logPostDeploy(treasury);
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
        uint256 minDelay,
        address[] memory proposers,
        address[] memory executors,
        address admin,
        address broadcaster
    )
        internal
        pure
    {
        console2.log("=== Deploying KozaTreasury ===");
        console2.log("  Broadcaster: ", broadcaster);
        console2.log("  Min delay (s):", minDelay);
        console2.log("  Proposer[0]: ", proposers[0]);
        console2.log("  Executor[0]: ", executors[0]);
        console2.log("  Admin:       ", admin);
    }

    function _logPostDeploy(KozaTreasury treasury) internal view {
        console2.log("=== Deployed ===");
        console2.log("  Address:     ", address(treasury));
        console2.log("  Min delay:   ", treasury.getMinDelay());
        console2.log("");
        console2.log("Next steps:");
        console2.log("  1) Fonla: native gonder veya korunan kontrat ownership'ini timelock'a devret");
        console2.log("  2) proposer: cast send <addr> 'schedule(address,uint256,bytes,bytes32,bytes32,uint256)' ...");
        console2.log(
            "  3) minDelay sonra executor: cast send <addr> 'execute(address,uint256,bytes,bytes32,bytes32)' ..."
        );
    }
}
