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
