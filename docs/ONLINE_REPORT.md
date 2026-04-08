# 🐉 Dungeon Master Tool (DMT) - Mimari ve Stratejik Vizyon Raporu

## 1. Proje Özeti ve Vizyon
**Dungeon Master Tool (DMT)**, masaüstü rol yapma oyunları (TTRPG) için geliştirilmiş, **Offline-First (Öncelikle Çevrimdışı)** prensibine dayalı, açık kaynaklı ve düşük maliyetli bir VTT (Virtual Tabletop) ve kampanya yönetim aracıdır. 

DMT'nin temel felsefesi; DM'lerin (Oyun Yöneticilerinin) devasa dünyaları, karmaşık ses ortamlarını ve haritaları internete bağlı olmadan, sıfır gecikme ile kendi cihazlarında yönetebilmesidir. Yeni eklenen **Hibrit Online Katmanı** ise, bu offline gücü bozmadan oyuncuları uzaktan aynı masaya bağlayan ve DM'lerin içeriklerini (dünyalarını) paylaşabilecekleri bir ekosistem sunar.

---

## 2. Temel Özellikler (Offline ve Online)

### 🗡️ Çekirdek (Offline) Özellikler
*   **Gelişmiş Battlemap ve Fog of War:** DM'in oyuncu ekranına (Screen Cast) harita yansıtması ve sis yönetimini yerel cihaz üzerinden gecikmesiz yapması.
*   **Dinamik Ses Motoru (Soundmap):** Ortam seslerini, savaş müziklerini ve anlık efektleri yoğunluk (intensity) seviyeleri ile yöneten yerel ses sistemi.
*   **Entity & Senaryo Yönetimi:** Karakter statları, NPC'ler ve hikaye ağaçlarının yerel veritabanında tutulması.

### 🌐 Hibrit Online Özellikler
*   **Uzak Session (Co-op Oyun):** Oyuncuların kendi cihazlarından DM'in haritasına bağlanıp token'larını hareket ettirebilmesi ve zarların anlık senkronize olması.
*   **Topluluk Pazarı (World Market):** DM'lerin oluşturduğu `.dmt` formatındaki dünya, harita ve senaryo paketlerinin diğer kullanıcılarla paylaşıldığı sosyal ağ.
*   **Bulut Senkronizasyonu:** İstenildiğinde yerel oyun verilerinin yedeklenmesi ve başka cihazlara aktarılması.

---

## 3. Teknoloji Yığını (Tech Stack)

Açık kaynaklı bir indie projenin "kendi kendini sürdürebilir" olması için maliyetler minimumda tutulmuş ve teknoloji yığını şu şekilde belirlenmiştir:

| Sistem Alanı | Kullanılan Teknoloji | Görevi ve Nedeni |
| :--- | :--- | :--- |
| **İstemci (Client/UI)** | **Flutter** | Çapraz platform masaüstü (Windows/Mac/Linux) ve mobil arayüzü, online köprü (NetworkBridge). |
| **Oyun ve Kural Motoru** | **Python (Pydantic, EventBus)**| Offline oyun mantığı, zar hesaplamaları, yerel dosya işlemleri. Arayüzden bağımsız çalışır. |
| **Veritabanı ve Auth** | **Supabase (PostgreSQL)** | Kullanıcı yönetimi (Auth), market verileri, mesajlaşma ve Row Level Security (RLS) ile yetkilendirme. |
| **Gerçek Zamanlı İletişim**| **Supabase Broadcast** | Oyun sırasındaki zar, token ve müzik hareketlerinin WebSocket üzerinden anlık iletimi. |
| **Ağır Dosya Depolama** | **Cloudflare R2** | Büyük `.dmt` dünya paketlerinin, haritaların ve müziklerin depolanması (Egress - Veri çıkış ücreti SIFIRDIR). |
| **Güvenlik ve Doğrulama** | **Cloudflare Workers** | R2 indirmelerinin yetki kontrolü ve doğrudan yükleme (Direct Upload) izinlerinin yönetimi. |

---

## 4. Karşılaşılan Sorunlar ve Çözüm Mimarileri

Açık kaynak dünyasında ve "ücretsiz hizmet limitleri" (Free Tier) altında çalışırken karşılaşılan mimari darboğazlar ve DMT'nin bu sorunlara getirdiği inovatif çözümler şunlardır:

### Sorun 1: Açık Kaynak Projede Veri/Dosya Güvenliği
**Durum:** Proje açık kaynak olduğu için, uygulama içine gizlenen şifreler veya gizli HTTP header'ları koddan okunabilir. Kötü niyetli biri premium veya kapalı harita dosyalarının indirme linkini bulup herkesle paylaşabilir.
*   **Çözüm (Worker + JWT Doğrulama):** Cloudflare R2 tamamen dış dünyaya kapatılır. Dosya indirme istekleri bir **Cloudflare Worker**'a yönlendirilir. Flutter istemcisi isteği atarken kullanıcının sisteme giriş yaptığını kanıtlayan **Supabase JWT (Oturum Token'ı)** gönderir. Worker, bu token'ı doğrular ve kullanıcının veritabanında (Supabase RLS) bu dosyaya erişim izni varsa R2'dan dosyayı stream eder.
*   **Avantaj:** Kod açık olsa da güvenlik matematiğe (JWT) dayanır. Sadece izinli ve sisteme giriş yapmış üyeler dosya indirebilir. Ek olarak Worker üzerine "Rate Limiting" (saatte max 20 harita indirme) konularak bot saldırıları engellenir.

### Sorun 2: Supabase Broadcast ile Veri Kaybı (State Recovery)
**Durum:** Supabase Broadcast veritabanına yazmadan çalıştığı (fire-and-forget) için hızlıdır ve maliyetsizdir. Ancak interneti kopup geri gelen bir oyuncu, koptuğu andaki harita hareketlerini (örneğin hareket eden bir NPC'yi) kaçırır.
*   **Çözüm (DM as Source of Truth):** DM'in (Sunucunun) yerel bilgisayarı sistemin "Ana Gerçeklik Kaynağı"dır. Bağlantısı kopan oyuncu yeniden bağlandığında, önce DM'in cihazına özel bir `sync_request` fırlatır. DM'in Python motoru o anki Pydantic modellerinin tek bir JSON fotoğrafını (Snapshot) oyuncuya yollar. Oyuncu haritayı güncelledikten sonra anlık Broadcast akışını dinlemeye devam eder.

### Sorun 3: Ses Dosyalarının Online Senkronizasyonu (Bant Genişliği Sorunu)
**Durum:** Yüksek kaliteli savaş müzikleri ve ortam seslerini online olarak oyunculara stream (yayın) etmek devasa bir ağ yükü yaratır ve senkronizasyonu (gecikmelerden dolayı) bozar.
*   **Çözüm (Trigger/Tetikleme Mantığı):** Oyuna girerken `.dmt` dosyası ile tüm müzik dosyaları zaten oyuncunun bilgisayarına önbelleklenmiş (cache) durumdadır. DM müzik başlattığında veya şiddetini artırdığında giden tek şey bir metin JSON'dır: `{"event": "audio", "track_id": "rain", "intensity": 0.8}`. Her oyuncunun yerel cihazı bu JSON'ı okuyarak kendi bilgisayarındaki müziği çalar. Gecikme sıfırdır, veri tüketimi baytlar düzeyindedir.

### Sorun 4: Supabase Ücretsiz Eşzamanlı (Concurrent) Limitleri
**Durum:** Supabase Free Tier, maksimum 200 eşzamanlı WebSocket bağlantısına izin verir. Sosyal medya ve market özelliklerini gezen her kullanıcı bu limiti işgal ederse sistem anında tıkanır.
*   **Çözüm (Bölünmüş Ağ Mimarisi):** Uygulamanın topluluk/market kısımları tamamen standart `HTTP REST` (statik veri çekme) modeliyle çalışır ve limit tüketmez. Supabase Realtime (WebSocket) kanalı **yalnızca** bir oyun masasına (Session) fiziksel olarak oturulduğunda açılır, oyuncu masadan kalktığında kanal anında kapatılır. Böylece ücretsiz sürümde bile aynı anda 40-50 oyun masası (party) eşzamanlı yönetilebilir.

### Sorun 5: Python Engine ve Online Realtime Uyuşmazlığı
**Durum:** Python ekosistemindeki Supabase Realtime SDK'sı, Flutter (Dart) kadar gelişmiş ve stabil değildir. Python'u doğrudan Supabase ile konuşturmak teknik risk taşır.
*   **Çözüm (Flutter as Network Bridge):** Python asla dış internetle doğrudan konuşmaz. Tamamen offline, saf ve hızlı bir kurallar motoru olarak yerelde çalışır. Python bir zarı attığında, sonucu Flutter uygulamasına yerel IPC (Inter-Process Communication) ile iletir. Supabase ile online iletişim kurma, verileri Broadcast ile fırlatma ve gelen veriyi dinleme görevi tamamen **Flutter'ın (Supabase_Flutter SDK)** omuzlarındadır.

---

## 5. Sonuç

DMT'nin bu yeni "Hibrit Online" mimarisi; projenin bağımsız (indie) kalmasını sağlayan **sıfır sunucu maliyeti**, açık kaynak felsefesine uygun **davranışsal güvenlik kalkanları** ve offline performansından hiçbir şey kaybettirmeyen **akıllı senkronizasyon yetenekleriyle** piyasadaki dev rakiplerine (Roll20, Foundry) modern, pratik ve performanslı bir alternatif sunmaktadır.