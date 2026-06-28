# Kendi Sovereign L1'ini Deploy Et

> **Hedef:** `KOZALAK-L1` genesis şablonlarından birini alıp, Avalanche CLI ile
> **kendi Sovereign L1'ini** önce local devnet'te, sonra Fuji testnet'te ayağa
> kaldırmak; ardından kontratlarını bu zincire deploy etmek.
>
> **Ön bilgi:** [`01-avalanche-101.md`](./01-avalanche-101.md) (Avalanche9000, ICM, L1 kavramı)

Bu rehber **operasyonel** akışı anlatır. Genesis dosyalarının her bir alanının
ne işe yaradığı ve mainnet özelleştirme listesi ayrı tutuldu — onlar için
[`genesis/README.md`](../../genesis/README.md) tek doğruluk noktasıdır. Burada
"hangi komut, hangi sırayla, nerede patlar" yazıyor.

---

## 🧰 Ön Koşullar

| Gereksinim | Niye |
|---|---|
| **WSL2 / Linux** | Avalanche CLI Windows native'de güvenilir değil; WSL2 Ubuntu önerilir |
| **Avalanche CLI** | L1 oluşturma + deploy aracı (aşağıda kuruluyor) |
| **Foundry** | Kontratları L1'e deploy etmek için (`forge`, `cast`) |
| **Fuji AVAX** | Fuji P-Chain'de L1 kaydı + validator için → [faucet.avax.network](https://faucet.avax.network/) |

---

## 1. Avalanche CLI Kurulumu

Repo'daki hazır script WSL/Ubuntu'ya kurar:

```bash
bash scripts/setup/install-avalanche-cli.sh
avalanche --version    # v1.9.x görmelisin
```

`$HOME/bin`'i `PATH`'e ekle (script hatırlatır). Sonra her oturumda `avalanche`
komutu kullanılabilir.

---

## 2. Genesis Şablonunu Seç ve Özelleştir

`genesis/` altında üç hazır config var:

| Dosya | Senaryo |
|---|---|
| `erc20-gas-token.json` | Native gas token L1 (kendi token'ınla gas) |
| `erc721-collection.json` | NFT-odaklı uygulama zinciri |
| `ictt-bridge.json` | ICTT ile başka L1'den token karşılayan hedef L1 |

Local test için **olduğu gibi** kullanabilirsin. Fuji/mainnet'e çıkmadan önce
**mutlaka** şu üçünü değiştir ([`genesis/README.md`](../../genesis/README.md) tam liste):

1. **`chainID`** — default `99999` sadece local. Benzersiz bir değer seç,
   [chainlist.org](https://chainlist.org)'da çakışma kontrol et.
2. **`alloc`** — placeholder adresi kendi deployer adresinle değiştir (balance hex-wei).
3. **`contractNativeMinterConfig.adminAddresses`** — production'da **Safe multisig**, EOA değil.

> ⚠️ Genesis JSON'da `comment` alanı bırakma — Avalanche CLI parse'ı bazı
> sürümlerde takılır. Özelleştirdikten sonra `cat genesis/<dosya>.json | jq .`
> ile geçerli JSON olduğunu doğrula.

---

## 3. Local Devnet'te Test Et

Önce yerelde dene — Fuji'ye çıkmadan tüm zinciri masaüstünde doğrula:

```bash
# L1'i tanımla (P-Chain'e henüz dokunmaz, sadece local config üretir)
avalanche blockchain create my-kozalak-l1 --custom \
  --genesis ./genesis/erc20-gas-token.json

# Local node cluster'ı ayağa kaldır + bu L1'i deploy et
avalanche blockchain deploy my-kozalak-l1 --local
```

CLI çıktısında **RPC URL**, **chainID** ve (ICTT genesis'iyse) otomatik yayılan
**Teleporter messenger** adresini verir. RPC'yi not al — kontrat deploy'unda
`--rpc-url` olarak kullanacaksın.

### L1 düştüyse: `deploy` DEĞİL, `node local start`

WSL/makine kapanınca local validator düşer (RPC reddedilir). Refleksif olarak
`blockchain deploy ... --local` çağırma — **"already exists, overwrite?"**
interaktif menüsü sorar, non-interactive shell'de EOF ile patlar ve bypass flag'i
yoktur. Doğrusu:

```bash
avalanche node local status               # cluster Stopped mı?
avalanche node local start <clusterName>  # disk state'iyle yeniden açar
```

> **Kural:** "L1 düştü" ≠ "blockchain gitti". Blockchain P-Chain'de kalıcı
> kayıtlı; sadece local node process'i ölmüş. `node local start` EVM disk state'ini
> korur — eski kontratların ve mint'lerin geri gelir, yeniden deploy gerekmez.

---

## 4. Fuji Testnet'e Deploy

Local'de çalıştığından emin olduktan sonra Fuji P-Chain'e çıkar:

```bash
avalanche blockchain deploy my-kozalak-l1 --fuji
```

Bu adım Fuji P-Chain'de bir **subnet + blockchain** oluşturur ve validator ekler —
bu yüzden cüzdanında Fuji AVAX olmalı. Deploy bitince zincirin kalıcıdır; sonraki
oturumlarda yeniden `create`/`deploy` etmene gerek yok.

```bash
avalanche blockchain describe my-kozalak-l1   # RPC URL, chainID, blockchainID
```

---

## 5. Kontratlarını L1'e Deploy Et

Artık kendi zincirin var. `KOZALAK-L1` şablonlarını Foundry ile oraya deploy et —
C-Chain'e deploy ile aynı, sadece `--rpc-url` senin L1'inin RPC'si:

```bash
# .env içine L1 RPC'sini ekle (örn. KOZA_L1_RPC)
forge script script/deploy/DeployERC20Gas.s.sol \
  --rpc-url "$KOZA_L1_RPC" \
  --broadcast
```

> Custom gas token L1'de işlem ücretini **native token'ınla** ödersin (genesis'teki
> `alloc` bakiyenden). Deployer adresinin `alloc`'ta yeterli bakiyesi olduğundan emin ol.

Şablonların kendi deploy detayları için: [`03-templateler/`](./03-templateler/).

---

## 6. (Opsiyonel) ICTT ile Cross-L1 Köprü

İki L1 arasında token taşımak istiyorsan ICTT devreye girer: C-Chain'de token
**lock** → L1'de **mint**, geri dönüşte **burn** → **unlock**. Tam akış, kontratlar
ve uçtan uca kanıt: [`03-templateler/ictt-bridge.md`](./03-templateler/ictt-bridge.md).
Köprünün çalışması için bir **relayer** gerekir — burada en sık yanılan yer:

- Relayer'ı `nohup` ile başlat; log'da L1 subnet için **`connectedWeight=100`** +
  `Initialization complete` görene kadar bekle, **sonra** ilk mesajı (burn/lock) at.
- `process-missed-blocks:false` ayarında, relayer hazır olmadan atılan mesaj
  **kaçar** (geçmiş blokları taramaz). Yeni başlayan relayer'da L1 peer handshake'i
  ~10-30 saniye sürebilir.
- Relayer canlılığını kontrol ederken `pgrep -af "[i]cm-relayer"` kullan (bracket
  trick) — düz `pgrep -f "icm-relayer"` kendi komut satırını yakalar, false positive verir.

---

## 🧱 Yaygın Tuzaklar (bu projede yandık)

| Belirti | Sebep | Çözüm |
|---|---|---|
| `deploy --local` "overwrite?" sorup EOF'ta patlıyor | L1 zaten var, sadece node düşmüş | `node local start <cluster>` |
| Geri dönüş burn'de `ERC20InsufficientAllowance` | wKGAS Home'a approve edilmiş, Remote'a değil | Burn öncesi `approve(REMOTE, amount)` Remote kontratına |
| ICTT mesajı hiç ulaşmıyor | Relayer hazır olmadan mesaj atıldı | `connectedWeight=100` + `Initialization complete` bekle |
| Genesis parse hatası | JSON'da `comment` alanı / geçersiz hex | `comment` sil, `jq` ile doğrula |

---

## ✅ Sonraki Adımlar

1. **Şablonu deploy et:** [`03-templateler/erc20-gas.md`](./03-templateler/erc20-gas.md)
2. **Güvenlik checklist'i:** [`04-guvenlik.md`](./04-guvenlik.md)
3. **Mainnet'e çıkış:** [`genesis/README.md`](../../genesis/README.md) → "Mainnet öncesi checklist"

## 📚 Daha Fazla

- [Avalanche CLI dokümantasyonu](https://docs.avax.network/tooling/avalanche-cli)
- [ACP-77 — Reinventing Subnets (Avalanche9000)](https://github.com/avalanche-foundation/ACPs/tree/main/ACPs/77-reinventing-subnets)
- [Subnet-EVM precompile reference](https://github.com/ava-labs/subnet-evm/tree/master/precompile)
