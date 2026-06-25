# Template 4 — Soulbound Credential (KozaCredential) · v0.4.0 Tasarım

## Bağlam

Kozalak-L1 Phase 1'in 4. template'i: transfer edilemez (soulbound) on-chain
sertifika NFT. Use-case: ARIA Hub gibi eğitim/topluluk platformlarının
mezunlarına/üyelerine verdiği, cüzdana kilitli, doğrulanabilir kanıt. Template
2 (KozaCollection, ERC-721) ile aynı audit-grade stil; OZ v5.3+ inherit,
Solidity 0.8.34, Foundry.

PHASE-1-PLAN "ERC-5114" diyordu; ancak ERC-5114 rozeti bir **NFT'ye** kalıcı
bağlar (cüzdana değil) ve revoke/transfer/burn'e izin vermez — eğitim
sertifikası use-case'ine ve istenen "revoke" davranışına oturmaz. Bu yüzden
**account-bound ERC-721 + revoke** modeli seçildi (brainstorming, 2026-06-25).

## Kararlar (onaylı)

1. **Model:** Account-bound ERC-721 (soulbound) — cüzdana mint, transfer disable.
2. **Metadata:** On-chain (struct + base64 JSON tokenURI). IPFS-bağımsız kalıcı kanıt.
3. **Yetki:** AccessControl — `ISSUER_ROLE` (issue + revoke), `DEFAULT_ADMIN_ROLE` (rol yönetimi).
4. **Revoke:** Revoked-flag (token silinmez, `revoked=true`, denetlenebilir geçmiş).

## Kontrat — `src/templates/soulbound-credential/KozaCredential.sol`

**Inherit:** `ERC721`, `AccessControl`

**Storage**
```solidity
struct Credential { string course; address issuer; uint64 issuedAt; bool revoked; }
mapping(uint256 tokenId => Credential) public credentials;  // getter: getCredential
uint256 public totalIssued;                                  // id 1'den başlar
```

**Roller:** `ISSUER_ROLE = keccak256("ISSUER_ROLE")`. Constructor: `admin` + ilk `issuer`
(ikisi de parametre; production: admin = multisig).

**Fonksiyonlar**
- `issue(address to, string calldata course) external onlyRole(ISSUER_ROLE) returns (uint256 tokenId)`
  — CEI: state (totalIssued++, credentials[id] kaydı) → `_safeMint`. issuer=msg.sender, issuedAt=uint64(block.timestamp). `course` boşsa revert `EmptyCourse`.
- `revoke(uint256 tokenId) external onlyRole(ISSUER_ROLE)` — token yoksa revert; zaten revoked ise revert `AlreadyRevoked`; `revoked=true` + `CredentialRevoked` event.
- `isValid(uint256 tokenId) external view returns (bool)` — `_ownerOf(id) != 0 && !credentials[id].revoked`.
- `tokenURI(uint256 tokenId) public view override returns (string)` — token yoksa revert (`ERC721NonexistentToken`); on-chain base64 JSON: `{name, description, attributes:[Course, Issuer, Issued (date), Status: Valid|Revoked]}`.
- `getCredential(uint256 tokenId) external view returns (Credential)`.

**Soulbound mekanik**
```solidity
function _update(address to, uint256 tokenId, address auth) internal override returns (address) {
    address from = _ownerOf(tokenId);
    if (from != address(0) && to != address(0)) revert Soulbound();  // transfer yasak; mint izinli
    return super._update(to, tokenId, auth);
}
```
Burn yok (revoke flag kullanılıyor) → `to=0` senaryosu hiç tetiklenmez ama izinli bırakılır (parent semantiği bozulmaz).

**supportsInterface:** override(ERC721, AccessControl) → super.

**Errors/Events:** `error Soulbound(); error EmptyCourse(); error AlreadyRevoked(uint256 tokenId);`
`event CredentialIssued(uint256 indexed tokenId, address indexed to, address indexed issuer, string course);`
`event CredentialRevoked(uint256 indexed tokenId, address indexed issuer);`

**Güvenlik kararları (NatSpec, KozaCollection gibi en üstte):** soulbound kilidi
(transfer/approve fiilen etkisiz), revoke-flag denetlenebilirliği, issuer≠admin
ayrımı (multisig-ready), on-chain metadata kalıcılığı, CEI, custom errors,
audited OZ primitive üstüne ince katman.

## Deploy script — `script/deploy/DeployCredential.s.sol`

`lessons.md` pattern'i: `run()` (env-driven, production) + `deploy(name, symbol, admin, issuer)` (public, parametrik, test-friendly). Env: `CREDENTIAL_NAME`, `CREDENTIAL_SYMBOL`, `CREDENTIAL_ADMIN`, `CREDENTIAL_ISSUER` (vm.envOr defaults).

## Testler — `test/templates/`

- `Soulbound.t.sol` (unit + fuzz): issue sadece ISSUER_ROLE (negatif: AccessControlUnauthorizedAccount); transfer/safeTransferFrom revert `Soulbound`; revoke flag + isValid; tokenURI JSON içeriği (course/status); getCredential; empty course revert; double-revoke revert; id 1'den başlar; admin rol grant/revoke.
- `Soulbound.invariants.t.sol`: (1) revoked credential asla `isValid` dönmez; (2) hiçbir token transfer edilemez (bakiye sadece mint ile artar); (3) totalIssued monotonik artar.

## Docs — `docs/tr/03-templateler/soulbound-credential.md`

Türkçe audit-grade rehber: ne/neden soulbound, ERC-5114 yerine account-bound
gerekçesi, issue/revoke akışı, on-chain metadata, AccessControl rol kurulumu,
deploy adımları, ortak hatalar, ARIA Hub use-case.

## Doğrulama

- `forge build` + `forge fmt --check` + `forge test --fuzz-runs 10000` yeşil; coverage ≥ %95.
- Slither/Aderyn temiz (CI).
- Fuji deploy + Routescan verify → tag `v0.4.0` + GitHub release.
- Frontend `Sablonlar.astro` PLAN→CANLI: backend komple (Treasury dahil) bitince, en sonda.
