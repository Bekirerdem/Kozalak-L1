<div align="center">

<img src="./.github/assets/kozalak-logo.png" alt="KOZALAK-L1 logo" width="96" />

# KOZALAK-L1

**Türk geliştiriciler için Avalanche L1 starter kit**

_Audit-grade Solidity şablonları · Subnet-EVM · ICTT cross-L1 köprü · Türkçe rehber_

[![CI](https://github.com/Bekirerdem/Kozalak-L1/actions/workflows/ci.yml/badge.svg)](https://github.com/Bekirerdem/Kozalak-L1/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Solidity](https://img.shields.io/badge/Solidity-0.8.34-blue.svg)](https://soliditylang.org)
[![Foundry](https://img.shields.io/badge/Foundry-1.5%2B-orange.svg)](https://book.getfoundry.sh)
[![Built on Avalanche](https://img.shields.io/badge/Built%20on-Avalanche-E84142.svg)](https://www.avax.network)
[![OpenZeppelin](https://img.shields.io/badge/OpenZeppelin-v5.3+-4E5EE4.svg)](https://www.openzeppelin.com)
[![Templates Live](https://img.shields.io/badge/Fuji-5%20templates%20live-success?logo=avalanche)](#-şablonlar)

[Ne Bu](#-ne-bu) · [Mimari](#%EF%B8%8F-mimari) · [Şablonlar](#-şablonlar) · [Hızlı Başlangıç](#-hızlı-başlangıç) · [Niye Avalanche](#-niye-avalanche) · [Yol Haritası](#%EF%B8%8F-yol-haritası) · [Güvenlik](#%EF%B8%8F-güvenlik) · [Katkı](#-katkı)

</div>

---

## 🎯 Ne Bu

**`KOZALAK-L1` = "create-react-app, ama Türk dev için Avalanche Solidity"**

Türk Solidity geliştiricilerinin Avalanche'da kendi blockchain'ini (Sovereign L1) ve smart contract'larını **production-grade şekilde** deploy etmesi için hazırlanmış açık kaynak audit-grade Solidity boilerplate kütüphanesi.

### 📖 Senaryo

> **Patika.dev mezunu bir Solidity geliştiricisi.** Avalanche Build Games hackathon'una katılmak istiyor. Solidity'yi temel düzeyde biliyor ama "kendi token'ımı nasıl deploy ederim, ICTT ile L1'ler arası nasıl köprü kurarım, audit-grade contract nasıl yazılır" bilmiyor.
>
> **Şu an:** Bir hafta İngilizce docs + 10 farklı tutorial + Stack Overflow arasında kayboluyor.
>
> **`KOZALAK-L1` ile:** `git clone` → `forge install` → audit-grade şablonu kendi projesine uyarla → Türkçe rehberi takip et → 1 saatte güvenli şekilde Fuji'ye deploy et.

### Niye Var?

| Sorun                                          | Mevcut Durum                                                                          | `KOZALAK-L1` Çözümü                                         |
| ---------------------------------------------- | ------------------------------------------------------------------------------------- | -------------------------------------------------------- |
| **Avalanche9000 ile L1 kurulumu %99 ucuzladı** | Ama production-grade Türkçe toolkit yok                                               | Türkçe + audit-grade boilerplate                         |
| **Hackathon → production geçişi zor**          | Audit pattern'leri, ICTT lock/burn, ERC-7201 storage Türkçe yazılı kaynaklar yetersiz | Audited primitive'ler üzerine kurulu, denenmiş şablonlar |
| **Türk Avalanche topluluğu büyüyor**           | Team1 TR + Bursa Koza DAO + üniversite kulüpleri aktif, ortak kod altyapısı eksik     | Topluluk içi ortak temel + Türkçe dokümantasyon          |

### Kim İçin?

- 🎓 Patika.dev, Kodluyoruz, BTK Akademi ve diğer Türk eğitim programlarının mezunları
- 🏗️ Hackathon-grade'den production'a geçen Türk Solidity geliştiricileri
- 🏛️ Avalanche'da kendi L1'ini kurmak isteyen küçük ekipler ve öğrenci kulüpleri
- 💰 Avalanche Foundation grant başvurusu (Retro9000, Codebase) hazırlayanlar

---

## 🏗️ Mimari

```
┌──────────────────────────────────────────────────────────────────┐
│                  KOZALAK-L1 — Avalanche Starter Kit                 │
└──────────────────────────────────┬───────────────────────────────┘
                                   │
        ┌──────────────────────────┼──────────────────────────┐
        │                          │                          │
┌───────▼──────────┐    ┌──────────▼──────────┐   ┌───────────▼─────────┐
│  Solidity        │    │  Subnet-EVM         │   │  Türkçe Rehber      │
│  Şablonları      │    │  Genesis Configs    │   │                     │
│                  │    │                     │   │  • Adım adım deploy │
│  • ERC-20 Gas    │    │  • Custom gas token │   │  • Audit checklist  │
│  • ERC-721 NFT   │    │  • Custom chain ID  │   │  • Avalanche 101    │
│  • ICTT Bridge   │    │  • Validator set    │   │  • ICTT pattern'leri│
│  • Soulbound     │    │                     │   │                     │
│  • Treasury      │    │                     │   │                     │
└──────────────────┘    └─────────────────────┘   └─────────────────────┘
                                   │
                                   │ üzerine inşa
                                   ▼
        ┌─────────────────────────────────────────────────────┐
        │  OpenZeppelin v5.3+ · ava-labs/icm-contracts        │
        │  (audit edilmiş primitive'ler)                      │
        └─────────────────────────────────────────────────────┘
                                   │
                                   │ deploy hedefi
                                   ▼
        ┌─────────────────────────────────────────────────────┐
        │  Avalanche C-Chain (Fuji 43113 / Mainnet 43114)     │
        │  ◄────────── ICM/ICTT ──────────►                   │
        │  Custom Sovereign L1 (kendi chain ID, kendi gas)    │
        └─────────────────────────────────────────────────────┘
```

---

## 📦 Şablonlar

| #   | Şablon                           | Durum          | Açıklama                                                                                                                                                                                                                               |
| --- | -------------------------------- | -------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | **ERC-20 + Custom Gas Token**    | ✅ v0.1.0      | Subnet-EVM için native gas token — `Ownable2Step`, `Capped`, `Permit` (EIP-2612). [Live on Fuji](https://testnet.snowtrace.io/address/0x06451DD4Fb8ebFC19870DacC9568f4364D2A2eB0)                                                      |
| 2   | **ERC-721 NFT Collection**       | ✅ v0.2.0      | Allowlist (Merkle), royalty (ERC-2981), 3-faz mint (Closed/Allowlist/Public). [Live on Fuji](https://testnet.snowtrace.io/address/0x59347BB4365A18BBd92396Fd138E6cEfcDDb79C9)                                                          |
| 3   | **ICTT Cross-L1 Köprü**          | ✅ v0.3.2      | `ava-labs/icm-contracts` audited inherit — Token Home ([Fuji C-Chain](https://testnet.snowtrace.io/address/0x2b1377537690793939DC42530c15DA897AC9D2D9)) + Token Remote (Fuji L1). **Çift yön uçtan uca doğrulandı:** KGAS lock→wKGAS mint **+** wKGAS burn→KGAS unlock (round-trip) ([kanıt](docs/tr/03-templateler/ictt-demo-kanit.md)), tek komutla tekrarlanabilir (`scripts/demo/run-ictt-demo.sh`) |
| 4   | **Soulbound Credential**         | ✅ v0.4.0      | Account-bound ERC-721 + `AccessControl` + on-chain metadata + revoke-flag — devredilemez eğitim/topluluk sertifikası, issuer-only mint. [Live on Fuji](https://testnet.snowtrace.io/address/0xCFdE91F214ABDe2a2E65B6cd41A7C7E3244E1ec1) ([rehber](docs/tr/03-templateler/soulbound-credential.md))                                                          |
| 5   | **Treasury Multisig + Timelock** | ✅ v0.5.0      | OZ `TimelockController` ince wrapper — rol-bazlı + 48h gecikmeli hazine (DAO fonları), Safe-uyumlu. [Live on Fuji](https://testnet.snowtrace.io/address/0x6864879522D70Fb8e1583Cc8Fd4baB0e9605A955) ([rehber](docs/tr/03-templateler/treasury-multisig.md))                                                                                                                                                                                               |

Her şablon:

- ✅ Solidity 0.8.34 (template 3 için 0.8.25 — icm-contracts uyumu, multi-version compile)
- ✅ OpenZeppelin v5.3+ inherit + audited 3rd-party (icm-contracts) miras
- ✅ Foundry test (unit + invariant + fuzz, ≥10000 runs; ICTT için smoke test'ler `vm.etch + vm.mockCall` Warp precompile mock'uyla)
- ✅ Slither + Aderyn statik analiz (CI)
- ✅ Türkçe deployment rehberi
- ✅ Fuji testnet'te çalışan deploy script + Snowtrace verified

---

## 🚀 Hızlı Başlangıç

### En Hızlı Yol — CLI (önerilen)

Tek komutla şablon seç, hazır Foundry projesi kur, opsiyonel olarak Fuji'ye deploy et:

```bash
npx create-kozalak-l1 benim-token
# → şablon seç (ERC-20 / ERC-721 / Soulbound / Treasury / ICTT)
# → bağımlılıklar kurulur, .env + README hazır
# → istersen Fuji'ye deploy + Snowtrace verify
```

[`create-kozalak-l1`](https://www.npmjs.com/package/create-kozalak-l1) npm'de yayında — kurulum gerektirmez.

### Gereksinimler

- [Foundry](https://book.getfoundry.sh/getting-started/installation) (1.5+)
- Node.js 18+ (landing site için — opsiyonel)
- Fuji testnet AVAX → [faucet.avax.network](https://faucet.avax.network/)
- _(Opsiyonel)_ [Avalanche CLI](https://docs.avax.network/tooling/avalanche-cli) — custom L1 deploy için

### Kurulum

```bash
git clone https://github.com/Bekirerdem/Kozalak-L1.git
cd Kozalak-L1
forge install              # forge-std + OpenZeppelin v5.3 + ava-labs/icm-contracts
forge build
forge test -vvv            # unit + invariant + fuzz testler
```

### Bir Şablonu Deploy Et (Örnek: ERC-20 Custom Gas)

```bash
cp .env.example .env       # PRIVATE_KEY, RPC, Snowtrace API key doldur
forge script script/deploy/DeployERC20Gas.s.sol \
    --rpc-url fuji \
    --broadcast \
    --verify
```

---

## ❓ Niye Avalanche?

| Avantaj                          | Anlamı                                                               |
| -------------------------------- | -------------------------------------------------------------------- |
| **Avalanche9000 / Etna upgrade** | L1 kurulumu Ethereum L2'lerden çok daha ucuz (%99 maliyet düşüşü)    |
| **ICM / ICTT**                   | Native cross-L1 mesajlaşma — bridge yok, ekstra trust assumption yok |
| **Sub-second finality**          | L2'lerin günlerce sürebilen withdrawal bekleme süresi yok            |
| **Custom Gas Token**             | Kendi token'ınla gas öder, AVAX bağımlılığı yok                      |
| **Audited primitive'ler**        | `ava-labs/icm-contracts`'tan miras al, bridge yazma riski yok        |
| **Türk topluluk**                | [Team1 TR](https://team1.blog) — Avalanche'a en aktif lokal topluluk |

---

## 🗺️ Yol Haritası

```
┌──────────────────────┬──────────────────────┬──────────────────────┐
│  Phase 1 (bitti)     │  Phase 2 (bitti)     │  Phase 3 (bitti)     │
│  Çekirdek (5/5)      │  Olgunlaştırma       │  Topluluğun eline    │
├──────────────────────┼──────────────────────┼──────────────────────┤
│ ✅ Repo + CI setup   │ ✅ Bug bounty        │ ✅ create-kozalak-l1 │
│ ✅ 5/5 şablon canlı  │ ✅ Grant taslağı     │ ✅ Şablon scaffold   │
│ ✅ Türkçe docs (1-5) │ ✅ Audit checklist   │ ✅ Deploy + verify   │
│ ✅ Slither/Aderyn CI │                      │ ✅ 5 şablon paketli  │
└──────────────────────┴──────────────────────┴──────────────────────┘
```

**Üç faz da tamamlandı** — 5/5 audit-grade şablon Fuji'de canlı + verified, CI yeşil, Türkçe rehberler 01–05 hazır (Phase 1); bug bounty / responsible disclosure politikası, grant başvuru taslağı ve audit hazırlık checklist yazıldı (Phase 2); `create-kozalak-l1` CLI **npm'de yayında** (`npx create-kozalak-l1`) — tek komutla şablon scaffold + Fuji deploy/verify (Phase 3). Web dashboard ve ek şablonlar isteğe bağlı gelecek genişlemelerdir — **topluluk katkısına açık**.

---

## 🛡️ Güvenlik

Tüm şablonlar:

- ✅ **Solidity 0.8.34** (IR storage bug fix sonrası)
- ✅ **OpenZeppelin v5.3+** (`Ownable2Step`, `AccessManager`, ERC-7201 namespaced storage)
- ✅ **Custom errors** (gas + audit kalitesi)
- ✅ **Foundry fuzz/invariant** (≥10000 runs)
- ✅ **Slither + Aderyn** statik analiz (CI)
- ✅ **`ava-labs/icm-contracts`** audited primitive'ler (custom bridge yazılmaz)

> ⚠️ **Bu kod henüz profesyonel audit'ten geçmemiştir.** Production deployment öncesi Sherlock veya Cantina contest (Phase 2 — olgunlaştırma) opsiyonel olarak planlanıyor.

Güvenlik açığı bildirimi: [`SECURITY.md`](./SECURITY.md)

---

## 🤝 Katkı

Hem Türkçe hem İngilizce katkı kabul edilir. Detaylar: [`CONTRIBUTING.md`](./CONTRIBUTING.md)

---

## 📄 Lisans

[MIT](./LICENSE)

---

## 🙏 Teşekkürler

Bu proje aşağıdaki ekosistemler ve toplulukların omuzlarında yükseliyor:

- **[Avalanche Foundation](https://www.avax.network/)** — ekosistem ve `ava-labs/icm-contracts` audited contract'lar
- **[OpenZeppelin](https://www.openzeppelin.com/)** — sektör standartı güvenlik kütüphanesi
- **[Cyfrin Updraft](https://updraft.cyfrin.io/)** — Avalanche L1 development eğitim materyalleri
- **[Team1 Türkiye](https://team1.blog/)** — Türkiye'nin Avalanche topluluğu
- **Koza DAO** — `KOZALAK-L1`'in çıkış noktası olan Bursa merkezli yerli Web3 topluluğu

---

<div align="center">

**Türkiye'de Avalanche L1 ekosistemi inşa ediliyor.** 🏔️

Built with ❤️ by [**Bekir Erdem**](https://github.com/Bekirerdem)

</div>
