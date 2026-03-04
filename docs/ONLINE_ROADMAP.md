# 🗺️ Online Version Roadmap

Dungeon Master Tool'un offline-first yapısından tam kapsamlı bir online oyun platformuna geçiş planı.

## 🏁 Faz 0: Temeller & Dahili Temizlik
*Online geçiş öncesi UI standartlarını belirleme ve mimari hazırlık.*
- [ ] **Single-Window Player View**: Battle map ve oyuncu ekranının DM uygulamasında tek pencerede (tab yapısı) birleştirilmesi.
- [ ] **GM Player Screen Control**: DM için oyuncu ekranını yönetebileceği yeni bir kontrol/edit paneli.
- [ ] **Embedded PDF & Image Viewer**: Tüm görsellerin ve dökümanların (spells, items) uygulama içinde standart bir viewer ile açılması.
- [ ] **Socket.io Client Integration**: PyQt6 uygulamasına `python-socketio` entegrasyonu ve Event Manager katmanı.
- [ ] **Standardize UI (#30)**: Buton boyutları ve layout tutarsızlıklarının giderilmesi.

## 🛰️ Faz 1: Bağlantı ve Hub Altyapısı (Hub MVP)
- [ ] **FastAPI Gateway**: JWT tabanlı oturum yönetimi ve 6 haneli Join Key (Session ID) üreticisi.
- [ ] **Login & Session Management**: DM uygulamasına online giriş ekranı ve abonelik kontrolü.
- [ ] **Basic Image/Map Sync**: 
    - DM'den gelen projeksiyonları (Resim/PDF) anlık QT Player'da render edilmesi.
    - Harita koordinatlarının ve grid durumunun senkronize edilmesi.
- [ ] **Asset Proxying (DM Side)**: Yerel resim dosyalarının FastAPI üzerinden geçici URL'lerle (`/assets/uuid`) güvenli servis edilmesi.

## 🎵 Faz 2: İnteraktif Senkronizasyon (Interactive MVP)
- [ ] **Soundpad / MusicBrain Sync**:
    - Müzik değişimi, intensity slider ve master volume senkronizasyonu.
    - Ambience slot'larının (Crossfade dahil) tüm katılımcılarda aynı anda tetiklenmesi.
    - Dosya eksikse server üzerinden otomatik indirme (Cache) mekanizması.
- [ ] **Mind Map Sharing (Push logic)**:
    - DM'in seçtiği düğümlerin (Not, Resim, Entity) "Push" edilerek oyuncu mind map alanına eklenmesi.
    - Düğümler arası bağlantıların (ConnectionLine) senkronize çizimi.
- [ ] **Player Instance Management**: Standalone QT Player uygulamasının "Join Session" modu ile oturuma katılması.

## 🎲 Faz 3: Gelişmiş Oyun Mekanikleri
- [ ] **Automated Event Log**: Savaş günlüğünün her round sonunda (hasar, healing vb.) otomatik olarak tüm oyunculara itilmesi.
- [ ] **Shared Dice Roller**: Log-tabanlı ortak zar atma sistemi ve görsel geçmiş.
- [ ] **Restricted Card Database**: DM kütüphanesindeki seçili kartların oyunculara tam veya kısıtlı yetkiyle açılması.
- [ ] **Player Character Sheets**: Oyuncuların kendi karakter statlarını anlık güncelleyebilmesi ve DM'in bunları onaylaması.

## 🚀 Faz 4: Cloud & Deployment
- [ ] **One-Click Hosting**: `ngrok` veya benzeri bir tünel servisi ile DM'in makinesini anında internete açması.
- [ ] **Cloud Persistence & Backup**: Oyun durumunun (`data.dat`) server üzerinde periyodik yedeklenmesi ve geri yüklenmesi.
- [ ] **Voice Chat Integration**: WebRTC kullanarak uygulama içinden doğrudan sesli görüşme katmanı.
- [ ] **Official Hosted Servers**: Subscription modeli ile DM'lerin donanım bağımsız sunucu kiralayabilmesi.

---

### ✅ Doğrulama ve Performans Hedefleri
- **Gecikme (Latency)**: Zar atma ve ses tetikleme gecikmesi < 120ms olmalı.
- **Varlık Yükleme**: 5MB'lık bir haritanın oyuncu tarafında yüklenme süresi < 3sn (yerel ağ harici) olmalı.
- **Güvenlik**: DM izni (Push) olmayan hiçbir veri oyuncu ram'ine veya diskine düşmemeli.

