# Template 3 — ICTT Cross-L1 Bridge

> **Audit-grade cross-L1 köprü contract'ları** — ava-labs/icm-contracts denetlenmiş
> Token Home + Token Remote pattern'i. Custom bridge logic YOK; bütün mesajlaşma,
> multi-hop, fee modeli ve yeniden oynatma koruması Avalanche'in resmi
> Teleporter altyapısı tarafından sağlanır. **Phase 1'in en kritik template'i.**

## Ne işe yarar?

ICTT (Inter-Chain Token Transfer), iki ya da daha fazla **Avalanche L1**
arasında bir token'ı kilitle-mintele veya yak-aç (lock-mint / burn-release)
modelinde transfer eder. Custom bridge yazmadan, **denetlenmiş** ortak bir
katmanı (Teleporter messenger) kullanır.

`KozaTokenHome.sol` ve `KozaTokenRemote.sol` üç farklı senaryoyu tek
kontrat-çifti ile destekler. Phase 1 default'u **Senaryo B**.

### Senaryo A — Native AVAX → ERC-20 representation (yeni L1'de wAVAX)

- **Kim için:** Avalanche C-Chain'den yeni bir L1'e AVAX taşımak isteyen DeFi
  protokolleri, AVAX collateral kullanan stablecoin'ler.
- **Home contract:** `NativeTokenHome` (parent değişir, KozaTokenHome'un
  yerine `NativeTokenHome` inherit edilir).
- **Remote contract:** `KozaTokenRemote` (ERC20TokenRemote inherit, mevcut hali).
- **Akış:** C-Chain'de AVAX deposit edilir → hedef L1'de wAVAX mint edilir.
- **Riski:** Native asset kilidi sağlam izolasyon ister; multisig manager şart.

### Senaryo B — ERC-20 → ERC-20 representation (KGAS ↔ wKGAS) ⭐

- **Kim için:** Phase 1 default — Fuji'de canlı `KozaGasToken` (KGAS)'ı yeni
  L1'e taşımak. Türk geliştirici ekosistemi için en eğitici akış.
- **Home contract:** `KozaTokenHome` (ERC20TokenHome inherit).
- **Remote contract:** `KozaTokenRemote` (ERC20TokenRemote inherit).
- **Akış:** Fuji'de KGAS approve + lock → kozalakTestL1'de wKGAS mint. Geri
  yönde wKGAS burn → Fuji'de KGAS unlock.
- **Avantaj:** En yaygın "wrapped token" mental modeli, kullanıcı UX'i basit.

### Senaryo C — ERC-20 → Native gas token (KGAS → kozalakTestL1 native TKOZA mint)

- **Kim için:** Avalanche9000'in en güçlü pattern'i — bridge ile gelen token,
  hedef L1'in **native fee parası** olur. Tokenomics olarak en bütünleşik.
- **Home contract:** `KozaTokenHome` (ERC20TokenHome inherit, mevcut hali).
- **Remote contract:** `NativeTokenRemote` inherit (KozaTokenRemote yerine).
- **Akış:** Fuji'de KGAS lock → kozalakTestL1'de **native TKOZA mint** (validator'a
  gas olarak geri verilebilir).
- **Riski:** Initial supply ve gas tokenomic'inin ICTT supply ile uyumlu kurulması
  gerek; yanlış parametrelerle deflasyon/enflasyon spirali oluşabilir.

> **Önerilmediği durumlar:** Tek-yönlü (one-way) airdrop için ICTT aşırı
> karmaşıktır — basit `transfer` + Merkle airdrop yeterli. Cross-rollup
> (Avalanche dışı) köprü için ICTT yetersiz, third-party bridge gerek.

---

## Avalanche / Solidity Özellikleri

### Üç Katman: ICM → Teleporter → ICTT

```
┌─────────────────────────────────────────────┐
│  ICTT (uygulama katmanı — token transfer)   │  ← bizim contract'larımız
│  TokenHome ↔ TokenRemote                    │
├─────────────────────────────────────────────┤
│  Teleporter (mesaj katmanı — generic msg)   │  ← Avalanche denetlenmiş
│  TeleporterMessenger + Registry             │     (üzerine custom yazılmaz)
├─────────────────────────────────────────────┤
│  ICM / Warp (precompile katmanı — VM-level) │  ← Subnet-EVM yerleşik
│  0x0200000000000000000000000000000000000005 │
└─────────────────────────────────────────────┘
```

- **ICM (Warp)**: Validator imzalı off-chain mesaj. Subnet-EVM precompile.
- **Teleporter**: ICM üzerinde mesaj router'ı + version registry. Audited.
- **ICTT**: Teleporter'ı kullanan token transfer protokolü. Audited.

Biz sadece **ICTT'nin üst katmanına ince bir wrapper** yazıyoruz. Audit-grade
prensibi: alt katmanlara dokunma.

### Solidity 0.8.25 — sıkı pin

`ava-labs/icm-contracts` reposu `pragma solidity 0.8.25` kesin pin'iyor (caret
yok). Bizim `KozaTokenHome` ve `KozaTokenRemote` da aynı pragma'yı kullanır.
`foundry.toml`'da `auto_detect_solc = true` aktif → KozaGasToken (0.8.34) ve
KozaTokenHome (0.8.25) yan yana derlenir.

### OpenZeppelin v5.3+ Upgradeable

ICTT contract'ları upgradeable (proxy-uyumlu) yazılmış (ERC-7201 storage
namespacing). Biz non-upgradeable wrapper kullanıyoruz; upgradeability
production'da gerekirse `KozaTokenHomeUpgradeable` versiyonuna geçilir.

### Teleporter Registry — version pinning

Teleporter messenger zaman içinde upgrade edilebilir (yeni versiyon
deploy edilir, registry'ye eklenir). `minTeleporterVersion` parametresi
contract'ın hangi minimum versiyondan mesaj alacağını sabitler. Yanlış
yapılandırma = bridge çalışmaz veya eski/güvensiz versiyondan mesaj alır.

---

## Audit-Grade Güvenlik Uyarıları

### 1. Custom bridge YASAK

Cross-chain köprüler en sık hack hedefidir (Ronin: $625M, Wormhole: $325M,
Nomad: $190M). **Asla** kendi köprü mantığını yazma. ava-labs/icm-contracts
audited katmanını miras al; sadece access control ekle.

### 2. `teleporterManager` mutlaka multisig

Mainnet öncesi `teleporterManager` parametresi Safe (Gnosis Safe) multisig
adresi olmalı. Bu adres:

- Teleporter version migration'larını yönetir
- Pause/unpause yapabilir
- **Tek nokta güven (single point of trust)** — EOA = saldırı vektörü

### 3. `tokenAddress` immutable olmalı

`KozaTokenHome` constructor'ında verilen `tokenAddress` deploy sonrası
değişmez. Token kontratı (KGAS) Ownable2Step + cap'li olmalı (Sprint 1
KozaGasToken bu kriterleri karşılar).

### 4. Multi-hop transfer ek güven

ICTT multi-hop'u destekler: A → B → C zinciri. Her ara halka, ayrı bir
Home/Remote çiftine güvenir. Multi-hop kullanmadan önce **trust graph'i**
çıkar.

### 5. Replay protection — zaten ICTT'de var

Teleporter messenger her mesaj için unique `messageID` kullanır;
yeniden oynatma (replay attack) koruması parent contract'ta. Custom
nonce ekleme gereksiz.

### 6. `requirePrimaryNetworkSigners=true`

Genesis'te bu flag MUTLAKA `true` olmalı. Aksi halde sahte L1'de mesaj
imzalayan validator'lar bridge'i ele geçirebilir. Sprint 3E
`genesis/ictt-bridge.json`'da default açık.

### 7. Yeniden giriş (reentrancy)

Parent `SendReentrancyGuardUpgradeable` zaten send/receive flow'unu kilitler.
Override ederken `nonReentrant` modifier'ını ezme.

### 8. Decimals uyumsuzluğu

Home ve Remote token decimals farklı olabilir (örn. 18 vs 6). ICTT
`TokenScalingUtils` ile otomatik ölçek düzeltir, ama deploy sırasında
`tokenHomeDecimals` parametresi DOĞRU verilmelidir. Yanlış değer = silent
miktar bozulması.

---

## Adım Adım Deploy

> **✅ Uçtan uca doğrulandı (v0.3.1, 2026-06-22).** Gerçek transfer kanıtı (tüm
> tx hash'leri) için `ictt-demo-kanit.md`'ye, tek komutla yeniden üretmek için
> `scripts/demo/run-ictt-demo.sh`'a bakın.
>
> **Önemli mimari notu:** Remote, **Fuji'ye gerçek bir sovereign L1** olarak
> deploy edilir (`avalanche blockchain deploy <l1> --fuji --use-local-machine`),
> yerel network'e DEĞİL. Yerel network ile Fuji ayrı P-Chain'lere sahiptir;
> yerel bir L1, Fuji C-Chain'in Warp imzalarını doğrulayamaz → cross-network ICM
> çalışmaz. Home ve Remote aynı primary network'te (Fuji) olmalıdır.

### Önkoşullar

- [x] Avalanche CLI v1.9.6+ kurulu (WSL/Linux/macOS)
  - Windows için: `bash scripts/setup/install-avalanche-cli.sh`
- [x] Yerel L1 spawn edilmiş: `avalanche blockchain create kozalakTestL1 && avalanche blockchain deploy kozalakTestL1`
- [x] Fuji'de KGAS token canlı: `0x06451DD4Fb8ebFC19870DacC9568f4364D2A2eB0`
- [x] `.env` `PRIVATE_KEY` + `SNOWTRACE_API_KEY` doluymalı

### 1. Fuji blockchain ID ve Teleporter Registry adresini öğren

```bash
# Fuji C-Chain Teleporter Registry — Avalanche resmi:
echo "0xF86Cb19Ad8405AEFa7d09C778215D2Cb6eBfB228"

# Fuji C-Chain blockchain ID — P-Chain'den:
avalanche primary describe --network fuji | grep "C-Chain blockchain ID"
# Veya cast ile P-Chain RPC sorgu (Avalanche docs'a bak)
```

### 2. KozaTokenHome'u Fuji'ye deploy et

```bash
forge script script/deploy/DeployTokenHome.s.sol \
  --rpc-url fuji --broadcast --verify
```

`Default'lar:` Fuji Teleporter Registry, KGAS token (v0.1.0), 18 decimals,
deployer EOA = manager. Deploy çıktısında **KozaTokenHome adresini** kaydet.

### 3. kozalakTestL1 Teleporter Registry adresini öğren (WSL içinde)

```bash
avalanche blockchain describe kozalakTestL1 | grep -A 2 "Teleporter Registry"
```

### 4. `.env`'i güncelle

```bash
REMOTE_TELEPORTER_REGISTRY=<3.adımdan>
REMOTE_TOKEN_HOME_BLOCKCHAIN_ID=<1.adımdan, bytes32>
REMOTE_TOKEN_HOME_ADDRESS=<2.adımdan>
```

### 5. KozaTokenRemote'u kozalakTestL1'e deploy et

```bash
forge script script/deploy/DeployTokenRemote.s.sol \
  --rpc-url $KOZALAK_TEST_L1_RPC_URL --broadcast
```

Yerel L1'de Routescan/Snowtrace yok; verify atla.

### 6. registerWithHome çağır (Remote tarafta)

```bash
cast send $REMOTE_ADDRESS "registerWithHome((address,uint256))" \
  "(0x0000000000000000000000000000000000000000,0)" \
  --rpc-url $KOZALAK_TEST_L1_RPC_URL \
  --private-key $PRIVATE_KEY
```

`feeInfo` boş geçilebilir (relayer ücreti yok). Bu mesaj Home tarafına
"Ben buradayım, mesaj alabilirim" der. Yapılmazsa `send()` revert eder.

### 7. Test transfer — Fuji'den kozalakTestL1'e KGAS

```bash
# 7a. Fuji'de KGAS approve et:
cast send 0x06451DD4Fb8ebFC19870DacC9568f4364D2A2eB0 \
  "approve(address,uint256)" $HOME_ADDRESS 1000000000000000000 \
  --rpc-url fuji --private-key $PRIVATE_KEY

# 7b. Home.send() çağır:
cast send $HOME_ADDRESS \
  "send((bytes32,address,address,address,uint256,uint256,uint256,address),uint256)" \
  "($REMOTE_BLOCKCHAIN_ID,$REMOTE_ADDRESS,$RECIPIENT,0x0000...0,0,0,250000,0x0000...0)" \
  1000000000000000000 \
  --rpc-url fuji --private-key $PRIVATE_KEY

# 7c. icm-relayer çalışıyorsa kozalakTestL1'de mint görülür:
cast call $REMOTE_ADDRESS "balanceOf(address)" $RECIPIENT \
  --rpc-url $KOZALAK_TEST_L1_RPC_URL
```

### 8. Relayer not'u

ICTT mesajları otomatik relayer ile taşınır. **Avalanche CLI yerel deploy'da
relayer otomatik başlar.** Production'da `icm-relayer` ayrı bir Go binary olarak
çalışır (Avalanche'in resmi relayer'ı veya kendi relayer'ınız).

---

## Ortak Hatalar ve Çözümleri

### "Source not registered"
**Sebep:** `registerWithHome` çağrılmadan `send()` denendi.
**Çözüm:** Adım 6'yı çalıştır.

### "Insufficient teleporter version"
**Sebep:** `minTeleporterVersion` registry'deki latest'tan büyük veya çok
düşük. Versiyon mismatch.
**Çözüm:** Her iki zincirin Teleporter Registry'sinde `latestVersion()`
karşılaştır, ikisinin ortak alt sınırını kullan.

### "Warp message not found"
**Sebep:** Relayer çalışmıyor veya mesaj henüz finalize olmadı.
**Çözüm:** Yerel: `avalanche network status` ile node'lar çalışıyor mu kontrol
et. Production: relayer log'larına bak.

### `vm.etch` smoke test'leri pas geçiyor ama gerçek deploy fail
**Sebep:** Smoke test Warp precompile mock'lar; gerçek L1'de Subnet-EVM
warpConfig kapalı olabilir.
**Çözüm:** L1 genesis'te `warpConfig` aktif mi doğrula (`avalanche blockchain
describe`).

### Deploy fail: "TokenHome: zero token home address" (Remote)
**Sebep:** `tokenHomeAddress` parametresi `address(0)`.
**Çözüm:** Önce Home'u deploy et, adresini `.env REMOTE_TOKEN_HOME_ADDRESS`'a
yaz.

### Decimals scaling tutarsızlığı
**Sebep:** Home decimals 18, Remote decimals 6 ama parametrede 18 verildi.
**Çözüm:** `tokenHomeDecimals` ZORUNLU olarak Home tarafındaki gerçek değeri
yansıtmalı. KGAS (Sprint 1) 18, wKGAS Remote 18 → uyumlu.

### `forge script` deploy'da `EvmError: StackUnderflow`
**Sebep:** `forge script`/`forge test` kontrat kodunu forge'un LOCAL EVM'inde
çalıştırır; Subnet-EVM'e özel Warp precompile (`0x0200…05`) orada yoktur, ICTT
constructor onu çağırınca stack hatası verir.
**Çözüm:** Remote'u `forge create` ile deploy et — constructor doğrudan hedef
zincirde (Warp precompile mevcut) çalışır. Smoke test'ler precompile'ı
`vm.etch + vm.mockCall` ile mock'lar.

### Relayer başlamıyor: `unknown flag: --config`
**Sebep:** `icm-relayer` binary flag'i `--config-file`'dır, `--config` değil.
**Çözüm:** `icm-relayer --config-file <path>`. Relayer'ı oturum boyunca canlı
tutmak için kendi terminalinizde veya `nohup` ile çalıştırın (komut bitince
child process SIGHUP alıp ölebilir).

### Relayer: `nonce too low: next nonce N, tx nonce N-1`
**Sebep:** Relayer mesaj teslimi için bir EOA key kullanır (deploy'da `--key`).
Aynı key'le manuel tx (deploy/register/send) gönderirseniz nonce ilerler,
relayer'ın cache'i geride kalır.
**Çözüm:** Relayer'ı fresh başlatın (nonce'u zincirden alır) ve relay sürerken
o key ile manuel tx GÖNDERMEYİN. Mümkünse relayer'a ayrı, fonlu bir key verin.

### Deploy: `can't airdrop to default address on public networks`
**Sebep:** Genesis alloc'unda well-known test adresi (ewoq vb.) airdrop'u var;
Fuji/mainnet bunu reddeder.
**Çözüm:** `avalanche blockchain create <l1> --force --genesis <dosya>` ile
genesis'i yalnızca kendi deployer adresinize airdrop yapacak şekilde düzenleyin
(validator manager precompile'larını ve `warpConfig`'i koruyun).

---

## Foundry Test Komutları

```bash
# Sadece ICTT smoke testler:
forge test --match-path "test/templates/ICTTBridge*" -vv

# Coverage:
forge coverage --match-path "test/templates/ICTTBridge*" \
  --report summary

# Fork test (ileride 3G sonrası):
forge test --match-path "test/templates/ICTTBridge.fork*" \
  --fork-url fuji
```

Smoke test'ler Warp precompile'ı `vm.etch` + `vm.mockCall` ile mock'lar:

```solidity
vm.etch(0x0200000000000000000000000000000000000005, hex"01");
vm.mockCall(
    0x0200000000000000000000000000000000000005,
    abi.encodeWithSignature("getBlockchainID()"),
    abi.encode(bytes32(uint256(43113)))
);
```

Bu pattern Sprint 3'ün öğretici keşiflerinden — Avalanche L1 precompile'larını
test etmek için reusable.

---

## Production Checklist (Mainnet öncesi)

- [ ] `KozaTokenHome` ve `KozaTokenRemote` deploy edilmiş, Snowtrace/explorer
      verified
- [ ] `teleporterManager` her iki tarafta multisig (Safe)
- [ ] `minTeleporterVersion` ekosistem güncel — Avalanche release notes ile
      eşleşiyor
- [ ] `tokenAddress` (Home) immutable, audit edilmiş ERC-20 (KGAS gibi)
- [ ] Fuji'de en az 1 hafta entegrasyon test çalıştırıldı
- [ ] icm-relayer production setup hazır (HA, monitoring, retry policy)
- [ ] Bug bounty (Immunefi) açık, en az $50K bridge contract'ı için
- [ ] Pause mekanizması test edildi (kritik incident senaryosunda devre dışı
      bırakma)
- [ ] Multi-hop kullanılıyorsa trust graph dökümante edilmiş

---

## Daha Fazla

- ICTT spec: https://github.com/ava-labs/icm-contracts/tree/main/contracts/ictt
- Teleporter dokümantasyonu: https://docs.avax.network/build/cross-chain/teleporter
- Avalanche CLI ICM rehberi: https://docs.avax.network/tooling/cross-chain/teleporter-cli
- Audit raporları (ava-labs/icm-contracts): repo'da `audits/` klasörü
- Türkçe Avalanche 101: `docs/tr/01-avalanche-101.md`
- Audit-grade güvenlik checklist: `docs/tr/04-guvenlik.md`
