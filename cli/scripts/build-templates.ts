/**
 * build-templates.ts — Şablon paketi üreticisi (Task 6).
 *
 * "Tek kaynak" prensibi: kozalak-l1 mono-repo'sunun denetlenmiş kaynaklarından
 * (`src/templates/`, `test/templates/`, `script/deploy/`, `foundry.toml`,
 * `foundry.lock`, `.gitmodules`) her şablon için **standalone, kendi başına
 * derlenebilir** bir Foundry projesi assemble eder → `cli/templates/<id>/`.
 *
 * Repo değişince bu generator yeniden çalıştırılır ve paketlenmiş şablonlar
 * senkronlanır. Çıktı dizinleri commit edilir; scaffold.ts (Task 7) bunları
 * kopyalar.
 *
 * Çalıştır: `cd cli && npm run build:templates`
 */
import { mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { basename, dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { TEMPLATES, type TemplateDef } from "../src/templates.js";

const SCRIPT_DIR = dirname(fileURLToPath(import.meta.url));
const CLI_ROOT = resolve(SCRIPT_DIR, "..");
const REPO_ROOT = resolve(CLI_ROOT, "..");
const OUT_ROOT = join(CLI_ROOT, "templates");

/* -------------------------------------------------------------------------- */
/*                       Submodule pin metadata (tek kaynak)                   */
/* -------------------------------------------------------------------------- */

interface SubmoduleMeta {
  url: string;
  tag: string;
  rev: string;
}

/**
 * `foundry.lock` (pin: tag + commit) ile `.gitmodules` (url) dosyalarını
 * okuyup submodule adı → {url, tag, rev} eşlemesi üretir. Versiyonlar repo
 * ile birebir aynı kalır (audit-grade tutarlılık).
 */
function readSubmoduleMeta(): Record<string, SubmoduleMeta> {
  const lock = JSON.parse(
    readFileSync(join(REPO_ROOT, "foundry.lock"), "utf8"),
  ) as Record<string, { tag?: { name: string; rev: string } }>;

  const gitmodules = readFileSync(join(REPO_ROOT, ".gitmodules"), "utf8");
  const urlByName: Record<string, string> = {};
  const blockRe = /path\s*=\s*(\S+)\s+url\s*=\s*(\S+)/g;
  for (let m = blockRe.exec(gitmodules); m; m = blockRe.exec(gitmodules)) {
    const name = m[1].split(/[\\/]/).pop()!;
    urlByName[name] = m[2];
  }

  const meta: Record<string, SubmoduleMeta> = {};
  for (const [key, value] of Object.entries(lock)) {
    const name = key.split(/[\\/]/).pop()!;
    if (!value.tag) continue;
    const url = urlByName[name];
    if (!url) throw new Error(`.gitmodules'te url bulunamadı: ${name}`);
    meta[name] = { url, tag: value.tag.name, rev: value.tag.rev };
  }
  return meta;
}

const SUBMODULE_META = readSubmoduleMeta();

/* -------------------------------------------------------------------------- */
/*                              Import yolu düzeltme                           */
/* -------------------------------------------------------------------------- */

/**
 * Flatten edilmiş yapıya göre repo-relative import'ları düzeltir.
 *
 * Repo'da test/script dosyaları kaynağa `../../src/templates/<id>/X.sol` ve
 * `../../script/deploy/X.s.sol` ile relative import yapıyor. Scaffold'da
 * yapı flatten olduğu için (`src/X.sol`, `test/X.t.sol`, `script/X.s.sol`)
 * bu yollar kırılır → tek seviye relative'e yeniden yazılır.
 *
 * `@openzeppelin/...`, `forge-std/...`, `@ictt/...` gibi remapping-tabanlı
 * import'lar dokunulmadan geçer (remappings.txt'de tanımlı).
 */
function rewriteImports(code: string): string {
  return code
    .replace(
      /(["'])\.\.\/\.\.\/src\/templates\/(?:[^"'/]+\/)+([^"'/]+\.sol)\1/g,
      "$1../src/$2$1",
    )
    .replace(
      /(["'])\.\.\/\.\.\/script\/deploy\/([^"'/]+\.sol)\1/g,
      "$1../script/$2$1",
    );
}

/** Bir .sol dosyasını kopyalar + import'larını düzeltir. */
function copySol(repoRelSrc: string, destPath: string): void {
  const raw = readFileSync(join(REPO_ROOT, repoRelSrc), "utf8");
  mkdirSync(dirname(destPath), { recursive: true });
  writeFileSync(destPath, rewriteImports(raw));
}

/* -------------------------------------------------------------------------- */
/*                            Dosya içeriği üreticileri                        */
/* -------------------------------------------------------------------------- */

function foundryToml(t: TemplateDef): string {
  const remappings = t.remappings.map((r) => `    "${r}"`).join(",\n");
  return `[profile.default]
src = "src"
out = "out"
libs = ["lib"]
test = "test"
script = "script"
# Bu şablon solc ${t.solc} pragma'sı kullanır. auto_detect_solc dosya
# pragma'sına göre doğru derleyiciyi otomatik indirir/seçer.
auto_detect_solc = true
optimizer = true
optimizer_runs = 200
via_ir = true
bytecode_hash = "none"
cbor_metadata = false
remappings = [
${remappings}
]

[fmt]
line_length = 120
tab_width = 4
bracket_spacing = false
int_types = "long"
multiline_func_header = "all"
quote_style = "double"
number_underscore = "thousands"

[rpc_endpoints]
fuji = "https://api.avax-test.network/ext/bc/C/rpc"
avalanche = "https://api.avax.network/ext/bc/C/rpc"

[etherscan]
fuji = { key = "\${SNOWTRACE_API_KEY}", url = "https://api.routescan.io/v2/network/testnet/evm/43113/etherscan", chain = 43113 }
avalanche = { key = "\${SNOWTRACE_API_KEY}", url = "https://api.routescan.io/v2/network/mainnet/evm/43114/etherscan", chain = 43114 }
`;
}

function remappingsTxt(t: TemplateDef): string {
  return t.remappings.join("\n") + "\n";
}

function gitmodules(t: TemplateDef): string {
  return (
    t.submodules
      .map((name) => {
        const url = SUBMODULE_META[name].url;
        return `[submodule "lib/${name}"]\n\tpath = lib/${name}\n\turl = ${url}`;
      })
      .join("\n") + "\n"
  );
}

/** forge install için pinli kurulum komutu (org/repo@commit). */
function installCommand(t: TemplateDef): string {
  const ORG: Record<string, string> = {
    "forge-std": "foundry-rs/forge-std",
    "openzeppelin-contracts": "OpenZeppelin/openzeppelin-contracts",
    "icm-contracts": "ava-labs/icm-contracts",
  };
  const deps = t.submodules
    .map((name) => `${ORG[name]}@${SUBMODULE_META[name].rev}`)
    .join(" ");
  return `forge install ${deps}`;
}

function gitignore(): string {
  return [".env", "out/", "cache/", "broadcast/", "lib/", ""].join("\n");
}

const TELEPORTER = "0x253b2784c75e510dD0fF1da844684a1aC0aa5fcf";

function envExample(t: TemplateDef): string {
  const lines = [
    "# ============================================",
    "# Bu dosyayı kopyalayıp `.env` olarak adlandırın. `.env` ASLA commit edilmez.",
    "# ============================================",
    "",
    "# ---- Deploy Wallet (Fuji testnet) ----",
    "# UYARI: Mainnet private key'i ASLA buraya koyma. Sadece testnet için.",
    "# Production'da Foundry Cast Wallet (encrypted keystore) veya hardware wallet kullan.",
    "PRIVATE_KEY=",
    "",
    "# Deployer adres (sanity check, opsiyonel)",
    "DEPLOYER_ADDRESS=",
    "",
    "# ---- Block Explorer (Routescan) ----",
    "# routescan.io'dan ücretsiz `rs_` prefix'li API key al. `--verify` için gerekir.",
    "SNOWTRACE_API_KEY=",
    "",
    "# ---- ICM / Teleporter ----",
    "# Avalanche Teleporter messenger — tüm L1'lerde deterministic adres.",
    `TELEPORTER_MESSENGER_ADDRESS=${TELEPORTER}`,
  ];
  if (t.envParams.length > 0) {
    lines.push("", `# ---- ${t.label} parametreleri ----`);
    for (const p of t.envParams) {
      const tag = p.optional ? " (opsiyonel)" : "";
      lines.push(`# ${p.prompt}${tag}`);
      lines.push(`${p.key}=`);
    }
  }
  lines.push("");
  return lines.join("\n");
}

function pinTable(t: TemplateDef): string {
  const rows = t.submodules
    .map((name) => {
      const m = SUBMODULE_META[name];
      return `| \`${name}\` | ${m.tag} | \`${m.rev}\` |`;
    })
    .join("\n");
  return `| Bağımlılık | Tag | Commit (pin) |\n| --- | --- | --- |\n${rows}`;
}

function readme(t: TemplateDef): string {
  const scriptName = basename(t.deployScript);
  const installCmd = installCommand(t);

  const needsIcm = t.submodules.includes("icm-contracts");

  // ICTT, icm-contracts'ın iç içe (recursive) submodule'larını gerektirir.
  const installBlock = needsIcm
    ? `> **Windows notu:** icm-contracts'ın iç içe submodule yolları uzundur;
> önce uzun-yol desteğini aç: \`git config --system core.longpaths true\`

\`\`\`bash
${installCmd}
# icm-contracts'ın iç bağımlılıkları (oz-upgradeable, subnet-evm) için:
git -C lib/icm-contracts submodule update --init --recursive
forge build
forge test
\`\`\``
    : `\`\`\`bash
${installCmd}
forge build
forge test
\`\`\``;

  const deploySection = t.deployable
    ? `## Deploy (Fuji testnet)

\`\`\`bash
cp .env.example .env      # PRIVATE_KEY + SNOWTRACE_API_KEY doldur
forge script script/${scriptName} \\
    --rpc-url fuji \\
    --broadcast \\
    --verify
\`\`\`

> Production: \`PRIVATE_KEY\` yalnızca testnet olmalı; sahiplik/yönetici
> adreslerini bir multisig'e (Safe) yönlendir, EOA bırakma.`
    : `## Deploy

Bu şablon (ICTT köprüsü) çok-adımlı, iki-zincirli bir kurulum gerektirir
(Home + Remote + Teleporter registry). Otomatik tek-komut deploy YOKTUR.

Adım adım rehber: kozalak-l1 deposundaki
\`docs/tr/03-templateler/${basename(t.guideDoc)}\` dosyasını izleyin.`;

  return `# ${t.label}

${t.description}

Bu, kozalak-l1 deposundan üretilmiş **standalone** bir Foundry projesidir;
kendi başına derlenir ve test edilir.

## Kurulum

${installBlock}

> \`forge install ...@<commit>\` bağımlılıkları repo ile birebir aynı commit'lere
> pinler (aşağıdaki tabloya bakın). \`.gitmodules\` ve \`remappings.txt\`
> bu pinlerle uyumludur.

${deploySection}

## Yeniden adlandırma

Contract'ı kendi adınla yeniden adlandırmak istersen \`src/\`, \`test/\` ve
\`script/\` altındaki dosyalarda contract/dosya adını birlikte güncelle
(import'lar tek-seviye relative olduğu için tutarlı kalmalı).

## Bağımlılık pinleri

${pinTable(t)}

---

_Bu proje \`create-kozalak-l1\` tarafından üretildi. Kaynak: kozalak-l1 mono-repo._
`;
}

/* -------------------------------------------------------------------------- */
/*                                 Üretim akışı                                */
/* -------------------------------------------------------------------------- */

function buildTemplate(t: TemplateDef): void {
  const outDir = join(OUT_ROOT, t.id);
  rmSync(outDir, { recursive: true, force: true });
  mkdirSync(outDir, { recursive: true });

  // src/ — flatten, import düzeltme (defansif; src dosyalarında relative yok).
  for (const rel of t.srcFiles) {
    copySol(rel, join(outDir, "src", basename(rel)));
  }
  // test/ — flatten + import düzeltme.
  for (const rel of t.testFiles) {
    copySol(rel, join(outDir, "test", basename(rel)));
  }
  // script/ — flatten + import düzeltme.
  copySol(t.deployScript, join(outDir, "script", basename(t.deployScript)));

  // Konfig + meta dosyaları.
  writeFileSync(join(outDir, "foundry.toml"), foundryToml(t));
  writeFileSync(join(outDir, "remappings.txt"), remappingsTxt(t));
  writeFileSync(join(outDir, ".gitmodules"), gitmodules(t));
  writeFileSync(join(outDir, ".env.example"), envExample(t));
  writeFileSync(join(outDir, ".gitignore"), gitignore());
  writeFileSync(join(outDir, "README.md"), readme(t));

  const fileCount =
    t.srcFiles.length + t.testFiles.length + 1; // +1 deploy script
  console.log(
    `  ✓ ${t.id.padEnd(22)} (${fileCount} .sol, ${t.submodules.length} submodule)`,
  );
}

function main(): void {
  console.log(`Şablon paketleri üretiliyor → cli/templates/`);
  rmSync(OUT_ROOT, { recursive: true, force: true });
  mkdirSync(OUT_ROOT, { recursive: true });
  for (const t of TEMPLATES) buildTemplate(t);
  console.log(`\n${TEMPLATES.length} şablon üretildi.`);
}

main();
