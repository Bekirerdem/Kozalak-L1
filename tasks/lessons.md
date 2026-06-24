# Lessons Learned — kozalak-L1

Sprint sırasında karşılaşılan ve gelecekte tekrar etmemek istediğimiz pattern'ler ve düzeltmeler.

## 2026-04-29

### Foundry `vm.setEnv` test'ler arasında ortak state oluşturuyor

**Problem:** Deploy script env-driven yazıldığında, `forge test` çalıştırırken her test kendi `vm.setEnv` çağrılarıyla env değiştiriyor; ama bu değişiklikler **sonraki test'lere taşıyor**. `setUp()` her test öncesi çalışsa da `vm.setEnv` davranışı deterministic değil — Foundry test execution order garanti vermiyor (alfabetik mı, paralel mi belli değil).

**Belirti:**
```
[FAIL: assertion failed: Custom Token != Koza Gas Token]
test_DefaultDeploy_ProducesValidToken
```
Beklenen `"Koza Gas Token"` ama önceki test'in `vm.setEnv("ERC20_NAME", "Custom Token")` çağrısı hâlâ aktif.

**Çözüm:** Script'lere **iki ayrı entry point** ekle:
- `run()` → env'den oku (production: `forge script ... --broadcast`)
- `deploy(...explicit params...)` → public, parametrik (test-friendly)

Test'ler `deploy(...)` direkt çağırır, env'e dokunmaz. Env-driven `run()` integration test ile (gerçek `forge script`) doğrulanır.

**Pattern:**
```solidity
function run() external returns (Token, address) {
    string memory name = vm.envOr("TOKEN_NAME", DEFAULT_NAME);
    // ...
    return deploy(name, ...);
}

function deploy(string memory name, ...) public returns (Token, address) {
    // shared logic
}
```

**Genel kural:** Deploy script'lerini ENV'den izole et. Test edilebilirlik için **parametre alan public fn** her zaman olsun.

### Solidity sürüm pin uyumsuzluğu (foundry.toml ↔ pragma)

**Problem:** `foundry.toml`'da `solc = "0.8.34"` ama dosyalarda `pragma solidity 0.8.35` (linter veya editor auto-fix değiştirmiş olabilir). `forge build` "No solc version exists" hatası verir.

**Çözüm:** İkisini de tutarlı tut. Memory'de Solidity sürüm referansları (memory bank) tek doğruluk noktası.

### CI: Slither ve Aderyn boş `src/` ile çalışmaz

**Problem:** İlk push'ta `src/` boştu. Slither `out/build-info` directory bulamadı, Aderyn `cargo install` upstream `svm-rs-builds` bug'ı yedi.

**Çözüm:**
- Slither/Aderyn job'larına `has_contracts` guard ekle (boş src'de skip)
- Aderyn için `cargo install` yerine **resmi pre-built binary installer** kullan (`Cyfrin/aderyn` releases)

### `bracket_spacing = true` Solidity ekosistem default'una aykırı

**Problem:** `import { ERC20 } from "..."` (boşluklu) Foundry fmt default ama OpenZeppelin/ava-labs ekosistemi boşluksuz yazar (`import {ERC20}`).

**Çözüm:** `foundry.toml` → `[fmt] bracket_spacing = false`

### Constructor'da redundant zero-checks gas waste + audit-grade kalitesini düşürür

**Problem:** Custom `ZeroAddress` ve `ZeroAmount` revert'leri `Ownable(0)` ve `ERC20Capped(0)` parent kontratlarının kendi error'larını fırlatmasından **sonra** çalışmaya çalışıyor → asla ulaşılmıyor.

**Çözüm:** Constructor body'de redundant check yapma. Parent error'larına güven (`OwnableInvalidOwner`, `ERC20InvalidCap`). Custom logic gerektiren check'leri (örn. `initialMint > cap`) bırak.

**Audit-grade prensibi:** "Minimum custom logic" — OZ/ava-labs'in audited primitive'lerine güven, kendi katmanını ince tut.

## 2026-04-30

### `foundry.toml` `[etherscan]` interpolation Routescan ile flaky

**Problem:** `forge script ... --verify` ve `forge verify-contract <addr> ... --chain fuji` çağrılarında `[etherscan]` bölümünden gelen `${SNOWTRACE_API_KEY}` interpolation'ı zaman zaman `Invalid API Key` hatası veriyor — özellikle deploy hemen sonrası verify'da. Aynı API key process env'de doğru, doğru `rs_` prefix'li ve doğru endpoint'e set edilmiş olsa bile.

**Belirti:**
```
Error: Failed to obtain contract ABI for 0x...
Context:
- Invalid API Key
```

**Hipotez:** Forge'un internal Etherscan handler'ı toml'dan okurken bazen `key` field'ını tam olarak resolve etmeden kullanıyor (özellikle Routescan endpoint'inde "verify-then-fetch" iki adımlı flow varken).

**Çözüm:** Verify çağrılarında **explicit flag'leri kullan**, toml interpolation'ına güvenme:

```bash
forge verify-contract <ADDR> <PATH>:<NAME> \
  --verifier-url "https://api.routescan.io/v2/network/testnet/evm/43113/etherscan" \
  --etherscan-api-key "$SNOWTRACE_API_KEY" \
  --chain 43113 \
  --watch \
  --retries 4 --delay 30 \
  --constructor-args $(cast abi-encode "<sig>" <args...>)
```

`forge script ... --verify` flow'unda da aynı flag'leri pass etmek gerekirse, deploy'u `--broadcast` ile yapıp verify'ı **ayrı `forge verify-contract`** çağrısıyla yürütmek en güvenli yol.

**Genel kural:** CI/CD ve manuel deploy script'lerinde Etherscan-uyumlu verify çağrılarını **explicit `--verifier-url` + `--etherscan-api-key`** ile yaz. `foundry.toml` interpolation'ı dokümante edilmiş ama production-ready değil — özellikle Routescan gibi 3rd party Etherscan klonlarında.

### `foundry.toml` `solc = "X"` global pin multi-version compile'i bloklar

**Problem:** Sprint 3'te `ava-labs/icm-contracts` library'si `pragma solidity 0.8.25` (caret yok, sıkı pin) kullanıyor. Bizim Sprint 1+2 template'leri ise `pragma 0.8.34` ile yazılmış. Foundry global ayarı `solc = "0.8.34"` ise ICTT contract'larını derlemek imkansız (`No solc version exists` veya `pragma mismatch`).

**Çözüm:** `foundry.toml`'dan `solc = "X"` satırını **kaldır**, `auto_detect_solc = true` ekle. Foundry her dosyanın pragma'sına göre solc seçer; multi-version derleme aktif olur. KozaGasToken (0.8.34), KozaCollection (0.8.34) ve KozaTokenHome/Remote (0.8.25) yan yana derlenir.

**Genel kural:** Tek bir Solidity sürümüyle deterministic build hedefi olan projelerde global `solc` pin mantıklı; ama denetlenmiş 3rd-party kütüphaneler (icm-contracts gibi) sıkı pin yaparsa multi-version compile zorunluluğu doğar. `auto_detect_solc` çözüm — sadece test'leri tekrar koş ve gas/bytecode farkı olmadığını doğrula.

### Avalanche Warp Messenger precompile'ı Foundry test'lerinde mock'lanmalı

**Problem:** ICTT contract'larını test etmek isteyince `__init` fonksiyonu Warp Messenger precompile'ını (`0x0200000000000000000000000000000000000005`) çağırıyor. Foundry test EVM'inde precompile yok → `call to non-contract address` hatası.

**Çözüm:** `vm.etch` + `vm.mockCall` ikilisi:

```solidity
address constant WARP = 0x0200000000000000000000000000000000000005;

function setUp() public {
    // Step 1: precompile address'ine sahte bytecode koy (yoksa mockCall override
    // çalışmaz — EVM önce contract var mı diye bakar).
    vm.etch(WARP, hex"01");

    // Step 2: getBlockchainID() çağrısını yakala, sahte değer döndür.
    vm.mockCall(
        WARP,
        abi.encodeWithSignature("getBlockchainID()"),
        abi.encode(bytes32(uint256(43113)))
    );
}
```

**Genel kural:** Avalanche L1 precompile'larını (Warp, ContractNativeMinter, AllowList, vs.) Foundry test'lerinde **etch + mockCall** ile mock'lamak reusable bir pattern. Sadece `vm.mockCall` yetmez — `vm.etch` ile non-zero bytecode set etmek zorunlu, aksi halde EVM call'u yapmadan boş döner.

### TeleporterRegistry init'i için minimal mock yeter

**Problem:** ICTT smoke test'lerinde gerçek `TeleporterRegistry` deploy etmek gereksiz overhead — `_addProtocolVersion` ve `WARP` precompile setup'ı zinciri uzatıyor.

**Çözüm:** Minimal `MockTeleporterRegistry` kontratı yazıldı (3 fonksiyon: `latestVersion`, `getAddressFromVersion`, `getLatestTeleporter`, `getVersionFromAddress`). `__TeleporterRegistryApp_init`'in zero-check + version-compare adımlarını geçmek için yeterli yüzey.

**Genel kural:** Wrapper kontratlar için **library logic'ini test etme**. Sadece kendi katmanını (constructor forwarding, access control eklemeleri) test et. Library zaten denetlenmiş.

## 2026-06-24 (ICTT round-trip / geri dönüş)

### Yerel L1'i yeniden ayağa kaldırmak: `node local start`, `blockchain deploy` DEĞİL

**Problem:** Makine/WSL kapanınca yerel L1 validator düşer (RPC reddedilir). Yeniden başlatmak için refleksif olarak `avalanche blockchain deploy kozaTestL1 --fuji ...` çağrıldı; komut **"A local machine L1 deploy already exists … overwrite?"** interaktif ok-menüsü sordu, non-interactive WSL'de stdin EOF (`^D`) ile patladı. Bypass eden bir flag de yok (`--overwrite`/`--force` mevcut değil).

**Çözüm:** Subnet + blockchain Fuji P-Chain'de **kalıcı** kayıtlı; yalnızca local node process'i ölmüş. Doğru komut: `avalanche node local status` (cluster `Stopped` mı gör) → `avalanche node local start <clusterName>`. Bu, node'u disk state'iyle yeniden açar — blockchain'i yeniden *create* etmeye gerek yok ve **EVM disk state korunur**: eski Remote contract + mint'ler geri gelir (redeploy/yeniden transfer gereksiz).

**Genel kural:** "L1 düştü" ≠ "blockchain gitti". Önce `node local status`; restart için `node local start`. `blockchain deploy` yalnızca ilk kurulum/gerçekten yeniden oluşturma içindir.

### Geri dönüş (Remote→Home) burn'de wKGAS **self-approve** şart

**Problem:** İleri yönde KGAS'ı **Home'a** approve ediyorduk; geri dönüşte aynı refleksle gidilirse `Remote.send` burn `ERC20InsufficientAllowance` verir. `ERC20TokenRemote._burn`, `_spendAllowance(sender, address(this), amount)` çağırır.

**Çözüm:** Burn'den önce wKGAS'ı **Remote kontratının kendisine** approve et: `cast send $REMOTE "approve(address,uint256)" $REMOTE <amount>`. `send` input'unda `destinationBlockchainID == tokenHomeBlockchainID` ise single-hop Home'a gider (unlock).

### Relayer: çift-yön config + `process-missed-blocks:false` + quorum gecikmesi

**Problem:** Round-trip mesajı L1'den (source) çıkar; relayer L1 validator'ına peer bağlanıp Warp quorum (67/100) sağlamadan ve `Listener initialized` demeden burn atılırsa, `process-missed-blocks:false` olduğu için mesaj **kaçar** (relayer geçmiş blokları taramaz).

**Çözüm:** Avalanche CLI relayer config'i zaten çift yön (C-Chain ↔ L1 ikisi de source+destination) kurar. Relayer'ı `nohup` ile başlat, log'da L1 subnet için `connectedWeight=100` + `Initialization complete` görene kadar bekle, **sonra** burn at. Yeni başlayan relayer'da L1 peer handshake'i ~10-30s sürebilir.

### `pgrep -f "<pattern>"` kendi komut satırını yakalar (false positive)

**Problem:** `pgrep -f "icm-relayer --config-file"` ile relayer canlılığı kontrolü, pattern string'i çağıran shell'in komut satırında **birebir geçtiği** için kendini match etti; "zaten çalışıyor" yanlış pozitifi başlatmayı atlattı.

**Çözüm:** Bracket trick — `pgrep -af "[i]cm-relayer"`. Regex `[i]cm` gerçek process'teki `icm`'i bulur ama kendi komut satırındaki `[i]cm`'i bulmaz. Binary path ile (`icm-relayer-v1.7.4/icm-relayer`) eşleştirmek de ayırt edicidir.
