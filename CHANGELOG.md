# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.5.0] — 2026-06-25

**Phase 1 TAMAMLANDI** 🎉 — 5/5 audit-grade template Fuji'de canlı + verified.
Son template: **Treasury Multisig + Timelock (KozaTreasury)** — OZ
`TimelockController` ince wrapper'ı; DAO/topluluk fonlarını rol-bazlı +
gecikmeli yürütmeyle korur.

### Live Deployment

**KozaTreasury (Fuji C-Chain, 43113):**
- **Contract:** [`0x6864879522D70Fb8e1583Cc8Fd4baB0e9605A955`](https://testnet.snowtrace.io/address/0x6864879522D70Fb8e1583Cc8Fd4baB0e9605A955) — verified
- Canlı kanıt: `schedule` tx [`0x4cf4410c…`](https://testnet.snowtrace.io/tx/0x4cf4410cc57040e44862ef0f45f3dd5a5e02db8eb8add648d4b0e236f1d07dca) → `getMinDelay`=172800 (48h), operation `getOperationState`=1 (Waiting).

### Added

- `src/templates/treasury-multisig/KozaTreasury.sol` — `TimelockController` wrapper (OZ v5.3+, ~5.4 KB runtime).
- `script/deploy/DeployTreasury.s.sol` — `run()`/`deploy()` pattern (env + parametrik).
- `test/templates/Treasury.t.sol` + `DeployTreasury.t.sol` — 10 test (schedule/execute delay enforcement, roller, cancel, native fon, open-executor, deploy smoke).
- `docs/tr/03-templateler/treasury-multisig.md` — Türkçe audit-grade rehber.

### Notes

- **Multisig + timelock:** Safe multisig proposer/executor olarak atanır; öneri çoklu imza + zaman kilidiyle korunur (tek nokta güven yok).
- **admin = `address(0)` (self-administered) önerilir:** roller yalnız timelock'un kendi gecikmeli önerisiyle değişir.
- **Phase 1 kapandı:** ERC20 (v0.1) · ERC721 (v0.2) · ICTT çift yön (v0.3.2) · Soulbound (v0.4) · Treasury (v0.5) — hepsi Fuji'de canlı + Routescan verified.

## [0.4.0] — 2026-06-25

Phase 1'in 4. template'i: **Soulbound Credential (KozaCredential)** — transfer
edilemez (account-bound) on-chain sertifika NFT. Issuer-only mint, on-chain
metadata, revoke-flag. Fuji'de canlı + Routescan verified.

### Live Deployment

**KozaCredential (Fuji C-Chain, 43113):**
- **Contract:** [`0xCFdE91F214ABDe2a2E65B6cd41A7C7E3244E1ec1`](https://testnet.snowtrace.io/address/0xCFdE91F214ABDe2a2E65B6cd41A7C7E3244E1ec1) — verified
- İlk sertifika kanıtı: `issue` tx [`0xd1de861d…`](https://testnet.snowtrace.io/tx/0xd1de861db6c309080253d2536a1767c11ee81a3fb2ab87b4e83aa298c2bcbc8d) → `isValid(1)=true`, `transferFrom` revert (soulbound), `tokenURI` on-chain base64 JSON.

### Added

- `src/templates/soulbound-credential/KozaCredential.sol` — account-bound ERC-721 + AccessControl + on-chain metadata + revoke-flag (OZ v5.3+ inherit, ~7.4 KB runtime).
- `script/deploy/DeployCredential.s.sol` — `run()` (env) / `deploy()` (parametrik) pattern.
- `test/templates/Soulbound.t.sol` + `Soulbound.invariants.t.sol` + `DeployCredential.t.sol` — 28 test (unit + fuzz 10000 + invariant 100k call + deploy smoke), TDD.
- `docs/tr/03-templateler/soulbound-credential.md` — Türkçe audit-grade rehber.
- `docs/superpowers/specs/2026-06-25-soulbound-credential-design.md` — tasarım dokümanı.

### Notes

- **ERC-5114 yerine account-bound:** ERC-5114 rozeti NFT'ye bağlar + revoke yok; eğitim sertifikası "kişiye + issuer revoke" gereksinimine account-bound ERC-721 + revoke-flag oturur.
- **Soulbound mekanik:** `_update` override — transfer (`from≠0 && to≠0`) → `revert Soulbound()`; `approve` fiilen etkisiz.
- **Revoke-flag (burn değil):** iptal denetlenebilir; token silinmez, `Status` metadata'ya yansır.
- **On-chain metadata:** `tokenURI` base64 JSON (`Strings` + `Base64`), IPFS bağımsız.

## [0.3.2] — 2026-06-24

ICTT köprüsünün **ters yönü (round-trip) uçtan uca canlı doğrulandı.** v0.3.1
ileri yönü (KGAS lock → wKGAS mint) kanıtlamıştı; bu sürüm geri dönüşü kapatır:
Fuji L1'de wKGAS `burn` → `icm-relayer` → Fuji C-Chain'de KGAS `unlock`. Köprünün
iki yönü de on-chain çalışıyor — Template 3 tam kapanış. Kod değişikliği yok;
`Remote.send` (burn) ve `Home._withdraw` (unlock) audited `icm-contracts`'tan gelir.

### Round-Trip Kanıtı (Fuji, 2026-06-24)

- **wKGAS BURN (`Remote.send`, L1):** `0x9dfad5a2c31b5c5546c7ffcc2947ab80fa333ba430ddd61958b6cbb585023ec5`
- **KGAS UNLOCK (`Home._withdraw`, Fuji C-Chain):** [`0x843772a8f9757d23ce961b703a86573d8dafafff37b1df3f241caabb3106cd22`](https://testnet.snowtrace.io/tx/0x843772a8f9757d23ce961b703a86573d8dafafff37b1df3f241caabb3106cd22)
- **Sonuç:** L1 wKGAS `totalSupply = 0` (burn tamam); Fuji `KGAS.balanceOf(deployer)` `99980` → `99990` (+10 unlock) ✅
- Tam kanıt zinciri: `docs/tr/03-templateler/ictt-demo-kanit.md` (Ters Yön bölümü)

### Added

- `scripts/demo/run-ictt-demo.sh` — `[6/6]` round-trip adımı (wKGAS self-approve →
  `Remote.send` burn → Fuji KGAS unlock poll). Tek script artık ileri + geri yönü doğrular.

### Notes

- **Geri dönüş burn ön koşulu:** `Remote._burn` → `_spendAllowance(sender, address(this))`;
  wKGAS, Remote kontratının **kendisine** approve edilmeli (ileri yönde KGAS Home'a approve ediliyordu).
- Yerel L1 disk state'i makine yeniden başlatmaları arasında korunur: `avalanche node local start
  <cluster>` node'u yeniden ayağa kaldırır (blockchain'i yeniden *create* etmeye gerek yok),
  Remote state + mint'ler geri gelir. `avalanche blockchain deploy` ise "overwrite?" interaktif
  sorusu sorar — restart için `node local start` tercih edilir.
- `icm-relayer` config'i çift yön relay eder (C-Chain ↔ L1 ikisi de source+destination);
  `process-missed-blocks: false` olduğundan burn, relayer L1 quorum'a (67/100) bağlandıktan **sonra** atılmalı.

## [0.3.1] — 2026-06-22

ICTT Cross-L1 Bridge **uçtan uca canlı doğrulandı.** v0.3.0'da kontratlar
canlıydı ama relayer kurulmadığı için gerçek transfer tamamlanmamıştı; bu
sürüm KGAS lock → `icm-relayer` → wKGAS mint zincirini on-chain kanıtlar.

### Mimari Düzeltme

v0.3.0 "Fuji C-Chain Home → **yerel** L1 Remote" varsayıyordu. Bu mimari
**çalışmaz**: yerel network ile Fuji ayrı P-Chain'lere sahiptir, yerel L1
Fuji'nin Warp imzalarını doğrulayamaz. v0.3.1'de Remote, **Fuji'ye gerçek bir
sovereign L1** olarak deploy edildi (`--use-local-machine`, validator local
makinede) — Home (Fuji C-Chain) ve Remote (Fuji L1) aynı primary network'te,
ICM çalışıyor. `requirePrimaryNetworkSigners=true` sayesinde L1, Fuji primary
network imzalı mesajları kabul eder.

### Uçtan Uca Transfer Kanıtı (Fuji)

- **Remote (wKGAS):** `KozaTokenRemote` at `0x0c4476E8D1d140B303E08aa75a0AbD44Ff202bb1`
  (Fuji L1 `kozaTestL1`, blockchain ID `iq2dnsHr4T9FG39r3Fkho3H8B2V31BdnkxHCnCVZNvbHCiSQE`).
  v0.3.0'daki `0x53c10844…` adresi geçersizdir (yerel state kayboldu).
- **`Home.send` (10 KGAS lock):** `0xb74ce3d8efcc46745466b3df4b87ac6452029a23aa69b8ce99b8d41f501c8bf4`
- **Sonuç:** Fuji L1'de `balanceOf = totalSupply = 10000000000000000000` (10 wKGAS) ✅
- Tam kanıt zinciri + tüm tx hash'leri: `docs/tr/03-templateler/ictt-demo-kanit.md`

### Added

- `scripts/demo/run-ictt-demo.sh` — uçtan uca demoyu yeniden üreten orchestration
  script (relayer → Remote deploy → register → transfer → mint doğrula).
- `docs/tr/03-templateler/ictt-demo-kanit.md` — canlı transfer kanıt dokümanı.

### Notes

- Relayer için: `icm-relayer` flag'i `--config-file`'dır; relayer deployer key
  kullanır, relay sırasında manuel tx göndermek nonce çakışması yaratır.
- Subnet-EVM precompile'a bağımlı kontratlar `forge create` ile deploy edilmeli
  (`forge script` local EVM'de Warp precompile'ı bulamaz → StackUnderflow).

## [0.3.0] — 2026-04-30

Third template release: ICTT Cross-L1 Bridge (`KozaTokenHome` /
`KozaTokenRemote`) is feature-complete, fully tested, documented in
Türkçe, and **live on Fuji + kozalakTestL1 yerel test L1**. Phase 1'in
en kritik template'i — `ava-labs/icm-contracts` audited inherit + Türkçe
audit-grade rehber.

### Live Deployment

**Home (Fuji testnet, chain ID 43113):**
- **Contract:** `KozaTokenHome` at [`0x2b1377537690793939DC42530c15DA897AC9D2D9`](https://testnet.snowtrace.io/address/0x2b1377537690793939DC42530c15DA897AC9D2D9)
- **Tx:** `0x4d13579732fef4f06970044a7640e6cfa832368e6b54aed33c8d9d5427061ff0`
- **Bridge token:** `KozaGasToken` (KGAS) v0.1.0 — `0x06451DD4Fb8ebFC19870DacC9568f4364D2A2eB0`
- **Teleporter Registry:** `0xF86Cb19Ad8405AEFa7d09C778215D2Cb6eBfB228` (Avalanche resmi Fuji)
- **Teleporter Manager:** deployer EOA (mainnet öncesi multisig'e migrate)

**Remote (kozalakTestL1, chain ID 9999, yerel Subnet-EVM):**
- **Contract:** `KozaTokenRemote` at `0x53c10844dD2A249eE488EeA66E7Df21365030ceB`
- **Tx:** `0x5d7f16478e9e248a35af8e3ab84807371476850ad0c4545263c5733d7e0ab97a`
- **Token meta:** `Wrapped Koza Gas` / `wKGAS` / 18 decimals
- **Teleporter Registry:** `0x965c383362FF8395f91677f17E9f9bD8E1f58724`
- **Token Home Blockchain ID (Fuji C-Chain):** `0x7fc93d85c6d62c5b2ac0b519c87010ea5294012d1e407030d6acd0021cac10d5`

### Verification Status

- `KozaTokenHome` source verified on Snowtrace via Routescan ([snowscan
  mirror](https://testnet.snowscan.xyz/address/0x2b1377537690793939dc42530c15da897ac9d2d9)).
- `KozaTokenRemote` yerel L1'de — Routescan/Snowtrace yok; bytecode + ABI
  on-chain doğrulandı (read fonksiyonları: `name=Wrapped Koza Gas`,
  `symbol=wKGAS`, `decimals=18`, `totalSupply=0`).
- `registerWithHome()` Remote tarafında çağrıldı; mesaj Teleporter
  messenger üzerinden Warp signed olarak yayımlandı (tx
  `0x920b39...3cf4e`). **Fuji tarafına teslim için manuel `icm-relayer`
  setup beklemede** — Avalanche CLI yerel relayer sadece yerel L1'leri
  izler, cross-Fuji köprü için ayrı relayer config'i gerek (Sprint 7
  Launch'a veya ek bir milestone'a ertelendi).

### Limitations & Follow-ups

- **End-to-end live bridge demo (Fuji → kozalakTestL1 KGAS transfer)
  beklemede.** Kontratlar canlı, smoke test'ler 6/6 yeşil, deploy
  + register mesajları broadcast'lendi; ama gerçek mesaj relay'i
  manuel `icm-relayer` setup gerektiriyor. Bu ek iş Sprint 7 (Launch)
  veya bağımsız bir 3.1 milestone'a ertelendi — Phase 1 audit-grade
  boilerplate hedefi etkilenmez.
- Fork test'ler (Fuji + kozalakTestL1 üzerinden gerçek mesaj relay testi)
  aynı sebepten ertelenmiştir; smoke test'ler `vm.etch + vm.mockCall`
  pattern'iyle Warp precompile'ı simüle ediyor.

## [0.2.0] — 2026-04-30

Second template release: ERC-721 NFT Collection (`KozaCollection`) is
feature-complete, fully tested, documented in Türkçe, and **live on Fuji
testnet with verified source**.

### Live Deployment

- **Network:** Avalanche Fuji Testnet (chain ID 43113)
- **Contract:** `KozaCollection` at [`0x59347BB4365A18BBd92396Fd138E6cEfcDDb79C9`](https://testnet.snowtrace.io/address/0x59347BB4365A18BBd92396Fd138E6cEfcDDb79C9)
- **Owner:** `0x39AEfbC8388da12907A21d9De888B288a9fa5794` (deployer EOA, will be migrated to multisig before mainnet)
- **Name / Symbol:** `Koza Genesis` / `KOZA`
- **Max supply:** 1,000 (testnet — production default 5,000)
- **Mint price:** 0.01 AVAX (testnet — production default 0.05)
- **Royalty:** 5% (ERC-2981)
- **Phase:** `Closed` (allowlist/public açılmadan önce Merkle root + setPhase çağrıları gerek)

### Verification Status

Source verified on Snowtrace/Snowscan via Routescan. Verify çağrısı
`foundry.toml`'daki `[etherscan]` interpolation üzerinden başarısız oldu
(API key "Invalid" hatası); explicit `--verifier-url` + `--etherscan-api-key`
flag'leriyle başarıya ulaştı. Lesson `tasks/lessons.md`'ye eklendi.

### Fixed

- **Verify flow**: env interpolation pitfall'ı `tasks/lessons.md`'de
  belgelenmiş; `forge verify-contract` için CI/manuel çağrılarda explicit
  flag'ler kullanılmalı.

## [0.1.1] — 2026-04-30

### Fixed

- **Snowtrace verify**: `KozaGasToken` Fuji deploy'u artık Routescan üzerinden
  doğrulanmış durumda. Eski `api-testnet.snowtrace.io/api` endpoint'i Routescan'in
  yeni `rs_` formatlı API anahtarlarını tanımıyordu; `foundry.toml` etherscan
  bölümü `https://api.routescan.io/v2/network/{testnet|mainnet}/evm/{43113|43114}/etherscan`
  adreslerine güncellendi. Doğrulanmış kontrat:
  [`0x06451...2eB0`](https://testnet.snowtrace.io/address/0x06451DD4Fb8ebFC19870DacC9568f4364D2A2eB0#code)
  / [snowscan mirror](https://testnet.snowscan.xyz/address/0x06451dd4fb8ebfc19870dacc9568f4364d2a2eb0).

## [0.1.0] — 2026-04-29

First public release: Template 1 (ERC-20 + Custom Gas Token) is feature-complete,
fully tested, documented in Türkçe, and **live on Fuji testnet**.

### Live Deployment

- **Network:** Avalanche Fuji Testnet (chain ID 43113)
- **Contract:** `KozaGasToken` at [`0x06451DD4Fb8ebFC19870DacC9568f4364D2A2eB0`](https://testnet.snowtrace.io/address/0x06451DD4Fb8ebFC19870DacC9568f4364D2A2eB0)
- **Owner:** `0x39AEfbC8388da12907A21d9De888B288a9fa5794` (Bekir Erdem deployer EOA, will be migrated to multisig before mainnet)
- **Initial mint:** 100,000 KGAS to owner
- **Cap:** 1,000,000 KGAS

### Verification Status

Snowtrace source verification pending — Routescan free-tier API key blocked by rate-limit / policy. Contract bytecode is live and all read functions confirmed via `cast call` (name, symbol, cap, totalSupply, owner all match expected). To be retried with a personal Snowtrace API key in v0.1.1.

> **Update (v0.1.1):** Verify resolved by switching `foundry.toml` etherscan endpoint to Routescan; source code now public on Snowtrace/Snowscan.

## [Unreleased]

### Notes

Sprint 3 ICTT bridge yayını v0.3.0 olarak tag'lendi. Aşağıdaki maddeler
detaylı geçmiş içindir; özet için `[0.3.0]` bölümüne bakın.

### Added (Sprint 3 — Template 3 ICTT Cross-L1 Bridge)

- **Template 3**: `src/templates/ictt-bridge/KozaTokenHome.sol` ve
  `KozaTokenRemote.sol` — `ava-labs/icm-contracts` ERC20TokenHome /
  ERC20TokenRemote audited inherit. Custom logic minimum (audit-grade
  prensibi). Phase 1 default senaryosu: Fuji KGAS lock → kozalakTestL1
  wKGAS mint.
- **Yerel test L1 (kozalakTestL1)**: WSL/Ubuntu'da Avalanche CLI ile
  spawn — Subnet-EVM PoA, chain ID 9999, TKOZA gas token, ICM açık,
  Teleporter messenger `0x253b...5fcf` deterministic deploy edilmiş.
  RPC: `http://127.0.0.1:9654/ext/bc/2s1JmPhG.../rpc` (Windows ↔ WSL
  port forwarding ile Foundry test'lerine erişilebilir).
- **Avalanche CLI install script'i**: `scripts/setup/install-avalanche-cli.sh`
  — WSL/Ubuntu üzerine v1.9.6 indir + kur + PATH idempotent ekle.
- **Tests 3C**: `test/templates/ICTTBridge.t.sol` — 6 smoke test:
  KozaTokenHome + KozaTokenRemote constructor + zero-check revert'leri.
  Warp Messenger precompile (`0x0200...0005`) `vm.etch` + `vm.mockCall`
  ikilisiyle mock'landı; minimal `MockTeleporterRegistry` kontratı yazıldı.
  Fork test'ler 3G live deploy'a ertelendi.
- **Deploy script'leri 3D**:
  - `script/deploy/DeployTokenHome.s.sol` — Fuji'ye `KozaTokenHome` yayar.
    Default Teleporter Registry: `0xF86Cb19Ad8405AEFa7d09C778215D2Cb6eBfB228`
    (Avalanche resmi); default token: KGAS v0.1.0.
  - `script/deploy/DeployTokenRemote.s.sol` — kozalakTestL1'e
    `KozaTokenRemote` yayar. `REMOTE_TOKEN_HOME_BLOCKCHAIN_ID` ve
    `REMOTE_TOKEN_HOME_ADDRESS` env'den okur.
  - İkisi de Sprint 1/2 pattern'iyle: `run()` (env-driven) + `deploy(...)`
    (parametric, test-friendly).
- **Genesis 3E**: `genesis/ictt-bridge.json` — ICTT hedef L1 için
  Subnet-EVM genesis preset; `warpConfig` zorunlu açık, contract
  deployer + tx allowlist placeholder'ları, deploy ücreti notu.
  `genesis/README.md` ICTT senaryosunu içerecek şekilde güncellendi.
- **Türkçe rehber 3F**: `docs/tr/03-templateler/ictt-bridge.md` —
  3 senaryo (Native↔ERC20, ERC20↔ERC20, ERC20↔Native), 3 katmanlı
  mimari (ICM → Teleporter → ICTT), 8 audit-grade güvenlik uyarısı
  (custom bridge yasağı, multisig manager, version pinning, replay,
  multi-hop trust, decimals scaling, vs.), 8 adımlı step-by-step deploy
  rehberi, ortak hatalar + çözümleri, Foundry test komutları, mainnet
  öncesi production checklist.

### Fixed (Sprint 3)

- **Foundry config**: `foundry.toml` `solc = "0.8.34"` global pin'i
  kaldırıldı, `auto_detect_solc = true` aktifleştirildi. icm-contracts
  `pragma 0.8.25` sıkı pin'iyle çakışma çözüldü; multi-version compile
  artık çalışıyor (KozaGasToken/KozaCollection 0.8.34, ICTT contract'lar
  0.8.25 yan yana). 78/78 test pass.
- **lessons.md**: Sprint 3'te öğrenilen 3 yeni pattern eklendi —
  `auto_detect_solc` ile multi-version compile, Warp precompile için
  `vm.etch + vm.mockCall` mock pattern, wrapper kontratlarda library
  logic'ini değil sadece kendi katmanını test etme prensibi.

### Added
- Project initialized (Phase 1 Sprint 0, 2026-04-29)
- Foundry config (Solidity 0.8.34, optimizer 200, via_ir, fuzz 10000, invariant 1000)
- Remappings: OpenZeppelin Contracts v5.3+, ava-labs/icm-contracts (Teleporter + ICTT)
- Initial documentation structure (`docs/tr/`, `docs/en/`)
- MIT License
- README seed with Phase 1 template roadmap
- SECURITY.md disclosure policy
- CONTRIBUTING.md (Türkçe + English)
- `.env.example` with Teleporter messenger address
- GitHub Actions CI workflows (build/test/slither/aderyn + release)
- README v2: branding (`kozalak-L1`), badges (CI, License, Solidity, Foundry, Avalanche, OZ), ASCII architecture diagram, value proposition, Phase 1/2/3 roadmap, "Why Avalanche?" section

### Fixed
- CI: Slither and Aderyn jobs now skip when `src/` has no Solidity files (Sprint 0 → Sprint 1 transition)
- CI: Aderyn switched from `cargo install` (upstream svm-rs-builds bug) to pre-built binary installer
- CI: `actions/checkout` upgraded to v5 (Node 24 compat)
- README: clarified ecosystem positioning (production-grade Türkçe toolkit pozisyonu, "anadilde rehber yok" abartısı düzeltildi)
- `chore(fmt)`: `bracket_spacing=false` to match Solidity ecosystem default

### Added (Sprint 1)
- **Template 1**: `src/templates/erc20-gas/KozaGasToken.sol` — ERC-20 + Capped + Permit + Ownable2Step (audit-grade boilerplate)
- **Tests 1B**: `test/templates/ERC20Gas.t.sol` — 26 unit + fuzz tests covering constructor, mint, burn, ERC-20 standard, ERC-2612 permit (valid/expired/replay), Ownable2Step (transfer, accept, cancel)
- **Invariants 1B**: `test/templates/ERC20Gas.invariants.t.sol` — handler-based stateful fuzzing with 3 invariants (totalSupply ≤ cap, sum(balances) == totalSupply, owner immutable)
- **Coverage**: 100% lines / statements / branches / functions on KozaGasToken.sol
- **Deploy script 1C**: `script/deploy/DeployERC20Gas.s.sol` with two entry points: `run()` (env-driven for `forge script`) and `deploy(...)` (parametric, test-friendly)
- **Smoke tests 1C**: `test/templates/DeployERC20Gas.t.sol` — 3 cases: defaults, custom params, no initial mint
- `tasks/lessons.md` capturing Foundry env state pitfall, solc/pragma pinning, CI guard pattern, OZ-first audit-grade principle
- **Genesis 1D**: `genesis/erc20-gas-token.json` — Avalanche9000 Subnet-EVM genesis with custom native gas token, ICM (Warp) enabled, `contractNativeMinter` and `contractDeployerAllowList` precompile placeholders
- **Genesis 1D docs**: `genesis/README.md` — chainID guidance, allocation hex helpers, multisig admin requirements, mainnet checklist, Avalanche CLI deployment commands
- **Türkçe rehber 1E**: `docs/tr/03-templateler/erc20-gas.md` (295 lines) — kapsamlı deployment guide: ne işe yarar (Senario A/B), Avalanche/Solidity özellikleri, güvenlik uyarıları (multisig owner, immutable cap, permit replay), adım-adım Fuji deploy, ortak hatalar + çözümleri, Foundry test komutları, ICTT bridge'e geçiş öngörüsü
- **Avalanche 101 (1F)**: `docs/tr/01-avalanche-101.md` — Türkçe ekosistem girişi: Primary Network 3-chain mimari, Avalanche9000 / Etna upgrade etkileri, Sovereign L1 türleri (Subnet-EVM / HyperSDK / Custom VM), ICM-Teleporter-ICTT katmanları, geliştirici araçları (CLI, AvaCloud, Foundry), hibe programları (Retro9000 $40M, Codebase $250K, Multiverse), Türkiye topluluğu (Team1 TR, SCDEVTR, üniversite kulüpleri)
- **Güvenlik Checklist (1F)**: `docs/tr/04-guvenlik.md` — audit-grade pre-deploy checklist (22 madde), Solidity 0.8.34+ best practices (pragma pin, custom errors, unchecked discipline, ERC-7201 storage), 9 attack vector (reentrancy, integer overflow, oracle manipulation, flash loan, MEV, signature replay, access control, bridge trust, custom bridge yasağı), Foundry test discipline (3 katman, coverage %95+, fuzz run sayıları), 5 araçlı toolchain (Slither/Aderyn/Halmos/Echidna/Mythril), audit stratejisi (Tier 1-2-3), 2025 case studies (Bybit/Cetus/Balancer V2/Sonne/Nemo), AI-generated code uyarısı, operational security (multisig, key discipline, RPC, frontend)

### Added (Sprint 2 — Frontend)

Marketing & landing site for `kozalak.bekirerdem.dev`. Stack and structure
finalized in collaboration with Gemini 3.1 Pro on UI/UX side; Claude
contributed scaffolding, design tokens, type/lint hygiene, and final
type-error cleanup.

- **Scaffold**: Astro 5 + Tailwind v4 (`@tailwindcss/vite`) + GSAP + Lenis,
  TypeScript strict, Cloudflare Pages-friendly static build
- **Design system** (`src/styles/global.css`):
  - Color tokens: `bg-primary` `#0a0a0a`, `bg-pure`, `bg-card-dark/light`,
    brand `koza-red` / `red-hot` / `red-deep` / `orange`, `koza-blue` /
    `blue-deep`, neutrals + `true-white` / `true-black`
  - Typography: Cabinet Grotesk (Fontshare CDN) for display, Inter
    (`@fontsource/inter` 400-700) for sans
  - **Avax-style chamfer utilities**: `chamfer-tr`, `chamfer-br`, `chamfer-bl`,
    `chamfer-bl-br`, `chamfer-right` — 64px clip-path corner cuts
  - `split-line` / `split-mask` helpers for line-by-line text reveal
- **Layout** (`src/layouts/Layout.astro`): page shell with OG/Twitter meta,
  Cabinet Grotesk preconnect, Lenis smooth-scroll bootstrap (1.2s
  exp-out, smoothWheel)
- **Nav** (`src/components/Nav.astro`): fixed top nav with custom Koza
  wordmark SVG (crystal in red + path-based "Koza" + "-L1" suffix),
  center menu with external arrow indicators, light/dark theme toggle,
  hot-pill "GitHub'da İncele" CTA
- **Hero** (`src/components/Hero.astro`): full-viewport 4-column asymmetric
  grid (1-2-1 ratio) — left col stacks pitch card + Powered-by Avalanche
  gradient card, center spans 2 cols with abstract orbital network SVG
  (central pulsing red core + 3 orbiting nodes with `feGaussianBlur`
  glow), right col with docs + "Kozalak-L1'i Keşfet" CTA. GSAP timeline
  for entrance + continuous orbital rotation + central pulse
- **Stacking cards** (`src/components/StackingCards.astro`): 5 sticky
  cards with chamfer-tr top-right cut, offset top values (`10vh + index*6.5rem`)
  for visible peek tabs, multi-color rotation (red-deep, blue-deep,
  red-hot, orange, dark), 65/35 horizontal split (number + heading +
  body left, oversized monochrome SVG icon right)
- **Index page** (`src/pages/index.astro`): two-layer scroll trick — z-0
  pinned "WHY KOZALAK-L1" mega title (`sticky top-0 h-screen`,
  `pointer-events-none`) sits as permanent backdrop while z-10 stacking
  cards scroll over it via `mt-[100vh] pt-[20vh]`. Footer carries Koza
  wordmark + GitHub / Live Contract / Team1 TR / © attribution

### Fixed (Sprint 2 — Frontend)

- `astro check`: 0 errors / 0 warnings / 0 hints
- `astro.config.mjs`: bypass Vite Plugin structural type mismatch between
  Astro 5's pinned Vite and the user-installed Vite that
  `@tailwindcss/vite` resolves against (runtime fully compatible, JSDoc
  cast added)
- `Hero.astro`: removed unused `masterSVG` declaration
- `index.astro`: replaced `<div class="split-line">` inside `<h2>` with
  `<span class="split-line">` (semantic HTML — `<h2>` may not contain
  block-level `<div>`)
- `StackingCards.astro`: replaced arbitrary hex `bg-[#B8232C]` /
  `bg-[#0046C8]` with theme-token utilities `bg-kozalak-red-deep` /
  `bg-kozalak-blue-deep` (Tailwind LSP autocomplete now resolves; tokens
  centralized for theme consistency)

### Coming Soon (Phase 1 Sprints)
- v0.1.0 — ERC-20 + Custom Gas Token template ✅
- v0.1.1 — Snowtrace verify retry (Sprint 1G follow-up) ✅
- v0.2.0 — ERC-721 Collection (allowlist + royalty) ✅
- v0.3.0 — ICTT Cross-L1 Bridge ✅
- v0.3.1 — End-to-end Fuji ↔ kozalakTestL1 live bridge demo (icm-relayer setup)
- v0.4.0 — Soulbound Credential (ERC-5114)
- v0.5.0 — Treasury Multisig + Timelock
- v0.6.0 — EN docs + landing site polish

---

[Unreleased]: https://github.com/Bekirerdem/Kozalak-L1/compare/v0.3.0...HEAD
[0.3.0]: https://github.com/Bekirerdem/Kozalak-L1/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/Bekirerdem/Kozalak-L1/compare/v0.1.1...v0.2.0
[0.1.1]: https://github.com/Bekirerdem/Kozalak-L1/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/Bekirerdem/Kozalak-L1/releases/tag/v0.1.0
