# Audit Hazırlık Checklist — KOZALAK-L1

> **Amaç:** Sherlock / Cantina (veya benzeri Code4rena, CodeHawks) contest başvurusundan
> önce repo'nun "audit-ready" durumda olduğunu kanıtlamak. `docs/tr/04-guvenlik.md` genel
> bir pre-deploy güvenlik checklist'idir; bu doküman ondan farklı olarak **contest paketinin
> kendisini** hazırlamaya odaklanır — jürinin/denetçinin ilk 10 dakikada göreceği şeyler.
>
> ⚠️ **Bu doküman bir audit yerine geçmez.** Aşağıdaki maddelerin tamamı işaretlense bile
> profesyonel/topluluk denetimi olmadan mainnet deploy önerilmez (bkz. `SECURITY.md`).

İlgili proje verisi: Solidity `0.8.34` (ICTT Bridge şablonları `0.8.25` pin — bkz.
`foundry.toml` `auto_detect_solc`), OpenZeppelin Contracts `v5.3.0`, CI Slither + Aderyn
(`.github/workflows/ci.yml`), Foundry `v1.7.1`. Beş şablon: ERC-20 Gas Token, ERC-721
Collection, ICTT Bridge (Home + Remote), Soulbound Credential, Treasury Multisig.

---

## 1. NatSpec Coverage

- [ ] `KozaGasToken.sol` — `mint`, `burn` external fonksiyonları `@notice`/`@param` içeriyor.
      Neden: Sherlock/Cantina denetçileri kod okumadan önce NatSpec'i tarar; eksik NatSpec
      "kötü hazırlanmış kod tabanı" izlenimi verip triage süresini uzatır.
- [ ] `KozaCollection.sol` — `publicMint`, `allowlistMint`, `setMerkleRoot`, `setPhase`,
      `setBaseURI`, `setMintPrice`, `setDefaultRoyalty`, `withdraw` fonksiyonlarının hepsinde
      `@param`/`@return` tam.
      Neden: Faz akışı (Closed/Allowlist/Public) ve Merkle allowlist mantığı NatSpec
      olmadan dışarıdan okunaklı değil; denetçi yanlış varsayımla zaman kaybedebilir.
- [ ] `KozaCredential.sol` — `issue`, `revoke`, `isValid`, `getCredential`, `tokenURI`
      fonksiyonları ve `Credential` struct alanları belgeli.
      Neden: Soulbound + revoke-flag tasarımı standart ERC-721'den sapıyor; sapmanın
      NatSpec'te açık olması yanlış-pozitif "bug" raporlarını azaltır.
- [ ] `KozaTokenHome.sol` / `KozaTokenRemote.sol` — kendi constructor'ları belgeli; miras
      alınan `ERC20TokenHome`/`ERC20TokenRemote` fonksiyonları için "audited upstream,
      override yok" notu üst-seviye NatSpec'te mevcut.
      Neden: Custom kod yüzeyi küçük olsa da denetçinin "neyin bizim, neyin ava-labs'ın"
      olduğunu bir bakışta ayırması gerekir.
- [ ] `KozaTreasury.sol` — constructor parametreleri (`minDelay`, `proposers`, `executors`,
      `admin`) ve production varsayımları (`@dev` bloğundaki checklist) güncel.
      Neden: Treasury saf bir `TimelockController` wrapper'ı; tüm risk yüzeyi constructor
      parametrelerinin doğru kurulmasında — NatSpec bunu denetçiye baştan anlatmalı.
- [ ] Tüm public/external fonksiyonlarda en az `@notice` var; `forge doc` ile üretilen
      çıktıda boş bırakılmış (auto-generated placeholder) madde yok.
      Neden: `forge doc` denetçi ekiplerinin ilk taradığı araçlardan biri; boş NatSpec
      coverage sayısını otomatik düşürür.

## 2. Invariant Dokümantasyonu

Her şablon için korunması gereken invariant'lar, mevcut Foundry stateful fuzzing
(`test/templates/*.invariants.t.sol`) dosyalarına referansla:

- [ ] **ERC-20 Gas Token** — `test/templates/ERC20Gas.invariants.t.sol`:
      `invariant_TotalSupplyDoesNotExceedCap`, `invariant_SumOfBalancesEqualsTotalSupply`,
      `invariant_OwnerDoesNotChange`. Submission paketinde bu üçü "garanti edilen
      özellikler" olarak listelenir.
      Neden: Denetçi invariant'ları okumadan kontratın "ne bozulursa kritik sayılır"
      sınırını bilemez; net liste scope tartışmasını önler.
- [ ] **ERC-721 Collection** — `test/templates/ERC721Collection.invariants.t.sol`:
      `invariant_TotalMintedDoesNotExceedMaxSupply`,
      `invariant_SumOfBalancesEqualsTotalMinted`,
      `invariant_ContractBalanceMatchesPaidMinusWithdrawn`, `invariant_OwnerDoesNotChange`.
      Neden: `contract.balance == totalPaid - totalWithdrawn` invariant'ı fon kaybı/kilitlenme
      sınıfı bug'ları için doğrudan tripwire'dır — denetçiye önceliklendirme sinyali verir.
- [ ] **Soulbound Credential** — `test/templates/Soulbound.invariants.t.sol`:
      `invariant_SumOfBalancesEqualsTotalIssued`, `invariant_RevokedAreNeverValid`,
      `invariant_TotalIssuedMatchesSuccessfulIssues`.
      Neden: "Transfer asla başarılı olmaz" ve "revoke edilen asla valid dönmez" iddiaları
      ürünün temel güven varsayımı; invariant test bunu kanıtlanmış hale getirir.
- [ ] **Treasury Multisig** — bağımsız bir `.invariants.t.sol` dosyası yok; kontrat saf
      `TimelockController` wrapper'ı olduğu için invariant yüzeyi OpenZeppelin'in kendi
      audited test paketinde zaten kapsanıyor (bkz. `lib/openzeppelin-contracts`).
      Submission notunda bu açıkça gerekçelendirilir, sessizce atlanmaz.
      Neden: Denetçi "neden Treasury'nin invariant testi yok" sorusunu sormadan önce
      gerekçeyi okumalı; aksi halde eksik test kapsamı olarak işaretlenir.
- [ ] **ICTT Bridge (Home + Remote)** — `test/templates/ICTTBridge.t.sol` şu an yalnızca
      smoke test (init/registration). Lock→mint / burn→unlock akışını kapsayan bir
      stateful invariant dosyası (`test/templates/ICTTBridge.invariants.t.sol`) henüz
      yazılmadı; contest öncesi en yüksek öncelikli açık iş budur.
      Neden: Cross-chain bridge'lerde "kilitlenen miktar == basılan miktar" invariant'ı
      eksikse, denetçi bunu kendi başına bulup raporlamak zorunda kalır — bu hem süre
      kaybı hem de "ekip kendi kritik invariant'ını test etmemiş" izlenimi yaratır.

## 3. Known Issues Listesi

- [ ] `auto_detect_solc` multi-version derleme durumu (Sprint 1+2 şablonları `0.8.34`,
      ICTT şablonları `0.8.25` pin) submission paketinde açık şekilde belirtiliyor.
      Neden: `SECURITY.md` bunu zaten kapsam dışı kabul ediyor; aynı not contest
      formunda tekrar edilmezse denetçi bunu yeni bir bulgu sanıp rapor açabilir.
- [ ] `KozaCollection.publicMint`/`allowlistMint` fazla ödemeyi (`msg.value` >
      gerekli tutar) refund etmiyor — bilinçli tasarım kararı (NatSpec'te "Strict
      msg.value" olarak belgeli) olarak listeleniyor.
      Neden: Refund eksikliği ilk bakışta fon kilitleme bug'ı gibi görünür; niyet
      belirtilmezse duplicate/geçersiz rapor trafiği artar.
- [ ] `KozaCredential` soulbound kilidi `approve`/`setApprovalForAll`'ı engellemiyor,
      sadece fiilen işe yaramaz hale getiriyor (`_update` override transfer'i bloklar) —
      bu kasıtlı tasarım known issue olarak not düşülüyor.
      Neden: Denetçi "approve çağrılabiliyor ama hiçbir işe yaramıyor" durumunu açıklık
      olmadan bulup ayrı bir bulgu olarak raporlayabilir.
- [ ] ICTT Bridge'in trust modeli (`teleporterManager` = Safe multisig varsayımı,
      Avalanche validator ekonomisine güven) `docs/tr/04-guvenlik.md` §3.8 referansıyla
      submission paketine ekleniyor.
      Neden: Cross-chain trust assumption'ları audit kapsamının neresi olduğunu belirler;
      belirtilmezse denetçi validator ekonomisini de scope sanabilir.
- [ ] Profesyonel/topluluk audit'ten daha önce geçilmediği (`SECURITY.md` "Audit Durumu"
      bölümü) submission'da ilk satırda tekrar belirtiliyor.
      Neden: Contest platformları "bu kod daha önce denetlendi mi" sorusunu sorar;
      net cevap olmadan başvuru reddedilebilir veya yanlış sınıflandırılabilir.

## 4. Scope Freeze (Commit Hash Sabitleme)

- [ ] Contest başvurusundan önce `main` dalında submission'a giren tam commit hash'i
      sabitleniyor (`git rev-parse HEAD`) ve bu hash submission formuna yazılıyor.
      Neden: Denetçi raporu belirli bir kod durumuna göre yazar; freeze sonrası kod
      değişirse rapor-kod uyuşmazlığı (false positive/negative) doğar.
- [ ] Freeze commit'i bir git tag ile işaretleniyor (`v0.x.0-audit` formatında, mevcut
      `v0.1.0`…`v0.5.0` release pattern'iyle tutarlı).
      Neden: Tag, hash'i insan-okunur ve geri dönülebilir kılar; reviewer geç katılırsa
      doğru noktayı bulması saniyeler alır.
- [ ] Freeze penceresi boyunca (contest süresi) `src/templates/**` altına yalnızca
      denetçi tarafından onaylanmış fix commit'leri merge ediliyor; aksi her değişiklik
      ayrı duyuruluyor.
      Neden: Sherlock/Cantina kuralları contest ortasında sessiz kod değişikliğini
      genelde ihlal sayar ve mevcut bulguları geçersiz kılabilir.
- [ ] Fuji testnet'teki canlı + Snowtrace-verified kontrat adresleri (`SECURITY.md`
      "Kapsam (In-Scope)" tablosu) freeze commit'iyle aynı bytecode'a karşılık geldiği
      doğrulanıyor.
      Neden: Denetçi çoğu zaman canlı deploy üzerinden de okuma yapar; kaynak kod ile
      on-chain bytecode farklıysa güven kaybı + geçersiz bulgu riski oluşur.

## 5. Test Coverage Hedefi (`forge coverage`)

- [ ] `forge coverage --report summary` çalıştırılıyor; line coverage **≥%95**,
      branch coverage **%100** hedefi `docs/tr/04-guvenlik.md` §4.2 ile tutarlı
      şekilde tutturuluyor.
      Neden: Düşük coverage, denetçiye "test edilmemiş kod yolu = potansiyel bug"
      sinyali verir ve contest jüri puanlamasında genelde doğrudan kriterdir.
- [ ] `forge coverage --ir-minimum --report lcov` CI çıktısı (Codecov) submission'a
      ek olarak linkleniyor.
      Neden: Self-reported coverage yerine CI'dan üretilen, manipüle edilemeyen rapor
      denetçiye daha güvenilir gelir.
- [ ] Coverage'ı %100'e tamamlamayan satırlar (varsa) tek tek gerekçelendiriliyor
      (örn. ulaşılamaz `revert` dalları, OZ parent fonksiyonlarının pass-through'ları).
      Neden: Gerekçesiz eksik coverage, denetçinin önceliklendirmesini gereksiz yere
      o satırlara yönlendirip gerçek riskli alanlardan saptırabilir.

## 6. Statik Analiz Temizliği

- [ ] CI'daki Slither job'ı (`.github/workflows/ci.yml` → `slither`, `fail-on: medium`)
      son freeze commit'inde **0 high, 0 medium** sonucuyla yeşil.
      Neden: Contest platformları genelde "Slither/Aderyn temiz mi" sorusunu başvuru
      formunda doğrudan sorar; kırmızı CI ile başvuru güvenilirliği düşer.
- [ ] CI'daki Aderyn job'ı (`.github/workflows/ci.yml` → `aderyn`) çalıştırılmış, raporundaki her
      finding triaged (kabul edilen/false-positive/fixed) olarak işaretli.
      Neden: Aderyn Slither'ın yakalamadığı bazı pattern'leri yakalar (Rust-based, farklı
      detector seti); triaj yapılmadan bırakılan finding'ler denetçi tarafından tekrar
      keşfedilip zaman kaybettirir.
- [ ] Low/informational seviye Slither/Aderyn uyarıları (varsa) tek satırlık gerekçeyle
      submission known-issues listesine ekleniyor (bkz. Bölüm 3).
      Neden: Sessizce bastırılan low-severity uyarı, denetçi tarafından "ekip statik
      analiz çıktısını okumamış" şeklinde yorumlanabilir.
- [ ] Slither/Aderyn raporlarının (JSON/markdown) son hali repo'da veya submission
      ekinde erişilebilir; sadece "CI yeşil" demekle yetinilmiyor.
      Neden: Denetçi ham raporu görmeden hangi detector'ların hangi sonuçla çalıştığını
      doğrulayamaz.

## 7. Erişim Kontrolü Matrisi

| Şablon | Rol/Yetki | Korunan Fonksiyonlar | Production Önerisi |
| --- | --- | --- | --- |
| ERC-20 Gas Token | `owner` (Ownable2Step) | `mint` | Safe multisig — EOA owner mainnet'te tek nokta risk |
| ERC-721 Collection | `owner` (Ownable2Step) | `setMerkleRoot`, `setPhase`, `setBaseURI`, `setMintPrice`, `setDefaultRoyalty`, `withdraw` | Safe multisig — özellikle `withdraw` doğrudan fon hareketi |
| Soulbound Credential | `DEFAULT_ADMIN_ROLE` (AccessControl) | `grantRole`/`revokeRole` (ISSUER_ROLE yönetimi) | Safe multisig, asla EOA |
| Soulbound Credential | `ISSUER_ROLE` (AccessControl) | `issue`, `revoke` | Eğitim kurumu/topluluk operasyon cüzdanı; admin tarafından atanır |
| ICTT Bridge (Home + Remote) | `teleporterManager` | Teleporter version migration (`TeleporterRegistryOwnableAppUpgradeable` üzerinden) | Safe multisig — Home ve Remote'da aynı kural |
| Treasury Multisig | `PROPOSER_ROLE` + `CANCELLER_ROLE` | `schedule`, `scheduleBatch`, `cancel` | Safe multisig (production önerisi) |
| Treasury Multisig | `EXECUTOR_ROLE` | `execute`, `executeBatch` | `address(0)` (açık execute) veya Safe multisig |
| Treasury Multisig | `DEFAULT_ADMIN_ROLE` | rol yönetimi, `updateDelay` (yalnızca timelock'un kendi önerisiyle) | `address(0)` (self-administered) — kurulum sonrası `renounceRole` önerilir |

- [ ] Yukarıdaki matris submission paketine ekleniyor ve her satırdaki "Production
      Önerisi" sütunu mevcut testnet deploy'larının gerçek konfigürasyonuyla karşılaştırılıyor.
      Neden: Denetçi privilege escalation senaryolarını değerlendirirken "kim hangi
      fonksiyona erişebilir" sorusunu ilk soran taraf olur; matris olmadan bunu kontrat
      kontrat çıkarmak zorunda kalır.
- [ ] Fuji'deki mevcut deploy'larda hangi rollerin hâlâ EOA'da olduğu (varsa) açıkça
      işaretleniyor; mainnet öncesi Safe'e taşınması gereken adresler listeleniyor.
      Neden: Testnet'te EOA kullanmak normaldir ama bunun mainnet'e taşınmayacağının
      teyidi denetçiye verilmezse "single point of failure" bulgusu açılabilir.

## 8. Upgrade/Timelock Varsayımları

- [ ] Beş şablonun da **upgrade edilemez** (proxy/`Initializable`/UUPS yok) olduğu
      submission'da açıkça belirtiliyor — `src/templates/**` içinde
      `Initializable`/`UUPSUpgradeable`/`TransparentUpgradeableProxy` kullanımı yok.
      Neden: Denetçi varsayılan olarak upgrade path arar; yoksa bunu "kasıtlı" olarak
      teyit etmek storage-collision/`_authorizeUpgrade` sınıfı soruları baştan kapatır.
- [ ] Upgrade edilemez olmanın bilinçli trade-off olduğu not düşülüyor: bug bulunursa
      tek yol redeploy + migration; bu, "admin upgrade key'i çalınırsa logic değişir"
      riskini sıfırlar ama "canlıdaki bug hot-fix edilemez" riskini doğurur.
      Neden: Trade-off'un iki yönü de açık yazılmazsa denetçi sadece riskli tarafı
      görüp eksik mimari kararı sanabilir.
- [ ] `KozaTreasury`'nin `minDelay` parametresi için production önerisi (48 saat+)
      ve `admin = address(0)` self-administered tercihi (kurulum sonrası
      `renounceRole(DEFAULT_ADMIN_ROLE, deployer)`) submission'a, kontrattaki NatSpec
      ile birebir tutarlı şekilde yansıtılıyor.
      Neden: Timelock'un güvenlik değeri tamamen `minDelay` + rol dağılımına bağlı;
      bu varsayımlar yanlış aktarılırsa denetçi gerçekte var olmayan bir riski (veya
      tam tersi, gerçek bir riski) değerlendirebilir.
- [ ] Treasury dışındaki dört şablonda "timelock" kavramı yok — owner/role değişiklikleri
      anında etkili olur. Bu, submission'da Treasury'nin neden ayrı bir güven modeline
      sahip olduğunu açıklayan bir dipnotla belirtiliyor.
      Neden: Aynı repoda bir şablonun timelock'lu, diğerlerinin anlık olması karışıklığa
      yol açabilir; tutarsızlık değil, bilinçli kapsam farkı olduğu açıklanmalı.

---

## Sıradaki Adım

Bu checklist'teki tüm maddeler işaretlendikten sonra: `docs/tr/04-guvenlik.md` §6
(Audit Stratejisi) içindeki Sherlock/Cantina karşılaştırma tablosuna göre platform
seçilir, freeze edilen commit hash + bu doküman + `SECURITY.md` submission paketine
eklenir.

İlgili dokümanlar: `docs/tr/04-guvenlik.md` (genel pre-deploy güvenlik checklist'i),
`SECURITY.md` (responsible disclosure + kapsam), `docs/grant/grant-basvuru-taslagi.md`
(roadmap bağlamı).
