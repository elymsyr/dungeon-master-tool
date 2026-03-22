# Dungeon Master Tool — Gelir Modeli ve Fiyatlandırma Stratejisi

> **Versiyon:** 1.0  
> **Tarih:** March 17, 2026  
> **Durum:** Öneri (Founder kararına açık)  
> **Kapsam:** Offline free + online paid modelinin ürün, teknik, operasyon ve gelir planı

---

## 1) Yönetici Özeti

Dungeon Master Tool için önerilen model:

1. `Offline Desktop`: Sonsuza kadar ücretsiz.
2. `Self-Hosted Online`: Ücretsiz/community (kendi sunucusunu kuran DM için).
3. `Official Hosted Online` (SaaS): Ücretli abonelik (ana gelir kanalı).

Bu yaklaşım proje hedefleriyle doğrudan uyumludur:
- Offline kullanıcıyı bozmadan online eklemek.
- Subscription altyapısını teknik olarak hazırlamak.
- Hosted server tarafına geçişi mümkün kılmak.

Bu modelin ana prensibi:  
**“Kreatif çekirdeği değil, konforu, güvenilirliği, operasyonu ve zaman kazancını ücretlendir.”**

---

## 2) Girdi ve Dayanaklar

Bu strateji şu dokümanlarla hizalanmıştır:

- [DEVELOPMENT_REPORT.md](/home/eren/GitHub/dungeon-master-tool/docs/DEVELOPMENT_REPORT.md)
  - Business goals: subscription foundation + hosted geçiş
  - Bounded contexts: `identity` içinde subscription entitlements
  - Feature flag yaklaşımı: `online_session_enabled` vb.
  - Faz disiplini: Phase 0 tamamlanmadan online çekirdek başlamamalı
- [SPRINT_MAP.md](/home/eren/GitHub/dungeon-master-tool/docs/SPRINT_MAP.md)
  - Sprint 1-8 sıralaması ve bağımlılıklar
  - Auth/session altyapısının Sprint 3 ve sonrası gelmesi
- [TODO.md](/home/eren/GitHub/dungeon-master-tool/TODO.md)
  - Online öncesi kritik UI/UX işleri henüz açık
- [LICENSE](/home/eren/GitHub/dungeon-master-tool/LICENSE)
  - Repository içindeki bazı artistik varlıklarda `CC BY-NC` (ticari kullanım kısıtı) notu

---

## 3) Stratejik Model Seçimi

### 3.1 Önerilen Model: Open-Core + Hosted SaaS

**Open-Core tarafı (ücretsiz):**
- Offline campaign yönetimi
- Temel yerel import/export
- Local projection ve local toolset
- Self-host etmek isteyen teknik kullanıcılar için online altyapı (community support)

**Hosted SaaS tarafı (ücretli):**
- Tek tık online session başlatma
- Yönetilen altyapı (TLS, uptime, backup, izleme)
- Daha iyi latency/reconnect garantisi
- Hesap bazlı plan/kota/yedekleme
- Ticari destek ve öncelikli destek kanalı

### 3.2 Neden Bu Model?

1. Mevcut kullanıcı tabanı için güvenli geçiş sağlar (free offline korunur).
2. Açık kaynak ruhunu bozmadan para kazanmayı mümkün kılar.
3. Teknik olarak zaten planlanan `identity + entitlements` mimarisine oturur.
4. “DM öder, oyuncu ücretsiz” yaklaşımı onboarding sürtünmesini düşürür.

---

## 4) Ürün Paketleme (Packaging)

## 4.1 Planlar (v1)

### `Free (Offline + Community Online)`
- Offline tüm temel akışlar
- Self-host kurulum dokümantasyonu
- Topluluk desteği (issue/discord)
- Resmi SLA yok

### `Hosted Starter` (öneri: **$6.99-$8.99 / ay**)
- 1 aktif online oturum
- Belirli asset storage kotası
- Temel backup (ör. günlük snapshot, kısa saklama)
- Email destek (best effort)

### `Hosted Pro` (öneri: **$11.99-$14.99 / ay**)
- Daha yüksek eşzamanlı/aktif oturum kapasitesi
- Daha yüksek storage + uzun saklama
- Hızlı restore + gelişmiş backup
- Öncelikli destek
- Gelişmiş session yönetim araçları

### `Hosted Creator / Team` (opsiyonel, v2)
- Çoklu campaign workspace
- Ortak kütüphane
- Ekip rolleri ve audit detayları
- Eğitim kulüpleri / stüdyo kullanımı

## 4.2 Ücret Duvarı Nerede Olmalı?

Ücret duvarı aşağıdaki konulara konulmalı:
- Hosted altyapı kullanımı
- Storage/transfer/backup gibi maliyetli servisler
- Operasyonel kolaylık (one-click hosting, otomatik bakım)
- SLA ve destek seviyesi

Ücret duvarı **konulmaması gereken** yerler:
- Temel offline yaratıcı akış
- Kullanıcının kendi verisine erişimi/taşınabilirliği
- Güvenlik yamaları

---

## 5) Fiyatlandırma Mantığı

## 5.1 Değer Metriği (Value Metric)

Tek bir metriğe aşırı bağımlı kalmayın. Hibrit metrik kullanın:
- Aktif hosted session sayısı
- Storage kotası
- Backup saklama süresi
- Premium operasyon özellikleri (restore hızı, öncelikli support)

## 5.2 Fiyat Aralığı Gerekçesi (Pazar Referansı)

**As-of: March 17, 2026** (fiyatlar değişebilir)

- Roll20 abonelik katmanları: Plus `5.99`, Pro `10.99`, Elite `14.99` USD / ay.
- The Forge: GM planları düşük giriş bandından başlıyor (`3.99` USD / ay seviyesinden).
- Foundry: host odaklı tek sefer lisans (`$50`), oyuncular ücretsiz katılır.
- Alchemy: core deneyim free; destekleyici üyelik ve marketplace gelirleriyle hibrit model.

Bu nedenle DM Tool için `Starter 6.99-8.99` ve `Pro 11.99-14.99` bandı konumlandırma açısından makul.

## 5.3 Erken Dönem Fiyat Politikası

Öneri:
1. Kapalı beta: ücretsiz.
2. GA öncesi “Founding DM” fiyatı: ömür boyu indirim (ör. ilk 200 kullanıcı).
3. GA sonrası standart fiyat + yıllık ödeme indirimi (%15-%20).

---

## 6) Ek Gelir Kanalları (Subscription Dışı)

1. **Marketplace komisyonu**  
   Soundpack, map pack, template world, handout paketleri.
2. **Premium içerik paketleri**  
   Resmi “ready-to-run campaign kit” paketleri.
3. **Creator Program**  
   Üretici gelir paylaşımı + mağaza vitrini.
4. **Destekçi üyelik (Patron modeli)**  
   Erken erişim, roadmap oylaması, topluluk rozetleri.
5. **Kurumsal/eğitim lisansları**  
   Kulüpler, oyun kafeleri, eğitim toplulukları için çoklu lisans.

Not: Subscription tek kanal olmamalı. Marketplace + creator ekosistemi uzun vadede LTV’yi artırır.

---

## 7) Lisans ve İçerik Riskleri (Kritik)

Repository lisans notlarında bazı artistik varlıklar için `NonCommercial` ibaresi bulunuyor.  
Bu, ücretli/hosted kullanımda hukuki risk doğurabilir.

### 7.1 Zorunlu Aksiyonlar

1. Ticari kullanıma kapalı tüm asset’leri envanterleyin.
2. Bu varlıkları ticari lisanslı alternatiflerle değiştirin veya paketten çıkarın.
3. “Core code license” ile “bundled asset license” ayrımını netleştirin.
4. Uygulama içinde asset attribution ekranı ekleyin.
5. README + LICENSE + dağıtım paketlerini ticari sürüm için uyumlu hale getirin.

Bu adım tamamlanmadan hosted ücretli açılış yapılmamalı.

---

## 8) Teknik Entegrasyon: Entitlement ve Billing Katmanı

## 8.1 Mimari Yerleşim

Mevcut önerilen server mimarisinde `identity` context’i içinde subscription entitlements yer alıyor.  
Bu tasarım korunmalı ve aşağıdaki bileşenler eklenmeli:

- `plans` tablosu
- `subscriptions` tablosu
- `entitlements` (aktif haklar)
- `usage_counters` (kota takibi)
- `billing_events` (audit ve hataya dayanıklılık)

## 8.2 API/Guard Enforcements

Plan kontrolü şu noktalarda zorunlu:
- Session create
- Concurrent session limiti
- Asset upload/storage limitleri
- Backup/restore endpoint’leri

Guard seviyesi:
- JWT auth sonrası `scope + entitlement` birlikte kontrol
- Fail durumunda deterministik hata kodları (`402`/`403` semantiği netleştirilmeli)

## 8.3 Feature Flag + Entitlement Birlikte Kullanım

Akış:
1. Feature flag global açar/kapatır (`online_session_enabled`).
2. Entitlement kullanıcı bazında erişim hakkını belirler.

Bu ikili yapı rollout riskini ciddi azaltır.

---

## 9) Fazlara Göre Gelir Aktivasyonu

Sprint takvimine göre para kazanma açılışı aşamalı olmalı.

### Phase 0 (Sprint 1-2)
- Monetization development yok (yalnız hazırlık)
- Öncelik: UI/UX borçları + EventManager + socket smoke test

### Phase 1 (Sprint 3-4)
- Auth/session çekirdeği
- Entitlement şemasının teknik iskeleti (plan enforcement henüz soft)
- Kapalı alpha, ücret yok

### Phase 2 (Sprint 5-6)
- Sync kalitesi ve reconnect güvenilirliği
- Kullanım telemetrisi + maliyet ölçümü
- İlk fiyat testi (yalnızca davetli gruplarda)

### Phase 3 (Sprint 7)
- Değer artırıcı multiplayer özellikleri (event log/dice/restricted cards)
- “Founding DM” erken erişim planının duyurulması

### Phase 4 (Sprint 8 + sonrası)
- Self-hosted beta + hosted kontrollü GA
- Ücretli hosted planların resmen açılması
- 30 günlük beta sağlık metrikleri geçilmeden geniş lansman yapılmaması

---

## 10) KPI ve Finansal Sağlık Panosu

## 10.1 Ürün KPI’ları

- `Activation Rate`: kurulumdan ilk oyun başlatmaya dönüşüm
- `Week-4 Retention`: 4. haftada aktif DM oranı
- `Hosted Conversion`: online kullanan DM içinde ücretliye geçiş
- `Churn`: aylık iptal oranı
- `NPS / CSAT`: destek ve stabilite algısı

## 10.2 Operasyon KPI’ları

- P95 event latency
- Reconnect başarı oranı
- Session drop rate
- Asset first-load time
- Uptime / incident sayısı

## 10.3 Unit Economics

Takip edilmesi gereken temel formül:

`Brüt Katkı = ARPPU - (Hosting + Storage + Bandwidth + Support + Payment fees)`

Hedef: Hosted planlar ilk 2-3 ayda bile pozitif veya nötr brüt katkıya yaklaşmalı.

---

## 11) Go-to-Market (GTM) Planı

## 11.1 Konumlandırma Mesajı

Önerilen ana mesaj:
- “Offline-first güç sende, online’da zahmeti biz alıyoruz.”
- “Oyuncular ücretsiz katılır, DM tek abonelikle yönetir.”

## 11.2 Lansman Sıralaması

1. Kapalı Discord/Tester grubu
2. Waitlist + kullanım senaryosu toplama
3. Founding DM erken erişim
4. GA + içerik üreticileriyle ortak showcase

## 11.3 Satın Alma Sürtünmesini Azaltma

- 14 günlük hosted deneme
- Kredi kartı istemeden trial (mümkünse)
- Yıllık planda görünür indirim
- Basit ve şeffaf iptal politikası

---

## 12) 90 Günlük Uygulama Planı

## 12.1 Gün 0-30

1. Lisans/asset envanteri ve ticari temizlik planı
2. Entitlement veri modeli tasarımı
3. Metering event tasarımı (hangi kullanım nasıl ölçülecek)
4. Pricing sayfası ve plan farkı metinleri

## 12.2 Gün 31-60

1. Session/create ve asset/upload için plan guard
2. Trial + founding plan kod altyapısı
3. Telemetry dashboard (conversion, latency, cost)
4. Kapalı alfa test grubu

## 12.3 Gün 61-90

1. Pro plan farklılaştırıcı özelliklerin netleştirilmesi
2. Hosted onboarding akışının sadeleştirilmesi
3. Destek operasyonu (SLA, yanıt şablonları)
4. Soft launch + fiyat deneyi A/B

---

## 13) Karar Gerektiren Konular (Founder Checklist)

1. **Lisans stratejisi:** Self-host ücretsiz kalacak mı, hangi sınırla?
2. **İlk fiyat bandı:** Starter/Pro hangi exact fiyatla çıkacak?
3. **Trial politikası:** 14 gün mü, 7 gün mü?
4. **Founding DM limiti:** kaç kullanıcıya, ne kadar indirim?
5. **Marketplace zamanlaması:** v1’de mi, v2’de mi?

---

## 14) Sonuç

Dungeon Master Tool için en düşük riskli ve en sürdürülebilir para kazanma yolu:

- Offline çekirdeği ücretsiz koru.
- Self-host topluluğunu canlı tut.
- Hosted online deneyimi (güvenilirlik + kolaylık + destek) ücretlendir.

Bu yaklaşım hem mevcut teknik yol haritanla uyumlu hem de VTT pazarındaki kullanıcı davranışıyla tutarlı.

---

## Ek A — Rekabet Referansları (As-of March 17, 2026)

- Roll20 Feature Breakdown: https://help.roll20.net/hc/en-us/articles/360037774633-Feature-Breakdown  
- Foundry FAQ (license modeli): https://foundryvtt.com/article/faq/  
- The Forge pricing sayfası: https://as.forge-vtt.com/  
- Alchemy pricing sayfası: https://alchemyrpg.com/  

> Not: Pazar fiyatları sık güncellendiği için GA öncesi final fiyat revizyonu önerilir.
