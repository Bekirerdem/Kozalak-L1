# Grant Başvuru Taslağı — KOZALAK-L1

> Bu doküman **doldurulabilir bir taslaktır**. Aşağıdaki bölümler Team1 Mini,
> Avalanche Foundation infraBUIDL() ve Retro9000 başvuru formlarının ortak
> gövdesini oluşturacak şekilde hazırlanmıştır. Her program kendi formuna
> özgü alanlar (cüzdan adresi, talep edilen kesin tutar, milestone takvimi)
> istediğinde bu metin kopyalanıp ilgili kutulara uyarlanır. Traction
> rakamları `README.md` ile birebir tutarlıdır; programların kendi koşulları
> (havuz büyüklüğü, başvuru penceresi) değişebileceğinden başvuru anında
> resmi sayfadan teyit edilmelidir.

---

## Hedef Programlar

| Program | Odak | Şu anki uygunluk |
| --- | --- | --- |
| **[Team1 Mini Grants](https://grants.team1.network/)** | Erken aşama Avalanche builder'larına mentorluk + küçük tutarlı fon (4 fazlı süreç: başvuru/değerlendirme → milestone'lu ilk fon → MVP lansmanı + pazarlama desteği → Demo Day) | **Yüksek** — Türk ekip, Team1 Türkiye ağına ve Koza DAO'ya zaten bağlı, prototip değil canlı kod var |
| **[infraBUIDL()](https://build.avax.network/grants/infrabuidl)** (Avalanche Foundation) | Avalanche ekosistemine stratejik önem taşıyan altyapı projelerine direkt + milestone-bazlı retroaktif fon | **Orta-yüksek** — bir starter kit/tooling projesi altyapı kapsamına girer; CLI wrapper (Phase 3) milestone olarak sunulabilir |
| **[Retro9000](https://retro9000.avax.network/)** (Avalanche Foundation, L1 & Infrastructure Tooling Round dahil) | Mainnet'te zaten canlı olan Avalanche L1 ve altyapı projelerine topluluk oylamasıyla retroaktif fon, periyodik snapshot | **Düşük-orta şu an** — proje hâlâ Fuji testnet'te; mainnet deploy + gerçek kullanım metrikleri sonrası yeniden değerlendirilmeli |

---

## 1. Proje Özeti

**KOZALAK-L1**, Türk Solidity geliştiricilerinin Avalanche üzerinde hem kendi
Sovereign L1'lerini hem de smart contract'larını production-grade şekilde
deploy etmesini sağlayan, açık kaynak (MIT) audit-grade Solidity boilerplate
kütüphanesidir — kısaca "`create-react-app`, ama Türk dev için Avalanche
Solidity". Beş audit-grade şablon (ERC-20 custom gas token, ERC-721 koleksiyon,
ICTT cross-L1 köprü, Soulbound credential, Treasury multisig + timelock),
OpenZeppelin v5.3+ ve `ava-labs/icm-contracts` audited primitive'leri üzerine
kurulu, Foundry fuzz/invariant testleri ve Slither/Aderyn statik analizinden
geçmiş, Türkçe adım adım rehberlerle desteklenir. Şu an beşi de Fuji
testnet'te canlı ve Snowtrace'te verified; sonraki adım profesyonel audit ve
1-komutla scaffold sağlayan CLI wrapper'dır.

## 2. Problem

Avalanche9000 / Etna upgrade'i ile özel L1 (Sovereign L1) kurulum maliyeti
yaklaşık %99 düştü, ancak bu fırsatı değerlendirecek **Türkçe, production-grade
bir başlangıç kiti yok**. Somut boşluklar:

- **Dil bariyeri:** ICTT lock/burn akışı, ERC-7201 namespaced storage,
  audit-grade pattern'ler gibi konularda Türkçe yazılı kaynak son derece
  sınırlı; Patika.dev, Kodluyoruz, BTK Akademi gibi programlardan mezun olan
  geliştiriciler İngilizce dokümantasyon + dağınık tutorial'lar arasında
  kayboluyor.
- **Hackathon → production geçişi zor:** Hackathon'da hızlıca yazılan
  kontratlar audit kalitesine taşınırken (custom error, ERC-7201, role-bazlı
  erişim kontrolü, invariant test) referans alınacak hazır, denenmiş şablon
  yok.
- **Büyüyen topluluk, ortak altyapı eksik:** Team1 Türkiye, Bursa merkezli
  Koza DAO ve üniversite kulüpleri aktif olarak büyüyor, ama bu topluluğun
  ortak kullanabileceği, audit-grade kod tabanlı bir paylaşılan altyapısı
  bulunmuyor — her ekip sıfırdan başlıyor.

## 3. Çözüm

KOZALAK-L1, yukarıdaki boşluğu üç bileşenle kapatır:

1. **5 audit-grade Solidity şablonu** — ERC-20 + custom gas token, ERC-721 NFT
   koleksiyonu (Merkle allowlist + ERC-2981 royalty), ICTT cross-L1 köprü
   (`ava-labs/icm-contracts` audited inherit), Soulbound credential
   (devredilemez, issuer-only mint), Treasury multisig + timelock (OZ
   `TimelockController` wrapper). Her biri Foundry fuzz/invariant test
   (≥10000 run), Slither + Aderyn statik analiz ve Fuji'de gerçek deploy +
   Snowtrace doğrulamasıyla teslim edilir.
2. **Türkçe rehber seti** — Avalanche 101'den L1 deploy'a, her şablonun
   deployment adımlarına ve güvenlik checklist'ine kadar 5 doküman
   (`docs/tr/01-05`), İngilizce kaynaklara muhtaç kalmadan baştan sona takip
   edilebilir.
3. **CLI wrapper (yol haritasında, Phase 3)** — `npx create-kozalak-l1` ile
   şablon seç → scaffold et → `.env` sihirbazıyla deploy et akışını tek
   komuta indirgeyen, topluluk katkısına açık bir geliştirme aşaması; bu
   başvurunun roadmap bölümünde milestone olarak detaylandırılmıştır.

## 4. Traction

Aşağıdaki veriler `README.md` ile birebir tutarlıdır (kaynak: bu repo,
2026-07-01 itibarıyla):

| # | Şablon | Versiyon | Durum | Fuji Adresi |
| --- | --- | --- | --- | --- |
| 1 | ERC-20 + Custom Gas Token | v0.1.0 | ✅ canlı + verified | `0x06451DD4Fb8ebFC19870DacC9568f4364D2A2eB0` |
| 2 | ERC-721 NFT Collection | v0.2.0 | ✅ canlı + verified | `0x59347BB4365A18BBd92396Fd138E6cEfcDDb79C9` |
| 3 | ICTT Cross-L1 Köprü (Token Home) | v0.3.2 | ✅ canlı + verified | `0x2b1377537690793939DC42530c15DA897AC9D2D9` |
| 4 | Soulbound Credential | v0.4.0 | ✅ canlı + verified | `0xCFdE91F214ABDe2a2E65B6cd41A7C7E3244E1ec1` |
| 5 | Treasury Multisig + Timelock | v0.5.0 | ✅ canlı + verified | `0x6864879522D70Fb8e1583Cc8Fd4baB0e9605A955` |

- **5/5 şablon Fuji testnet'te canlı ve Snowtrace'te verified.**
- **CI yeşil** — her push'ta Foundry test suite (unit + invariant + fuzz)
  ve Slither + Aderyn statik analiz çalışır
  ([CI badge](https://github.com/Bekirerdem/Kozalak-L1/actions/workflows/ci.yml)).
- **ICTT çift yön round-trip uçtan uca kanıtlanmış:** KGAS lock → wKGAS mint
  **ve** wKGAS burn → KGAS unlock akışı tek komutla tekrarlanabilir
  (`scripts/demo/run-ictt-demo.sh`), kanıt dokümanı:
  [`docs/tr/03-templateler/ictt-demo-kanit.md`](../tr/03-templateler/ictt-demo-kanit.md).
- **Solidity 0.8.34** (template 3 — ICTT — `icm-contracts` uyumu için
  0.8.25, multi-version compile), **OpenZeppelin v5.3+**, **Foundry 1.5+**.
- **Türkçe dokümantasyon (01-05) tamamlandı**, açık kaynak (MIT), public
  GitHub repo: [github.com/Bekirerdem/Kozalak-L1](https://github.com/Bekirerdem/Kozalak-L1).
- **Responsible disclosure politikası canlı** (`SECURITY.md`) — kapsam,
  severity sınıfları, raporlama akışı ve SLA tanımlı.

## 5. Yol Haritası

```
┌──────────────────────┬──────────────────────┬──────────────────────┐
│  Phase 1 (bitti)     │  Phase 2             │  Phase 3             │
│  Çekirdek (5/5)      │  Olgunlaştırma       │  Topluluk katkısı    │
├──────────────────────┼──────────────────────┼──────────────────────┤
│ ✅ Repo + CI setup   │ ⏳ Grant başvurusu   │ ○ CLI wrapper        │
│ ✅ 5/5 şablon canlı  │ ⏳ Bug bounty        │ ○ Web dashboard      │
│ ✅ Türkçe docs (1-5) │ ⏳ Opsiyonel audit   │ ○ 1-tıkla deploy     │
│ ✅ Slither/Aderyn CI │                      │                      │
└──────────────────────┴──────────────────────┴──────────────────────┘
```

> **Bu grant başvurusu Phase 2 (olgunlaştırma) kapsamındadır.**

- **Phase 1 — tamamlandı:** 5/5 audit-grade şablon Fuji'de canlı + verified,
  CI yeşil, Türkçe rehberler (01-05) hazır.
- **Phase 2 — olgunlaştırma:** grant başvurusu (bu doküman), responsible
  disclosure politikası (`SECURITY.md`), opsiyonel profesyonel audit hazırlığı
  (Sherlock veya Cantina contest için `docs/grant/audit-hazirlik-checklist.md`).
- **Phase 3 — topluluk katkısına açık:** CLI wrapper
  (`npx create-kozalak-l1` — şablon seç → scaffold → deploy), web dashboard,
  1-tıkla deploy akışı. Çekirdek toolkit Phase 3'ten bağımsız olarak kendi
  başına kullanıma hazırdır.

## 6. Bütçe Kalemleri

Aşağıdaki tutarlar **örnek aralıklardır**; gerçek talep her programın kendi
formuna ve o anki kapsamına göre ayarlanır (örn. Team1 Mini için tek bir alt
kalem, infraBUIDL() için CLI + audit milestone kombinasyonu talep edilebilir).

| Kalem | Kapsam | Örnek aralık |
| --- | --- | --- |
| **Profesyonel audit** | Sherlock veya Cantina contest — 5 şablonun (özellikle Treasury timelock ve ICTT lock/mint/burn/unlock akışları) bağımsız incelemesi, contest havuzu + judging maliyeti dahil | **$5.000 – $15.000** |
| **Geliştirme (CLI wrapper)** | `create-kozalak-l1` CLI'ı — template registry, scaffold motoru, `.env` deploy sihirbazı, npm publish (Phase 3 milestone'ı) | **$3.000 – $8.000** |
| **Dokümantasyon genişletme** | Türkçe rehberlerin İngilizce çevirisi, video walkthrough, audit-hazırlık checklist'inin derinleştirilmesi | **$1.000 – $3.000** |
| **Topluluk operasyonları** | Team1 Türkiye ve üniversite kulüpleriyle ortak workshop/hackathon desteği, Koza DAO üzerinden yerel builder onboarding'i | **$1.000 – $2.500** |
| **Toplam (örnek aralık)** | Yukarıdaki dört kalemin toplamı | **$10.000 – $28.500** |

## 7. Ekip

| | |
| --- | --- |
| **İsim** | Bekir Erdem |
| **GitHub** | [@Bekirerdem](https://github.com/Bekirerdem) |
| **İletişim** | l3ekirerdem@gmail.com |
| **Rol** | Solo geliştirici — proje sahibi, tüm Solidity şablonları, test paketi, CI/CD ve Türkçe dokümantasyonun yazarı |
| **Geçmiş** | Avalanche hackathon tecrübesi (ChainBounty, shavaxre), Foundry + Hardhat + ICM + Subnet-EVM ile çalışma geçmişi, Bursa merkezli Koza DAO topluluğundan ve Team1 Türkiye ağına bağlı |

## 8. Ekler

- Repo: [github.com/Bekirerdem/Kozalak-L1](https://github.com/Bekirerdem/Kozalak-L1)
- README: [`README.md`](../../README.md)
- ICTT round-trip kanıtı: [`docs/tr/03-templateler/ictt-demo-kanit.md`](../tr/03-templateler/ictt-demo-kanit.md)
- Güvenlik politikası: [`SECURITY.md`](../../SECURITY.md)
- CI iş akışı: [`.github/workflows/ci.yml`](../../.github/workflows/ci.yml)
