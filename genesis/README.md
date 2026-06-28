# Genesis Configurations — kozalak-L1

Bu klasör, Avalanche **Subnet-EVM** üzerinde kendi Sovereign L1'ini ayağa kaldırmak isteyen geliştiriciler için hazır genesis JSON şablonları içerir. Her şablon, ilgili template ile birlikte kullanılır.

> ⚠️ **Bu dosyalar PLACEHOLDER içerir.** Mainnet veya halka açık testnet'e deploy etmeden önce **mutlaka** aşağıdaki özelleştirmeleri yapın.

---

## 📁 Dosyalar

### `erc20-gas-token.json` — Custom Native Gas Token L1

Avalanche9000 (Etna) sonrası **Sovereign L1** için, kendi native token'ınızla gas ödediğiniz minimal genesis. ICM (Interchain Messaging) aktif → diğer Avalanche L1'leriyle bridge'siz cross-L1 mesajlaşma yapabilirsiniz.

### `erc721-collection.json` — NFT Collection L1

NFT-odaklı bir uygulama zinciri. Kullanıcılar mint, transfer, marketplace etkileşimi yapar. ICM açık, contract deployer + tx allowlist mainnet için zorunlu placeholder'lar.

### `ictt-bridge.json` — ICTT Cross-L1 Bridge için Hedef L1

Inter-Chain Token Transfer (ICTT) ile başka bir L1'den gelen tokeni karşılayan **hedef** L1. Kritik özellik: `warpConfig` zorunlu (kapatılırsa bridge tamamen disable olur). Teleporter messenger contract'ı (`0x253b...5fcf`) **genesis'te pre-deploy edilmez** — Avalanche CLI `avalanche blockchain deploy` komutu otomatik yayar; manuel L1'lerde post-deploy adımı zorunludur.

---

## 🛠️ Kullanım Senaryoları

### Senaryo A: Pure Native Gas Token L1

L1'in native token'ı = sizin token'ınız (örn. KGAS). Kullanıcılar tx ödemesini KGAS ile yapar. AVAX bağımlılığı **yoktur**.

```bash
# Avalanche CLI ile:
avalanche blockchain create my-kozalak-l1 --custom \
  --genesis ./genesis/erc20-gas-token.json
```

### Senaryo B: Native + ERC-20 (ICTT Bridge)

L1'in native'i KGAS, ek olarak C-Chain'de `KozaGasToken.sol` ERC-20 deploy edilir. **ICTT** ile iki tarafın token'ları bridge'lenir (Phase 1 Sprint 3'te detaylı).

### Senaryo C: NFT Collection L1

Bir NFT koleksiyonuna özel L1 (sanat, üyelik, utility). Kullanıcılar TKOZA gibi custom gas token ile mint öder. Genesis: `erc721-collection.json`.

### Senaryo D: ICTT Hedef L1 (cross-L1 bridge alıcısı)

Başka bir Avalanche L1'inden ICTT ile gelen tokeni `KozaTokenRemote` üzerinden temsil eder. Phase 1 default akışı: Fuji'de KGAS lock → bu L1'de wKGAS mint. Genesis: `ictt-bridge.json`. Kritik: `warpConfig` AÇIK olmalı, `quorumNumerator=67` ve `requirePrimaryNetworkSigners=true` korunmalı.

```bash
avalanche blockchain create my-bridge-target-l1 --custom \
  --genesis ./genesis/ictt-bridge.json
avalanche blockchain deploy my-bridge-target-l1 --local
# CLI otomatik olarak Teleporter messenger'ı 0x253b...5fcf'ye yayar.
```

---

## 🔧 Özelleştirme — Yapılacaklar Listesi

### 1. `chainID` Değiştir (zorunlu)

Default `99999` — sadece local test için. Üretimde **benzersiz bir chain ID** seçin:

- **Asla** kullanmayın: 1 (Ethereum), 43113 (Fuji), 43114 (Avalanche C-Chain), 137 (Polygon)
- Önerilen: 4 ila 8 haneli rastgele bir sayı (örn. `423456`)
- Çakışmayı kontrol edin: https://chainlist.org

### 2. Initial Allocation (zorunlu)

`alloc` bölümündeki placeholder adresi **kendi deployer adresinizle** değiştirin:

```json
"alloc": {
  "0x_YOUR_DEPLOYER_ADDRESS_HERE": {
    "balance": "0x295BE96E64066972000000"
  }
}
```

**Balance hex-encoded wei.** Örnekler:
| KGAS Miktarı | Hex Balance |
|---|---|
| 1 KGAS | `0xDE0B6B3A7640000` |
| 1,000 KGAS | `0x3635C9ADC5DEA00000` |
| 1,000,000 KGAS | `0xD3C21BCECCEDA1000000` |
| 50,000,000 KGAS | `0x295BE96E64066972000000` |
| 1,000,000,000 KGAS | `0x33B2E3C9FD0803CE8000000` |

`comment` alanını çıkarın — JSON spec uymaz, Avalanche CLI parse hatası verebilir (gerçi şu an "ignore unknown fields" davranışı var, yine de güvende olun).

### 3. Precompile Yapılandırması (opsiyonel ama önerilir)

#### `contractNativeMinterConfig`

L1'in native token'ını **deploy sonrası mint** edebilen rolleri tanımlar.

```json
"contractNativeMinterConfig": {
  "blockTimestamp": 0,
  "adminAddresses": ["0x_ADMIN_MULTISIG"],
  "managerAddresses": [],
  "enabledAddresses": []
}
```

- **adminAddresses**: rol yönetimi yapabilir, mint edebilir → **Safe multisig olmalı, EOA değil**
- **managerAddresses**: enabled list'i değiştirebilir, kendisi mint edebilir
- **enabledAddresses**: sadece mint edebilir

**Üretim kuralı:** En az 3-of-5 multisig, Safe (Gnosis Safe) cüzdan kullanın.

#### `contractDeployerAllowListConfig`

Kim L1'inize contract deploy edebilir? Boş bırakılırsa **herkes** deploy edebilir.

```json
"contractDeployerAllowListConfig": {
  "blockTimestamp": 0,
  "adminAddresses": ["0x_ADMIN_MULTISIG"],
  "enabledAddresses": ["0x_TRUSTED_DEV_1", "0x_TRUSTED_DEV_2"]
}
```

İlk başta açık bırakmak development hızını artırır; production'da kısıtlamak güvenlik sertliğini artırır.

### 4. `warpConfig` (Avalanche9000 ICM)

ICM aktif edilmiş şekilde gelir. Bunu kapatmak istiyorsanız (gerçekten gerekli değilse), bölümü silin:

```json
"warpConfig": {
  "blockTimestamp": 0,
  "quorumNumerator": 67,
  "requirePrimaryNetworkSigners": true
}
```

- `quorumNumerator`: 1-100 arası. 67 ≈ %67 BFT güvenlik. Düşürmek hız kazandırır, güvenliği azaltır.
- `requirePrimaryNetworkSigners`: `true` ise C-Chain validator'lar mesajları imzalamaya katılır (yüksek güvenlik). `false` ise sadece L1 validator'ları (daha hızlı, daha az merkeziyetsiz).

### 5. `feeConfig`

Default değerler `15M gas/block`, `2 saniye block time`. Gaming/yüksek-frekanslı L1 için artırılabilir, düşük-aktivite L1 için bırakılır.

---

## 🚀 Deployment

### Local devnet (test için)

```bash
avalanche blockchain create my-kozalak-l1 --custom \
  --genesis ./genesis/erc20-gas-token.json

avalanche blockchain deploy my-kozalak-l1 --local
```

### Fuji testnet (entegrasyon test için)

```bash
avalanche blockchain deploy my-kozalak-l1 --fuji
```

### Mainnet (production)

```bash
avalanche blockchain deploy my-kozalak-l1 --mainnet
```

⚠️ **Mainnet öncesi checklist:**
- [ ] `chainID` benzersiz (chainlist.org kontrolü)
- [ ] `alloc` adresleri Safe multisig (EOA değil)
- [ ] `contractNativeMinterConfig.adminAddresses` Safe multisig
- [ ] Genesis dosyası audit edilmiş (en az ikinci bir göz)
- [ ] Validator stake ekonomisi ayarlanmış (Avalanche9000 dynamic fee)
- [ ] Bug bounty programı (Immunefi) hazır
- [ ] Fuji'de en az 1 hafta entegrasyon test çalıştırıldı

---

## 📚 Daha Fazla

- Türkçe deployment rehberi: [`docs/tr/02-l1-deploy.md`](../docs/tr/02-l1-deploy.md)
- Avalanche CLI dokümantasyonu: https://docs.avax.network/tooling/avalanche-cli
- Subnet-EVM precompile reference: https://github.com/ava-labs/subnet-evm/tree/master/precompile
- Avalanche9000 (Etna) ACP-77: https://github.com/avalanche-foundation/ACPs/tree/main/ACPs/77-reinventing-subnets
