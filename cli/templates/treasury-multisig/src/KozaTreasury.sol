// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

/**
 * @title KozaTreasury
 * @author kozalak-L1 contributors
 * @notice Zaman-kilitli (timelock) hazine — OpenZeppelin `TimelockController` ince wrapper'ı.
 *         DAO/topluluk fonlarını rol-bazlı + gecikmeli yürütmeyle korur. Avalanche L1 /
 *         C-Chain için audit-grade boilerplate.
 * @dev OZ v5.3+ `TimelockController`'ı doğrudan miras alır; custom logic eklemez. Audit-grade
 *      prensibi: minimum custom layer on top of audited primitives.
 *
 *      "Multisig" katmanı: bir Safe (Gnosis) multisig'i `proposers`/`executors` olarak atanır.
 *      Öneri Safe'te imzalanır → timelock gecikmesi dolar → execute. Tek nokta güven yoktur;
 *      gecikme, kötü niyetli/yanlış önerilere tepki penceresi sağlar.
 *
 *      Parent `TimelockController`'ın sağladıkları:
 *        - Roller: PROPOSER_ROLE (schedule), EXECUTOR_ROLE (execute), CANCELLER_ROLE (cancel),
 *          DEFAULT_ADMIN_ROLE (rol yönetimi).
 *        - `schedule`/`scheduleBatch` → minDelay bekle → `execute`/`executeBatch`.
 *        - `cancel` (henüz yürütülmemiş öneriyi iptal).
 *        - `updateDelay` — YALNIZCA timelock'un kendi önerisiyle değiştirilebilir.
 *        - `receive()` payable — native fon tutar; ERC20'ler `schedule(token, 0, transferCalldata, ...)`
 *          ile zaman-kilitli gönderilir.
 *        - `executor = address(0)` → açık execute (herkes yürütebilir, schedule yine korumalı).
 *
 *      Production hazırlık checklist'i:
 *        - `minDelay` kritik hazine için anlamlı olmalı (örn. 48h+). Çok düşük delay timelock'un
 *          güvenlik değerini düşürür.
 *        - `proposers`/`executors` birer Safe multisig olmalı; EOA mainnet'te tek nokta risktir.
 *        - `admin = address(0)` (self-administered) en güvenlidir: roller yalnız timelock'un kendi
 *          gecikmeli önerisiyle değişir. Kurulum kolaylığı için deployer verilirse, kurulum
 *          sonrası `renounceRole(DEFAULT_ADMIN_ROLE, deployer)` ile bırakılması önerilir.
 *        - Hazine sahipliği: korunan kontratların `owner`/admin'i bu timelock olmalı.
 *
 * @custom:security-contact security@bekirerdem.dev
 */
contract KozaTreasury is TimelockController {
    /**
     * @param minDelay Önerinin yürütülebilmesi için geçmesi gereken minimum süre (saniye)
     * @param proposers PROPOSER_ROLE + CANCELLER_ROLE alacak adresler (production: Safe multisig)
     * @param executors EXECUTOR_ROLE alacak adresler (`address(0)` → açık execute)
     * @param admin DEFAULT_ADMIN_ROLE (production: `address(0)` self-administered önerilir)
     */
    constructor(
        uint256 minDelay,
        address[] memory proposers,
        address[] memory executors,
        address admin
    )
        TimelockController(minDelay, proposers, executors, admin)
    {}
}
