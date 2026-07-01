import { readFileSync, existsSync } from 'node:fs';
import { basename, join } from 'node:path';
import type { TemplateDef } from './templates.js';
import { runForge, parseDeployedAddress } from './forge.js';

const TELEPORTER_MESSENGER_ADDRESS = '0x253b2784c75e510dD0fF1da844684a1aC0aa5fcf';
const ROUTESCAN_TESTNET_VERIFIER = 'https://api.routescan.io/v2/network/testnet/evm/43113/etherscan';
const FUJI_CHAIN_ID = '43113';

export interface DeployInput {
  template: TemplateDef;
  cwd: string;
  privateKey: string;
  snowtraceKey?: string;
  envParams: Record<string, string>;
}

/**
 * Scaffold edilmiş bir projeyi Fuji testnet'e deploy eder.
 *
 * Sadece `template.deployable === true` olan şablonlar için çalışır (ICTT gibi
 * çok-adımlı şablonlar scaffold-only'dir, burada deploy edilmez).
 *
 * `privateKey` disk'e yazılmaz; yalnızca forge alt-süreci için `process.env`
 * üzerinden geçirilir.
 */
export async function deploy(input: DeployInput): Promise<{ address: string | null; explorerUrl: string | null }> {
  const { template, cwd, privateKey, snowtraceKey, envParams } = input;

  if (!template.deployable) {
    throw new Error(`Şablon "${template.id}" deploy edilemez (deployable: false). Rehber: ${template.guideDoc}`);
  }

  // Registry'deki deployScript repo-relative bir yol (script/deploy/X.s.sol).
  // Scaffold edilmiş projede yapı flatten edilmiştir (build-templates.ts): script/X.s.sol.
  const scriptFile = basename(template.deployScript);
  const scriptRelPath = join('script', scriptFile);

  const env: NodeJS.ProcessEnv = {
    ...process.env,
    PRIVATE_KEY: privateKey,
    TELEPORTER_MESSENGER_ADDRESS,
    ...envParams,
  };
  if (snowtraceKey) env.SNOWTRACE_API_KEY = snowtraceKey;

  const args = ['script', scriptRelPath, '--rpc-url', 'fuji', '--broadcast'];
  if (snowtraceKey) {
    args.push('--verify', '--verifier-url', ROUTESCAN_TESTNET_VERIFIER, '--etherscan-api-key', snowtraceKey);
  }

  const result = runForge(args, cwd, env);
  if (result.code !== 0) {
    // forge compile hatası / revert reason genelde stderr'e yazılır; ikisini de göster.
    const detail = [result.stdout, result.stderr].filter((s) => s.trim()).join('\n');
    throw new Error(`forge script başarısız oldu (exit ${result.code}):\n${detail}`);
  }

  const broadcastPath = join(cwd, 'broadcast', scriptFile, FUJI_CHAIN_ID, 'run-latest.json');
  if (!existsSync(broadcastPath)) {
    return { address: null, explorerUrl: null };
  }

  const address = parseDeployedAddress(readFileSync(broadcastPath, 'utf8'));
  const explorerUrl = address ? `https://testnet.snowtrace.io/address/${address}` : null;
  return { address, explorerUrl };
}
