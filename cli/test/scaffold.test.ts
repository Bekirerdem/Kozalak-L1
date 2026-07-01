import { describe, it, expect, afterEach } from 'vitest';
import { scaffold, templatesRoot } from '../src/scaffold.js';
import { getTemplate } from '../src/templates.js';
import { mkdtempSync, existsSync, rmSync, mkdirSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

let dir: string;
afterEach(() => { if (dir) rmSync(dir, { recursive: true, force: true }); });

describe('scaffold', () => {
  it('erc20-gas scaffold dosyaları üretir', async () => {
    const base = mkdtempSync(join(tmpdir(), 'koza-'));
    dir = join(base, 'benim-token');
    await scaffold({ template: getTemplate('erc20-gas')!, targetDir: dir, projectName: 'benim-token' });
    expect(existsSync(join(dir, 'foundry.toml'))).toBe(true);
    expect(existsSync(join(dir, 'src', 'KozaGasToken.sol'))).toBe(true);
    expect(existsSync(join(dir, 'README.md'))).toBe(true);
    expect(existsSync(join(dir, '.env.example'))).toBe(true);
    // npm `.gitignore` dosyalarını pakete koymadığı için template'lerde
    // noktasız "gitignore" taşınır; scaffold sonrası `.gitignore`'a rename
    // edilmiş olmalı (aksi halde kullanıcı .env'i yanlışlıkla commit edebilir).
    expect(existsSync(join(dir, '.gitignore'))).toBe(true);
    expect(existsSync(join(dir, 'gitignore'))).toBe(false);
  });

  it('dolu hedef dizinde hata fırlatır', async () => {
    const base = mkdtempSync(join(tmpdir(), 'koza-'));
    dir = join(base, 'dolu-dizin');
    mkdirSync(dir, { recursive: true });
    writeFileSync(join(dir, 'mevcut-dosya.txt'), 'merhaba');
    await expect(
      scaffold({ template: getTemplate('erc20-gas')!, targetDir: dir, projectName: 'dolu-dizin' })
    ).rejects.toThrow();
  });

  it('templatesRoot paket-relative templates/ dizinini döner', () => {
    expect(existsSync(templatesRoot())).toBe(true);
    expect(existsSync(join(templatesRoot(), 'erc20-gas', 'foundry.toml'))).toBe(true);
  });
});
