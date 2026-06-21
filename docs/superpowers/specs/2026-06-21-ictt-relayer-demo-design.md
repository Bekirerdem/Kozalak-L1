# v0.3.1 — Uçtan Uca ICTT Relayer Demo (Tasarım)

> Tarih: 2026-06-21 · Sprint 3.1 · Template 3 (ICTT Cross-L1 Bridge) follow-up
> Durum: tasarım onaylandı, canlı yürütme aşamasında

## 1. Problem

v0.3.0'da ICTT köprüsü kontrat seviyesinde tamamlandı:

- `KozaTokenHome` Fuji'de canlı + verified (`0x2b1377537690793939DC42530c15DA897AC9D2D9`)
- `KozaTokenRemote` daha önce yerel L1'e deploy edildi, `registerWithHome()` çağrıldı

**Ama uçtan uca transfer hiç gerçekleşmedi:** `icm-relayer` kurulmadığı için
Fuji'de gönderilen Warp mesajı yerel L1'e teslim edilmedi. Ayrıca yerel L1
network'ü şu an `not running` — önceki deploy state'i kayboldu, Remote adresi
(`0x53c10844...`) ve blockchain ID artık geçersiz.

Sonuç: README/site'ta "uçtan uca canlı" benzeri ifadeler gerçeği yansıtmıyor.
Bu tutarsızlık kapatılmalı.

## 2. Hedef ve Başarı Kriteri

**Doğrulanabilir başarı kriteri:**

> Fuji'de KGAS lock (`send`) işlemi gönderildikten sonra, relayer mesajı taşır
> ve yerel L1'de wKGAS mint'i `balanceOf(recipient) > 0` ile **on-chain
> doğrulanır**. Tüm tx hash'leri + relayer log alıntıları repoda saklanır.

**Kapsam kararları:**

- **Yön:** Önce tek yön (Fuji → L1 mint) = başarı kriteri. Çalışınca round-trip
  (L1 → Fuji wKGAS burn → KGAS unlock) bonus olarak eklenir.
- **Hedef zincir stratejisi:** Yerel L1 (geçici — her makine kapanışında ölür).
  Kalıcılık, **tek komutla tekrarlanabilir orchestration script** ile sağlanır:
  isteyen herkes kendi makinesinde demoyu yeniden üretir.
- **Yürütme:** Canlı, interaktif. WSL komutları Claude tarafından çalıştırılır,
  her adım kullanıcı onayıyla ilerler. `PRIVATE_KEY` `.env`'de mevcut.
- **İsim:** Yeni L1 `kozalakTestL1` adıyla deploy edilir (dokümanlarla uyumlu;
  eski `kozaTestL1` config'i terk edilir). genesis hazır: `genesis/ictt-bridge.json`.

## 3. Ortam Durumu (doğrulandı 2026-06-21)

- Avalanche CLI v1.9.6 kurulu (WSL/Ubuntu) ✅
- `avalanche network status` → `network is not running` ❌
- `.env`: `PRIVATE_KEY`, `REMOTE_TOKEN_HOME_BLOCKCHAIN_ID` (Fuji C-Chain, statik),
  `REMOTE_TOKEN_HOME_ADDRESS` (Home, statik), `SNOWTRACE_API_KEY` dolu ✅
- `genesis/ictt-bridge.json` → `warpConfig.requirePrimaryNetworkSigners: true`,
  quorum ⅔ ✅ (Fuji imzalarının kabulü için şart)

## 4. Relayer Yaklaşımı (en kritik teknik karar)

`avalanche interchain relayer deploy` tek network bağlamında çalışıyor
(`--fuji` XOR `--local`). Bizim senaryomuz **hibrit**: Fuji C-Chain (public) ↔
yerel L1 (localhost). Bu yüzden:

- **Birincil yol:** Elle `icm-relayer` config.json. Her iki blockchain'i source +
  destination tanımlar; Fuji için signature aggregator'ı Primary Network
  validator'larına yönlendirir (Fuji info/P-Chain API). Config, yerel L1 deploy
  edildikten sonra blockchain ID + Teleporter Registry'yi otomatik gömen bir
  generator ile üretilir.
- **Fallback:** CLI `relayer deploy --blockchains ...` hibrit config üretebiliyorsa
  o kullanılır (implementasyonda denenerek netleşir).

## 5. İş Zinciri

| # | Adım | Doğrulama |
|---|------|-----------|
| 1 | Yerel L1'i deploy et (`kozalakTestL1`, genesis hazır) | `avalanche blockchain describe` → RPC + blockchain ID + Teleporter Registry |
| 2 | `.env`'i otomatik güncelle (yeni RPC, registry, blockchain ID) | grep doğrula |
| 3 | `KozaTokenRemote`'u yerel L1'e deploy et | deploy log + `name()/symbol()` read |
| 4 | `registerWithHome()` çağır | Warp mesajı yayımlandı (tx hash) |
| 5 | icm-relayer config üret + relayer başlat (çift yönlü) | relayer log "listening" |
| 6 | Fuji'de KGAS approve + `send()` | tx hash |
| 7 | Yerel L1'de wKGAS mint doğrula | `balanceOf(recipient) > 0` ← başarı |
| 8 | (Bonus) round-trip: L1 → Fuji burn/unlock | Fuji'de KGAS unlock doğrula |

## 6. Üretilecek Artifact'lar (reproducible'ı sağlayan kalıcı kısım)

- `scripts/demo/run-ictt-demo.sh` — adım 1-7'yi tek komutla çalıştıran idempotent
  orchestration; her adımı doğrular, hata durumunda durur.
- `scripts/demo/gen-relayer-config.sh` (+ `relayer-config.template.json`) — yeni
  blockchain ID / registry'yi otomatik gömerek relayer config üretir.
- `docs/tr/03-templateler/ictt-bridge.md` — "Sprint 3G ön rehber" bölümünü
  gerçekleştirilmiş + tx-hash kanıtlı adımlara çevir.
- `docs/tr/03-templateler/ictt-demo-kanit.md` — çalıştırma kanıtları (tx hash'ler,
  relayer log alıntıları, balanceOf çıktısı).

## 7. Dokümantasyon Dürüstlüğü

- README + CHANGELOG + site (`koza.bekirerdem.dev`): "uçtan uca canlı" →
  **"uçtan uca doğrulandı (yerel L1 demo) + tek komutla tekrarlanabilir"**.
  Yerel L1'in geçici olduğu açıkça belirtilir.
- CHANGELOG `[0.3.1]` bölümü eklenir; gerçek tx hash'ler + Remote adres kaydedilir.

## 8. Riskler

- **R1 (yüksek):** Fuji → L1 imza toplama. requirePrimaryNetworkSigners=true →
  relayer'ın Fuji Primary Network ⅔ validator imzasını toplaması gerek. icm-relayer
  signature aggregator bunu yapar ama config doğru olmalı. → Adım 5'te erken test.
- **R2 (orta):** Relayer fee fonlaması. Relayer her iki zincirde gas öder (Fuji'de
  AVAX, L1'de TKOZA). Funding-key + genesis alloc ile çözülür.
- **R3 (düşük):** Yerel L1 her seferinde yeni blockchain ID üretir → config + `.env`
  generator ile otomatik güncellenir (manuel hata önlenir).

## 9. Güvenlik Notları (audit-grade prensibi korunur)

- Custom bridge/relayer logic YOK — `ava-labs/icm-contracts` + resmi `icm-relayer`.
- `.env` PRIVATE_KEY sadece testnet. Demo değerleri/tx hash'leri repoda; secret yok.
- requirePrimaryNetworkSigners düşürülmez.
