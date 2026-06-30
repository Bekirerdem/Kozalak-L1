# ICTT Bridge (Home + Remote)

Avalanche Interchain Token Transfer ile C-Chain ↔ L1 token köprüsü (KozaTokenHome + KozaTokenRemote).

Bu, kozalak-l1 deposundan üretilmiş **standalone** bir Foundry projesidir;
kendi başına derlenir ve test edilir.

## Kurulum

> **Windows notu:** icm-contracts'ın iç içe submodule yolları uzundur;
> önce uzun-yol desteğini aç: `git config --system core.longpaths true`

```bash
forge install foundry-rs/forge-std@8987040ede9553cea20c95ad40d0455930f9c8e0 OpenZeppelin/openzeppelin-contracts@e4f70216d759d8e6a64144a9e1f7bbeed78e7079 ava-labs/icm-contracts@dac65983fb956586aebeadab1c4290d2f87927b4
# icm-contracts'ın iç bağımlılıkları (oz-upgradeable, subnet-evm) için:
git -C lib/icm-contracts submodule update --init --recursive
forge build
forge test
```

> `forge install ...@<commit>` bağımlılıkları repo ile birebir aynı commit'lere
> pinler (aşağıdaki tabloya bakın). `.gitmodules` ve `remappings.txt`
> bu pinlerle uyumludur.

## Deploy

Bu şablon (ICTT köprüsü) çok-adımlı, iki-zincirli bir kurulum gerektirir
(Home + Remote + Teleporter registry). Otomatik tek-komut deploy YOKTUR.

Adım adım rehber: kozalak-l1 deposundaki
`docs/tr/03-templateler/ictt-bridge.md` dosyasını izleyin.

## Yeniden adlandırma

Contract'ı kendi adınla yeniden adlandırmak istersen `src/`, `test/` ve
`script/` altındaki dosyalarda contract/dosya adını birlikte güncelle
(import'lar tek-seviye relative olduğu için tutarlı kalmalı).

## Bağımlılık pinleri

| Bağımlılık | Tag | Commit (pin) |
| --- | --- | --- |
| `forge-std` | v1.16.0 | `8987040ede9553cea20c95ad40d0455930f9c8e0` |
| `openzeppelin-contracts` | v5.3.0 | `e4f70216d759d8e6a64144a9e1f7bbeed78e7079` |
| `icm-contracts` | v1.0.9 | `dac65983fb956586aebeadab1c4290d2f87927b4` |

---

_Bu proje `create-kozalak-l1` tarafından üretildi. Kaynak: kozalak-l1 mono-repo._
