// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ERC20TokenRemote} from "@ictt/TokenRemote/ERC20TokenRemote.sol";
import {TokenRemoteSettings} from "@ictt/TokenRemote/interfaces/ITokenRemote.sol";

/**
 * @title KozaTokenRemote
 * @notice kozalak-l1 Sprint 3 ICTT TokenRemote boilerplate (Phase 1, v0.3.0).
 *
 *         Hedef-zincir mint/burn ERC-20 representation. ava-labs/icm-contracts'tan
 *         denetlenmiş `ERC20TokenRemote`'u doğrudan miras alır; üzerine custom
 *         logic eklemez. Audit-grade prensibi: minimum custom layer.
 *
 *         Yayın senaryosu (Phase 1 default):
 *           - Hedef zincir: kozaTestL1 (chain ID 9999) — Subnet-EVM,
 *             Avalanche CLI ile yerel deploy
 *           - Bu kontrat üretir: wKGAS (Wrapped Koza Gas), 18 decimals
 *           - Kaynak zincir TokenHome: Fuji'deki `KozaTokenHome`
 *             instance'ı (Sprint 3'ün diğer yarısı)
 *
 *         Akış (Senaryo B):
 *           1. Kullanıcı Fuji'de KGAS (`KozaGasToken`) approve eder.
 *           2. `KozaTokenHome.send(...)` çağırır → KGAS lock'lanır,
 *              Teleporter messenger üzerinden kozaTestL1'e mesaj gider.
 *           3. kozaTestL1'de `KozaTokenRemote` mesajı alır → kullanıcının
 *              cüzdanına wKGAS mint eder.
 *           4. Geri yönde: kullanıcı wKGAS'ı burn eder, Fuji'deki KGAS'ı
 *              unlock olur.
 *
 *         Parent `ERC20TokenRemote`'un sağladıkları:
 *           - ERC-20 standardı (mint/burn dahil)
 *           - Reentrancy guard (SendReentrancyGuardUpgradeable)
 *           - Teleporter registry üzerinden version pinning + migration
 *           - TokenHome ile decimals scaling (farklı decimals ise oranlar)
 *           - Multi-hop transfer ve sendAndCall desteği
 *           - `registerWithHome()` ilk deploy sonrası çağrılarak
 *             TokenHome ile eşleşmeyi tamamlar
 *
 *         Production hazırlık checklist'i:
 *           - `settings.teleporterManager` MUTLAKA Safe (Gnosis) multisig
 *             olmalı (Home tarafıyla aynı kural).
 *           - `settings.tokenHomeBlockchainID` Fuji blockchain ID'si:
 *             `0x` prefix'li 32-byte (Avalanche CLI veya P-Chain query
 *             ile öğrenilir).
 *           - `settings.tokenHomeAddress` deploy edilmiş `KozaTokenHome`
 *             contract adresi.
 *           - `tokenName`/`tokenSymbol`: hedef L1'de "wKGAS" / "Wrapped
 *             Koza Gas" gibi anlamlı değerler (kullanıcı UX'i için).
 *           - Deploy sonrası ilk işlem: `registerWithHome(feeInfo)` ile
 *             Home tarafına bildirim gönder; bu olmadan transfer'ler
 *             reverte uğrar.
 *
 * @custom:security-contact security@bekirerdem.dev
 */
contract KozaTokenRemote is ERC20TokenRemote {
    constructor(
        TokenRemoteSettings memory settings,
        string memory tokenName,
        string memory tokenSymbol,
        uint8 tokenDecimals
    )
        ERC20TokenRemote(settings, tokenName, tokenSymbol, tokenDecimals)
    {}
}
