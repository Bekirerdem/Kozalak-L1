export interface TemplateDef {
  id: 'erc20-gas' | 'erc721-collection' | 'soulbound-credential' | 'treasury-multisig' | 'ictt-bridge';
  label: string; // prompt'ta görünen ad
  description: string; // tek satır
  srcFiles: string[]; // repo-relative: 'src/templates/erc20-gas/KozaGasToken.sol'
  testFiles: string[]; // 'test/templates/ERC20Gas.t.sol', ...
  deployScript: string; // 'script/deploy/DeployERC20Gas.s.sol'
  guideDoc: string; // 'docs/tr/03-templateler/erc20-gas.md'
  remappings: string[]; // foundry.toml remappings'ten gereken alt küme
  submodules: ('forge-std' | 'openzeppelin-contracts' | 'icm-contracts')[];
  solc: string; // '0.8.34' | '0.8.25'
  envParams: { key: string; prompt: string; secret?: boolean; optional?: boolean }[];
  deployable: boolean; // ICTT: false
}

const OZ_REMAPPINGS = ['@openzeppelin/contracts/=lib/openzeppelin-contracts/contracts/', 'forge-std/=lib/forge-std/src/'];
const OZ_SUBMODULES: TemplateDef['submodules'] = ['forge-std', 'openzeppelin-contracts'];

const ICTT_REMAPPINGS = [
  ...OZ_REMAPPINGS,
  'icm-contracts/=lib/icm-contracts/',
  '@subnet-evm/=lib/icm-contracts/contracts/subnet-evm/',
  '@teleporter/=lib/icm-contracts/contracts/teleporter/',
  '@utilities/=lib/icm-contracts/contracts/utilities/',
  '@mocks/=lib/icm-contracts/contracts/mocks/',
  '@ictt/=lib/icm-contracts/contracts/ictt/',
];
const ICTT_SUBMODULES: TemplateDef['submodules'] = ['forge-std', 'openzeppelin-contracts', 'icm-contracts'];

export const TEMPLATES: TemplateDef[] = [
  {
    id: 'erc20-gas',
    label: 'ERC-20 Gas Token',
    description: 'Mintable, capped arz, sahip-kontrollü ERC-20 (KozaGasToken).',
    srcFiles: ['src/templates/erc20-gas/KozaGasToken.sol'],
    testFiles: [
      'test/templates/ERC20Gas.t.sol',
      'test/templates/ERC20Gas.invariants.t.sol',
      'test/templates/DeployERC20Gas.t.sol',
    ],
    deployScript: 'script/deploy/DeployERC20Gas.s.sol',
    guideDoc: 'docs/tr/03-templateler/erc20-gas.md',
    remappings: OZ_REMAPPINGS,
    submodules: OZ_SUBMODULES,
    solc: '0.8.34',
    envParams: [],
    deployable: true,
  },
  {
    id: 'erc721-collection',
    label: 'ERC-721 Collection',
    description: 'Merkle allowlist + faz bazlı mint, royalty destekli NFT koleksiyonu (KozaCollection).',
    srcFiles: ['src/templates/erc721-collection/KozaCollection.sol'],
    testFiles: [
      'test/templates/ERC721Collection.t.sol',
      'test/templates/ERC721Collection.invariants.t.sol',
      'test/templates/DeployERC721Collection.t.sol',
    ],
    deployScript: 'script/deploy/DeployERC721Collection.s.sol',
    guideDoc: 'docs/tr/03-templateler/erc721-collection.md',
    remappings: OZ_REMAPPINGS,
    submodules: OZ_SUBMODULES,
    solc: '0.8.34',
    envParams: [
      { key: 'NFT_NAME', prompt: 'Koleksiyon adı', optional: true },
      { key: 'NFT_SYMBOL', prompt: 'Koleksiyon sembolü', optional: true },
      { key: 'NFT_BASE_URI', prompt: 'Base URI (ipfs://.../ ile bitmeli)', optional: true },
      { key: 'NFT_MAX_SUPPLY', prompt: 'Maksimum arz', optional: true },
      { key: 'NFT_MINT_PRICE', prompt: 'Mint fiyatı (wei)', optional: true },
      { key: 'NFT_ROYALTY_BPS', prompt: 'Royalty (basis points, 500 = %5)', optional: true },
      { key: 'NFT_ROYALTY_RECEIVER', prompt: 'Royalty alıcı adresi', optional: true },
      { key: 'NFT_OWNER', prompt: 'Sahip adresi (boş → deployer)', optional: true },
    ],
    deployable: true,
  },
  {
    id: 'soulbound-credential',
    label: 'Soulbound Credential',
    description: 'Devredilemez (soulbound), role-bazlı sertifika NFT\'si (KozaCredential).',
    srcFiles: ['src/templates/soulbound-credential/KozaCredential.sol'],
    testFiles: [
      'test/templates/Soulbound.t.sol',
      'test/templates/Soulbound.invariants.t.sol',
      'test/templates/DeployCredential.t.sol',
    ],
    deployScript: 'script/deploy/DeployCredential.s.sol',
    guideDoc: 'docs/tr/03-templateler/soulbound-credential.md',
    remappings: OZ_REMAPPINGS,
    submodules: OZ_SUBMODULES,
    solc: '0.8.34',
    envParams: [],
    deployable: true,
  },
  {
    id: 'treasury-multisig',
    label: 'Treasury Multisig (Timelock)',
    description: 'OpenZeppelin TimelockController tabanlı, gecikmeli-yürütme hazine kontratı (KozaTreasury).',
    srcFiles: ['src/templates/treasury-multisig/KozaTreasury.sol'],
    testFiles: ['test/templates/Treasury.t.sol', 'test/templates/DeployTreasury.t.sol'],
    deployScript: 'script/deploy/DeployTreasury.s.sol',
    guideDoc: 'docs/tr/03-templateler/treasury-multisig.md',
    remappings: OZ_REMAPPINGS,
    submodules: OZ_SUBMODULES,
    solc: '0.8.34',
    envParams: [],
    deployable: true,
  },
  {
    id: 'ictt-bridge',
    label: 'ICTT Bridge (Home + Remote)',
    description: 'Avalanche Interchain Token Transfer ile C-Chain ↔ L1 token köprüsü (KozaTokenHome + KozaTokenRemote).',
    srcFiles: ['src/templates/ictt-bridge/KozaTokenHome.sol', 'src/templates/ictt-bridge/KozaTokenRemote.sol'],
    testFiles: ['test/templates/ICTTBridge.t.sol'],
    deployScript: 'script/deploy/DeployTokenHome.s.sol',
    guideDoc: 'docs/tr/03-templateler/ictt-bridge.md',
    remappings: ICTT_REMAPPINGS,
    submodules: ICTT_SUBMODULES,
    solc: '0.8.25',
    envParams: [],
    deployable: false,
  },
];

export function getTemplate(id: string): TemplateDef | undefined {
  return TEMPLATES.find((t) => t.id === id);
}
