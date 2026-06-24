# Template 3 — ICTT Uçtan Uca Köprü Demosu (Kanıt)

> **Durum: ✅ ÇİFT YÖN UÇTAN UCA DOĞRULANDI**
>
> - **İleri yön** (2026-06-22): Fuji C-Chain'de KGAS `lock` → `icm-relayer` →
>   Fuji L1'de wKGAS **mint**. Başarı kriteri (`balanceOf > 0`) sağlandı.
> - **Ters yön / round-trip** (2026-06-24): Fuji L1'de wKGAS `burn` →
>   `icm-relayer` → Fuji C-Chain'de KGAS **unlock**. Köprünün iki yönü de
>   on-chain kanıtlandı (v0.3.2).

Bu doküman, `ictt-bridge.md` rehberindeki adımların **gerçekten çalıştığını**
kanıtlayan canlı transfer kayıtlarını içerir. v0.3.0'da kontratlar canlıydı ama
relayer kurulmadığı için uçtan uca transfer tamamlanmamıştı; v0.3.1 bunu kapatır.

## Mimari (v0.3.0'dan düzeltme)

v0.3.0 notları "Fuji C-Chain Home → **yerel** L1 Remote" senaryosunu
varsayıyordu. **Bu mimari çalışmaz:** yerel Avalanche network'ü ile Fuji ayrı
P-Chain'lere sahiptir; yerel bir L1, Fuji C-Chain'in validator setini kendi
P-Chain'inde bulamaz, dolayısıyla Fuji'den gelen Warp mesajını doğrulayamaz.

**v0.3.1 doğru mimarisi — her iki uç da Fuji primary network'te:**

```
Fuji C-Chain (Home, KGAS lock)  ←→  Fuji L1 "kozaTestL1" (Remote, wKGAS mint)
        primary network               primary network'e bağlı sovereign L1
                                       (validator local makinede, --use-local-machine)
```

`kozaTestL1` genesis'inde `warpConfig.requirePrimaryNetworkSigners = true`
(quorum 67) olduğu için L1, Fuji primary network imzalı mesajları kabul eder.

## Adresler

| Bileşen | Zincir | Adres |
|---------|--------|-------|
| KGAS (bridge token) | Fuji C-Chain | `0x06451DD4Fb8ebFC19870DacC9568f4364D2A2eB0` |
| KozaTokenHome | Fuji C-Chain | `0x2b1377537690793939DC42530c15DA897AC9D2D9` |
| KozaTokenRemote (wKGAS) | Fuji L1 (kozaTestL1) | `0x0c4476E8D1d140B303E08aa75a0AbD44Ff202bb1` |
| Teleporter Registry (Home) | Fuji C-Chain | `0xF86Cb19Ad8405AEFa7d09C778215D2Cb6eBfB228` |
| Teleporter Registry (Remote) | Fuji L1 | `0x965c383362FF8395f91677f17E9f9bD8E1f58724` |
| Deployer / recipient | — | `0x39AEfbC8388da12907A21d9De888B288a9fa5794` |

- **Fuji C-Chain blockchain ID:** `0x7fc93d85c6d62c5b2ac0b519c87010ea5294012d1e407030d6acd0021cac10d5`
- **Fuji L1 (kozaTestL1) blockchain ID:** `iq2dnsHr4T9FG39r3Fkho3H8B2V31BdnkxHCnCVZNvbHCiSQE` (CB58) / `0x5ef9cb0c2c14e1b1276535177c29378d4a4e6d6df891d0e049bd0f21edc296f5` (hex)

## Transfer Kanıt Zinciri

| # | İşlem | Tx / Sonuç |
|---|-------|-----------|
| 1 | Remote (wKGAS) deploy — `forge create` (Warp precompile constructor) | `0x763343bce6dddd10d23d59bae250b6e2e0f0fcce37214fbc81bf4019960b7a4e` |
| 2 | `registerWithHome()` (Remote → Home, relayer Fuji C-Chain'e taşıdı) | `0xbe3cf595d5381cb6f3924e0e373a792f0aa493bf9180266ea1ea304ff3c1c8e6` |
| 3 | KGAS approve (100 KGAS → Home) | `0xfdfd2d02b5c281fb0f8df0ba14a738f8a902a6b55de4f0a118e39c88b504fc1f` |
| 4 | **`Home.send()` — 10 KGAS lock + Warp mesajı** | `0xb74ce3d8efcc46745466b3df4b87ac6452029a23aa69b8ce99b8d41f501c8bf4` |
| 5 | **Relayer** Fuji C-Chain → Fuji L1 mesajı taşıdı | `icm-relayer` "Delivered message to destination chain" |
| 6 | **wKGAS mint doğrulama** | `balanceOf(deployer) = 10000000000000000000` (10 wKGAS), `totalSupply = 10000000000000000000` ✅ |

`KozaTokenHome` Fuji'de Snowtrace üzerinde verified:
[snowscan mirror](https://testnet.snowscan.xyz/address/0x2b1377537690793939dc42530c15da897ac9d2d9).
Fuji L1 yerel RPC üzerinden çalıştığı için Remote explorer'da görünmez; bytecode
+ read fonksiyonları (`name=Wrapped Koza Gas`, `symbol=wKGAS`, `decimals=18`) ve
mint sonrası `totalSupply` on-chain doğrulandı.

## Ters Yön — Round-Trip (L1 → Fuji Geri Dönüş)

> **2026-06-24** — Köprünün geri dönüşü: Fuji L1'de wKGAS `burn` →
> `icm-relayer` mesajı C-Chain'e taşıdı → Fuji C-Chain'de kilitli KGAS
> **unlock** edildi (`KozaTokenHome._withdraw` → `safeTransfer`).

Senaryo: İleri yönde mint edilen 10 wKGAS, sahibine (deployer) Fuji'deki
KGAS'ı geri vermek için yakılır. ICTT muhasebesi: Remote'ta `burn` →
`Home`'da kilitli teminat `recipient`'a çözülür. Kod yolu audited
`ava-labs/icm-contracts`'tan gelir (`ERC20TokenRemote.send` →
`TokenHome._receiveTeleporterMessage` → `_withdraw`).

**Yeni ön koşul (ileri yönde yoktu):** `Remote._burn`,
`_spendAllowance(sender, address(this), amount)` çağırır. Yani burn'den önce
wKGAS, **Remote kontratının kendisine** approve edilmelidir:
`cast send $REMOTE "approve(address,uint256)" $REMOTE <amount>`.

### Ters Yön Kanıt Zinciri (2026-06-24)

| # | İşlem | Tx / Sonuç |
|---|-------|-----------|
| 0 | wKGAS self-approve (Remote'a) | `allowance(deployer, Remote) = 10000000000000000000` |
| 1 | **`Remote.send()` — 10 wKGAS BURN + Warp mesajı (L1)** | `0x9dfad5a2c31b5c5546c7ffcc2947ab80fa333ba430ddd61958b6cbb585023ec5` |
| 2 | Warp / Teleporter mesaj kimliği | warp `2F57KdCup4ZQbPATnxwirgFciHfh446nBdkSoe2Exai5wJHcAK` · teleporter `2g6jYJxeqoyrXDnUgoBURFekfRKjVD7Hf3GAL7mv6QVp6mZCXv` |
| 3 | **Relayer** Fuji L1 → Fuji C-Chain mesajı taşıdı | `icm-relayer` "Delivered message to destination chain" |
| 4 | **KGAS UNLOCK — `Home._withdraw` → `recipient`** | [`0x843772a8f9757d23ce961b703a86573d8dafafff37b1df3f241caabb3106cd22`](https://testnet.snowtrace.io/tx/0x843772a8f9757d23ce961b703a86573d8dafafff37b1df3f241caabb3106cd22) |
| 5 | Sonuç doğrulama | L1: wKGAS `totalSupply = 0`, `balanceOf(deployer) = 0`; Fuji: `KGAS.balanceOf(deployer)` `99980` → **`99990`** (+10) ✅ |

Unlock tx'i Fuji C-Chain'de yer aldığı için **Snowtrace'te görünür** (yukarıdaki
link); receipt log'unda `Home` (`0x2b1377…`) `TokensWithdrawn` event'i ve
`KGAS` `Transfer(Home → deployer, 10e18)` doğrulandı.

## Yeniden Üretilebilirlik

Yerel L1 her makine kapanışında state'ini kaybeder; bu demo **tek komutla
yeniden üretilebilir**: `scripts/demo/run-ictt-demo.sh`. Script Fuji L1'i deploy
eder, Remote'u yayar, register + relayer + transfer'i yürütür ve mint'i doğrular.

## Yol Boyunca Çözülen Kritik Engeller

Demo, audit-grade boilerplate'in gerçek dünya validasyonudur; karşılaşılan ve
çözülen engeller `ictt-bridge.md` "Ortak Hatalar" bölümüne işlendi:

- **`forge script` Subnet-EVM precompile'a bağımlı kontratları deploy edemez** —
  local EVM'de Warp precompile (`0x0200…05`) yok, constructor `StackUnderflow`
  verir. Çözüm: `forge create` (constructor doğrudan zincirde çalışır).
- **Fuji↔yerel network ICM çalışmaz** — ayrı P-Chain'ler. Çözüm: her iki uç da
  Fuji primary network'te (L1'i `--fuji --use-local-machine` ile deploy).
- **`icm-relayer` flag'i `--config-file`** (`--config` değil).
- **Relayer nonce çakışması** — relayer deployer key kullanırken manuel tx'ler
  nonce'u ilerletir; relayer fresh başlatılmalı ve relay sırasında deployer key
  ile manuel tx gönderilmemeli.
