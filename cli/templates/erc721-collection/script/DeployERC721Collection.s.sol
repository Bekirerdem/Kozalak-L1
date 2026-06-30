// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {KozaCollection} from "../src/KozaCollection.sol";

/**
 * @title DeployERC721Collection
 * @notice Foundry deployment script for KozaCollection (Phase 1, Template 2).
 *
 *         Usage (Fuji testnet, with .env populated):
 *
 *             forge script script/deploy/DeployERC721Collection.s.sol \
 *                 --rpc-url fuji \
 *                 --broadcast \
 *                 --verify
 *
 *         Required env (loaded by `forge` from .env):
 *           - PRIVATE_KEY                     — deployer private key (testnet only!)
 *
 *         Optional env (defaults below if unset):
 *           - NFT_NAME                  ("Koza Genesis")
 *           - NFT_SYMBOL                ("KOZA")
 *           - NFT_BASE_URI              ("ipfs://CHANGE_ME/")  — sonu `/` ile bitir
 *           - NFT_MAX_SUPPLY            (5000)
 *           - NFT_MINT_PRICE            (0.05 ether)
 *           - NFT_ROYALTY_RECEIVER      (broadcaster)
 *           - NFT_ROYALTY_BPS           (500 = %5)
 *           - NFT_OWNER                 (broadcaster)         — production: multisig
 *
 *         Production checklist:
 *           - PRIVATE_KEY testnet-only veya cast-wallet/keystore ile değiştirilmeli
 *           - NFT_OWNER + NFT_ROYALTY_RECEIVER birer Safe (Gnosis) multisig olmalı
 *           - NFT_BASE_URI gerçek IPFS CID veya HTTPS gateway içermeli (sonu `/` ile)
 *           - Snowtrace/Routescan API key `.env`'de SNOWTRACE_API_KEY olarak set'li olmalı
 */
contract DeployERC721Collection is Script {
    /*//////////////////////////////////////////////////////////////
                                DEFAULTS
    //////////////////////////////////////////////////////////////*/

    string internal constant DEFAULT_NAME = "Koza Genesis";
    string internal constant DEFAULT_SYMBOL = "KOZA";
    string internal constant DEFAULT_BASE_URI = "ipfs://CHANGE_ME/";
    uint256 internal constant DEFAULT_MAX_SUPPLY = 5000;
    uint256 internal constant DEFAULT_MINT_PRICE = 0.05 ether;
    uint96 internal constant DEFAULT_ROYALTY_BPS = 500; // %5

    /*//////////////////////////////////////////////////////////////
                                  RUN
    //////////////////////////////////////////////////////////////*/

    /// @notice Entry point invoked by `forge script`. Reads parameters from env.
    function run() external returns (KozaCollection nft, address deployer) {
        string memory name = vm.envOr("NFT_NAME", DEFAULT_NAME);
        string memory symbol = vm.envOr("NFT_SYMBOL", DEFAULT_SYMBOL);
        string memory baseURI = vm.envOr("NFT_BASE_URI", DEFAULT_BASE_URI);
        uint256 maxSupply = vm.envOr("NFT_MAX_SUPPLY", DEFAULT_MAX_SUPPLY);
        uint256 mintPrice = vm.envOr("NFT_MINT_PRICE", DEFAULT_MINT_PRICE);
        uint256 royaltyBpsRaw = vm.envOr("NFT_ROYALTY_BPS", uint256(DEFAULT_ROYALTY_BPS));
        uint96 royaltyBps = uint96(royaltyBpsRaw);

        address broadcaster = _resolveBroadcaster();
        address royaltyReceiver = vm.envOr("NFT_ROYALTY_RECEIVER", broadcaster);
        address owner = vm.envOr("NFT_OWNER", broadcaster);

        return deploy(name, symbol, baseURI, maxSupply, mintPrice, royaltyReceiver, royaltyBps, owner, broadcaster);
    }

    /// @notice Test-friendly entry point. Takes explicit parameters instead of env.
    /// @dev Prefer this from Foundry tests so env state does not leak between cases.
    function deploy(
        string memory name,
        string memory symbol,
        string memory baseURI,
        uint256 maxSupply,
        uint256 mintPrice,
        address royaltyReceiver,
        uint96 royaltyBps,
        address owner,
        address broadcaster
    )
        public
        returns (KozaCollection nft, address deployer)
    {
        _logPreDeploy(name, symbol, baseURI, maxSupply, mintPrice, royaltyReceiver, royaltyBps, owner, broadcaster);

        vm.startBroadcast();
        nft = new KozaCollection(name, symbol, baseURI, maxSupply, mintPrice, royaltyReceiver, royaltyBps, owner);
        vm.stopBroadcast();

        deployer = broadcaster;

        _logPostDeploy(nft, owner);
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
        string memory baseURI,
        uint256 maxSupply,
        uint256 mintPrice,
        address royaltyReceiver,
        uint96 royaltyBps,
        address owner,
        address broadcaster
    )
        internal
        pure
    {
        console2.log("=== Deploying KozaCollection ===");
        console2.log("  Broadcaster:    ", broadcaster);
        console2.log("  Owner:          ", owner);
        console2.log("  Name:           ", name);
        console2.log("  Symbol:         ", symbol);
        console2.log("  Base URI:       ", baseURI);
        console2.log("  Max supply:     ", maxSupply);
        console2.log("  Mint price (wei):", mintPrice);
        console2.log("  Royalty BPS:    ", royaltyBps);
        console2.log("  Royalty receiver:", royaltyReceiver);
    }

    function _logPostDeploy(KozaCollection nft, address owner_) internal view {
        console2.log("=== Deployed ===");
        console2.log("  Address:        ", address(nft));
        console2.log("  Owner:          ", nft.owner());
        console2.log("  Owner (input):  ", owner_);
        console2.log("  Phase:          ", uint8(nft.phase()));
        console2.log("");
        console2.log("Next steps:");
        console2.log("  1) cast send <addr> 'setMerkleRoot(bytes32)' <root> --rpc-url fuji ...");
        console2.log("  2) cast send <addr> 'setPhase(uint8)' 1  # Allowlist");
        console2.log("  3) cast send <addr> 'setPhase(uint8)' 2  # Public");
    }
}
