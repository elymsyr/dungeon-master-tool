Bu harika bir vizyon değişikliği! "Remote Control" (Uzaktan Kumanda) mantığına geçiyoruz. Yani DM, kendi ekranında neyle uğraşıyorsa veya neyi aktif ettiyse, oyuncu ekranı (Projection Window) ona göre şekillenecek. Oyuncu ekranında buton veya kontrol olmayacak, tam bir sinema perdesi gibi çalışacak.

İsteğinize uygun olarak, **Kod Yazmadan**, tamamen mimari ve mantık kurgusu üzerine detaylı geliştirme raporunu aşağıda sunuyorum.

---

# 📜 Geliştirme Raporu: Entegre DM Kontrol Merkezi & Dinamik Projeksiyon

## 1. Yönetici Özeti
Mevcut sistemdeki ayrık "Player Window" kontrolleri ve sol üstteki "Toggle" butonu kaldırılacaktır. Bunun yerine, DM'in ana ekranındaki sekmeler (Tabs) birer **"Yayın Masası"** gibi çalışacaktır. DM, "Battle Map" sekmesine geçtiğinde oyuncular savaşı, "Player View" sekmesine geçtiğinde atmosfer görsellerini görecektir. Tema değişiklikleri (Karanlık/Aydınlık/Özel) anlık olarak iki pencereye de yansıtılacaktır.

## 2. Yeni Arayüz Mimarisi (GM Screen)

GM (Dungeon Master) penceresi artık sadece bir veri giriş ekranı değil, aynı zamanda canlı yayın kontrol panelidir.

### A. Sekme Yapısı (Tabs) ve İşlevleri
Mevcut `QTabWidget` yapısı şu şekilde revize edilecek:

1.  **📝 DM Notes (Gizli Alan):**
    *   *Davranış:* DM bu sekmeye geçtiğinde, Projeksiyon ekranı **değişmez**. En son ne gösteriliyorsa (Harita veya Görsel) oyuncular onu görmeye devam eder. Böylece DM, oyun sırasında gizlice notlarına bakabilir.
    *   *UI:* Mevcut not alma sistemi.

2.  **🖼️ Player View (Yeni Sekme - Görsel Sahne Yönetimi):**
    *   *Davranış:* Bu sekme aktif edildiğinde, Projeksiyon ekranı otomatik olarak **"Scene Mode"**a geçer.
    *   *İçerik:*
        *   **Canvas Editor:** Ortada oyuncuların gördüğü ekranın küçültülmüş bir önizlemesi (Mini-Map gibi).
        *   **Layout Kontrolleri:** Resimlerin konumu, boyutu ve sıralamasını (z-order) buradan sürükle-bırak ile ayarlama.
        *   **Asset Browser:** Yana sürüklemek için hazır NPC/Manzara resimleri listesi.

3.  **⚔️ Battle Map (Mevcut Sekme):**
    *   *Davranış:* Bu sekme aktif edildiğinde, Projeksiyon ekranı otomatik olarak **"Combat Mode"**a geçer.
    *   *İçerik:* Mevcut ızgara, token ve fog of war sistemi.

### B. Projeksiyon Kontrolleri (Global Toolbar)
Artık sol üstteki "Toggle" butonu yerine, pencerenin üst barında veya statüs çubuğunda **"Projection Controls"** grubu olacak:
*   **Canlı (Live) Göstergesi:** Hangi modun yayında olduğunu gösteren ikon (Savaş/Hikaye).
*   **📺 Fullscreen Butonu:** Tıklandığında ikinci ekranı tam ekran yapar (F11 işlevi).
*   **🚫 Blackout (Karart):** Acil durumlar için oyuncu ekranını siyaha düşürür.

---

## 3. Tema Senkronizasyon Sistemi (Theme Engine)

Tema değişikliği artık global bir "Event" (Olay) olarak işlenecektir.

*   **Logic:**
    *   Uygulama genelinde bir `ThemeManager` sınıfı olacak.
    *   DM temasını değiştirdiğinde (örn: "Blood Red" -> "Forest Green"), bu yönetici yeni CSS/QSS kodunu oluşturacak.
    *   **Signal (Sinyal):** `themeChanged(QString styleSheet)` sinyali yayılacak.
*   **Hedef:**
    *   Hem GM penceresi hem de Projeksiyon penceresi bu sinyale bağlı (`connect`) olacak.
    *   Projeksiyon penceresi, temayı alırken sadece renkleri alacak; ancak kendi yapısal özelliklerini (çerçevesiz olması, butonların gizliliği vb.) koruyacak şekilde CSS'i "merge" (birleştirme) işlemine tabi tutacak.

---

## 4. Teknik Mimari ve Sinyal Akışı

Sistemin "Remote Control" gibi çalışması için Qt Sinyal-Slot mekanizması şöyle kurulacak:

### A. Projeksiyon Penceresi (`ProjectionWindow`)
Bu pencere "Aptal Terminal" (Dumb Terminal) mantığında çalışacak. Kendi başına karar vermeyecek, sadece emirleri uygulayacak.

*   **Yapı:** `QStackedWidget` (Sayfa Yığını).
    *   *Page 0:* Scene Viewer (Resimler).
    *   *Page 1:* Battle Map Viewer.
    *   *Page 2:* Blackout (Siyah ekran).
*   **Input Yok:** Üzerinde tıklanabilir buton olmayacak. Sadece klavye kısayolu (F11) dinlenecek.

### B. Kontrol Mantığı (GM Side)

```text
[GM Tab Widget] --- (currentChanged) ---> [Main Controller]
                                                |
                                                V
                                      [Karar Mekanizması]
                                      (Hangi sekmedeyiz?)
                                                |
          +-------------------------+-----------+------------------+
          |                         |                              |
   [Tab: Player View]       [Tab: Battle Map]              [Tab: DM Notes]
          |                         |                              |
   Sinyal: setMode(0)       Sinyal: setMode(1)             (Sinyal Yok)
          |                         |                  (Son durum korunur)
          |                         |
          V                         V
  [Projection Window] <---- [Projection Window]
  (Scene Göster)           (Map Göster)
```

### C. Layout Senkronizasyonu (Real-time Mirroring)
"Player View" sekmesindeki düzenlemelerin anlık gitmesi için:
*   GM tarafındaki "Canvas Editor"deki her hareket (Move, Resize), bir veri objesi (`SceneState`) oluşturacak.
*   Bu obje JSON veya Dictionary formatında anlık olarak Projeksiyon penceresine gönderilecek (`updateScene(data)`).
*   Böylece DM resmin yerini değiştirdiği an, oyuncular da aynı hareketi görecek.

---

## 5. Geliştirme Adımları (Roadmap)

1.  **Temizlik:** Mevcut "Toggle Player Screen" butonunun ve eski pencere yönetim kodlarının kaldırılması.
2.  **Yeni Pencere Sınıfı:** `UnifiedProjectionWindow` adında, içinde `Stack` yapısı olan, çerçevesiz ve UI elemanlarından arındırılmış sınıfın yazılması.
3.  **GM Arayüz Revizyonu:**
    *   Mevcut TabWidget'a "Player View" sekmesinin eklenmesi.
    *   Bu sekmenin içine "Sahne Düzenleyici" (Scene Editor) widget'ının yerleştirilmesi.
4.  **Bağlantıların Kurulması:**
    *   Tab değişimi -> Projeksiyon Modu değişimi sinyallerinin bağlanması.
    *   Tema değişimi -> Global stil güncelleme sinyalinin bağlanması.
5.  **Tam Ekran ve Çoklu Monitör Desteği:**
    *   GM arayüzüne "Projeksiyonu Aç/Kapat" ve "Tam Ekran Yap" butonlarının eklenmesi.
    *   Otomatik olarak 2. monitörü algılayıp oraya taşıma mantığının eklenmesi.

Bu plan, **"DM masada ne görüyorsa (veya göstermek istiyorsa), oyuncular onu görür"** felsefesine tam uyumludur. Onayınızla birlikte kodlama aşamasına (sınıf yapıları vb.) geçebiliriz.