import { execSync, spawnSync } from 'node:child_process';

/** `forge --version` çalışıyor mu (Foundry kurulu mu) kontrol eder. */
export function forgeAvailable(): boolean {
  try {
    execSync('forge --version', { stdio: 'ignore' });
    return true;
  } catch {
    return false;
  }
}

/** `forge` komutunu verilen çalışma dizininde + ortam değişkenleriyle çalıştırır. */
export function runForge(
  args: string[],
  cwd: string,
  env: NodeJS.ProcessEnv,
): { code: number; stdout: string; stderr: string } {
  const result = spawnSync('forge', args, { cwd, env, encoding: 'utf8' });
  return { code: result.status ?? 1, stdout: result.stdout ?? '', stderr: result.stderr ?? '' };
}

/** Foundry `broadcast/.../run-latest.json` içeriğinden ilk dolu contractAddress'i çıkarır. */
export function parseDeployedAddress(broadcastJson: string): string | null {
  try {
    const parsed = JSON.parse(broadcastJson) as { transactions?: { contractAddress?: string | null }[] };
    const tx = parsed.transactions?.find((t) => t.contractAddress);
    return tx?.contractAddress ?? null;
  } catch {
    return null;
  }
}
