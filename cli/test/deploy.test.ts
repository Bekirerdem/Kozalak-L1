import { describe, it, expect } from 'vitest';
import { buildDeployArgs } from '../src/deploy.js';
import { getTemplate } from '../src/templates.js';

const template = getTemplate('erc20-gas')!;

describe('buildDeployArgs', () => {
  it('--private-key flag\'ini forge args\'a ekler (forge PRIVATE_KEY env\'den otomatik imzalamaz)', () => {
    const args = buildDeployArgs({ template, privateKey: '0xabc123', snowtraceKey: undefined });
    const idx = args.indexOf('--private-key');
    expect(idx).toBeGreaterThan(-1);
    expect(args[idx + 1]).toBe('0xabc123');
  });

  it('snowtraceKey verildiyse --verify + routescan verifier-url + --etherscan-api-key ekler', () => {
    const args = buildDeployArgs({ template, privateKey: '0xabc123', snowtraceKey: 'rs_test_key' });
    expect(args).toContain('--verify');
    const urlIdx = args.indexOf('--verifier-url');
    expect(urlIdx).toBeGreaterThan(-1);
    expect(args[urlIdx + 1]).toBe('https://api.routescan.io/v2/network/testnet/evm/43113/etherscan');
    const keyIdx = args.indexOf('--etherscan-api-key');
    expect(keyIdx).toBeGreaterThan(-1);
    expect(args[keyIdx + 1]).toBe('rs_test_key');
  });

  it('snowtraceKey yoksa --verify eklemez', () => {
    const args = buildDeployArgs({ template, privateKey: '0xabc123' });
    expect(args).not.toContain('--verify');
  });
});
