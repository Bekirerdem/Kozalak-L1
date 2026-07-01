#!/usr/bin/env node
/**
 * create-kozalak-l1 — interaktif scaffold + Fuji deploy akışı.
 *
 * Varsayılan mod: @clack ile adım adım sorular. Non-interactive mod
 * (`--template <id>` verilince) prompt'ları atlar; E2E ve CI içindir.
 *
 * Örnek (non-interactive):
 *   create-kozalak-l1 koza-e2e --template erc20-gas --yes-install --no-deploy
 */
import { existsSync, readFileSync } from "node:fs";
import { join, resolve } from "node:path";
import {
  intro,
  outro,
  cancel,
  select,
  text,
  password,
  confirm,
  isCancel,
  note,
  log,
} from "./prompts.js";
import { TEMPLATES, getTemplate, type TemplateDef } from "./templates.js";
import { scaffold } from "./scaffold.js";
import { deploy } from "./deploy.js";
import { forgeAvailable, runForge } from "./forge.js";

interface CliArgs {
  projectName?: string;
  templateId?: string;
  install: boolean; // --yes-install
  nonInteractive: boolean; // --template verildiyse
}

function parseArgs(argv: string[]): CliArgs {
  let projectName: string | undefined;
  let templateId: string | undefined;
  let install = false;
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--template") templateId = argv[++i];
    else if (a.startsWith("--template=")) templateId = a.slice("--template=".length);
    else if (a === "--yes-install") install = true;
    else if (a === "--no-install") install = false;
    else if (a === "--no-deploy") {
      /* non-interactive modda deploy zaten yapılmaz; flag CI okunabilirliği için kabul edilir */
    } else if (!a.startsWith("-") && projectName === undefined) projectName = a;
  }
  return { projectName, templateId, install, nonInteractive: templateId !== undefined };
}

/** Bir prompt sonucu iptal edildiyse temiz çıkış yapar; değilse değeri döner. */
function unwrap<T>(value: T | symbol): T {
  if (isCancel(value)) cancel("İşlem iptal edildi.");
  return value as T;
}

/**
 * Scaffold edilmiş projenin README'sinden pinli `forge install ...` komutunu
 * çıkarır (build-templates.ts her şablona bu satırı yazar). Bulunamazsa null.
 */
function forgeInstallArgs(cwd: string): string[] | null {
  const readmePath = join(cwd, "README.md");
  if (!existsSync(readmePath)) return null;
  const line = readFileSync(readmePath, "utf8")
    .split(/\r?\n/)
    .find((l) => l.trim().startsWith("forge install "));
  if (!line) return null;
  return line.trim().split(/\s+/).slice(1); // ['install', 'org/repo@rev', ...]
}

async function runInstall(targetDir: string): Promise<void> {
  if (!forgeAvailable()) {
    log.warn("forge bulunamadı — bağımlılık kurulumu atlandı. Foundry kurup projede `forge install` çalıştırın.");
    return;
  }
  const args = forgeInstallArgs(targetDir);
  if (!args) {
    log.warn("forge install komutu README'de bulunamadı; bağımlılıkları manuel kurun.");
    return;
  }
  log.step("Bağımlılıklar kuruluyor (forge install)... bu biraz sürebilir.");
  const res = runForge(args, targetDir, process.env);
  if (res.code === 0) {
    log.success("Bağımlılıklar kuruldu.");
  } else {
    log.warn(
      `forge install başarısız (exit ${res.code}). Projede manuel çalıştırın:\n${res.stderr || res.stdout}`,
    );
  }
}

/** Deploy adımı: private key + snowtrace + envParams sorup deploy() çağırır. */
async function runDeploy(template: TemplateDef, targetDir: string): Promise<void> {
  if (!forgeAvailable()) {
    log.warn("forge bulunamadı — deploy atlandı. Foundry kurulumundan sonra tekrar deneyin.");
    return;
  }

  const privateKey = unwrap(
    await password({
      message: "Deploy private key (⚠️ SADECE testnet cüzdanı — mainnet anahtarı GİRMEYİN)",
    }),
  );

  const snowRaw = unwrap(
    await text({
      message: "Snowtrace/Routescan API key (opsiyonel — kontrat doğrulama için, boş geçebilirsiniz)",
      placeholder: "rs_...",
    }),
  );
  const snowtraceKey = snowRaw.trim() || undefined;

  const envParams: Record<string, string> = {};
  for (const p of template.envParams) {
    const label = `${p.prompt}${p.optional ? " (opsiyonel)" : ""}`;
    const raw = unwrap(p.secret ? await password({ message: label }) : await text({ message: label, placeholder: "" }));
    const value = raw.trim();
    if (value) envParams[p.key] = value;
  }

  log.step("Fuji testnet'e deploy ediliyor...");
  try {
    const { address, explorerUrl } = await deploy({ template, cwd: targetDir, privateKey, snowtraceKey, envParams });
    if (address) {
      note(`Kontrat adresi:\n${address}\n\nExplorer:\n${explorerUrl}`, "Deploy başarılı");
    } else {
      log.warn("Deploy tamamlandı ama kontrat adresi broadcast dosyasından okunamadı.");
    }
  } catch (e) {
    log.error((e as Error).message);
  }
}

async function main(): Promise<void> {
  const cli = parseArgs(process.argv.slice(2));
  intro();

  // 1) Proje adı
  let projectName = cli.projectName;
  if (!projectName) {
    if (cli.nonInteractive) cancel("Non-interactive modda proje adı zorunludur: create-kozalak-l1 <ad> --template <id>");
    projectName = unwrap(
      await text({
        message: "Proje adı (klasör olarak oluşturulur)",
        placeholder: "benim-l1-projem",
        validate: (v) => (v && v.trim() ? undefined : "Proje adı boş olamaz."),
      }),
    ).trim();
  }

  // 2) Şablon
  let template: TemplateDef | undefined;
  if (cli.nonInteractive) {
    template = getTemplate(cli.templateId!);
    if (!template) {
      cancel(`Geçersiz şablon: "${cli.templateId}". Geçerli: ${TEMPLATES.map((t) => t.id).join(", ")}`);
    }
  } else {
    const id = unwrap(
      await select({
        message: "Bir şablon seçin",
        options: TEMPLATES.map((t) => ({ value: t.id, label: t.label, hint: t.description })),
      }),
    );
    template = getTemplate(id as string)!;
  }
  const tmpl = template!;

  // 3) Bağımlılık kurulumu?
  const wantInstall = cli.nonInteractive
    ? cli.install
    : unwrap(await confirm({ message: "Bağımlılıklar şimdi kurulsun mu? (forge install)" }));

  // 4) Scaffold
  const targetDir = resolve(process.cwd(), projectName);
  log.step(`"${projectName}" oluşturuluyor (${tmpl.label})...`);
  try {
    await scaffold({ template: tmpl, targetDir, projectName });
  } catch (e) {
    cancel((e as Error).message);
  }
  log.success("Proje dosyaları oluşturuldu.");

  // 5) forge install (best-effort)
  if (wantInstall) await runInstall(targetDir);

  // 6) Deploy (yalnızca interaktif mod + deployable şablon)
  if (!tmpl.deployable) {
    note(
      `Bu şablon (ICTT köprüsü) iki-zincirli, çok-adımlı bir kurulum gerektirir; otomatik tek-komut deploy yoktur.\n\nAdım adım rehber:\n${tmpl.guideDoc}`,
      "Sonraki adım: ICTT kurulum rehberi",
    );
  } else if (!cli.nonInteractive) {
    const wantDeploy = unwrap(await confirm({ message: "Şimdi Fuji testnet'e deploy edelim mi?" }));
    if (wantDeploy) await runDeploy(tmpl, targetDir);
  }

  outro(`Hazır! Sonraki adımlar:\n  cd ${projectName}\n  forge test`);
}

main().catch((e) => {
  cancel((e as Error).message);
});
