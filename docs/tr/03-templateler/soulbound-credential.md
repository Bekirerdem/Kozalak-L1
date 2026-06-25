# Template 4 — Soulbound Credential (KozaCredential)

> **Durum: ✅ CANLI (Fuji) · v0.4.0**
>
> Transfer edilemez (account-bound) on-chain sertifika NFT. Issuer-only mint,
> on-chain metadata, revoke-flag. Use-case: eğitim/topluluk platformlarının
> (örn. ARIA Hub) mezun/üye sertifikası.

## Canlı Deployment

| Bileşen | Zincir | Adres |
|---------|--------|-------|
| KozaCredential | Fuji C-Chain (43113) | [`0xCFdE91F214ABDe2a2E65B6cd41A7C7E3244E1ec1`](https://testnet.snowtrace.io/address/0xCFdE91F214ABDe2a2E65B6cd41A7C7E3244E1ec1) (verified) |

İlk sertifika kanıtı: `issue` tx
[`0xd1de861db6c309080253d2536a1767c11ee81a3fb2ab87b4e83aa298c2bcbc8d`](https://testnet.snowtrace.io/tx/0xd1de861db6c309080253d2536a1767c11ee81a3fb2ab87b4e83aa298c2bcbc8d)
→ `isValid(1) = true`, `transferFrom` revert (soulbound), `tokenURI` on-chain base64 JSON.

## Soulbound nedir, neden?

Soulbound (account-bound) token, bir cüzdana **kilitli** kalır — transfer
edilemez. Sertifika/diploma/üyelik gibi "kişiye ait, devredilemez" kanıtlar için
uygundur: bir sertifikayı satıp başkasına geçirmek anlamsızdır.

**Neden ERC-5114 değil?** ERC-5114 (Soulbound Badge) rozeti bir **NFT'ye** kalıcı
bağlar (cüzdana değil) ve `revoke`/`transfer`/`burn`'e izin vermez. Eğitim
sertifikası "kişiye verilir + issuer hatalı/sahte sertifikayı geri alabilmeli"
gereksinimine **account-bound ERC-721 + revoke-flag** modeli oturur. Bu template
audited OZ `ERC721` + `AccessControl` üstüne ince bir katman ekler.

## Mimari

```
ERC721 (OZ) ── transfer kilidi (_update override) ─┐
AccessControl (OZ) ── ISSUER_ROLE / ADMIN_ROLE     ├─► KozaCredential
on-chain Credential struct ── tokenURI base64 JSON ─┘
```

- **Soulbound:** `_update` override; transfer (`from≠0 && to≠0`) → `revert Soulbound()`. Sadece mint izinli. `approve` çağrılabilir ama transfer yine bloklu (fiilen etkisiz).
- **Revoke-flag:** iptal token'ı silmez; `revoked=true` işaretler. `ownerOf` çözülmeye devam eder → "sertifika vardı, iptal edildi" denetlenebilir. `isValid` ve metadata `Status` yansıtır.
- **On-chain metadata:** kurs/issuer/tarih/durum zincirde; `tokenURI` base64 JSON üretir. IPFS/sunucu ölse bile kanıt kaybolmaz.

## Roller

| Rol | Yetki | Production |
|-----|-------|-----------|
| `DEFAULT_ADMIN_ROLE` | Rol verme/alma (`grantRole`/`revokeRole`) | Safe (Gnosis) multisig |
| `ISSUER_ROLE` | `issue` + `revoke` | Kurum/eğitmen cüzdanı (çoklu olabilir) |

Constructor admin ve ilk issuer'ı alır. Çoklu eğitmen: admin `grantRole(ISSUER_ROLE, ...)` ile ekler.

## Kullanım

### 1. Deploy (Fuji)

```bash
forge script script/deploy/DeployCredential.s.sol:DeployCredential \
  --rpc-url fuji --broadcast --private-key $PRIVATE_KEY
```

Env (opsiyonel): `CREDENTIAL_NAME`, `CREDENTIAL_SYMBOL`, `CREDENTIAL_ADMIN`,
`CREDENTIAL_ISSUER` (admin/issuer set'li değilse broadcaster).

### 2. Sertifika ver

```bash
cast send <ADDR> "issue(address,string)" <recipient> "Avalanche L1 Workshop" \
  --rpc-url fuji --private-key $ISSUER_KEY
# → tokenId (1'den başlar), CredentialIssued event
```

### 3. Doğrula

```bash
cast call <ADDR> "isValid(uint256)(bool)" 1 --rpc-url fuji          # true
cast call <ADDR> "getCredential(uint256)" 1 --rpc-url fuji          # course/issuer/issuedAt/revoked
cast call <ADDR> "tokenURI(uint256)(string)" 1 --rpc-url fuji       # data:application/json;base64,...
```

### 4. İptal (revoke)

```bash
cast send <ADDR> "revoke(uint256)" 1 --rpc-url fuji --private-key $ISSUER_KEY
# → revoked=true, isValid(1)=false, CredentialRevoked event
```

### 5. Çoklu issuer ekle (admin)

```bash
ISSUER_ROLE=$(cast call <ADDR> "ISSUER_ROLE()(bytes32)" --rpc-url fuji)
cast send <ADDR> "grantRole(bytes32,address)" $ISSUER_ROLE <newIssuer> \
  --rpc-url fuji --private-key $ADMIN_KEY
```

## On-chain Metadata

`tokenURI` zincirde JSON üretir, base64'le encode eder:

```json
{
  "name": "ARIA Hub Credential #1",
  "description": "Soulbound, transfer edilemez on-chain sertifika (Kozalak-L1 Template 4).",
  "attributes": [
    {"trait_type": "Course",  "value": "Avalanche L1 Workshop"},
    {"trait_type": "Issuer",  "value": "0x39ae..."},
    {"trait_type": "Issued",  "display_type": "date", "value": 1750000000},
    {"trait_type": "Status",  "value": "Valid"}
  ]
}
```

`revoke` sonrası `Status` → `Revoked`. IPFS bağımlılığı yoktur.

## Güvenlik Kararları

- **Soulbound kilidi `_update`'te:** tüm transfer yolları (transferFrom,
  safeTransferFrom) tek noktadan bloklanır — `approve` etkisizdir.
- **Revoke-flag, burn değil:** denetlenebilir geçmiş; token silinmediği için
  `ownerOf`/explorer kaydı korunur.
- **issuer ≠ admin:** rol yönetimi (admin) ile sertifika operasyonu (issuer)
  ayrı; admin multisig olmalı.
- **Minimum custom logic:** audited OZ primitive'leri; custom katman ince.
- **CEI:** `issue` state'i `_safeMint` (external call) öncesi yazar.
- **`course` JSON'a düz gömülür:** issuer **güvenilir** aktördür (rol-korumalı).
  Untrusted girdi senaryosunda `"` escape'i eklenmeli — bu template issuer-trusted varsayar.

## Ortak Hatalar

### `AccessControlUnauthorizedAccount`
`issue`/`revoke` çağıranın `ISSUER_ROLE`'u yok. Admin `grantRole(ISSUER_ROLE, ...)` ile ekler.

### `Soulbound()` revert
Transfer denendi — beklenen davranış. Sertifika cüzdana kilitli; devredilemez.

### `AlreadyRevoked(tokenId)`
Aynı sertifika ikinci kez `revoke` edildi. `isValid` ile önce kontrol et.

### `ERC721NonexistentToken`
`revoke`/`tokenURI` var olmayan id'ye çağrıldı. `totalIssued` aralığını doğrula (id'ler 1..totalIssued).

## ARIA Hub Use-Case

Avalanche eğitim platformu (ARIA Hub) workshop mezunlarına bu template ile
on-chain, devredilemez sertifika verebilir: admin = topluluk multisig'i,
eğitmenler ISSUER_ROLE ile mezunlara `issue` eder. Sertifika cüzdanda kalır,
işverene/DAO'ya `isValid` ile kanıtlanır; hata/sahtekarlıkta `revoke` edilir.

## Test & Komutlar

```bash
forge test --match-path "test/templates/Soulbound*.t.sol" -vv   # unit + invariant
forge test --match-path "test/templates/DeployCredential.t.sol" # deploy smoke
```

Kapsam: issue/revoke/isValid/tokenURI/soulbound-transfer/AccessControl +
invariant (revoked asla valid değil, transfer imkansız, totalIssued kayıpsız).
