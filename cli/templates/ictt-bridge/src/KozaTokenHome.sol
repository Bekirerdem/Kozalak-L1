// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ERC20TokenHome} from "@ictt/TokenHome/ERC20TokenHome.sol";

/**
 * @title KozaTokenHome
 * @notice kozalak-l1 Sprint 3 ICTT TokenHome boilerplate (Phase 1, v0.3.0).
 *
 *         Source-chain ERC-20 lock contract. ava-labs/icm-contracts'tan
 *         denetlenmiş `ERC20TokenHome`'u doğrudan miras alır; üzerine
 *         custom logic eklemez. Audit-grade prensibi: minimum custom
 *         layer on top of audited primitives.
 *
 *         Yayın senaryosu (Phase 1 default):
 *           - Kaynak zincir: Avalanche Fuji testnet (chain ID 43113)
 *           - Bridge edilen token: KozaGasToken (KGAS) v0.1.0 — Fuji'de
 *             zaten canlı: 0x06451DD4Fb8ebFC19870DacC9568f4364D2A2eB0
 *           - Hedef zincir: kozaTestL1 (chain ID 9999) — Avalanche CLI
 *             tarafından local'de ayağa kaldırılmış Subnet-EVM tabanlı L1
 *           - Hedef contract: `KozaTokenRemote` (ayrı deploy)
 *
 *         Parent `ERC20TokenHome`'un sağladıkları:
 *           - Reentrancy guard (SendReentrancyGuardUpgradeable)
 *           - Teleporter registry üzerinden version pinning ve migration
 *             (TeleporterRegistryOwnableAppUpgradeable)
 *           - Multi-hop transfer desteği (Home -> Remote A -> Remote B)
 *           - sendAndCall pattern: token transfer + uzak zincirde
 *             fonksiyon çağrısı (atomik)
 *           - ERC-20 lock/unlock (deposit/withdraw) muhasebesi
 *
 *         Production hazırlık checklist'i:
 *           - `teleporterManager` MUTLAKA Safe (Gnosis) multisig olmalı.
 *             Bu adres Teleporter version migration'ları yönetir; tek
 *             nokta güven (single point of trust). EOA mainnet'e konmaz.
 *           - `tokenAddress` immutable bir ERC-20'ye işaret etmeli
 *             (KozaGasToken zaten Ownable2Step + cap'li, uygun).
 *           - `minTeleporterVersion` her iki zincirin desteklediği en
 *             düşük versiyon olmalı; Avalanche resmi Teleporter
 *             release notes'a bakılarak güncellenir.
 *           - Constructor argümanları deterministic — aynı Bridge
 *             birden fazla L1 çiftine deploy edilirse her seferinde
 *             aynı bytecode + adres üretmek için CreateX/CREATE2 kullan.
 *
 * @custom:security-contact security@bekirerdem.dev
 */
contract KozaTokenHome is ERC20TokenHome {
    constructor(
        address teleporterRegistryAddress,
        address teleporterManager,
        uint256 minTeleporterVersion,
        address tokenAddress,
        uint8 tokenDecimals
    )
        ERC20TokenHome(teleporterRegistryAddress, teleporterManager, minTeleporterVersion, tokenAddress, tokenDecimals)
    {}
}
