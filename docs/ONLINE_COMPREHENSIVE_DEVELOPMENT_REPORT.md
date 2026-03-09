# Dungeon Master Tool Online Geçişi
## Kapsamlı Geliştirme Raporu

Bu döküman, mevcut offline-first Dungeon Master Tool uygulamasının tam kapsamlı online ürüne dönüşümü için teknik, ürünsel ve operasyonel yol haritasını detaylı biçimde tanımlar.

- Doküman tarihi: 9 Mart 2026
- Kapsam: Mimari, faz planı, güvenlik, performans, test, operasyon, sürümleme
- Kaynak dokümanlar:
  - `docs/ONLINE_ROADMAP.md`
  - `docs/ONLINE_DEVELOPMENT.md`

---

## 1. Yönetici Özeti

Dungeon Master Tool'un online'a geçişi, yalnızca bir ağ bağlantısı ekleme işi değildir. Bu geçiş:
- Uygulama mimarisinin hibrit client-server modele evrilmesini,
- Rol ve yetki modelinin netleşmesini,
- Gerçek zamanlı veri senkronizasyonu için olay tabanlı bir omurganın kurulmasını,
- Varlık (asset) dağıtımı, cache, güvenlik, yedekleme ve gözlemlenebilirlik katmanlarının birlikte ele alınmasını gerektirir.

Bu nedenle önerilen strateji:
1. Faz 0 ve Faz 1'i tek bir "Online MVP çekirdeği" olarak ele almak.
2. Faz 2 özelliklerini (audio + mind map + player instance) kontrollü ve ölçümlenebilir şekilde açmak.
3. Faz 3 ve Faz 4'ü ürün olgunlaştırma ve operasyonel ölçekleme fazları olarak yönetmek.

---

## 2. Vizyon, Hedefler ve Başarı Kriterleri

### 2.1 Ürün Vizyonu
- DM'in masaüstü gücünü koruyan,
- Oyuncuların düşük sürtünmeyle oturuma katılabildiği,
- Harita, media, ses ve etkileşimli oyun öğelerinin gerçek zamanlı senkronize edildiği,
- Güvenli, ölçümlenebilir ve ölçeklenebilir bir online platform.

### 2.2 İş Hedefleri
- Mevcut kullanıcı tabanını bozmadan online yetenek eklemek.
- Abonelik modeli için teknik temel oluşturmak.
- Hosted server modeline geçişi mümkün kılmak.

### 2.3 Teknik Başarı Kriterleri (KPI)
- P95 olay gecikmesi (`event publish -> client apply`) < 120ms
- 5MB harita için ilk yükleme süresi < 3sn (genel internet koşullarında)
- Sıcak cache yükleme süresi < 1sn
- DM izin vermediği içeriğin oyuncu RAM/disk tarafına düşmemesi
- Oturum kopma sonrası yeniden bağlanmada 5sn içinde state toparlanması

---

## 3. Mevcut Durum ve Boşluk Analizi

### 3.1 Güçlü Temel
- Mevcut PyQt6 uygulaması güçlü domain ve içerik yönetimi sunuyor.
- Mind map, session view, map view, audio kontrolleri gibi online'a taşınabilir modüller mevcut.
- Yol haritası yüksek seviyede doğru fazlara ayrılmış.

### 3.2 Kritik Boşluklar
- Event sözleşmeleri örnek seviyede; versiyonlama ve idempotency kuralları eksik.
- Yetki modeli (rol, kapsam, paylaşım türü) teknik olarak formalize edilmemiş.
- Ağ kopması, retry, ordering, duplicate event handling net değil.
- Asset erişimi için token/TTL/imza politikaları net değil.
- Operasyon tarafı (metric, log, alert, tracing) tanımlı değil.

### 3.3 Uyum Notu
- `Auto Event Log` bir yerde prereq gibi, bir yerde ileri faz özelliği gibi geçiyor.
- Öneri: Event log altyapısını Faz 1 sonunda minimal, faz 3'te gelişmiş hale getirmek.

---

## 4. Mimari Tasarım

### 4.1 Hedef Mimari (Hibrit)
- DM App (PyQt6): Master client ve oturum yöneticisi.
- Player App (PyQt6 Player Mode): Kısıtlı yetkili görüntüleyici ve etkileşim istemcisi.
- Backend Gateway (FastAPI + python-socketio): Auth, session, real-time orchestration.
- Redis: Session state, kısa ömürlü anahtarlar, pub/sub ve geçici dağıtık koordinasyon.
- Asset Service: Geçici URL üretimi, güvenli dosya akışı, cache yönlendirme.

### 4.2 Bounded Context Önerisi
- `identity`: login, JWT, subscription entitlements
- `session`: create/join/close, participant lifecycle
- `sync`: map, mind map, audio, event routing
- `assets`: upload/proxy/cache invalidation
- `gameplay`: event log, dice, restricted card views

### 4.3 Veri Akışı İlkeleri
- Server authoritative session state.
- Client-side optimistic UI sadece düşük riskli aksiyonlarda.
- Her event için `event_id`, `session_id`, `ts`, `schema_version` zorunlu.
- Client apply pipeline idempotent olmalı (`event_id` dedupe).

### 4.4 Kullanılacak Teknoloji Stack'i (Self-Hosted)
- Desktop istemciler (DM + Player): Python 3.12, PyQt6, `python-socketio` client, Pydantic v2.
- Backend/API: FastAPI, `python-socketio` (ASGI), Uvicorn + Gunicorn.
- Veri katmanı: PostgreSQL 16 (kalıcı veri), Redis 7 (session/presence/pubsub/rate limit).
- Asset ve yedekleme: MinIO (S3 uyumlu object storage), istemci tarafında yerel cache.
- Operasyon ve gözlemlenebilirlik: Prometheus, Grafana, Loki, merkezi JSON loglama.
- CI/CD: GitHub Actions ile test, SSH tabanlı Docker Compose deploy.

### 4.5 Kendi Sunucumuzda Hedef Topoloji
- Sunucu işletim sistemi: Ubuntu Server 24.04 LTS (VPS veya dedicated server).
- Giriş katmanı: Nginx reverse proxy + Let's Encrypt (TLS sonlandırma).
- Uygulama katmanı: FastAPI + socket server konteynerleri.
- İç servisler: Redis ve PostgreSQL yalnızca internal networkten erişilebilir.
- Asset servis katmanı: MinIO, imzalı kısa ömürlü URL ile erişim.
- Üretim politikası: Production erişimi doğrudan self-hosted sunucu üzerinden verilir; tünel servisleri sadece lokal demo/debug için opsiyonel kalır.

---

## 5. Rol ve Yetki Modeli

### 5.1 Roller
- `DM_OWNER`: tam yetki, oturum ve paylaşım yönetimi
- `PLAYER`: yalnızca izinli içerik ve etkileşimler
- `OBSERVER` (opsiyonel): salt okunur görüntüleme

### 5.2 Yetki Kapsamları
- `session:manage`
- `player:join`
- `asset:read:scoped`
- `mindmap:push`
- `audio:control`
- `gameplay:dice:roll`

### 5.3 İçerik Görünürlük Seviyeleri
- `private_dm`: sadece DM
- `shared_full`: tam içerik oyuncuya açılır
- `shared_restricted`: redacted alanlar ile paylaşılır

---

## 6. API ve Real-time Sözleşme Tasarımı

### 6.1 REST Uçları (Öneri)
- `POST /auth/login`
- `GET /auth/me`
- `POST /sessions`
- `POST /sessions/{session_id}/join`
- `POST /sessions/{session_id}/close`
- `POST /assets/presign`
- `GET /assets/{asset_id}`

### 6.2 WebSocket Event Envelope

```json
{
  "event_id": "uuid-v7",
  "schema_version": "1.0",
  "session_id": "XY1234",
  "event": "AUDIO_STATE",
  "sender": {"role": "DM_OWNER", "id": "dm-1"},
  "ts": "2026-03-09T10:00:00Z",
  "seq": 1203,
  "payload": {}
}
```

### 6.3 Zorunlu Event Sınıfları
- `SESSION_STATE`
- `PLAYER_JOINED`, `PLAYER_LEFT`
- `MAP_STATE_SYNC`
- `MINDMAP_PUSH`, `MINDMAP_LINK_SYNC`
- `AUDIO_STATE`, `AUDIO_CROSSFADE`
- `EVENT_LOG_APPEND`
- `DICE_ROLL_REQUEST`, `DICE_ROLL_RESULT`

### 6.4 Güvenilirlik Kuralları
- At-least-once teslim varsayımı.
- `seq` ile ordering kontrolü.
- Eksik seq tespitinde incremental resync isteği.
- 3 başarısız retry sonrası full snapshot fallback.

---

## 7. Faz Bazlı Uygulama Planı

## Faz 0: Temeller ve İç Temizlik

### Hedef
Online'a geçiş öncesi UI/UX ve istemci altyapısının standardize edilmesi.

### Teslimatlar
- Single-window player view
- GM player screen control panel
- Embedded PDF/Image viewer
- Socket.io client + event manager abstraction
- UI standardizasyonu (#30)

### Teknik Notlar
- Event Manager modülü bağımsız bir katman olmalı (`connect`, `emit`, `subscribe`, `retry`).
- Viewer bileşeni hem local hem remote URL için ortak render pipeline kullanmalı.

### Çıkış Kriteri
- Uygulama içinde tek bir akışla player projection kontrolü yapılabiliyor olmalı.
- Socket katmanı mock server ile smoke testten geçmeli.

---

## Faz 1: Hub MVP

### Hedef
DM ve oyuncuların güvenli şekilde aynı oturumda buluşabildiği minimum online çekirdek.

### Teslimatlar
- FastAPI gateway + JWT auth
- Session create/join + 6 karakter join key
- Basic image/map sync
- Asset proxying (signed/expiring URL)

### Teknik Notlar
- Join key tek başına yetki vermemeli; JWT + session membership zorunlu.
- Asset URL TTL varsayılanı 60sn, tek kullanımlık imza tercih edilmeli.
- Map sync için başlangıçta full snapshot + düşük frekans diff modeli yeterli.

### Çıkış Kriteri
- DM oturum açar, oyuncu katılır, map ve projection senkron izlenir.
- Güvenlik testinde yetkisiz asset erişimi engellenir.

---

## Faz 2: Interactive MVP

### Hedef
Gerçek zamanlı etkileşimi artıran ses ve mind map işlevleri.

### Teslimatlar
- Soundpad/MusicBrain sync
- Crossfade senkronu
- Cache miss durumunda otomatik indirme
- Mind map push ve bağlantı senkronu
- Standalone player instance join mode

### Teknik Notlar
- Audio event'leri için drift kontrolü gerekebilir (`start_at`, `server_time`).
- Mind map node'larında immutable origin metadata tutulmalı.
- Player node edit izinleri DM-origin node'larından ayrıştırılmalı.

### Çıkış Kriteri
- Birden fazla oyuncuda eşzamanlı audio state sapması kabul edilebilir eşiğin altında.
- Push edilen mind map öğeleri oyuncuda tutarlı görünmeli.

---

## Faz 3: Gelişmiş Oyun Mekanikleri

### Hedef
Ortak oyun deneyimini ürün düzeyine taşıyan mekaniklerin eklenmesi.

### Teslimatlar
- Automated event log
- Shared dice roller + görsel geçmiş
- Restricted card database views
- Player character sheets + DM approval flow

### Teknik Notlar
- Dice sonuçları server-side üretilmeli ve imzalı log girdisi olarak saklanmalı.
- Event log için append-only model ve filtrelenebilir event type şeması önerilir.

### Çıkış Kriteri
- Oyuncu/DM tarafında aynı event geçmişi tutarlı görüntülenir.
- Rol bazlı veri kısıtları doğrulanır.

---

## Faz 4: Cloud ve Deployment

### Hedef
İnternetten erişim, yedekleme ve hosted model hazırlığı.

### Teslimatlar
- Self-hosted production deployment (VPS/dedicated) + domain/TLS yönetimi
- Cloud backup/restore
- Voice chat (WebRTC)
- Official hosted servers için operasyonel temel

### Teknik Notlar
- Voice modülü feature flag ile kademeli açılmalı.
- Backup, world data + assets + metadata bütünlüğünü korumalı.
- Tünel tabanlı çözümler production için birincil dağıtım modeli olmamalı; yalnızca geçici demo amaçlı kullanılmalı.

### Çıkış Kriteri
- DM tek adımda oturumunu internete açabilir.
- Backup geri yükleme smoke testi başarıyla tamamlanır.

---

## 8. Güvenlik Tasarımı

### 8.1 Kimlik ve Oturum
- JWT kısa ömür + refresh token rotasyonu.
- Session membership sunucu tarafında zorunlu doğrulama.

### 8.2 Veri Erişim Güvenliği
- Asset URL imzalı, kısa ömürlü, role-scope kontrollü.
- Paylaşılmayan içerik için istemciye hiçbir payload gönderilmemeli.

### 8.3 İletişim Güvenliği
- TLS zorunlu.
- WebSocket origin ve token doğrulaması.
- Rate limit ve basic abuse korumaları.

### 8.4 Denetim
- Kritik aksiyonlar için audit log:
  - session create/close
  - permission change
  - restricted content share

---

## 9. Performans ve Ölçeklenebilirlik

### 9.1 Hedef Metrikler
- P50/P95 event latency
- reconnect success rate
- cache hit ratio
- asset throughput

### 9.2 Performans Stratejileri
- Snapshot + diff tabanlı sync
- Event coalescing (özellikle slider güncellemelerinde)
- Asset CDN/proxy cache katmanı

### 9.3 Ölçeklenebilirlik Stratejileri
- Stateless API + Redis tabanlı session koordinasyonu
- Horizontal scaling için sticky-session gereksinimi analizi
- Regional relay ihtiyacı (ileriki aşama)

---

## 10. Test Stratejisi

### 10.1 Test Piramidi
- Unit test: event parser, permission guard, state reducer
- Integration test: API + Redis + WS event flow
- E2E test: DM ve 2+ oyuncu senaryoları

### 10.2 Kritik Senaryolar
- Join/leave/ reconnect
- Yetkisiz asset erişimi denemeleri
- Mind map push + restriction doğrulaması
- Audio crossfade eşzaman testleri

### 10.3 Non-Functional Testler
- Load test: eşzamanlı 10/25/50 oyuncu profilleri
- Soak test: 3+ saat kesintisiz oturum
- Fault injection: Redis kesintisi, network jitter, packet loss

---

## 11. Gözlemlenebilirlik ve Operasyon

### 11.1 Logging
- Yapısal log formatı (JSON)
- Correlation id: `session_id`, `event_id`, `user_id`

### 11.2 Metrics
- `ws_connected_clients`
- `event_delivery_latency_ms`
- `asset_download_duration_ms`
- `sync_resync_count`

### 11.3 Alerting
- P95 latency artışı
- reconnect failure spike
- unauthorized access attempts

### 11.4 Incident Süreci
- Seviyelendirilmiş incident sınıfları
- Rollback/runbook tanımları
- Postmortem şablonu

---

## 12. Sürümleme ve Yayınlama Planı

### 12.1 Release Trenleri
- `alpha`: internal team + sınırlı test kullanıcıları
- `beta`: davetli DM grupları
- `ga`: genel kullanım

### 12.2 Feature Flags
- `online_session_enabled`
- `mindmap_sync_enabled`
- `audio_sync_enabled`
- `voice_chat_enabled`

### 12.3 Geriye Dönük Uyumluluk
- Event schema minor versiyonları geriye dönük okunabilmeli.
- Breaking değişiklikler için çift yazım/dönüşüm dönemi uygulanmalı.

---

## 13. Ürün ve UX Notları

- DM için kontrol merkezi tek sekmede toplanmalı (Session Control).
- Oyuncu arayüzü sade tutulmalı, karmaşık yönetim fonksiyonları gizlenmeli.
- Kritik canlı aksiyonlarda (push, session close, force sync) onay diyalogları kullanılmalı.
- Ağ sorunlarında kullanıcıya net ve eyleme dönük geri bildirim verilmeli.

---

## 14. Veri Modeli Önerileri

### 14.1 Session
- `session_id`
- `owner_id`
- `status`
- `participants`
- `created_at`, `updated_at`

### 14.2 Shared Node
- `node_id`
- `origin` (`dm` | `player`)
- `visibility` (`private_dm` | `shared_full` | `shared_restricted`)
- `content_ref`
- `position`

### 14.3 Asset Record
- `asset_id`
- `source_path`
- `hash`
- `size`
- `media_type`
- `scope`
- `expires_at`

---

## 15. Geliştirme Organizasyonu ve Sprint Planı

### Sprint 1
- Faz 0 UI konsolidasyonu
- Event Manager iskeleti

### Sprint 2
- Embedded viewer
- Socket smoke test altyapısı

### Sprint 3
- Auth/session gateway
- Join key ve katılım akışı

### Sprint 4
- Asset proxy + basic map/projection sync
- Güvenlik testleri

### Sprint 5
- Mind map push/sync
- Reconnect ve resync stratejisi

### Sprint 6
- Audio sync + crossfade
- Performans iyileştirme + E2E stabilizasyon

### Sprint 7
- Event log + dice roller
- Restricted card database

### Sprint 8
- Cloud backup/restore
- Self-hosted production deployment ve release hazırlığı

---

## 16. Risk Kaydı ve Azaltım Planı

### Risk 1: Faz 0 teknik borçla geçilmesi
- Etki: Tüm online özelliklerde geri dönüp UI düzeltme maliyeti
- Azaltım: Faz 0 çıkış kriteri sağlanmadan Faz 1'e geçilmemesi

### Risk 2: Yetki modeli eksikliği
- Etki: Veri sızıntısı, güven kaybı
- Azaltım: Scope tabanlı auth guard + audit log zorunluluğu

### Risk 3: Ses senkronunda gecikme/sapma
- Etki: Kullanıcı deneyiminde bozulma
- Azaltım: Time-based scheduling + jitter tolerance

### Risk 4: Network kopmalarında state drift
- Etki: Oyuncu ekranlarında tutarsızlık
- Azaltım: seq + resync + full snapshot fallback

---

## 17. Teknik Borç ve Refactor Öncelikleri

- UI bileşenlerinde ortak stil sistemi ve reusable widget seti
- Session/mind map/map/audio state yönetimi için merkezi state katmanı
- Serialization/deserialization kodlarında ortak şema doğrulama
- Player mode için kod izolasyonu ve modüler paketleme

---

## 18. Done Kriterleri (Definition of Done)

Bir iş "bitti" sayılmadan önce:
- Kod tamam ve testleri yeşil.
- Yetki ve güvenlik kontrolleri doğrulandı.
- Log ve metric entegrasyonu yapıldı.
- Kullanıcı akışı QA tarafından doğrulandı.
- Dokümantasyon güncellendi.

---

## 19. İlk 30 Gün Uygulama Planı

### Hafta 1
- Faz 0 kapsamını kesinleştir
- Teknik task breakdown ve sahiplikler

### Hafta 2
- Event Manager + socket test harness
- Single-window ve GM control panel prototipi

### Hafta 3
- Embedded viewer entegrasyonu
- UI standardizasyonu ve regression test

### Hafta 4
- Gateway iskeleti (auth/session)
- DM create/join akışının ilk E2E demosu

---

## 20. Sonuç ve Karar Önerisi

Online dönüşüm teknik olarak uygulanabilir ve ürün açısından yüksek etkili bir yatırım.
Başarı için kritik nokta, faz geçiş disiplinidir:
- Faz 0 tamamlanmadan online çekirdek başlatılmamalı.
- Faz 1'de sade ama güvenli bir MVP çıkarılmalı.
- Faz 2 ve sonrası feature flag ve metrik odaklı kademeli yayına alınmalı.

Bu doküman, ekiplerin aynı teknik dilde hizalanması ve teslimlerin ölçülebilir hale gelmesi için referans plan olarak kullanılmalıdır.
