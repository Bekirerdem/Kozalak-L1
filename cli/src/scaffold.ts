import { existsSync, readdirSync } from 'node:fs';
import { cp, mkdir } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { join } from 'node:path';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import type { TemplateDef } from './templates.js';

const execFileAsync = promisify(execFile);

export interface ScaffoldOpts {
  template: TemplateDef;
  targetDir: string;
  projectName: string;
}

/** Bundle edilmiş templates/ dizininin paket-relative yolu (dist'ten paket köküne çözülür). */
export function templatesRoot(): string {
  return fileURLToPath(new URL('../templates', import.meta.url));
}

export async function scaffold(opts: ScaffoldOpts): Promise<void> {
  const { template, targetDir } = opts;

  if (existsSync(targetDir) && readdirSync(targetDir).length > 0) {
    throw new Error(`Hedef dizin boş değil: ${targetDir}`);
  }

  await mkdir(targetDir, { recursive: true });

  const source = join(templatesRoot(), template.id);
  await cp(source, targetDir, { recursive: true });

  try {
    await execFileAsync('git', ['init'], { cwd: targetDir });
  } catch {
    console.warn('git init başarısız oldu, scaffold dosyaları yine de oluşturuldu (git yüklü değil mi?).');
  }
}
