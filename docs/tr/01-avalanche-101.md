# Avalanche 101 — Türk Geliştiriciler İçin Giriş

> **Hedef kitle:** Avalanche'a yeni başlayan Solidity geliştiricileri
> **Bilmesi gerekenler:** Solidity temel sözdizimi, ERC-20 / ERC-721 standartları, EVM kavramı

---

## 🎯 Bu Doküman Niye Var?

Avalanche, **Aralık 2024 itibariyle radikal bir mimari değişim** yaşadı (Avalanche9000 / Etna upgrade). Eski "Subnet" terimi öldü, "Sovereign L1" geldi. ICM, ICTT, AvaCloud, HyperSDK gibi yeni primitive'ler ortaya çıktı.

Türkçe kaynaklarda bu değişim **henüz yansımıyor**. Bu doküman, mevcut bilginizi 2026 standardına yükseltmek için yazıldı.

---

## 1. Mimari Genel Bakış

Avalanche = **Primary Network** (3 chain) + N tane **Sovereign L1** (sınırsız).

```
┌─────────────────────────────────────────────────────────────────┐
│                    AVALANCHE EKOSİSTEMİ                         │
└──────────────┬─────────────────────────────────┬────────────────┘
               │                                 │
        ┌──────▼─────┐                  ┌────────▼────────┐
        │  Primary   │                  │  Sovereign L1's │
        │  Network   │                  │  (sınırsız)     │
        │            │                  │                 │
        │  C-Chain   │                  │  L1 #1 (Beam)   │
        │  P-Chain   │   ◄── ICM ──►   │  L1 #2 (DFK)    │
        │  X-Chain   │                  │  L1 #3 (sizin!) │
        └────────────┘                  └─────────────────┘
```

### 1.1 Primary Network — 3 Chain

| Chain | Görev | VM | Ne için kullanılır |
|---|---|---|---|
| **C-Chain** | Smart contract layer | Coreth (EVM) | Solidity contract deploy, DeFi (Aave, GMX, Trader Joe), genelleşmiş dApp |
| **P-Chain** | Platform yönetimi | PVM | Validator kayıt, L1 oluşturma, staking, blockchain meta verileri |
| **X-Chain** | Asset takası | AVM (UTXO) | Native asset transferi, atomik swap |

**Pratik özet:** Solidity geliştiricisi olarak %95 zamanını **C-Chain** ve **kendi Sovereign L1**'ında geçirir. P-Chain ve X-Chain genelde altyapı işlemleri için kullanılır.

### 1.2 Avalanche9000 / Etna Upgrade (Aralık 2024)

Avalanche tarihinin **en büyük yapısal değişikliği**. Sonuçları:

| Önce | Sonra |
|---|---|
| "Subnet" terimi | "**Sovereign L1**" |
| 2000 AVAX kilit zorunluluğu (~$70-100K validator başına) | **Kalktı** — dynamic fee (~1.33 AVAX/ay) |
| L1 başlangıç maliyeti yüksek | **%99 düştü** |
| Validator P-Chain doğrulamak zorunda | **Zorunlu değil** |
| C-Chain base fee 25 nAVAX | **1 nAVAX** ($0.00000004) |

**Pratik etki:** Bir startup veya solo dev artık **birkaç saatte** kendi blockchain'ini ayağa kaldırabilir. ICM ile diğer Avalanche L1'leriyle bridge'siz konuşabilir.

---

## 2. Sovereign L1 (Custom Blockchain) Türleri

Kendi L1'ini kurmak istiyorsan 3 seçeneğin var:

### 2.1 Subnet-EVM (en yaygın, default tercih)

EVM-uyumlu. Solidity contract'ları aynen çalışır. Custom gas token, custom precompile, validator allowlist mümkün.

**Ne zaman tercih:** Ethereum/Avalanche dApp'ini kendi izole blokspace'ine taşımak. SocialFi, GameFi, kurumsal RWA L1'leri.

**Performans:** ~5,000-15,000 TPS, sub-second finality.

**Örnekler:** Beam (gaming), DeFi Kingdoms, Dexalot (CLOB DEX), kurumsal Citi/JPMorgan pilot'ları.

### 2.2 HyperSDK (yüksek performans, Rust)

Custom VM yazma framework'ü. Rust/WebAssembly ile derlenmiş. EVM kullanmaz.

**Ne zaman tercih:** Yüksek-frekanslı oyunlar, on-chain order book DEX'ler, AI agent mikro-ödemeler, DePIN sensör doğrulama.

**Performans:** 10,000-50,000 TPS production, kapalı testte 143K TPS.

**Solo dev için:** **Aşırı karmaşık.** Rust + konsensüs mühendisliği gerektirir. HyperSDK Phase 1'de tercih edilmemeli.

### 2.3 Custom VM (uzman seviye)

Go ile sıfırdan yazılmış kendi sanal makineniz. Ava-Labs çekirdek dev ekibinin yaptığı seviye.

**Ne zaman tercih:** Eğer "neden custom VM yazmam gerekiyor" sorusunu kolayca cevaplayamıyorsan, asla.

---

## 3. ICM (Interchain Messaging) — Avalanche'ın Sırrı

Avalanche'ın diğer L1'lerden (Ethereum, Solana, Cosmos) **gerçek farklılaşma noktası** budur.

### 3.1 Bridge'siz Cross-Chain İletişim

Geleneksel bridge'ler (Wormhole, LayerZero, Across) **multisig oracle ağı** veya **light client** üzerine kurulu. Bu da:
- Multisig hack'i (Ronin $625M, Wormhole $325M, Nomad $190M, vb.)
- Oracle gecikmeleri
- Ekstra trust assumption

ICM **bunların hiçbirine** ihtiyaç duymaz. BLS multi-signature ile L1 validator'larının imzaladığı mesajları doğrudan başka L1'lerin doğrulayabilmesi.

### 3.2 ICM Katmanları

```
┌─────────────────────────────────────────────────────┐
│  ICTT (Inter-Chain Token Transfer)                  │
│  → Audited token bridge contracts                   │
│  → Token Home + Token Remote pattern                │
│  → sendAndCall: tek tx'te transfer + uzak fn çağrı  │
├─────────────────────────────────────────────────────┤
│  Teleporter                                         │
│  → Solidity-friendly wrapper                        │
│  → sendCrossChainMessage(destChain, dest, payload)  │
│  → Receipt + fee modeli                             │
├─────────────────────────────────────────────────────┤
│  AWM (Avalanche Warp Messaging)                     │
│  → Alt katman (BLS multi-sig)                       │
│  → P-Chain validator registry doğrulama             │
└─────────────────────────────────────────────────────┘
```

**Pratik etki:** Bir oyun L1'inde kazandığın kılıç NFT'sini, C-Chain'deki Trader Joe'da satabilirsin. Bridge yok, ekstra trust yok, sub-second.

### 3.3 ICTT Pattern (Token Bridge)

```
   Kaynak L1 (örn. C-Chain)              Hedef L1 (örn. Custom L1)
  ┌──────────────────────┐              ┌──────────────────────┐
  │  KozaGasToken (ERC)  │              │  KozaGasTokenRemote  │
  │  ↓ approve + send    │              │  ↑ mint              │
  │  ┌────────────────┐  │  ICM mesaj   │  ┌────────────────┐  │
  │  │ TokenHome      │  │ ──────────►  │  │ TokenRemote    │  │
  │  │ - lock or burn │  │              │  │ - mint or unlock│  │
  │  └────────────────┘  │              │  └────────────────┘  │
  └──────────────────────┘              └──────────────────────┘
```

İki mod:
- **Lock/Release**: kaynakta token kilitlenir, hedefte ayrı bir token mint edilir; geri dönüş simetrik
- **Burn/Mint**: kaynakta yakılır, hedefte mint edilir

`kozalak-L1` Phase 1 Sprint 3'te hazır audited template.

---

## 4. Geliştirici Araçları

### 4.1 Avalanche CLI

L1 oluşturmanın en hızlı yolu. Tek komutla local devnet'te custom L1 ayağa kaldırır.

```bash
avalanche blockchain create my-l1 --evm --latest
avalanche blockchain deploy my-l1 --local      # local devnet
avalanche blockchain deploy my-l1 --fuji       # Fuji testnet
avalanche blockchain deploy my-l1 --mainnet    # production
```

**Windows kurulumu** karmaşık (WSL2 önerilir). Linux/macOS direkt binary.

### 4.2 AvaCloud

L1'i kendi sunucularınızda çalıştırmak istemiyorsanız: **managed L1** hizmeti. AWS'in blockchain karşılığı.

- Validator hosting (kendi node'unuzu kurmazsınız)
- RPC endpoint (mainnet-grade)
- Indexer + faucet
- Enterprise SLA

**Kurumsal kullanım:** Citi, JPMorgan, KKR gibi devler.
**Solo dev:** Phase 3'te (production) düşünebilirsin, Phase 1'de gereksiz.

### 4.3 Foundry (en iyi Solidity dev framework'ü)

Hardhat'in yerini aldı. **Avalanche ekosisteminde default tercih.**

```bash
forge build              # contract derle
forge test --fuzz-runs 10000  # 10K random test
forge coverage           # coverage raporu
forge fmt                # auto-format
forge script ... --broadcast --verify  # deploy + Snowtrace verify
```

`kozalak-L1` tamamen Foundry üzerine kurulu.

### 4.4 Builder Hub & Faucet

- **Builder Hub:** https://build.avax.network — Tüm dökümanlar, Academy, tools
- **Faucet:** https://faucet.avax.network — Fuji testnet AVAX (her gün limit var)
- **Snowtrace:** https://testnet.snowtrace.io — Etherscan-equivalent block explorer

---

## 5. Hibe Programları (Türkçe Geliştiriciler İçin)

Avalanche Foundation, sermaye tahsisi konusunda sektördeki **en agresif** vakıflardan biri.

### 5.1 Retro9000 — $40M Retroactive

**Niye var:** Avalanche9000 ekosistemini büyüten builder'lara geriye dönük ödül.

**Nasıl çalışır:** Önce inşa edersin, sonra başvurursun. Topluluk leaderboard oylaması ile sıralama.

**Hedef projeler:**
- L1 deployment toolkits (← `kozalak-L1` tam buraya oturur)
- ICM/ICTT use case'leri
- Geliştirici araçları (indexer, monitoring, dashboard)
- Eğitim içerikleri (Türkçe doc, video)

**URL:** https://www.avalanche9000.com

### 5.2 Codebase by Avalanche — $250K Inkübatör

**10 hafta yoğun program.** Mentorluk + co-working + Demo Day.

**Sonunda:** SAFE token warrant + $250K direkt yatırım (seçilen projeler için).

**Hedef profil:** Production traction'ı olan, ürün-pazar uyumu kanıtlanan girişimler.

**URL:** https://www.avax.network/codebase

### 5.3 Multiverse / Rush — Multi-Million

**Multiverse:** Kurumsal L1 deployment teşvikleri (gaming, RWA).
**Rush:** Mainnet DeFi liquidity teşvikleri.

**Hedef profil:** Yüksek hacimli kurumsal projeler, Codebase mezunları.

### 5.4 Türkçe Geliştiriciler İçin Önerilen Yol

```
Phase 1 — Build:
  └─ Açık kaynak proje (örn. kozalak-L1)
  └─ Türk topluluğu adoption (Team1 TR, üniversite kulüpleri)
  └─ Production traction (X kullanıcı, Y star)
        ↓
Phase 2 — Retro9000 başvurusu:
  └─ Topluluk oylaması leaderboard'unda görün
  └─ $10K-$50K hibe (proje boyutuna göre)
        ↓
Phase 3 — Codebase başvurusu:
  └─ 10 hafta inkübatör
  └─ $250K SAFE
  └─ Demo Day pitch
```

---

## 6. Türkiye'de Avalanche Topluluğu

### Team1 Türkiye

Avalanche Foundation'ın **resmi TR chapter**'ı (eski adıyla Avalanche Türkiye).

- 35+ yerel etkinlik (İstanbul, Ankara, Bursa, İzmir, ...)
- 8 şehirde 10+ üniversite blockchain kulübü tour
- "Spekülasyon değil, ürün ship etme" vizyonu
- Avalanche Foundation'a referans köprüsü

**URL:** https://team1.blog
**Topluluk:** Discord + Telegram aktif

### Diğer Aktörler

- **SCDEVTR** — Smart Contract Developers Türkiye (Discord, GitHub org)
- **TRWEB3** — Türkiye Web3 İnisiyatifi (LinkedIn)
- **Patika.dev** — Solidity bootcamp (Paribu Hub partnership)
- **Üniversite kulüpleri:** İTÜ Blockchain (~2500 üye), ODTÜ Blockchain, Bilkent BTF, Boğaziçi BUchain

---

## 7. Sıradaki Adım

`kozalak-L1`'in kendisini kullanarak başla:

1. **Repo'yu clone et:** `git clone github.com/Bekirerdem/Kozalak-L1`
2. **Template 1 deploy et:** [`docs/tr/03-templateler/erc20-gas.md`](./03-templateler/erc20-gas.md)
3. **Kendi L1'ini ayağa kaldır:** [`docs/tr/02-l1-deploy.md`](./02-l1-deploy.md)
4. **Güvenlik checklist'i takip et:** [`docs/tr/04-guvenlik.md`](./04-guvenlik.md)

---

## 📚 Daha Fazla Okuma

- [Avalanche9000 ACP-77 spesifikasyonu](https://github.com/avalanche-foundation/ACPs/tree/main/ACPs/77-reinventing-subnets)
- [ICM Architecture (Builder Hub)](https://build.avax.network/docs/cross-chain/teleporter/overview)
- [Subnet-EVM GitHub](https://github.com/ava-labs/subnet-evm)
- [Foundry Book](https://book.getfoundry.sh)
- [OpenZeppelin Contracts v5](https://docs.openzeppelin.com/contracts/5.x)
