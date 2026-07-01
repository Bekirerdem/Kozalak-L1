# Security Policy — kozalak-l1

## ⚠️ Audit Durumu

**Bu kod henüz profesyonel audit'ten geçmemiştir.** Phase 1 sonunda Sherlock veya Cantina contest planlanıyor. O zamana kadar:

- ⛔ Mainnet deploy ÖNERİLMEZ
- ✅ Fuji testnet ve eğitim amaçlı kullanım uygundur
- ✅ Tüm template'ler audited bağımlılıklar (OpenZeppelin, ava-labs/icm-contracts) miras alır

## Güvenlik Açığı Bildirimi

`kozalak-l1` kodunda bir güvenlik açığı tespit ederseniz lütfen **public issue açmayın**. Aşağıdaki kanallardan birini kullanın:

### Tercih Edilen: Email

📧 **l3ekirerdem@gmail.com**

Konu satırına `[kozalak-l1 SECURITY]` yazınız.

İçerik:
- Etkilenen dosya / fonksiyon
- Adım adım reproduce
- Etki tahmininiz (low/medium/high/critical)
- Önerdiğiniz fix (varsa)

### Yanıt Süresi

- İlk yanıt: 72 saat içinde
- Triage: 1 hafta içinde
- Fix + disclosure: severity'e göre 7-90 gün

## Bug Bounty

Phase 1 launch sonrası **Immunefi**'da bug bounty programı aktif olacak. Detaylar yakında.

Bu programa kadar geçerli olan **responsible disclosure politikası** aşağıda detaylandırılmıştır.

## Responsible Disclosure Politikası

### Kapsam (In-Scope)

5 şablonun Fuji testnet'te canlı kontratları kapsam dahilindedir:

| # | Şablon | Fuji Adresi |
|---|--------|--------------|
| 1 | ERC-20 + Custom Gas Token | `0x06451DD4Fb8ebFC19870DacC9568f4364D2A2eB0` |
| 2 | ERC-721 NFT Collection | `0x59347BB4365A18BBd92396Fd138E6cEfcDDb79C9` |
| 3 | ICTT Cross-L1 Köprü (Token Home) | `0x2b1377537690793939DC42530c15DA897AC9D2D9` |
| 4 | Soulbound Credential | `0xCFdE91F214ABDe2a2E65B6cd41A7C7E3244E1ec1` |
| 5 | Treasury Multisig + Timelock | `0x6864879522D70Fb8e1583Cc8Fd4baB0e9605A955` |

Ayrıca `src/templates/**` altındaki tüm kaynak kod (deploy script'leri ve testler dahil) kapsam dahilindedir.

### Severity Sınıfları

- **Critical:** Doğrudan fon kaybına, yetkisiz mint/burn'e veya kontrat erişim kontrolünün tamamen bypass edilmesine yol açan açıklar (ör. Treasury timelock'unun atlanması, ERC-20 supply cap'inin aşılması).
- **High:** Belirli koşullar altında fon/yetki kaybına veya kalıcı servis dışı kalmaya (DoS) yol açan açıklar (ör. ICTT mesaj replay'i, soulbound revoke mekanizmasının bypass edilmesi).
- **Medium:** Sınırlı etkili mantık hataları veya geçici DoS — kullanıcı fonlarını doğrudan riske atmaz ama beklenmeyen davranışa yol açar.
- **Low:** Gas inefficiency, best-practice sapmaları, etkisi ihmal edilebilir edge case'ler.

### Kapsam Dışı (Out-of-Scope)

- Audited üçüncü parti bağımlılıklardaki açıklar (OpenZeppelin Contracts, `ava-labs/icm-contracts`) — bunlar upstream projeye bildirilmelidir.
- Testnet-only deployment riskleri (Fuji faucet limitleri, validator merkeziyeti vb.).
- Bilinen `auto_detect_solc` multi-version durumu (takip edilen bilinen kısıtlama, ayrı rapor gerekmez).
- "Henüz profesyonel audit'ten geçmemiş olması" — bu README ve bu dosyada zaten açıkça belirtilmiştir, ayrı bir bulgu olarak raporlanmasına gerek yoktur.

### Raporlama Akışı

Tercih edilen kanal: **GitHub Security Advisory** (private) — repo üzerindeki "Security" sekmesinden "Report a vulnerability" ile açılır, public issue'dan farklı olarak yalnızca maintainer'lar görür.

Alternatif: yukarıdaki [Email](#tercih-edilen-email) kanalı.

Bu repo şu an için bir ödül (bounty) **vaat etmemektedir** — politika **responsible disclosure** esasına dayanır: açığı keşfeden kişi, fix yayınlanana ve kullanıcılar güvenli hale gelene kadar bilgiyi gizli tutar. Karşılığında geçerli raporlar için public teşekkür/kredi sunulur (bkz. [Disclosure Policy](#disclosure-policy)).

### SLA

- İlk yanıt hedefi: **72 saat içinde**.
- Triage (geçerlilik + severity sınıflandırması): **1 hafta içinde**.
- Fix + disclosure: severity'e göre **7-90 gün** (Critical/High öncelikli, Low en geç).

## Dahil Edilmiş Güvenlik Önlemleri

- Solidity ≥ 0.8.34 (IR storage bug fix sonrası)
- OpenZeppelin Contracts v5.3+ (Ownable2Step, AccessManager, ERC-7201 namespaced storage)
- Custom errors (audit kalitesi)
- Foundry fuzz/invariant testing (10000+ runs)
- Slither + Aderyn + Halmos CI
- ICM/Teleporter/ICTT için ava-labs audited kontratları miras alınır (custom bridge yazılmaz)

## Disclosure Policy

Coordinated disclosure tercih edilir. Reporter'lar uygun süre vermeden public açıklama yapmamalıdır. Karşılığında:
- Public credit (isteğe bağlı)
- Hall of Fame listing (yakında)
- Bug bounty (Immunefi açıldıktan sonra)
