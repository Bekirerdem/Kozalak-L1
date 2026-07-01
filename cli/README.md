# create-kozalak-l1

Avalanche L1 için **denetime hazır (audit-grade) Foundry projelerini** tek
komutla oluşturan interaktif CLI. Bir şablon seçersin, CLI kendi başına
derlenip test edilen standalone bir Foundry projesi çıkarır; istersen
bağımlılıkları kurar ve kontratı Fuji testnet'e deploy eder.

## Kullanım

```bash
npx create-kozalak-l1
```

CLI seni adım adım yönlendirir:

1. **Proje adı** — oluşturulacak klasör (argüman olarak da verebilirsin:
   `npx create-kozalak-l1 benim-projem`).
2. **Şablon seçimi** — aşağıdaki 5 şablondan biri.
3. **Bağımlılıklar** — `forge install` ile pinli commit'lerden kurulum
   (isteğe bağlı).
4. **Deploy** — deploy edilebilir şablonlarda Fuji testnet'e tek-komut deploy
   (isteğe bağlı; private key **yalnızca testnet cüzdanı** olmalı, disk'e
   yazılmaz).

### Şablonlar

| Şablon | Ne işe yarar |
| --- | --- |
| `erc20-gas` | Mintable, capped arz, sahip-kontrollü ERC-20 gaz token'ı |
| `erc721-collection` | Merkle allowlist + faz bazlı mint, royalty destekli NFT koleksiyonu |
| `soulbound-credential` | Devredilemez, role-bazlı sertifika NFT'si |
| `treasury-multisig` | TimelockController tabanlı gecikmeli-yürütme hazine kontratı |
| `ictt-bridge` | Avalanche ICTT ile C-Chain ↔ L1 token köprüsü (scaffold-only) |

> `ictt-bridge` iki-zincirli, çok-adımlı bir kurulum gerektirdiği için otomatik
> deploy edilmez; CLI seni adım adım rehbere (`docs/tr/03-templateler/ictt-bridge.md`)
> yönlendirir.

### Oluşturduktan sonra

```bash
cd benim-projem
forge install   # bağımlılıkları CLI'da kurmadıysan
forge test
```

Deploy için proje README'sindeki adımları izle (`.env` doldur → `forge script`).

## Geliştirme

Bu paket kozalak-l1 mono-repo'sunun bir parçasıdır.

```bash
cd cli
npm install
npm run build            # TypeScript → dist/
npm run build:templates  # cli/templates/ paketlerini repo kaynaklarından yeniden üret
npm test                 # vitest (registry / scaffold / forge parse testleri)
```

`build:templates`, repo'nun denetlenmiş kaynaklarından (`src/templates/`,
`test/templates/`, `script/deploy/`, `foundry.lock`) her şablon için standalone
bir Foundry projesi assemble eder ve `cli/templates/<id>/` altına yazar. Repo
kaynakları değişince bu komut yeniden çalıştırılır ve paketlenmiş şablonlar
senkronlanır.

### Non-interactive mod (CI / E2E)

Otomasyon için prompt'lar atlanabilir:

```bash
node dist/index.js koza-e2e --template erc20-gas --yes-install --no-deploy
```

- `--template <id>` — şablon seçer ve non-interactive modu açar.
- `--yes-install` / `--no-install` — bağımlılık kurulumunu aç/kapat.
- `--no-deploy` — deploy'u atla (non-interactive modda deploy zaten yapılmaz,
  çünkü private key interaktif alınır).

## Yayınlama

Paket henüz npm'e yayınlanmadı. `npm publish` **yakında**; o zamana kadar
mono-repo içinden `node dist/index.js` veya `npm run dev` ile çalıştırılır.

## Lisans

MIT
