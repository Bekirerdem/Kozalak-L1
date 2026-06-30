# ERC-721 Collection

Merkle allowlist + faz bazlı mint, royalty destekli NFT koleksiyonu (KozaCollection).

Bu, kozalak-l1 deposundan üretilmiş **standalone** bir Foundry projesidir;
kendi başına derlenir ve test edilir.

## Kurulum

```bash
forge install foundry-rs/forge-std@8987040ede9553cea20c95ad40d0455930f9c8e0 OpenZeppelin/openzeppelin-contracts@e4f70216d759d8e6a64144a9e1f7bbeed78e7079
forge build
forge test
```

> `forge install ...@<commit>` bağımlılıkları repo ile birebir aynı commit'lere
> pinler (aşağıdaki tabloya bakın). `.gitmodules` ve `remappings.txt`
> bu pinlerle uyumludur.

## Deploy (Fuji testnet)

```bash
cp .env.example .env      # PRIVATE_KEY + SNOWTRACE_API_KEY doldur
forge script script/DeployERC721Collection.s.sol \
    --rpc-url fuji \
    --broadcast \
    --verify
```

> Production: `PRIVATE_KEY` yalnızca testnet olmalı; sahiplik/yönetici
> adreslerini bir multisig'e (Safe) yönlendir, EOA bırakma.

## Yeniden adlandırma

Contract'ı kendi adınla yeniden adlandırmak istersen `src/`, `test/` ve
`script/` altındaki dosyalarda contract/dosya adını birlikte güncelle
(import'lar tek-seviye relative olduğu için tutarlı kalmalı).

## Bağımlılık pinleri

| Bağımlılık | Tag | Commit (pin) |
| --- | --- | --- |
| `forge-std` | v1.16.0 | `8987040ede9553cea20c95ad40d0455930f9c8e0` |
| `openzeppelin-contracts` | v5.3.0 | `e4f70216d759d8e6a64144a9e1f7bbeed78e7079` |

---

_Bu proje `create-kozalak-l1` tarafından üretildi. Kaynak: kozalak-l1 mono-repo._
