# 🌐 Online Version Development Guide

Bu döküman, Dungeon Master Tool'un online (uzaktan erişilebilir) bir sisteme dönüştürülmesi için teknik mimariyi ve geliştirme standartlarını tanımlar.

Bu geliştirmelerden önce [TODO](../TODO.md) içindeki `Immediate Improvements & UI` bölümü tamamlanmalıdır. Aşağıda bu bölümün içerikleri bulunmaktadır:

```markdown
- [ ] **GM Player Screen Control:** Add a specific edit/control view for the GM to manage the Player Window more effectively.
- [ ] **Single Player Screen:** The battle map view and player view will be on a single window.
- [ ] **Auto Event Log:** On the Session View Tab, for each combat round, damages and everything should be printed to the event log automatically.
- [ ] **Free Single Import:** Users should be able to import an entitiy from the import data sources such as spells, items and else, directly into any other entitiy like characters or npcs without needing to import them to the card entity database first.
- [ ] **Embedded PDF Viewer:** Implement a native PDF viewer within the application (Session/Docs tab).
- [ ] **Standardize UI (#30):** Fix inconsistent button sizes and layouts across the application.
- [ ] **Soundpad Transitions (#29):**
    - [ ] Make loop switching smoother to avoid audio glitches.
    - [ ] Add support for "mid-length" transition sounds between loops.
```

## 🏗️ Mimari Yaklaşım: Hibrit Client-Server

Sistemin mevcut masaüstü gücünü koruyarak online hale getirilmesi için **Hibrit** bir model önerilmektedir:
- **DM Uygulaması (Client/Host):** Mevcut PyQt6 uygulaması, server ile haberleşen bir "Master" client rolünü üstlenir.
- **Backend (API Gateway & WebSocket Server):** FastAPI tabanlı, DM ve Oyuncular arasındaki senkronizasyonu yöneten merkezi bir hub.
- **Oyuncu Paneli (Web Client):** Oyuncuların herhangi bir kurulum yapmadan tarayıcı üzerinden katılabileceği React veya Vanilla JS tabanlı bir web arayüzü. Bu kısım sonraki aşamalarda kullanılabilir olabilir ancak şuan için yalnızca planlamadan ibaret.
- **Oyuncu Paneli (QT):** Aynı uygulama üzerinde oyuncu ekranı. DM ekranı ile farklar açıklanmıştır.
- **Giriş Ekranı (QT):** Artık kullanıcılar uygulamaya giriş yaparken online özellikleri aktif etmek için giriş yapabilecek. Giriş yapıldığında, abonelik durumlarına bağlı olarak DM oalrak oluşturdukları dünyaları ya da oyuncu olarak katıldıkları dünyaları, veya ikisini beraber görebilecek.

## 🔌 Haberleşme Protokolü

### WebSocket Olayları (Sync Events)
Real-time iletişim için aşağıdaki olay tipleri kullanılacaktır:

| Olay Adı | Gönderen | Açıklama |
| :--- | :--- | :--- |
| `SESSION_JOIN` | Oyuncu | DM anahtarı ile oturuma katılma. |
| `MAP_UPDATE` | DM | Battle map görüntüsü, grid durumu ve Fog of War verisi. |
| `MINDMAP_SHOW` | DM | Seçilen mind map düğümlerinin oyunculara itilmesi. |
| `CARD_SEND` | DM | Oyuncuya bir NPC, eşya veya bilgi kartı gönderilmesi. |
| `AUDIO_SYNC` | DM | Soundmap çalınan müzik ve yoğunluk (intensity) bilgisi. |
| `DICE_ROLL` | Herkes | Tüm katılımcılara açık zar atma sonuçları. |

## 👥 Rol Bazlı Ekranlar

### 🛡️ DM (Dungeon Master) Ekranı
- **Yeni: Session Control Tab**:
    - Oturumu başlatma/durdurma.
    - Davet kodu (Session Key) oluşturma.
    - Bağlı oyuncuları listeleme ve yönetme.
    - "Push to Player" butonları (Her öğe için).
- **Audio Control**: Soundmap slider'ları tüm oyuncuların ses seviyelerini ve çalınan parçaları senkronize eder.

### ⚔️ Oyuncu (Player) Ekranı
QT uygulamasındaki tüm bölgeler oyuncular için aynı şekilde kalacak. Ancak görüntüleme kısmında farklılık olacak.

- **Database and Characters View ve Sol Card Database Panel:** Bu bölge oyuncular için aynı şekilde kalacak. Oyuncular kendi kartlarını oluşturabilecek. DM tarafından oluşturulmuş kartlar (database öğeleri) için ise, yalnızca DM tarafından izin verilen öğeler görüntülenecebilecek. Database öğeleri yani kartlar, DM tarafından ister tüm içerikleriyle, ister yalnızca kısıtlanmış içerikle paylaşılabilecek.
- **Mind Map Bölgesi**: DM alanında olduğu gibi aynı işlevde, her oyuncu için bir mind map olacak. DM mind map alanı gizli kalırken, DM diğer oyuncuların alanlarını görebilecek ve manipüle edebilecek. DM tarafından, kendi alanındaki öğeler diğer oyuncular ile paylaşılabilecek. Paylaşılan öğeler, oyuncular tarafından sürüklenerek kendi mind map alanlarına alınabilecek.
- **Map View:** DM tarafından eklenmiş harita, DM View orjinal QT App'te olduğu gibi görüntülenebilecek. Oyuncular yalnızca kendi karakterleri için Timeline görüntüleyebilecek. DM tarafından izin verilmiş pinler de aynı şekilde oyuncular tarafından görüntülenebilecek. DM tüm pin ve timelineları gösterip gizleyebilecek. Yani dört seçenek oalcak: hepsini göster, hepsini gizle, oyuncu timeline göster ve izin verilmiş diğer pinleri göster.
- **Session View:** Bu noktada oyuncular DM gibi çok detaylı bir view görmeyecekler. Bunun yerine player Window gibi, yalnızca harite, player screen ve event log görüntüleyebilecek ve zar atabilecekler.
    - **Tam Ekran Battle View**: DM'in yönettiği harita ve Fog of War.
    - **Player Screen**: DM'in projeksiyon olarak gönderdiği resimler/PDF'ler.


## 💾 Veri Senkronizasyonu ve Güvenlik

- **Asset Hosting:** DM'in yerelindeki resimler, FastAPI üzerinden geçici URL'lerle (S3 veya lokal statik sunucu) oyunculara servis edilir.
- **State Persistence:** Oyun durumu `data.dat` dosyasında DM tarafında saklanmaya devam eder, ancak anlık "online session" durumu server üzerinde kısa süreli (Redis veya in-memory) tutulur.
- **Session Keys:** 6 haneli alfa-nümerik rastgele anahtarlar.
- **Online Backup:** DM tarafından database üzerinde world backup ve load yapılabilmelidir.

## 🛠️ Teknoloji Yığını Önerisi

- **DM App**: PyQt6 + `websockets` kütüphanesi.
- **Server**: FastAPI (Python) + Socket.io.
- **Web App**: React.js + TailwindCSS (Modern ve premium görünüm için).
- **Deployment**: Dockerize edilmiş server (AWS/DigitalOcean veya DM'in kendi makinesinde Ngrok/Cloudflare Tunnel ile).
