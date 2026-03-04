# 🗺️ Online Version Roadmap

Dungeon Master Tool'un offline-first yapısından tam kapsamlı bir online oyun platformuna geçiş planı.

## 🏁 Faz 0: Hazırlık & Altyapı
- [ ] **FastAPI Integration**: DM uygulamasının içine gömülü veya harici bir backend server kurulumu.
- [ ] **WebSocket Layer**: DM ve server arasında real-time veri köprüsü.
- [ ] **Session Logic**: DM tarafında oturum açma ve 6 haneli "Join Key" üretimi.

## 🛰️ Faz 1: Görsel Senkronizasyon (Minimum Viable Product)
- [ ] **Player Web Client (v1)**: Oyuncuların sadece tam ekran DM projeksiyonunu gördüğü web arayüzü.
- [ ] **Image Sync**: DM'in projeksiyona attığı resimlerin anlık web'e düşmesi.
- [ ] **Battle Map & Fog of War**: Harita ve sisin oyuncularla senkronize olması.
- [ ] **Session Control Tab**: DM için oyuncu listesi ve bağlantı durumu sekmesi.

## 🎵 Faz 2: Etkileşim & Ses
- [ ] **Soundmap Sync**: DM'in çaldığı müziğin ve intensity slider'larının tüm oyuncularda aynı anda duyulması (Volume DM kontrolünde).
- [ ] **Mind Map Sharing**: DM'in mind map üzerindeki bazı node'ları "Oyuncuya Göster" diyerek paylaşabilmesi.
- [ ] **Card System**: Oyun eşyaları, NPC kartları veya el notlarının oyuncuların "Handout" bölgesine itilmesi.

## 🎲 Faz 3: Gelişmiş Özellikler
- [ ] **Shared Dice Roller**: Ortak bir zar atma alanı ve geçmişi.
- [ ] **Player Inventory & Notes**: Oyuncuların kendi notlarını ve DM'in verdiği kartları yönetebileceği alan.
- [ ] **Multi-Player View**: Her oyuncunun kendi ekranında farklı (DM'in izin verdiği) pencereleri görebilmesi.
- [ ] **Persistent Online Save**: Online oturumların bulut üzerinden kaldığı yerden devam edebilmesi.

## 🚀 Faz 4: Topluluk & Hosting
- [ ] **One-Click Hosting**: Ngrok veya benzeri bir servis entegrasyonu ile DM'in makinesini anında dış dünyaya açması.
- [ ] **Official Hosted Servers**: Subscription modeli ile DM'lerin donanım bağımsız sunucu kiralayabilmesi.
- [ ] **Voice Chat Integration**: WebRTC tabanlı entegre sesli sohbet.
