# Kozalak-L1 — Phase 2 + Phase 3 Tasarım Spec'i

**Tarih:** 2026-06-30
**Durum:** Onaylandı (brainstorm → spec)
**Kapsam:** Phase 3 (`create-kozalak-l1` CLI) + Phase 2 (olgunlaştırma dokümanları) + landing site entegrasyonu

---

## 1. Bağlam ve Amaç

Phase 1 tamamlandı: 5 audit-grade Solidity şablonu Fuji'de canlı + verified, Foundry test + Slither/Aderyn CI, Türkçe rehberler (01–05), Astro landing site.

Bu tur iki fazı **birlikte** kurar:

- **Phase 3 — Topluluğun eline:** Toolkit'i "kütüphane"den "ürüne" çevirmek. Birinin `git clone` yapmadan tek komutla şablon seçip Fuji'ye deploy edebilmesi.
- **Phase 2 — Olgunlaştırma:** Grant başvurusu, bug bounty, audit için gerçek, doldurulabilir dokümanlar.

Her görünür çıktı **mevcut site tasarım DNA'sı korunarak** üretilir.

---

## 2. Phase 3 — `create-kozalak-l1` CLI

### 2.1 Amaç ve akış

`npx create-kozalak-l1 [proje-adı]` → interaktif şablon seçimi → tam çalışır standalone Foundry projesi → opsiyonel `.env` wizard + Fuji'ye deploy + Snowtrace verify.

```
$ npx create-kozalak-l1 benim-token
◆ Hangi şablon?   › ERC-20 Gas / ERC-721 / Soulbound / Treasury / ICTT (scaffold-only)
◇ Bağımlılıklar kurulsun mu? (forge install)  › Evet
◇ Şimdi Fuji'ye deploy edelim mi?  › Evet
  ◇ Private key (gizli, SADECE testnet) ········
  ◇ Snowtrace API key (verify, opsiyonel) ····
  ◇ [ERC-721 ise] NFT adı / symbol / max supply / mint price
✓ benim-token/ hazır · ✓ forge install · ✓ deploy: 0xABC… → snowtrace linki
→ Sonraki adımlar: cd benim-token && forge test
```

### 2.2 Mimari — "tek kaynak" prensibi

Şablonları iki yerde tutmak (repo `src/` + CLI paketi) DRY ihlali olur. Çözüm:

- **Template bundle generator** (`cli/scripts/build-templates.ts`): repo kaynaklarından
  (`src/templates/X` + ilgili `test/` + `script/deploy/` + `docs/tr/03-templateler/`) her şablon için
  **standalone Foundry projesi** assemble eder → `cli/templates/X/`. CLI her publish'te repo ile %100 senkron.
- **Submodule versiyon pinleme:** scaffold edilen projenin bağımlılık versiyonları mevcut repo ile
  (`foundry.lock` / submodule commit'leri) **pin'lenir** ki audit-grade tutarlılık korunsun.
- **Paketleme:** şablonlar CLI paketine **bundle** edilir (degit/network değil) → offline, versiyonlu, güvenilir.
- **Stack:** Node.js + TypeScript, interaktif prompt `@clack/prompts`, deploy `forge` binary'sini
  `child_process` ile çağırır (forge precheck'i ile).

### 2.3 Template registry (`cli/src/templates.ts`)

Her şablon için metadata:

| Alan | Açıklama |
|------|----------|
| `id` | `erc20-gas`, `erc721-collection`, `soulbound-credential`, `treasury-multisig`, `ictt-bridge` |
| `label` / `description` | Prompt'ta gösterilen ad + tek satır açıklama |
| `srcFiles` | `src/templates/X/*.sol` |
| `testFiles` | İlgili `test/templates/*.t.sol` (+ invariants) |
| `deployScript` | `script/deploy/Deploy*.s.sol` |
| `guideDoc` | `docs/tr/03-templateler/*.md` |
| `remappings` | Yalnızca gereken satırlar (ERC-20/721/SBT/Treasury: OZ + forge-std; ICTT: + icm-contracts) |
| `submodules` | `forge-std` + `openzeppelin-contracts` her zaman; `icm-contracts` yalnızca ICTT |
| `solc` | `0.8.34` default; ICTT `0.8.25` (multi-version) |
| `envParams` | ERC-721: `NFT_NAME/SYMBOL/MAX_SUPPLY/MINT_PRICE/...`; diğerleri minimal |
| `deployable` | ICTT: `false` (scaffold-only, rehbere yönlendir); diğerleri `true` |

### 2.4 Scaffold çıktısı (standalone Foundry projesi)

```
benim-token/
  src/<Contract>.sol
  test/<Template>.t.sol (+ invariants varsa)
  script/Deploy<Template>.s.sol
  foundry.toml        # template-aware: minimal remappings + doğru solc + fuji/avalanche rpc + routescan etherscan
  remappings.txt      # yalnızca gereken satırlar
  .gitmodules         # yalnızca gereken submodule'ler (pinli)
  .env.example        # template-aware (ERC-721 ise NFT_* dahil)
  .gitignore          # .env, out/, cache/, broadcast/, lib/
  README.md           # Türkçe: kurulum + deploy + "yeniden adlandırmak istersen" notu
```

- **Bağımlılık kurulumu:** scaffold sonrası opsiyonel `forge install` (network + git gerekir).
- **Rename:** MVP'de contract isimleri **korunur** (`KozaGasToken`). Global find/replace = test/import kırma
  riski. README'de manuel rename notu. (AST-aware rename → gelecek, YAGNI.)

### 2.5 Deploy davranışı + güvenlik

- **Deploy edilebilir 4 şablon** (ERC-20, ERC-721, Soulbound, Treasury) → tek akışta `forge script … --rpc-url fuji --broadcast` + verify.
- **Verify:** explicit `--verify --verifier-url <routescan v2> --etherscan-api-key <key>` (toml interpolation flaky — lessons.md). Routescan testnet endpoint.
- **ICTT istisnası:** TokenHome (C-Chain) + TokenRemote (L1) + Warp/relayer → tek-tık gerçekçi değil.
  Scaffold-only; deploy adımı `docs/tr/03-templateler/ictt-demo-kanit.md` rehberine yönlendirir.
- **Güvenlik:**
  - Private key `@clack` gizli (password) input → `process.env` üzerinden forge'a geçer, **diske yazılmaz**.
  - "SADECE testnet" uyarısı; mainnet deploy CLI'den **yapılmaz** → keystore/hardware wallet yönlendirmesi.
- **forge precheck:** `forge` yoksa kurulum linkiyle anlamlı hata.

### 2.6 Dosya yapısı

```
cli/
  src/
    index.ts        # entry — interaktif akış orchestration
    templates.ts    # template registry
    scaffold.ts     # kopyala + config üret + .env.example + README + git init
    deploy.ts       # .env wizard + forge wrap + adres parse + snowtrace link
    forge.ts        # forge precheck + child_process sarmalayıcı
    prompts.ts      # @clack/prompts ince wrapper + ortak mesajlar
  scripts/
    build-templates.ts   # repo → cli/templates/ bundle generator
  templates/        # generated (build-templates çıktısı)
  package.json      # "bin": { "create-kozalak-l1": "dist/index.js" }
  tsconfig.json
  README.md
```

### 2.7 npm publish

Bu tur **kod + lokal doğrulama** (`npx .` / `npm link`). **npm publish ayrı, sonraki adım** — npm hesabı + isim rezervasyonu + Bekir onayı gerektirir. Site komutu gerçek (`npx create-kozalak-l1`) gösterir; publish'e kadar "yakında npm'de" rozeti.

---

## 3. Phase 2 — Olgunlaştırma dokümanları

1. **`SECURITY.md` genişletme** → bug bounty / responsible disclosure politikası:
   kapsam (5 şablon adresleri), severity sınıfları (Critical/High/Medium/Low), in/out-of-scope,
   raporlama akışı + iletişim. Ödül vaadi yok — "responsible disclosure" (gerçekçi).
2. **`docs/grant/grant-basvuru-taslagi.md`** → Team1 Mini / infraBUIDL / Retro9000 için
   doldurulabilir taslak: problem, çözüm, traction (5 şablon canlı + verified + CI yeşil), roadmap, bütçe kalemleri.
3. **`docs/grant/audit-hazirlik-checklist.md`** → Sherlock/Cantina contest öncesi hazırlık:
   NatSpec coverage, invariant dokümantasyonu, known issues, scope freeze, test coverage hedefi.

Dokümanlar **dolu** olmalı (placeholder/TBD değil) — proje gerçek verisiyle (canlı adresler, versiyonlar, CI durumu).

---

## 4. Site — tasarım DNA'sı korunarak

> Yeni tasarım dili **icat edilmez**; mevcut chamfer/renk/font/section pattern aynen kullanılır.

1. **Yeni bölüm: `frontend/src/components/Kullan.astro` (CLI tanıtımı)** — Phase 3'ün somut çıktısı.
   - Section header pattern: `"03 / Kullan"` (tracking-[0.3em] uppercase, `text-kozalak-red`, ince çizgi).
   - Büyük başlık (accent kelime `text-kozalak-red`).
   - `avax-chamfer-*` kart içinde **mono "terminal mockup"**: `$ npx create-kozalak-l1` + adım listesi (şablon seç → scaffold → deploy).
   - "Yakında npm'de" rozeti (publish'e kadar), GitHub linki.
   - `max-w-[1400px]`, `py-24 lg:py-32`, dark zemin — diğer bölümlerle birebir.
   - **Yeri:** `02 Şablonlar`'dan sonra. Numara kaydırma: Şablonlar 02 → **Kullan 03** → Mimari 04 → Yol Haritası 05.
2. **`YolHaritasi.astro` güncelleme** — Phase 2 item'larına doküman durumu (bug bounty politikası ✓ + link,
   grant taslağı ✓, audit checklist ✓), Phase 3 "CLI wrapper" item durumu. `status` ve `done` flag'leri güncellenir.
3. **`Nav.astro` güncelleme** — "Kullan" linki + numara sırası.
4. **`index.astro`** — `Kullan` bölümünü `Sablonlar` ile `Mimari` arasına ekle.

---

## 5. Kapsam dışı (YAGNI)

Web dashboard, L1 genesis üretici, ICTT tek-tık deploy, contract rename, mainnet deploy CLI'den,
npm publish'in kendisi (ayrı onaylı adım), profesyonel audit'in kendisi (yalnızca hazırlık).

---

## 6. Başarı kriterleri (doğrulanabilir)

1. **CLI build:** `cd cli && npm install && npm run build` → hatasız.
2. **Scaffold + build:** `node cli/dist/index.js test-proj` (non-interactive flag'lerle veya manuel) → `erc20-gas` →
   `test-proj/` oluşur → `forge build` + `forge test` geçer.
3. **Template senkron:** `npm run build:templates` repo kaynaklarından `cli/templates/`'i yeniden üretir, fark yok.
4. **Phase 2 docs:** 3 doküman yazılır, içerik dolu (placeholder yok), canlı adresler/versiyonlar doğru.
5. **Site build:** `cd frontend && npm run build` → hatasız; `Kullan` bölümü render olur; numaralar tutarlı (02→03→04→05).
6. **DNA uyumu:** yeni bölüm chamfer kart + mono terminal + `kozalak-red` accent + Cabinet Grotesk başlık —
   mevcut bölümlerden görsel olarak ayırt edilemez.
