# Template 5 — Treasury Multisig + Timelock (KozaTreasury)

> **Durum: ✅ CANLI (Fuji) · v0.5.0**
>
> Zaman-kilitli (timelock) hazine. OZ `TimelockController` ince wrapper'ı —
> DAO/topluluk fonlarını rol-bazlı + gecikmeli yürütmeyle korur.

## Canlı Deployment

| Bileşen | Zincir | Adres |
|---------|--------|-------|
| KozaTreasury | Fuji C-Chain (43113) | [`0x6864879522D70Fb8e1583Cc8Fd4baB0e9605A955`](https://testnet.snowtrace.io/address/0x6864879522D70Fb8e1583Cc8Fd4baB0e9605A955) (verified) |

Canlı kanıt: `schedule` tx
[`0x4cf4410c…`](https://testnet.snowtrace.io/tx/0x4cf4410cc57040e44862ef0f45f3dd5a5e02db8eb8add648d4b0e236f1d07dca)
→ `getMinDelay = 172800` (48h), operation `getOperationState = 1 (Waiting)` —
öneri zincirde kabul edildi, gecikme sayıyor.

## Timelock neden?

Hazine fonlarını/kritik admin işlemlerini **gecikmeyle** yürütmek, kötü
niyetli veya yanlış bir öneriye **tepki penceresi** açar: öneri schedule
edilir, `minDelay` boyunca herkes görür, gerekirse `cancel` edilir. Tek bir
imza/cüzdanın anında fonları boşaltmasını engeller.

**"Multisig" katmanı:** bir **Safe (Gnosis)** multisig'i `proposers`/`executors`
olarak atanır. Öneri Safe'te çoklu imzayla onaylanır → timelock gecikmesi dolar
→ execute. Böylece *hem* çoklu imza *hem* zaman kilidi korur.

## Mimari

`KozaTreasury`, audited OZ `TimelockController`'ı doğrudan miras alır; custom
logic eklemez (minimum custom layer).

```solidity
contract KozaTreasury is TimelockController {
    constructor(uint256 minDelay, address[] proposers, address[] executors, address admin)
        TimelockController(minDelay, proposers, executors, admin) {}
}
```

## Roller

| Rol | Yetki |
|-----|-------|
| `PROPOSER_ROLE` | `schedule` / `scheduleBatch` (öneri oluştur) |
| `EXECUTOR_ROLE` | `execute` / `executeBatch` (gecikme sonrası yürüt) — `address(0)` → herkese açık |
| `CANCELLER_ROLE` | `cancel` (bekleyen öneriyi iptal) — proposer'lara otomatik verilir |
| `DEFAULT_ADMIN_ROLE` | Rol yönetimi — `address(0)` (self-administered) önerilir |

## Kullanım

### 1. Deploy (Fuji)

```bash
forge script script/deploy/DeployTreasury.s.sol:DeployTreasury \
  --rpc-url fuji --broadcast --private-key $PRIVATE_KEY
```

Env (opsiyonel): `TREASURY_MIN_DELAY` (default 48h), `TREASURY_PROPOSER`,
`TREASURY_EXECUTOR`, `TREASURY_ADMIN`.

### 2. Fonla

Native: timelock adresine doğrudan gönder (`receive()` payable). Korunan
kontratlar: `owner`/admin'lerini timelock'a devret.

### 3. Öneri oluştur (proposer)

```bash
# Örn. recipient'a 1 AVAX gönderme önerisi (data boş = native transfer)
cast send <ADDR> "schedule(address,uint256,bytes,bytes32,bytes32,uint256)" \
  <recipient> 1000000000000000000 0x \
  0x0000000000000000000000000000000000000000000000000000000000000000 \
  <salt> 172800 \
  --rpc-url fuji --private-key $PROPOSER_KEY
```

### 4. Durumu izle

```bash
ID=$(cast call <ADDR> "hashOperation(address,uint256,bytes,bytes32,bytes32)(bytes32)" \
  <recipient> 1000000000000000000 0x 0x00...00 <salt> --rpc-url fuji)
cast call <ADDR> "getOperationState(bytes32)(uint8)" $ID --rpc-url fuji  # 1=Waiting 2=Ready 3=Done
```

### 5. Yürüt (executor, gecikme sonrası)

```bash
cast send <ADDR> "execute(address,uint256,bytes,bytes32,bytes32)" \
  <recipient> 1000000000000000000 0x 0x00...00 <salt> \
  --rpc-url fuji --private-key $EXECUTOR_KEY
```

### 6. İptal (canceller, gecikme içinde)

```bash
cast send <ADDR> "cancel(bytes32)" $ID --rpc-url fuji --private-key $CANCELLER_KEY
```

## Güvenlik Kararları

- **Minimum custom logic:** audited `TimelockController`; wrapper yalnız
  constructor forward. Saldırı yüzeyi minimal.
- **minDelay anlamlı olmalı:** kritik hazine için 48h+. Çok düşük delay
  timelock'un güvenlik değerini düşürür (tepki penceresi daralır).
- **proposers/executors = Safe multisig:** EOA mainnet'te tek nokta risktir.
- **admin = `address(0)` (self-administered):** roller yalnız timelock'un kendi
  gecikmeli önerisiyle değişir — en güvenli. Deployer verilirse kurulum sonrası
  `renounceRole(DEFAULT_ADMIN_ROLE, deployer)`.
- **`updateDelay` yalnız timelock'un kendisi:** delay değişikliği de gecikmeye tabidir.

## Ortak Hatalar

### `TimelockInsufficientDelay`
`schedule` delay'i `minDelay`'den küçük. En az `getMinDelay()` ver.

### `TimelockUnexpectedOperationState`
`execute` gecikme dolmadan veya `cancel` edilmiş/bilinmeyen öneriye çağrıldı.
`getOperationState` ile Ready (2) olduğunu doğrula.

### `AccessControlUnauthorizedAccount`
`schedule`/`execute`/`cancel` çağıranın ilgili rolü yok. Roller deploy'da set edilir.

### Execute fonu olmadan
`execute` value gönderiyorsa timelock'un o kadar native/ERC20 fonu olmalı.

## Test & Komutlar

```bash
forge test --match-path "test/templates/Treasury.t.sol" -vv          # schedule/execute/cancel/roller
forge test --match-path "test/templates/DeployTreasury.t.sol"        # deploy smoke
```

Wrapper olduğu için `TimelockController`'ın iç mantığı yeniden test edilmez;
constructor forwarding + uçtan uca schedule→bekle→execute akışı doğrulanır.
