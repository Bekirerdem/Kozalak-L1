import { describe, it, expect } from 'vitest';
import { parseDeployedAddress } from '../src/forge.js';

describe('parseDeployedAddress', () => {
  it('broadcast json adres çıkarır', () => {
    const json = JSON.stringify({
      transactions: [{ contractAddress: '0xAbc0000000000000000000000000000000000001', contractName: 'KozaGasToken' }],
    });
    expect(parseDeployedAddress(json)).toBe('0xAbc0000000000000000000000000000000000001');
  });

  it('adres yoksa null', () => {
    expect(parseDeployedAddress('{"transactions":[]}')).toBeNull();
  });

  it('birden fazla transaction varsa ilk dolu contractAddress\'i döner', () => {
    const json = JSON.stringify({
      transactions: [
        { contractAddress: null, contractName: 'SomeCall' },
        { contractAddress: '0xDef0000000000000000000000000000000000002', contractName: 'KozaCollection' },
      ],
    });
    expect(parseDeployedAddress(json)).toBe('0xDef0000000000000000000000000000000000002');
  });

  it('geçersiz json için null döner', () => {
    expect(parseDeployedAddress('not json')).toBeNull();
  });
});
