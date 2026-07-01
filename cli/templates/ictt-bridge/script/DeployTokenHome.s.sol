// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {KozaTokenHome} from "../src/KozaTokenHome.sol";

/**
 * @title DeployTokenHome
 * @notice Foundry deployment script for KozaTokenHome (Phase 1, Sprint 3, v0.3.0).
 *         Kaynak zincirde (default: Fuji) ERC-20 lock contract'ını yayar.
 *
 *         Kullanım (Fuji testnet, .env doluyken):
 *
 *             forge script script/deploy/DeployTokenHome.s.sol \
 *                 --rpc-url fuji \
 *                 --broadcast \
 *                 --verify
 *
 *         Zorunlu env (.env):
 *           - PRIVATE_KEY                       — deployer (testnet only!)
 *
 *         Opsiyonel env (default'lar Phase 1 senaryosu — Fuji'de KGAS bridge):
 *           - HOME_TELEPORTER_REGISTRY  (0xF86Cb19Ad8405AEFa7d09C778215D2Cb6eBfB228 — Fuji resmi)
 *           - HOME_TELEPORTER_MANAGER   (broadcaster)         — production: multisig
 *           - HOME_MIN_TELEPORTER_VERSION (1)
 *           - HOME_TOKEN_ADDRESS        (KozaGasToken v0.1.0 — 0x06451...2eB0)
 *           - HOME_TOKEN_DECIMALS       (18)
 *
 *         Production checklist:
 *           - HOME_TELEPORTER_MANAGER MUTLAKA multisig olmalı (mainnet öncesi)
 *           - HOME_TOKEN_ADDRESS denetlenmiş, immutable bir ERC-20'ye işaret etmeli
 *           - Snowtrace/Routescan API key SNOWTRACE_API_KEY env'inde set'li olmalı
 */
contract DeployTokenHome is Script {
    /*//////////////////////////////////////////////////////////////
                                DEFAULTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Fuji Teleporter Registry — Avalanche resmi sürüm (chain ID 43113).
    address internal constant DEFAULT_TELEPORTER_REGISTRY = 0xF86Cb19Ad8405AEFa7d09C778215D2Cb6eBfB228;

    /// @dev KozaGasToken v0.1.0 — Fuji'de canlı, Phase 1'in default bridge token'ı.
    address internal constant DEFAULT_TOKEN_ADDRESS = 0x06451DD4Fb8ebFC19870DacC9568f4364D2A2eB0;

    uint256 internal constant DEFAULT_MIN_TELEPORTER_VERSION = 1;
    uint8 internal constant DEFAULT_TOKEN_DECIMALS = 18;

    /*//////////////////////////////////////////////////////////////
                                  RUN
    //////////////////////////////////////////////////////////////*/

    function run() external returns (KozaTokenHome home, address deployer) {
        address teleporterRegistry = vm.envOr("HOME_TELEPORTER_REGISTRY", DEFAULT_TELEPORTER_REGISTRY);
        uint256 minTeleporterVersion = vm.envOr("HOME_MIN_TELEPORTER_VERSION", DEFAULT_MIN_TELEPORTER_VERSION);
        address tokenAddress = vm.envOr("HOME_TOKEN_ADDRESS", DEFAULT_TOKEN_ADDRESS);
        uint256 tokenDecimalsRaw = vm.envOr("HOME_TOKEN_DECIMALS", uint256(DEFAULT_TOKEN_DECIMALS));
        uint8 tokenDecimals = uint8(tokenDecimalsRaw);

        address broadcaster = _resolveBroadcaster();
        address teleporterManager = vm.envOr("HOME_TELEPORTER_MANAGER", broadcaster);

        return
            deploy(
                teleporterRegistry, teleporterManager, minTeleporterVersion, tokenAddress, tokenDecimals, broadcaster
            );
    }

    /// @notice Test-friendly entry point. Parametrik, env'e dokunmaz.
    function deploy(
        address teleporterRegistry,
        address teleporterManager,
        uint256 minTeleporterVersion,
        address tokenAddress,
        uint8 tokenDecimals,
        address broadcaster
    )
        public
        returns (KozaTokenHome home, address deployer)
    {
        _logPreDeploy(
            teleporterRegistry, teleporterManager, minTeleporterVersion, tokenAddress, tokenDecimals, broadcaster
        );

        vm.startBroadcast();
        home =
            new KozaTokenHome(teleporterRegistry, teleporterManager, minTeleporterVersion, tokenAddress, tokenDecimals);
        vm.stopBroadcast();

        deployer = broadcaster;

        _logPostDeploy(home);
    }

    /*//////////////////////////////////////////////////////////////
                              INTERNALS
    //////////////////////////////////////////////////////////////*/

    function _resolveBroadcaster() internal view returns (address) {
        address explicitDeployer = vm.envOr("DEPLOYER_ADDRESS", address(0));
        if (explicitDeployer != address(0)) return explicitDeployer;

        uint256 pk = vm.envOr("PRIVATE_KEY", uint256(0));
        if (pk != 0) return vm.addr(pk);

        return tx.origin;
    }

    function _logPreDeploy(
        address teleporterRegistry,
        address teleporterManager,
        uint256 minTeleporterVersion,
        address tokenAddress,
        uint8 tokenDecimals,
        address broadcaster
    )
        internal
        pure
    {
        console2.log("=== Deploying KozaTokenHome ===");
        console2.log("  Broadcaster:           ", broadcaster);
        console2.log("  Teleporter Registry:   ", teleporterRegistry);
        console2.log("  Teleporter Manager:    ", teleporterManager);
        console2.log("  Min Teleporter Version:", minTeleporterVersion);
        console2.log("  Token Address (KGAS):  ", tokenAddress);
        console2.log("  Token Decimals:        ", tokenDecimals);
    }

    function _logPostDeploy(KozaTokenHome home) internal pure {
        console2.log("=== Deployed ===");
        console2.log("  KozaTokenHome at: ", address(home));
        console2.log("");
        console2.log("Next steps:");
        console2.log("  1) Hedef zincire (kozaTestL1) KozaTokenRemote'u deploy et:");
        console2.log("     - REMOTE_TOKEN_HOME_ADDRESS = <yukaridaki adres>");
        console2.log("  2) Remote tarafta registerWithHome() cagrisini gonder.");
        console2.log("  3) End-to-end bridge demosu icin Sprint 3G rehberini takip et.");
    }
}
