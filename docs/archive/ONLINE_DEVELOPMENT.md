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
- **Oyuncu Paneli (QT):** Aynı uygulama üzerinde oyuncu ekranı. DM ekranı ile farklar açıklanmıştır.
- **Giriş Ekranı (QT):** Artık kullanıcılar uygulamaya giriş yaparken online özellikleri aktif etmek için giriş yapabilecek. Giriş yapıldığında, abonelik durumlarına bağlı olarak DM oalrak oluşturdukları dünyaları ya da oyuncu olarak katıldıkları dünyaları, veya ikisini beraber görebilecek.

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

## 🔌 Haberleşme ve Senkronizasyon Detayları

### WebSocket Olay Yapıları (JSON)

Real-time iletişim için kullanılacak temel veri yapıları:

#### 1. `SESSION_STATE` (DM -> Server -> Oyuncu)
Oturumun genel durumunu ve bağlı oyuncuları tanımlar.
```json
{
  "event": "SESSION_STATE",
  "data": {
    "session_id": "XY1234",
    "dm_status": "online",
    "active_players": ["Eren", "Player2"],
    "current_view": "BATTLE_MAP" 
  }
}
```

#### 2. `MINDMAP_SYNC` (DM -> Oyuncu)
DM'in paylaştığı mind map düğümlerini senkronize eder.
```json
{
  "event": "MINDMAP_SYNC",
  "data": {
    "node_id": "uuid-1234",
    "type": "note|entity|image",
    "content": "Not içeriği veya Entity ID",
    "position": {"x": 100, "y": 200},
    "connections": ["uuid-5678"]
  }
}
```

#### 3. `AUDIO_STATE` (DM -> Oyuncu)
Soundpad durumunu tüm katılımcılarda eşitler.
```json
{
  "event": "AUDIO_STATE",
  "data": {
    "theme_id": "dark_forest",
    "intensity": 2,
    "master_volume": 0.7,
    "ambience_slots": [
      {"id": "birds_id", "volume": 0.5},
      {"id": null, "volume": 0}
    ]
  }
}
```

## 🧠 Mind Map Senkronizasyon Mantığı

DM'in `mind_map_tab.py` üzerindeki "Master" görünümü, tüm dünyayı kapsayan geniş bir alandır. Online versiyonda:
- **Paylaşım (Push):** DM, bir düğüme sağ tıklayıp "Oyuncularla Paylaş" dediğinde, o düğümün tüm içeriği (`extra_data`, `content`, `position`) WebSocket üzerinden oyunculara iletilir.
- **Player Workspace:** Her oyuncunun kendi "Handout" mind map alanı olur. DM'den gelen öğeler burada belirir.
- **Interaktivite:** Oyuncular kendilerine gelen öğeleri sürükleyebilir, birbirine bağlayabilir ancak DM'in orjinal düğümlerini silemezler.

## 🎵 Soundpad (Ses) Senkronizasyonu

Ses senkronizasyonu `MusicBrain` sınıfı üzerinden yönetilir:
- **DM Kontrolü:** DM bir müzik veya ambiyans başlattığında, sadece dosya ID'si ve çalma komutu gönderilir. Dosyalar her oyuncunun yerel `cache` klasöründe yoksa arka planda server üzerinden indirilir.
- **Anlık Değişimler:** Intensity slider'ı kaydırıldığında, tüm oyuncularda `Crossfade` işlemi aynı anda tetiklenir.
- **Master Volume:** DM, tüm oyuncuların genel ses seviyesini bir üst limit olarak belirleyebilir (örneğin DM %50 yaparsa, oyuncunun kendi ayarı %100 olsa bile efektif ses %50 olur).

## 💾 Veri ve Varlık (Asset) Yönetimi

- **Proxy Server:** DM'in makinesindeki resimler (ör. `worlds/myworld/images/map.jpg`), FastAPI server üzerinden `http://server-ip/assets/uuid-map-name.jpg` formatında geçici olarak sunulur.
- **Cache Mechanism:** Oyuncular bir haritayı veya sesi bir kez indirdiğinde yerel depolamaya (IndexedDB veya LocalStorage/File) kaydedilir.
- **World Backup:** DM, tüm `data.dat` ve assets klasörünü tek tıkla server'a yedekleyebilir veya başka bir makinedeki online oturuma aktarabilir.

## 🛠️ Teknoloji Yığını (Detaylı)

- **DM App**: PyQt6 + `python-socketio` (Client).
- **Backend**: FastAPI + `python-socketio` (Server) + Redis (Session storage).
- **QT Player**: 
    - **QT:** Mevcut uygulamanın kısıtlanmış "Oyuncu Modu" (Standalone Player Client).
- **Deployment**: `ngrok` entegrasyonu ile "Tek Tıkla Sunucu Başlat" özelliği.