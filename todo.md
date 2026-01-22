Aşağıda, tespit edilen tüm eksiklikleri (tema renkleri ve lokalizasyon) gidermek için hangi dosyalarda ne tür değişiklikler yapılması gerektiğini adım adım listeledim.

Bu planı onayladığınızda kodlamaya geçeceğiz.

---

### 1. Temel Yapılandırma Dosyaları

Bu dosyalar, diğer tüm dosyaların kullanacağı merkezi verileri (renkler ve metinler) barındıracak.

#### **A. `core/theme_manager.py` (Renk Paleti Genişletme)**
Mevcut palete, tespit edilen hardcoded renkler için yeni anahtarlar eklenmeli:
*   `ui_resize_handle`: Resize tutamacı rengi.
*   `ui_floating_bg`, `ui_floating_border`: Harita üzerindeki yüzen butonların stili.
*   `ui_autosave_bg`, `ui_autosave_text`: Autosave etiketi renkleri.
*   `ui_projection_bg`, `ui_projection_border`: Header'daki projeksiyon alanı.
*   `token_border_player`, `token_border_hostile`, `token_border_neutral`, `token_border_friendly`: Token çerçeve renkleri.
*   `hp_bar_high`, `hp_bar_med`, `hp_bar_low`: Can barı renkleri.
*   `fog_pen_add`, `fog_pen_remove`: Sis ekleme/çıkarma kalem renkleri.
*   `pin_npc`, `pin_monster`, `pin_location`: Harita pin renkleri.

#### **B. `locales/en.yml` ve `locales/tr.yml` (Dil Dosyaları)**
Aşağıdaki kategorilerdeki tüm ham metinler (string) için yeni anahtarlar eklenmeli:
*   **Mind Map:** Zoom kontrolleri, sağ tık menüleri, kayıt durumu.
*   **Combat:** Durum listesi (Blinded, Charmed...), HP barı menüleri.
*   **NPC Sheet:** Resim sayaçları, placeholder metinleri, DM notları başlığı.
*   **Map Tab:** Filtreleme butonları, timeline uyarıları.
*   **Genel:** "Select", "Map", "Video", pencere başlıkları.

---

### 2. UI Bileşenlerinde Yapılacak Değişiklikler

Her dosya için **Tema** ve **Lokalizasyon** başlıkları altında yapılacaklar:

#### **1. `ui/widgets/mind_map_items.py`**
*   **Tema:** `ResizeHandle.paint` metodunda sabit renkler yerine `ThemeManager`'dan `ui_resize_handle` rengi kullanılacak.
*   **Lokalizasyon:** `contextMenuEvent` içindeki "Bağı Sil", "Yansıt", "Bağlantı Kur", "Sil" metinleri `tr()` fonksiyonuna alınacak.

#### **2. `ui/tabs/mind_map_tab.py`**
*   **Tema:**
    *   `FloatingControls` sınıfında `setStyleSheet` içindeki renkler `ThemeManager`'dan alınacak şekilde formatlanacak.
    *   `lbl_save_status` stil tanımları dinamik hale getirilecek.
*   **Lokalizasyon:**
    *   Yüzen buton metinleri ("Zoom In", "Fit") ve Tooltip'leri çevrilecek.
    *   Kaydetme durumu metinleri ("Saved", "Editing...") çevrilecek.
    *   Sağ tık menüsü ("Not Ekle", "Resim Ekle") çevrilecek.

#### **3. `ui/widgets/projection_manager.py`**
*   **Tema:** `ProjectionThumbnail` ve `ProjectionManager` sınıflarındaki `setStyleSheet` çağrıları, `ThemeManager` renklerini kullanacak şekilde güncellenecek (border, background).
*   **Lokalizasyon:**
    *   Thumbnail üzerindeki "MAP" yazısı ve "?" işareti çevrilebilir hale gelecek.
    *   "Drop to Project" etiketi ve Tooltip'ler `tr()` ile sarılacak.

#### **4. `ui/widgets/combat_tracker.py`**
*   **Tema:**
    *   `HpBarWidget.update_color`: Yeşil/Sarı/Kırmızı renk geçişleri `ThemeManager`'dan (hp_bar_*) alınacak.
    *   `ConditionIcon`: Varsayılan mavi fırça rengi temaya bağlanacak.
*   **Lokalizasyon:**
    *   Global `CONDITIONS` listesi (Blinded, Charmed...) `tr()` fonksiyonu ile dinamik hale getirilecek (bunun için listeyi bir fonksiyona veya `core/models.py` içine taşımak gerekebilir).
    *   `load_map_dialog` içindeki dosya seçim başlığı ve `ConditionIcon` sağ tık menüsü ("Kaldır") çevrilecek.

#### **5. `ui/windows/battle_map_window.py`**
*   **Tema:**
    *   `BattleMapView` (Fog Edit): Çizim kalemlerinin (Sarı, Kırmızı, Yeşil) renkleri temadan alınacak.
    *   `BattleTokenItem`: Token çerçeve renkleri (Dost, Düşman vb.) `ThemeManager`'daki `token_border_*` anahtarlarına bağlanacak.
*   **Lokalizasyon:** Varsa sidebar başlıkları ve tooltip'ler kontrol edilip eksikler tamamlanacak.

#### **6. `ui/widgets/map_viewer.py`**
*   **Tema:** `MapPinItem` ve `TimelinePinItem` sınıflarındaki varsayılan renk atamaları (hardcoded hex kodları) `ThemeManager` üzerinden yapılacak.
*   **Lokalizasyon:** `contextMenuEvent` içindeki tüm aksiyonlar ("Inspect", "Edit Note", "Change Color", "Move", "Delete") `tr()` ile sarılacak.

#### **7. `ui/widgets/npc_sheet.py`**
*   **Tema:**
    *   `grp_dm_notes` (DM Notları Grubu) için stil (`border: 1px solid #d32f2f`) temaya uygun hale getirilecek (örneğin dark temada kırmızı kalabilir ama light temada daha koyu kırmızı).
*   **Lokalizasyon:**
    *   Resim sayacı "0/0".
    *   Placeholder metinleri: "SRD 5e...", "Select or Write...", "Hidden from players...".
    *   Tab başlığı: "Battlemaps".
    *   Buton metni: "Add Media".
    *   Dosya listesindeki ek: "(Video)".

#### **8. `ui/tabs/map_tab.py`**
*   **Lokalizasyon:**
    *   Filtre butonları: "Filter", "Clear".
    *   Checkbox etiketleri: "Show Non-Player...", "Show Map Pins".
    *   Uyarı mesajları: "Please import...", "Cannot link...".

#### **9. `ui/tabs/session_tab.py`**
*   **Lokalizasyon:** Log giriş kutusundaki "Hızlı log ekle..." placeholder'ı çevrilecek.

#### **10. Diğer Diyaloglar (`ui/dialogs/`)**
*   **`theme_builder.py`:** Placeholder metinleri ("e.g. Dark Forest").
*   **`entity_selector.py`:** Pencere başlığı ("Add Entity to Combat") ve Tablo başlıkları ("HP", "AC", "Init Bonus").
*   **`ui/player_window.py`:** Pencere başlığı ("Player View...").

---

### 3. İşlem Sırası

1.  **`locales` Güncellemesi:** Önce `en.yml` ve `tr.yml` dosyalarına tüm yeni anahtarları ekleyeceğiz.
2.  **`theme_manager.py` Güncellemesi:** Yeni renk tanımlarını `DEFAULT_PALETTE` ve diğer temalara ekleyeceğiz.
3.  **UI Kodlama:** Dosya dosya ilerleyerek yukarıdaki değişiklikleri uygulayacağız.

Bu yol haritası ile sistem %100 tema uyumlu ve yerelleştirilmiş olacaktır. Hazırsanız **1. Adım (Locales ve Theme Manager)** ile başlayabilirim.