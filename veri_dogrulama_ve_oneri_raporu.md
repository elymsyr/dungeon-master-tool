# Open5e Veri Doğrulama ve Anlamsal Mükerrerlik Analiz Raporu & Çözüm Stratejisi

## 1. Yönetici Özeti & Mevcut Durum

Mevcut projede, farklı kaynaklardan (PDF, taranmış metinler, ham JSON kaynakları) dönüştürülmüş ve standartlaştırılmış **21 adet paketlenmiş JSON dosyası** bulunmaktadır. Toplam veri hacmi şu şekildedir:

| Metrik | Değer |
| :--- | :--- |
| **Toplam Dosya Sayısı** | 21 Dosya |
| **Toplam Kelime Sayısı** | ~2.597.590 Kelime |
| **Toplam Karakter Sayısı** | ~11.928.696 Harf |
| **Tahmini Token Hacmi** | **~4.045.251 Token** |

Bu büyüklükteki bir TTRPG (özellikle D&D 5e / A5E kural seti) veritabanında; canavar stat blokları, büyüler, yetenekler, eşyalar ve mekanik açıklamalar yer almaktadır.

---

## 2. Karşılaşılan Temel Problemler

### 2.1. İnsan/Manuel Doğrulamanın İmkânsızlığı (Ölçek Problemi)
- **4 milyon token**, yaklaşık **8.000 sayfalık** standart bir kitap külliyatına eşdeğerdir.
- Bir uzmanın veya editörün bu veriyi satır satır okuyup kaynak PDF/JSON ile kıyaslaması aylar sürer ve insan dikkat dağınıklığı nedeniyle hata kaçırma riski çok yüksektir.

### 2.2. Sohbet Tabanlı (Chat-UI) Yapay Zeka Yaklaşımının Yetersizliği
- Verileri ChatGPT/Claude arayüzüne elle kopyala-yapıştır yaparak doğrulatmak şu kısıtlara takılır:
  - **Bağlam Penceresi ve Maliyet:** 4M token'ı parça parça sohbet penceresine yüklemek günlerce sürer.
  - **Bağlam Kaybı (Lost in the Middle):** Büyük metin blokları modele verildiğinde aradaki küçük sayısal ve mekanik hatalar gözden kaçar.
  - **Süreklilik/Format Tutarsızlığı:** Modelin serbest metin yanıtları standardize edilemez ve tekrar JSON'a geri aktarılamaz.

### 2.3. Doğrulama Katmanlarının Birbirine Karışması
Veri aktarımında 3 farklı hata türü vardır ve hepsini aynı yöntemle çözmeye çalışmak verimsizdir:
1. **Şema / Sentaks Hataları:** Eksik JSON anahtarı, sayı yerine string yazılması, eksik dizi (array) yapısı. *(LLM gerektirmez)*
2. **Kural ve Mekanik Uyumsuzluklar:** D&D 5e kurallarına göre `CR` (Challenge Rating) ile `Proficiency Bonus` veya `HP` uyuşmazlığı, büyü bileşenlerinin eksik aktarılması.
3. **Anlamsal Mükerrerlik (Semantic Duplication):** Aynı yaratığın veya büyünün farklı kaynaklarda (`tob`, `tob-2023`, `vom`, `a5e`) birebir aynı kelimelerle olmasa bile aynı mekanik anlam ve etkiyle birden fazla dosyada yer alması.

### 2.4. $O(N^2)$ Karşılaştırma Karmaşıklığı (Duplicate Arama Tuzağı)
- Veri tabanında on binlerce girdi varsa, her girdiyi diğer tüm girdilerle LLM'e okutarak "Bu ikisi aynı mı?" diye sormak milyonlarca API çağrısı gerektirir ve astronomik bir API faturası çıkarır.

---

## 3. Stratejik Tavsiyeler ve Önerilen Yol Haritası

Problemi sıfır insan eforuyla (veya sadece kritik istisnalarda insan müdahalesiyle) çözmek için **3 Aşamalı Kademeli Filtreleme (Tiered Validation Pipeline)** mimarisi önerilmektedir:

```
[4M Token Ham JSON Verisi]
             │
             ▼
┌─────────────────────────────────────────┐
│ AŞAMA 1: Deterministik Kural & Şema     │ ──► Hatalı JSON/Format Raporu
│ (Python / Pydantic / Regex) - ÜCRETSİZ  │     (Saniyeler içinde)
└─────────────────────────────────────────┘
             │ (Geçerli Kayıtlar)
             ▼
┌─────────────────────────────────────────┐
│ AŞAMA 2: Vektör Embedding Taraması      │ ──► Mükerrer (Duplicate) Eşleşme Listesi
│ (text-embedding-3-small / Cosine Sim)   │     (Düşük Maliyet: ~$0.08)
└─────────────────────────────────────────┘
             │ (Benzersiz & Şüpheli Kayıtlar)
             ▼
┌─────────────────────────────────────────┐
│ AŞAMA 3: Asenkron Batch LLM Denetimi    │ ──► Anlamsal / Mekanik Hata Raporu
│ (OpenAI Batch API / Yapılandırılmış Çıktı)│     (%50 İndirimli Gece Çalıştırması)
└─────────────────────────────────────────┘
```

---

### Tavsiye 1: Kural Tabanlı Kontrolleri LLM'den Ayırın (Aşama 1)
- **Öneri:** JSON şema uyumluluğu, zorunlu alanlar (ör. `name`, `type`, `hit_points`, `actions`), sayısal aralık kontrolleri Pydantic ile yerel Python ortamında test edilmelidir.
- **Kazanım:** Token harcamadan verinin %20-%30'undaki tipik dönüşüm hataları (NoneType, bozuk karakter, eksik tag) ilk saniyede ayıklanır.

### Tavsiye 2: Anlamsal Duplicate İçin Vektör Benzerliği Kullanın (Aşama 2)
- **Öneri:** Her kaydın metinsel açıklaması (`description`, `traits`, `actions`) embedding modeline sokulmalı ve kosinüs benzerliği matrisi hesaplanmalıdır.
- **Kazanım:**
  - Benzerlik skoru **%95 ve üzeri** olanlar doğrudan kesin duplicate sayılır.
  - Benzerlik skoru **%85 - %95** arasında olanlar (ör. aynı büyünün farklı 5e varyantları) inceleme listesine alınır.
  - 4 milyon token'ın embedding maliyeti 1 doların bile altındadır.

### Tavsiye 3: LLM'i Sadece Asenkron Batch Modunda ve Yapılandırılmış Çıktıyla Kullanın (Aşama 3)
- **Öneri:** Anlamsal denetim gerektiren parçalar için anlık API yerine **Batch API** kullanılmalıdır. Çıktılar serbest metin olarak değil, katı bir JSON şeması (`is_valid`, `conflicts`, `severity`) şeklinde alınmalıdır.
- **Kazanım:**
  - Canlı API rate limitlerine takılmadan arka planda çalışır.
  - %50 maliyet tasarrufu sağlar.
  - Tüm süreç bittiğinde tek bir özet hata raporu (audit log) üretilir.

### Tavsiye 4: Hata Raporlama ve İyileştirme Çevrimi Kurun
- **Öneri:** Süreç hiçbir zaman veriyi körü körüne değiştirmemelidir. Boru hattı çalıştıktan sonra geriye şu 3 raporu bırakmalıdır:
  1. `schema_errors.json`: Şema ve tip uyuşmazlığı olan kayıtlar.
  2. `duplicate_candidates.json`: Çakışan/benzer içerik çiftleri ve benzerlik skorları.
  3. `mechanical_issues.json`: Kural çelişkisi olan açıklamalar.

---

## 4. Sonuç ve Eylem Planı

| Adım | İşlem | Araç / Yöntem | İnsan Eforu |
| :--- | :--- | :--- | :--- |
| **1. Adım** | Tüm JSON dosyalarını Pydantic şemasıyla filtrele | Python Script | Sıfır (Otomatik) |
| **2. Adım** | Açıklamaları vektörleştirip benzerlik matrisi çıkar | Embedding API / FAISS / NumPy | Sıfır (Otomatik) |
| **3. Adım** | Kalan şüpheli verileri Batch LLM işi olarak gönder | Batch API (gpt-4o-mini) | Sıfır (Arka Plan) |
| **4. Adım** | Üretilen hata raporlarına göre istisnaları değerlendir | Log İnceleme | Sadece Hatalı Kayıtlar |
