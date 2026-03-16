# Dungeon Master Tool
## Sprint Bazlı Detaylı Geliştirme Raporları

Bu doküman, online dönüşüm programı için her sprintte yapılacak geliştirme işlerini kapsamlı biçimde tanımlar.

- Program başlangıcı: 9 Mart 2026
- Sprint süresi: 2 hafta
- Toplam sprint: 8
- Odak alanı: Online MVP çekirdeği, etkileşimli senkronizasyon, gelişmiş oyun mekanikleri, self-hosted server hazırlığı

---

## 1. Program Çerçevesi

### 1.1 Ana Hedef
Offline-first masaüstü uygulamayı güvenli, düşük gecikmeli, ölçülebilir bir online platforma dönüştürmek.

### 1.2 Başarı Metrikleri
- P95 event gecikmesi < 120ms
- 5MB map ilk yükleme < 3 saniye
- Reconnect sonrası state toparlanma < 5 saniye
- Yetkisiz içerik erişimi: 0 kritik ihlal

### 1.3 Takım Rolleri
- Teknik Lider: Mimari, sözleşmeler, kod kalite kapısı
- Backend Geliştirici: Auth, session, gateway, event route
- Desktop Geliştirici: PyQt6 DM/Player entegrasyonu
- QA: Fonksiyonel + non-functional test senaryoları
- DevOps: Ortam, gözlemlenebilirlik, release güvenliği

### 1.4 Bağımlılıklar
- Faz 0 UI işleri tamamlanmadan online özellikler açılmaz.
- Event sözleşmesi sabitlenmeden çoklu istemci senkronizasyonu açılmaz.
- Güvenlik kontrolleri tamamlanmadan internete açık kullanım başlatılmaz.

### 1.5 Kullanılacak Teknoloji Stackleri

#### Desktop Uygulama (DM + Player)
- Python 3.12
- PyQt6
- `python-socketio` (client)
- Pydantic v2 (event payload doğrulama)
- `pytest` + `pytest-qt`

#### Backend ve Real-time Katmanı
- Python 3.12
- FastAPI
- `python-socketio` (ASGI)
- Uvicorn + Gunicorn
- Redis 7 (presence, session state, pub/sub, rate limit)
- PostgreSQL 16 (kalıcı kullanıcı/oturum metadata ve audit kayıtları)

#### Varlık ve Depolama
- MinIO (S3 uyumlu, self-hosted object storage)
- İstemci tarafında yerel cache (map/audio/doc)

#### Gözlemlenebilirlik ve Operasyon
- Prometheus + Grafana (metrik)
- Loki + Promtail (log toplama)
- GitHub Actions (CI) + SSH tabanlı deploy adımları

### 1.6 Kendi Sunucumuz (Self-Hosted) Dağıtım Modeli
- Hedef ortam: Ubuntu Server 24.04 LTS (VPS veya dedicated server)
- Konteyner çalıştırma: Docker + Docker Compose
- Reverse proxy ve TLS: Nginx + Let's Encrypt (Certbot)
- DNS yapısı: `api.<alanadi>`, `ws.<alanadi>`, `assets.<alanadi>`
- Ortamlar: `staging` ve `production` için ayrı compose profilleri
- Yedekleme: PostgreSQL dump + MinIO bucket snapshot (günlük)
- Güvenlik: UFW, fail2ban, yalnızca 80/443 ve kısıtlı SSH erişimi

---

## 2. Sprint 1 Raporu

### 2.1 Dönem
- 9 Mart 2026 - 20 Mart 2026

### 2.2 Sprint Hedefi
Faz 0'ın omurgasını kurmak: UI konsolidasyonu ve istemci tarafı event katmanının başlatılması.

### 2.3 Kapsam
- Single-window player view tasarımının uygulanması
- GM Player Screen Control panel iskeleti
- UI standardizasyonu için ortak stil seti
- Event Manager sınıfının temel API'si

### 2.4 Teknik Geliştirme İşleri
- UI bileşen envanteri çıkarılır ve tutarsızlıklar etiketlenir.
- Buton, panel, spacing ve typography için ortak stil token'ları tanımlanır.
- `Player View` ve `Battle Map` tek pencere altında tab yapısıyla birleştirilir.
- `Session Control` paneli için placeholder bileşenler oluşturulur.
- `EventManager` için aşağıdaki arayüz hazırlanır:
  - `connect()`
  - `emit(event, payload)`
  - `subscribe(event, handler)`
  - `disconnect()`

### 2.5 Çıktılar
- UI refactor PR'ı
- Event manager skeleton PR'ı
- Teknik tasarım notu: "Desktop Event Lifecycle v1"

### 2.6 Test ve Doğrulama
- UI regression test listesi hazırlanır.
- EventManager için unit test: subscribe/emit lifecycle
- Manuel smoke: tek istemci üzerinde açılış, sekme geçişleri, panel render

### 2.7 Riskler ve Azaltım
- Risk: UI refactor sırasında mevcut ekran akışlarının bozulması.
- Azaltım: Görsel karşılaştırma checklist + incremental merge.

### 2.8 Done Kriterleri
- Single-window akışı stabil çalışır.
- Session control paneli görünür ve temel aksiyonları tetikleyebilir.
- EventManager unit testleri yeşildir.

---

## 3. Sprint 2 Raporu

### 3.1 Dönem
- 23 Mart 2026 - 3 Nisan 2026

### 3.2 Sprint Hedefi
Embedded viewer ve socket smoke altyapısını tamamlayarak Faz 0 çıkışına yaklaşmak.

### 3.3 Kapsam
- Embedded PDF/Image viewer entegrasyonu
- Socket.io istemci bağlantısı
- Event schema v1 draft
- Hata/bağlantı durum göstergeleri

### 3.4 Teknik Geliştirme İşleri
- Viewer bileşeni local dosya ve remote URL'den içerik açacak şekilde standartlaştırılır.
- `python-socketio` istemcisi EventManager ile entegre edilir.
- WS envelope taslağı hazırlanır:
  - `event_id`
  - `session_id`
  - `schema_version`
  - `ts`
  - `payload`
- UI'da bağlantı durumu rozetleri eklenir: `Disconnected`, `Connecting`, `Connected`, `Error`.

### 3.5 Çıktılar
- Viewer modülü PR'ı
- Socket client integration PR'ı
- `event_schema_v1.md` teknik dokümanı

### 3.6 Test ve Doğrulama
- PDF ve image render testleri
- Socket connect/disconnect retry testleri
- Bozuk payload durumunda güvenli hata yönetimi testi

### 3.7 Riskler ve Azaltım
- Risk: Viewer performans sorunları (büyük dosya açılışı).
- Azaltım: Lazy load ve önbellekli thumbnail stratejisi.

### 3.8 Done Kriterleri
- Viewer Session/Docs akışında kullanılabilir.
- Socket istemcisi kontrollü şekilde bağlanıp ayrılabilir.
- Event schema v1 ekip tarafından onaylanır.

---

## 4. Sprint 3 Raporu

### 4.1 Dönem
- 6 Nisan 2026 - 17 Nisan 2026

### 4.2 Sprint Hedefi
Hub MVP'nin ilk backend çekirdeğini kurmak: auth + session create/join.

### 4.3 Kapsam
- FastAPI gateway iskeleti
- JWT tabanlı login/me uçları
- Session oluşturma ve katılma
- 6 karakter join key mekanizması

### 4.4 Teknik Geliştirme İşleri
- FastAPI servisinde auth middleware ve token doğrulama katmanı eklenir.
- Endpointler:
  - `POST /auth/login`
  - `GET /auth/me`
  - `POST /sessions`
  - `POST /sessions/{session_id}/join`
- Session store için Redis şeması hazırlanır.
- Join key üretimi için çakışma korumalı algoritma uygulanır.

### 4.5 Çıktılar
- Gateway repo modülü
- Auth/session API PR'ı
- OpenAPI şeması

### 4.6 Test ve Doğrulama
- Auth success/fail integration testleri
- Session create/join yetki testleri
- Join key collision test senaryoları

### 4.7 Riskler ve Azaltım
- Risk: Join key brute-force saldırıları.
- Azaltım: Rate limiting + failed attempt throttling + kısa geçerlilik.

### 4.8 Done Kriterleri
- DM login olur, session oluşturur.
- Oyuncu geçerli anahtarla katılır, geçersiz anahtar reddedilir.
- API integration testleri yeşil.

---

## 5. Sprint 4 Raporu

### 5.1 Dönem
- 20 Nisan 2026 - 1 Mayıs 2026

### 5.2 Sprint Hedefi
Hub MVP'yi işlevsel hale getirmek: asset proxy + basic map/projection sync.

### 5.3 Kapsam
- Geçici URL ile asset erişimi
- Map/projection ilk senkronizasyonu
- Session state broadcast
- Yetkisiz erişim korumaları

### 5.4 Teknik Geliştirme İşleri
- Asset erişimi için imzalı URL üretimi (`TTL`, `scope`, `session`).
- `SESSION_STATE` yayın mekanizması hazırlanır.
- DM tarafında seçilen projection içeriği oyuncuya aktarılır.
- Map koordinat ve grid state temel senkronizasyonu uygulanır.

### 5.5 Çıktılar
- Asset proxy PR'ı
- Map/projection sync PR'ı
- Security checklist v1

### 5.6 Test ve Doğrulama
- Yetkisiz asset URL testi
- Session dışı istemciye veri sızmama testi
- 5MB harita yükleme benchmark testi

### 5.7 Riskler ve Azaltım
- Risk: Asset URL paylaşımı ile yetkisiz erişim.
- Azaltım: Kısa ömürlü ve oturuma bağlı imzalı URL; tek kullanımlık token opsiyonu.

### 5.8 Done Kriterleri
- DM projection içerikleri oyuncuda açılır.
- Map state tek oturumdaki tüm oyuncularda tutarlı görünür.
- Güvenlik testlerinde kritik bulgu kalmaz.

---

## 6. Sprint 5 Raporu

### 6.1 Dönem
- 4 Mayıs 2026 - 15 Mayıs 2026

### 6.2 Sprint Hedefi
Mind map paylaşımı ve reconnect/resync dayanıklılığını sağlamak.

### 6.3 Kapsam
- Mind map push (node + connection)
- Player workspace davranışları
- Reconnect stratejisi
- Kısmi resync ve tam snapshot fallback

### 6.4 Teknik Geliştirme İşleri
- `MINDMAP_PUSH` ve `MINDMAP_LINK_SYNC` olayları uygulanır.
- Node metadata alanları netleşir: `origin`, `visibility`, `content_ref`.
- Reconnect olduğunda son `seq` üzerinden delta talebi yapılır.
- Delta başarısız olursa full snapshot uygulanır.

### 6.5 Çıktılar
- Mind map sync PR'ı
- Reconnect/resync PR'ı
- "State Recovery Strategy" teknik notu

### 6.6 Test ve Doğrulama
- Ağ kesintisi simülasyonu ile reconnect testleri
- Aynı node üzerinde eşzamanlı güncelleme çatışma testleri
- Push edilen kısıtlı içerik doğrulama testleri

### 6.7 Riskler ve Azaltım
- Risk: State drift (istemcilerde farklı durum).
- Azaltım: seq kontrolü, idempotent apply ve snapshot fallback.

### 6.8 Done Kriterleri
- DM push ettiği node'lar oyuncu alanında doğru görünür.
- Reconnect sonrası istemci state'i tutarlı hale gelir.
- Drift oranı kabul edilebilir sınır altında kalır.

---

## 7. Sprint 6 Raporu

### 7.1 Dönem
- 18 Mayıs 2026 - 29 Mayıs 2026

### 7.2 Sprint Hedefi
Audio senkronizasyonunu üretim kalitesine getirmek ve performans hedeflerini doğrulamak.

### 7.3 Kapsam
- `AUDIO_STATE` ve crossfade olayları
- Cache miss durumunda otomatik asset indirme
- Master volume üst sınır kuralı
- Gecikme ve jitter toleransı

### 7.4 Teknik Geliştirme İşleri
- Audio event payload formatı kesinleştirilir.
- Client tarafında `start_at` zamanı ile senkron başlatma uygulanır.
- Oyuncu cache klasörü versiyonlu yönetilir.
- Master volume ile player local volume çarpım kuralı uygulanır.

### 7.5 Çıktılar
- Audio sync PR'ı
- Performance benchmark raporu
- "Audio Timing and Drift" teknik notu

### 7.6 Test ve Doğrulama
- Çoklu istemci audio simultane başlatma testi
- Crossfade kesintisiz geçiş testi
- Ağ gecikmesi altında sapma ölçümü

### 7.7 Riskler ve Azaltım
- Risk: Cihaz farklarına bağlı senkron sapması.
- Azaltım: Server-time referansı, tolerans penceresi ve düzenli re-align.

### 7.8 Done Kriterleri
- Audio state değişimleri katılımcılarda tutarlı uygulanır.
- P95 event latency < 120ms hedefi sağlanır veya iyileştirme backlog'u açılır.

---

## 8. Sprint 7 Raporu

### 8.1 Dönem
- 1 Haziran 2026 - 12 Haziran 2026

### 8.2 Sprint Hedefi
Gelişmiş oyun mekanikleri için ortak log tabanını kurmak.

### 8.3 Kapsam
- Automated Event Log
- Shared Dice Roller
- Restricted Card Database erişim kuralları

### 8.4 Teknik Geliştirme İşleri
- Event log append-only veri modeli uygulanır.
- Zar atma akışı server-authoritative hale getirilir.
- Zar sonuçları logda immutably saklanır.
- Card database için `shared_full` ve `shared_restricted` görünüm dönüştürücüleri eklenir.

### 8.5 Çıktılar
- Event log PR'ı
- Dice roller PR'ı
- Restricted card view PR'ı

### 8.6 Test ve Doğrulama
- Zar sonucu tutarlılık testi (aynı olay tüm istemcide aynı sonuç)
- Event log sıralama testi
- Restriction bypass negatif testleri

### 8.7 Riskler ve Azaltım
- Risk: Oyuncu tarafında gizli alanların istemeden görünmesi.
- Azaltım: Server-side redaction ve contract test.

### 8.8 Done Kriterleri
- Ortak event log DM/oyuncu ekranlarında tutarlı.
- Dice roller güvenilir ve denetlenebilir.
- Kısıtlı kart görünümü güvenli çalışır.

---

## 9. Sprint 8 Raporu

### 9.1 Dönem
- 15 Haziran 2026 - 26 Haziran 2026

### 9.2 Sprint Hedefi
Self-hosted production ortamını tamamlayarak kontrollü beta dağıtıma geçmek.

### 9.3 Kapsam
- Self-hosted production server kurulumu
- World backup/restore
- Gözlemlenebilirlik (log/metric/alert)
- Beta release gate kontrolleri

### 9.4 Teknik Geliştirme İşleri
- Kendi sunucuda Docker Compose stack'i devreye alınır.
- Nginx reverse proxy, TLS sertifikaları ve domain yönlendirmeleri tamamlanır.
- World backup için bütünlük doğrulamalı paketleme uygulanır.
- Metric ve alarm seti devreye alınır:
  - `event_delivery_latency_ms`
  - `reconnect_failure_rate`
  - `asset_download_error_rate`
- Beta release checklist hazırlanır.

### 9.5 Çıktılar
- Self-hosted deployment PR'ı
- Backup/restore PR'ı
- Monitoring dashboard ve alert kuralları
- Beta release notları

### 9.6 Test ve Doğrulama
- İnternetten katılım uçtan uca testi
- Backup al/geri yükle bütünlük testi
- 3 saatlik soak test

### 9.7 Riskler ve Azaltım
- Risk: Tek sunucuda darboğaz veya tek nokta arızası.
- Azaltım: Kaynak limitleri, düzenli backup, hızlı restore runbook ve yatay ölçek planı.

### 9.8 Done Kriterleri
- Kendi sunucumuz üzerinden oturum dış dünyadan erişilebilir.
- Backup/restore güvenle tamamlanır.
- Beta için kalite kapıları sağlanır.

---

## 10. Sprintler Arası Ortak Kalite Kapıları

- Güvenlik: Kritik ve yüksek seviye açık sayısı 0
- Test: Sprint kapsamındaki integration test oranı hedefini sağlama
- Performans: Sprint sonu benchmark raporu paylaşımı
- Dokümantasyon: API/event sözleşmesi güncellemelerinin yayınlanması
- Operasyon: Error budget ve incident hazırlığı

---

## 11. Raporlama Şablonu (Her Sprint Sonu)

Aşağıdaki şablon her sprint kapanışında doldurulmalıdır.

### 11.1 Sprint Özeti
- Planlanan iş puanı
- Tamamlanan iş puanı
- Sapma oranı

### 11.2 Teslimler
- Tamamlanan user story listesi
- Kapanan teknik borç kalemleri

### 11.3 Kalite
- Test sonuç özeti
- Bulunan/kapatılan hata sayısı
- Performans ölçümleri

### 11.4 Risk ve Aksiyonlar
- Devam eden riskler
- Bir sonraki sprint için azaltım aksiyonları

### 11.5 Kararlar
- Mimari karar kayıtları (ADR)
- Kapsam değişiklikleri ve gerekçeleri

---

## 12. Sonuç

Bu sprint rapor seti, online dönüşüm programını uygulanabilir ve denetlenebilir hale getirmek için hazırlanmıştır.

Ana prensipler:
- Önce temel (Faz 0/Faz 1), sonra hız.
- Ölçülemeyen özellik üretime alınmaz.
- Güvenlik ve yetki modeli, tüm sprintlerde kalite kapısıdır.

Bu plana bağlı kalınması, ürünün hem teknik doğruluk hem de kullanıcı deneyimi açısından güvenli biçimde online'a taşınmasını sağlar.
