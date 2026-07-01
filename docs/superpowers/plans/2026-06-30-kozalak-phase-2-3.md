# Kozalak-L1 Phase 2+3 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Toolkit'i ürüne çevir — `create-kozalak-l1` CLI'si + Phase 2 olgunlaştırma dokümanları + site CLI tanıtımı, mevcut tasarım DNA'sı korunarak.

**Architecture:** Mono-repo içinde 3 bağımsız parça. (A) Phase 2 markdown dokümanları. (B) `cli/` altında Node.js+TypeScript CLI — repo şablonlarından standalone Foundry projeleri assemble eden "tek kaynak" generator + interaktif scaffold/deploy. (C) Astro landing site'a mevcut chamfer/renk/font diliyle yeni `Kullan` bölümü.

**Tech Stack:** Foundry (Solidity 0.8.34 / ICTT 0.8.25), Node.js 18+, TypeScript, `@clack/prompts`, `vitest`, Astro 5 + Tailwind v4 + GSAP + Lenis.

## Global Constraints

- **Solidity:** 0.8.34 (ICTT şablonu 0.8.25, `auto_detect_solc=true` multi-version), `via_ir=true`, `optimizer_runs=200`.
- **Bağımlılıklar:** OpenZeppelin v5.3+ + `ava-labs/icm-contracts`; submodule versiyonları mevcut repo `foundry.lock`/submodule commit'leriyle **pin'lenir**.
- **Verify:** explicit `--verify --verifier-url https://api.routescan.io/v2/network/testnet/evm/43113/etherscan --etherscan-api-key <key>` (toml interpolation flaky).
- **Teleporter messenger:** `0x253b2784c75e510dD0fF1da844684a1aC0aa5fcf` (tüm L1'lerde deterministic).
- **Güvenlik:** private key gizli input → `process.env` üzerinden forge'a, **diske yazılmaz**; sadece testnet; mainnet CLI'den deploy edilmez.
- **CLI bin adı:** `create-kozalak-l1`. **npm publish bu turda YAPILMAZ** (ayrı onaylı adım).
- **Tasarım DNA (site):** display font `Cabinet Grotesk` weight **400** (light, bold değil); gövde `Inter`; accent `--color-kozalak-red #e84142`; zemin `--color-bg-primary #0a0a0a`; kart `avax-chamfer-tr` (`--cut:64px`); `max-w-[1400px]`; `py-24 lg:py-32`; section header `"NN / Başlık"` tracking-[0.3em] uppercase + `text-kozalak-red` + `flex-1 h-px bg-white/10`; alt detay `text-[0.65rem] font-mono opacity-50`. **Yeni tasarım dili icat edilmez.**
- **Dil:** tüm kullanıcıya dönük metin Türkçe, tam ortografik doğruluk (ç ş ğ ü ö ı İ).
- **Commit:** conventional commits; her task sonunda commit.

---

## FAZ A — Phase 2 Olgunlaştırma Dokümanları

Bağımsız, kod riski yok. Her doküman dolu olmalı (placeholder/TBD yok), proje gerçek verisiyle.

### Task 1: Bug bounty / responsible disclosure politikası

**Files:**
- Modify: `SECURITY.md` (mevcut dosyayı genişlet)

**Interfaces:**
- Consumes: yok
- Produces: `SECURITY.md` — site Phase 2 bölümünde "bug bounty politikası" linki bu dosyaya gider.

- [ ] **Step 1: Mevcut SECURITY.md'yi oku**

Run: mevcut içeriği oku, ton/format/dili koru (genişlet, yeniden yazma).

- [ ] **Step 2: Bug bounty bölümünü ekle**

Eklenecek bölümler (Türkçe):
- **Kapsam (in-scope):** 5 şablonun Fuji adresleri (README'den birebir): ERC-20 `0x06451DD4Fb8ebFC19870DacC9568f4364D2A2eB0`, ERC-721 `0x59347BB4365A18BBd92396Fd138E6cEfcDDb79C9`, ICTT Home `0x2b1377537690793939DC42530c15DA897AC9D2D9`, Soulbound `0xCFdE91F214ABDe2a2E65B6cd41A7C7E3244E1ec1`, Treasury `0x6864879522D70Fb8e1583Cc8Fd4baB0e9605A955`. Ayrıca `src/templates/**` kaynak kodu.
- **Severity sınıfları:** Critical / High / Medium / Low — her biri için 1 cümle kriter (ör. Critical = fon kaybı/yetkisiz mint; Low = gas inefficiency).
- **Out-of-scope:** üçüncü parti audited bağımlılıklar (OZ, icm-contracts), testnet-only deployment riskleri, bilinen `auto_detect_solc` multi-version durumu, henüz audit edilmemiş olması (zaten README'de belirtili).
- **Raporlama akışı:** GitHub Security Advisory (private) tercih; alternatif iletişim. Ödül **vaadi yok** — "responsible disclosure" + teşekkür/kredi.
- **SLA:** ilk yanıt hedefi (ör. 72 saat), düzeltme süreci.

- [ ] **Step 3: Doğrula — placeholder ve link kontrolü**

Run: `grep -nE "TBD|TODO|XXX|CHANGE_ME" SECURITY.md` → çıktı boş olmalı. Adreslerin README ile birebir aynı olduğunu kontrol et.

- [ ] **Step 4: Commit**

```bash
git add SECURITY.md
git commit -m "docs(security): bug bounty / responsible disclosure politikası ekle"
```

### Task 2: Grant başvuru taslağı

**Files:**
- Create: `docs/grant/grant-basvuru-taslagi.md`

**Interfaces:**
- Consumes: yok
- Produces: site Phase 2 bölümünde "grant taslağı" linki bu dosyaya gider.

- [ ] **Step 1: docs/grant/ dizinini oluştur ve taslağı yaz**

Türkçe, doldurulabilir başvuru taslağı. Bölümler: **Proje özeti** (1 paragraf), **Problem** (Türk dev için Avalanche L1 toolkit boşluğu), **Çözüm** (5 audit-grade şablon + Türkçe rehber + CLI), **Traction** (5/5 şablon Fuji'de canlı + verified, CI yeşil, ICTT çift-yön round-trip kanıtı), **Roadmap** (Phase 2/3), **Bütçe kalemleri** (audit, geliştirme, dokümantasyon — tutar placeholder olarak `<doldur>` değil, örnek aralık ver ama net etiketle), **Ekip** (Bekir Erdem, GitHub). Hedef programlar: Team1 Mini, infraBUIDL, Retro9000.

- [ ] **Step 2: Doğrula**

Run: `grep -nE "TBD|TODO|lorem" docs/grant/grant-basvuru-taslagi.md` → boş. Traction rakamları README ile tutarlı.

- [ ] **Step 3: Commit**

```bash
git add docs/grant/grant-basvuru-taslagi.md
git commit -m "docs(grant): grant başvuru taslağı ekle (Team1/infraBUIDL/Retro9000)"
```

### Task 3: Audit hazırlık checklist'i

**Files:**
- Create: `docs/grant/audit-hazirlik-checklist.md`

**Interfaces:**
- Consumes: yok
- Produces: site Phase 2 bölümünde "audit checklist" linki bu dosyaya gider.

- [ ] **Step 1: Checklist'i yaz**

Türkçe, Sherlock/Cantina contest öncesi hazırlık. Checkbox listesi: NatSpec coverage (tüm public/external fonksiyonlar), invariant dokümantasyonu (her şablon için korunması gereken invariant'lar — mevcut `*.invariants.t.sol` referansla), known issues listesi, scope freeze (commit hash sabitleme), test coverage hedefi (`forge coverage`), statik analiz temizliği (Slither/Aderyn 0 high), erişim kontrolü matrisi, upgrade/timelock varsayımları. Her madde için 1 satır "neden".

- [ ] **Step 2: Doğrula**

Run: `grep -nE "TBD|TODO" docs/grant/audit-hazirlik-checklist.md` → boş.

- [ ] **Step 3: Commit**

```bash
git add docs/grant/audit-hazirlik-checklist.md
git commit -m "docs(grant): audit hazırlık checklist'i ekle"
```

---

## FAZ B — `create-kozalak-l1` CLI

### Task 4: CLI iskeleti

**Files:**
- Create: `cli/package.json`, `cli/tsconfig.json`, `cli/.gitignore`, `cli/src/index.ts`, `cli/src/prompts.ts`, `cli/vitest.config.ts`
- Modify: kök `.gitignore` (gerekirse `cli/node_modules`, `cli/dist`)

**Interfaces:**
- Produces:
  - `cli/package.json` → `"bin": { "create-kozalak-l1": "dist/index.js" }`, `"type": "module"`, scripts: `build` (`tsc`), `build:templates` (`tsx scripts/build-templates.ts`), `test` (`vitest run`), `dev` (`tsx src/index.ts`).
  - `prompts.ts` → `export const intro(): void`, `export const outro(msg: string): void`, `export function cancel(msg: string): never` (process.exit(1)), `@clack/prompts` re-export wrapper'ları.

- [ ] **Step 1: package.json + tsconfig + bağımlılıklar**

`cli/package.json` deps: `@clack/prompts`. devDeps: `typescript`, `tsx`, `vitest`, `@types/node`. `tsconfig.json`: `target ES2022`, `module NodeNext`, `moduleResolution NodeNext`, `outDir dist`, `strict true`. Entry shebang: `#!/usr/bin/env node`.

```bash
cd cli && npm install
```

- [ ] **Step 2: prompts.ts wrapper + minimal index.ts**

`index.ts` şimdilik: intro yaz, "yakında" mesajı, outro. `prompts.ts` @clack wrapper.

- [ ] **Step 3: Build doğrula**

Run: `cd cli && npm run build && node dist/index.js`
Expected: intro/outro mesajları görünür, hata yok.

- [ ] **Step 4: Commit**

```bash
git add cli/
git commit -m "feat(cli): create-kozalak-l1 iskeleti (package + tsconfig + prompts)"
```

### Task 5: Template registry

**Files:**
- Create: `cli/src/templates.ts`, `cli/test/templates.test.ts`

**Interfaces:**
- Consumes: yok
- Produces:
```ts
export interface TemplateDef {
  id: 'erc20-gas' | 'erc721-collection' | 'soulbound-credential' | 'treasury-multisig' | 'ictt-bridge';
  label: string;          // prompt'ta görünen ad
  description: string;    // tek satır
  srcFiles: string[];     // repo-relative: 'src/templates/erc20-gas/KozaGasToken.sol'
  testFiles: string[];    // 'test/templates/ERC20Gas.t.sol', ...
  deployScript: string;   // 'script/deploy/DeployERC20Gas.s.sol'
  guideDoc: string;       // 'docs/tr/03-templateler/erc20-gas.md'
  remappings: string[];   // foundry.toml remappings'ten gereken alt küme
  submodules: ('forge-std'|'openzeppelin-contracts'|'icm-contracts')[];
  solc: string;           // '0.8.34' | '0.8.25'
  envParams: { key: string; prompt: string; secret?: boolean; optional?: boolean }[];
  deployable: boolean;    // ICTT: false
}
export const TEMPLATES: TemplateDef[];
export function getTemplate(id: string): TemplateDef | undefined;
```

- [ ] **Step 1: Failing test yaz**

`cli/test/templates.test.ts`:
```ts
import { describe, it, expect } from 'vitest';
import { TEMPLATES, getTemplate } from '../src/templates.js';

describe('template registry', () => {
  it('5 şablon içerir', () => expect(TEMPLATES).toHaveLength(5));
  it('ictt-bridge deployable=false', () => expect(getTemplate('ictt-bridge')?.deployable).toBe(false));
  it('erc20-gas deployable=true + OZ submodule', () => {
    const t = getTemplate('erc20-gas')!;
    expect(t.deployable).toBe(true);
    expect(t.submodules).toContain('openzeppelin-contracts');
    expect(t.submodules).not.toContain('icm-contracts');
  });
  it('sadece ICTT icm-contracts kullanır', () => {
    expect(getTemplate('ictt-bridge')!.submodules).toContain('icm-contracts');
  });
  it('erc721 NFT env paramları var', () => {
    expect(getTemplate('erc721-collection')!.envParams.some(p => p.key === 'NFT_NAME')).toBe(true);
  });
});
```

- [ ] **Step 2: Test fail doğrula**

Run: `cd cli && npx vitest run test/templates.test.ts`
Expected: FAIL (templates.ts yok).

- [ ] **Step 3: templates.ts'i doldur**

Repo'daki `foundry.toml` remappings'i, `src/templates/`, `test/templates/`, `script/deploy/`, `docs/tr/03-templateler/` dosyalarını referans alarak 5 `TemplateDef` yaz. ICTT: 2 src dosyası (Home+Remote), `solc='0.8.25'`, icm-contracts remappings (`@subnet-evm`, `@teleporter`, `@utilities`, `@mocks`, `@ictt`, `icm-contracts/`), `deployable=false`. Diğer 4: OZ + forge-std remapping, `solc='0.8.34'`, `deployable=true`.

- [ ] **Step 4: Test pass doğrula**

Run: `cd cli && npx vitest run test/templates.test.ts`
Expected: PASS (5/5).

- [ ] **Step 5: Commit**

```bash
git add cli/src/templates.ts cli/test/templates.test.ts
git commit -m "feat(cli): template registry (5 şablon metadata)"
```

### Task 6: Template bundle generator

**Files:**
- Create: `cli/scripts/build-templates.ts`
- Generate: `cli/templates/<id>/` (her şablon için standalone Foundry projesi)

**Interfaces:**
- Consumes: `TEMPLATES` (Task 5), repo kök dosyaları.
- Produces: `cli/templates/<id>/` dizinleri — scaffold.ts bunları kopyalar.

- [ ] **Step 1: Generator'ı yaz**

`build-templates.ts` her `TemplateDef` için `cli/templates/<id>/` üretir:
- `src/` ← `srcFiles` (flatten: `src/<dosya adı>.sol`)
- `test/` ← `testFiles`
- `script/` ← `deployScript` (→ `script/Deploy<X>.s.sol`)
- `foundry.toml` ← template-aware (sadece `t.remappings`, `t.solc`'a uygun `auto_detect_solc`, fuji/avalanche rpc, routescan etherscan blokları).
- `remappings.txt` ← `t.remappings`
- `.gitmodules` ← `t.submodules` (her biri için path+url; URL'ler kök `.gitmodules`'ten).
- **Submodule pin:** kök repo'dan her submodule'ün commit'ini oku (`git -C <repo> submodule status` veya `foundry.lock`), `foundry.lock`'a yaz veya README'de pin commit'i belirt.
- `.env.example` ← ortak (PRIVATE_KEY, SNOWTRACE_API_KEY, TELEPORTER_MESSENGER_ADDRESS) + `t.envParams`.
- `.gitignore` ← `.env\nout/\ncache/\nbroadcast/\nlib/`
- `README.md` ← template-aware Türkçe (kurulum: `forge install && forge build && forge test`; deploy; "yeniden adlandırmak istersen `src/`, `test/`, `script/` dosyalarındaki contract adını değiştir" notu; ICTT için deploy yerine rehber linki).

İmport yolu düzeltme: kopyalanan `.sol` dosyalarındaki import path'leri scaffold projesinin remapping'leriyle çalışmalı (repo zaten remapping kullanıyor — `@openzeppelin/contracts/...` aynen geçer, ek değişiklik gerekmez; doğrula).

- [ ] **Step 2: Generator'ı çalıştır**

Run: `cd cli && npm run build:templates`
Expected: `cli/templates/erc20-gas/` … `cli/templates/ictt-bridge/` oluşur.

- [ ] **Step 3: Üretilen bir şablonu gerçek forge ile doğrula (en kritik adım)**

```bash
cd cli/templates/erc20-gas
forge install   # forge-std + openzeppelin-contracts (pinli)
forge build
forge test
```
Expected: build + test PASS. (ERC-721 ve Soulbound için de tekrarla — en az 2 deployable şablon doğrulanmalı.)

- [ ] **Step 4: cli/templates'i commit politikası**

`cli/templates/` generated. Karar: **commit edilir** (publish'te paket içinde gitmeli, build adımına bağımlı kalmasın). `cli/.gitignore`'a `templates/lib/`, `templates/**/out/`, `templates/**/cache/` ekle ama `templates/**/src,test,script,*.toml,*.txt,*.md` commit'le.

- [ ] **Step 5: Commit**

```bash
git add cli/scripts/build-templates.ts cli/templates cli/.gitignore
git commit -m "feat(cli): template bundle generator + 5 standalone Foundry projesi"
```

### Task 7: Scaffold mantığı

**Files:**
- Create: `cli/src/scaffold.ts`, `cli/test/scaffold.test.ts`

**Interfaces:**
- Consumes: `TemplateDef` (Task 5), `cli/templates/` (Task 6).
- Produces:
```ts
export interface ScaffoldOpts { template: TemplateDef; targetDir: string; projectName: string; }
export async function scaffold(opts: ScaffoldOpts): Promise<void>; // templates/<id>'yi targetDir'e kopyalar, git init eder
export function templatesRoot(): string; // bundle edilmiş templates/ yolu (paket-relative, import.meta.url ile)
```

- [ ] **Step 1: Failing test yaz**

`scaffold.test.ts`: geçici dizine `erc20-gas` scaffold et, `src/KozaGasToken.sol` + `foundry.toml` + `README.md` + `.env.example` var mı kontrol et; hedef dizin doluysa hata fırlatsın.
```ts
import { describe, it, expect, afterEach } from 'vitest';
import { scaffold, templatesRoot } from '../src/scaffold.js';
import { getTemplate } from '../src/templates.js';
import { mkdtempSync, existsSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

let dir: string;
afterEach(() => { if (dir) rmSync(dir, { recursive: true, force: true }); });

it('erc20-gas scaffold dosyaları üretir', async () => {
  const base = mkdtempSync(join(tmpdir(), 'koza-'));
  dir = join(base, 'benim-token');
  await scaffold({ template: getTemplate('erc20-gas')!, targetDir: dir, projectName: 'benim-token' });
  expect(existsSync(join(dir, 'foundry.toml'))).toBe(true);
  expect(existsSync(join(dir, 'src', 'KozaGasToken.sol'))).toBe(true);
  expect(existsSync(join(dir, 'README.md'))).toBe(true);
});
```

- [ ] **Step 2: Test fail doğrula**

Run: `cd cli && npx vitest run test/scaffold.test.ts` → FAIL.

- [ ] **Step 3: scaffold.ts implement et**

`templatesRoot()` → `new URL('../templates', import.meta.url)` (dist'ten paket köküne). `scaffold()`: hedef dizin varsa+doluysa throw; `cp -r` (node `fs.cp` recursive) `templates/<id>` → `targetDir`; `git init` (child_process, opsiyonel/best-effort). Bundle'da zaten config dosyaları var, ek üretim yok.

- [ ] **Step 4: Test pass doğrula**

Run: `cd cli && npx vitest run test/scaffold.test.ts` → PASS.

- [ ] **Step 5: Commit**

```bash
git add cli/src/scaffold.ts cli/test/scaffold.test.ts
git commit -m "feat(cli): scaffold mantığı (bundle kopyala + git init)"
```

### Task 8: Forge wrapper + deploy

**Files:**
- Create: `cli/src/forge.ts`, `cli/src/deploy.ts`, `cli/test/forge.test.ts`

**Interfaces:**
- Consumes: `TemplateDef`.
- Produces:
```ts
// forge.ts
export function forgeAvailable(): boolean;                    // `forge --version` çalışır mı
export function runForge(args: string[], cwd: string, env: NodeJS.ProcessEnv): { code: number; stdout: string };
export function parseDeployedAddress(broadcastJson: string): string | null;  // broadcast/*/run-latest.json'dan
// deploy.ts
export interface DeployInput { template: TemplateDef; cwd: string; privateKey: string; snowtraceKey?: string; envParams: Record<string,string>; }
export async function deploy(input: DeployInput): Promise<{ address: string | null; explorerUrl: string | null }>;
```

- [ ] **Step 1: parseDeployedAddress için failing test**

`forge.test.ts`: örnek bir Foundry `run-latest.json` fixture string'inden `contractAddress`'i çıkarsın (deterministic, forge çağırmadan).
```ts
import { describe, it, expect } from 'vitest';
import { parseDeployedAddress } from '../src/forge.js';
it('broadcast json adres çıkarır', () => {
  const json = JSON.stringify({ transactions: [{ contractAddress: '0xAbc0000000000000000000000000000000000001', contractName: 'KozaGasToken' }] });
  expect(parseDeployedAddress(json)).toBe('0xAbc0000000000000000000000000000000000001');
});
it('adres yoksa null', () => expect(parseDeployedAddress('{"transactions":[]}')).toBeNull());
```

- [ ] **Step 2: Test fail doğrula**

Run: `cd cli && npx vitest run test/forge.test.ts` → FAIL.

- [ ] **Step 3: forge.ts + deploy.ts implement et**

`forge.ts`: `forgeAvailable` (`execSync('forge --version')` try/catch); `runForge` (`spawnSync('forge', args, {cwd, env, encoding:'utf8'})`); `parseDeployedAddress` (JSON parse → `transactions[].contractAddress` ilk dolu).
`deploy.ts`: env hazırla (`PRIVATE_KEY`, `SNOWTRACE_API_KEY`, `TELEPORTER_MESSENGER_ADDRESS`, envParams) → `process.env`'e yaz (diske değil); forge args: `['script', t.deployScript-relative, '--rpc-url','fuji','--broadcast']` + snowtraceKey varsa `['--verify','--verifier-url', ROUTESCAN_TESTNET, '--etherscan-api-key', key]`; çalıştır; `broadcast/<script>/43113/run-latest.json` oku → `parseDeployedAddress`; explorerUrl = `https://testnet.snowtrace.io/address/<addr>`.

- [ ] **Step 4: Test pass doğrula**

Run: `cd cli && npx vitest run test/forge.test.ts` → PASS.

- [ ] **Step 5: Commit**

```bash
git add cli/src/forge.ts cli/src/deploy.ts cli/test/forge.test.ts
git commit -m "feat(cli): forge wrapper + Fuji deploy/verify"
```

### Task 9: index.ts orchestration + E2E lokal doğrulama

**Files:**
- Modify: `cli/src/index.ts`
- Create: `cli/README.md`

**Interfaces:**
- Consumes: `prompts`, `TEMPLATES`/`getTemplate`, `scaffold`, `deploy`, `forgeAvailable`.
- Produces: çalışır CLI.

- [ ] **Step 1: index.ts akışını yaz**

Akış: `intro` → proje adı (argv[2] veya `text` prompt) → `select` şablon (TEMPLATES) → `confirm` "forge install?" → scaffold çağır → (deployable && confirm "deploy?") ise: `forgeAvailable` kontrol (yoksa uyar+atla) → `password` private key (testnet uyarısı) → `text` snowtrace key (optional) → template envParams sor → `deploy` çağır → adres+explorer göster. ICTT seçilirse deploy yerine rehber linki (`docs/tr/03-templateler/ictt-demo-kanit.md`). `outro` sonraki adımlar. İptal (`isCancel`) → temiz çıkış.

- [ ] **Step 2: Build + non-interactive smoke**

Run: `cd cli && npm run build`
Expected: hatasız derlenir.

- [ ] **Step 3: E2E — gerçek scaffold + forge (kritik kabul testi)**

```bash
cd /tmp && rm -rf koza-e2e && node <repo>/cli/dist/index.js koza-e2e
# erc20-gas seç, forge install evet, deploy hayır
cd koza-e2e && forge build && forge test
```
Expected: proje oluşur, `forge build` + `forge test` PASS. (Başarı kriteri #2.)

- [ ] **Step 4: cli/README.md yaz**

Türkçe: ne işe yarar, `npx create-kozalak-l1`, geliştirme (`npm run build:templates`, `npm test`), "npm publish yakında" notu.

- [ ] **Step 5: Commit**

```bash
git add cli/src/index.ts cli/README.md
git commit -m "feat(cli): interaktif scaffold+deploy akışı + README"
```

---

## FAZ C — Site (tasarım DNA'sı korunarak)

### Task 10: `Kullan.astro` CLI tanıtım bölümü

**Files:**
- Create: `frontend/src/components/Kullan.astro`

**Interfaces:**
- Consumes: global.css DNA token'ları.
- Produces: `<Kullan />` bileşeni — index.astro kullanır.

- [ ] **Step 1: Bileşeni yaz (DNA birebir)**

`YolHaritasi.astro`'yu referans şablon al. Yapı:
- `<section id="kullan" class="relative w-full bg-bg-primary text-white py-24 lg:py-32 px-4 lg:px-8">` + `max-w-[1400px] mx-auto`.
- Section header: `"03 / Kullan"` — `text-kozalak-red` + `tracking-[0.3em] uppercase` + `flex-1 h-px bg-white/10`.
- Başlık (font-sans font-bold leading-[0.95] tracking-tight, accent kelime `text-kozalak-red`): ör. "Tek komutla **Avalanche L1 projesi**."
- `avax-chamfer-tr` kart (`bg-bg-card-dark` veya `bg-kozalak-red-deep`) içinde **mono terminal**: `<pre class="font-mono text-sm">` → `$ npx create-kozalak-l1 benim-token` + birkaç satır akış.
- Sağda/altda 3 adım listesi (şablon seç → scaffold → Fuji'ye deploy) — YolHaritasi item stiliyle.
- "Yakında npm'de" rozeti (YolHaritasi'ndaki TAMAMLANDI rozet stili: `bg-white/15 px-2 py-1 rounded-full text-[0.65rem]`).
- GitHub linki (kare buton, `radius-button 0`).
- Alt detay: `text-[0.65rem] font-mono opacity-50 border-t border-white/10`.

- [ ] **Step 2: Render doğrula (geçici)**

`index.astro`'ya geçici ekleyip `cd frontend && npm run build` → hata yok. (Kalıcı entegrasyon Task 11.)

- [ ] **Step 3: Commit**

```bash
git add frontend/src/components/Kullan.astro
git commit -m "feat(site): Kullan (CLI tanıtım) bölümü — DNA korunarak"
```

### Task 11: index.astro + Nav entegrasyonu + numara kaydırma

**Files:**
- Modify: `frontend/src/pages/index.astro`, `frontend/src/components/Nav.astro`

**Interfaces:**
- Consumes: `Kullan.astro`.
- Produces: yeni bölüm sırası 01→02→03(Kullan)→04(Mimari)→05(Yol Haritası).

- [ ] **Step 1: index.astro'ya Kullan'ı ekle**

`Sablonlar` (02) ile `Mimari` (03) arasına `<Kullan />` import + yerleştir.

- [ ] **Step 2: Numara kaydırma**

`Mimari.astro` header'ı `03 →` `04`, `YolHaritasi.astro` `04 →` `05` olacak şekilde section numaralarını güncelle. (Yalnızca numara metni — başka değişiklik yok.)

- [ ] **Step 3: Nav.astro — "Kullan" linki**

Nav'a `#kullan` linki ekle (mevcut link stilini birebir kopyala), sıralamayı Şablonlar'dan sonra koy.

- [ ] **Step 4: Build doğrula**

Run: `cd frontend && npm run build`
Expected: hatasız; numaralar 01→02→03→04→05 tutarlı.

- [ ] **Step 5: Commit**

```bash
git add frontend/src/pages/index.astro frontend/src/components/Nav.astro frontend/src/components/Mimari.astro frontend/src/components/YolHaritasi.astro
git commit -m "feat(site): Kullan bölümünü entegre et + section numaralarını kaydır"
```

### Task 12: YolHaritasi içerik güncellemesi

**Files:**
- Modify: `frontend/src/components/YolHaritasi.astro`

**Interfaces:**
- Consumes: Faz A doküman yolları, CLI durumu.
- Produces: güncel roadmap.

- [ ] **Step 1: Phase 2 + Phase 3 item'larını güncelle**

Phase 2 item'ları: "Bug bounty politikası" `done:true` + (mümkünse) `SECURITY.md` linki; "Grant başvuru taslağı" `done:true`; "Audit hazırlık checklist" `done:true`; "Grant başvurusu (gönderim)" `done:false`. Phase 2 `status: 'next'`. Phase 3 item'ları: "CLI wrapper (create-kozalak-l1)" `done:true`; "npm publish" `done:false`; "Web dashboard" `done:false`; "Daha fazla şablon" `done:false`. Alt-detay metni (idx===1/2) güncelle.

- [ ] **Step 2: Build doğrula**

Run: `cd frontend && npm run build`
Expected: hatasız, item durumları doğru render.

- [ ] **Step 3: Commit**

```bash
git add frontend/src/components/YolHaritasi.astro
git commit -m "docs(site): yol haritası — Phase 2 docs + Phase 3 CLI durumunu yansıt"
```

---

## Self-Review (yazım sonrası)

**Spec coverage:** Spec §2 (CLI) → Task 4-9 ✓; §3 (Phase 2 docs) → Task 1-3 ✓; §4 (site) → Task 10-12 ✓; §6 başarı kriterleri → Task 6 step 3 (#3), Task 9 step 3 (#2), Task 11/12 build (#5), Faz A doğrulama (#4) ✓.

**Placeholder scan:** Plan içinde TBD/TODO yok; kod örnekleri gerçek interface'ler.

**Type consistency:** `TemplateDef`/`getTemplate`/`TEMPLATES` (Task 5) → Task 6/7/8/9'da aynı isimlerle tüketilir; `scaffold`/`templatesRoot` (Task 7), `parseDeployedAddress`/`deploy` (Task 8) tutarlı.

**Bilinen risk:** Task 6 step 3 (üretilen şablonun gerçek `forge build/test`'i geçmesi) en kritik nokta — import path / remapping / submodule pin burada doğrulanır; sorun çıkarsa generator'a geri dönülür.
