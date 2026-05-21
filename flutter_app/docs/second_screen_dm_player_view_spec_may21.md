# İkinci Ekran — DM / Oyuncu View Spec

Tarih: 2026-05-21
Durum: tasarım
İlgili: `online_second_screen_architecture_may21.md` (mimari / transport)

## 1. Kapsam

İki view:

- **DM view** — paylaşımı başlatan. Offline (yerel ikinci pencere) + online (uzak
  oyuncular) aynı kaynaktan beslenir (`ProjectionController`).
- **Player view** — `PlayerSecondScreenTab`. DM'in paylaştığını render eder + battle
  map'te etkileşir.

Offline pencere bugün çalışıyor; online player view yeni. İkisi davranışça **paralel**:
aynı içerik, aynı render. Fark: online'da geri kanal (çizim, token) var.

## 2. Paylaşılabilir içerik

| İçerik | Kaynak | DM aksiyonu |
|---|---|---|
| Entity card | DB entity | kart üzerinde "Project" |
| Entity resmi (yalnız) | entity'nin resim ref'i | kart resmi menüsü "Sadece resmi paylaş" |
| Medya galerisi fotoğrafı | galerideki yüklü asset | galeri tile "İkinci ekrana paylaş" |
| Battle map | aktif encounter | battle map "Project" |

**Kural:** DM projeksiyon için **ad-hoc dosya yükleyemez**. Her paylaşılan medyanın zaten
bir `AssetRef`'i var (entity resmi, galeri asset'i, battle map). Projeksiyon UI'sında
dosya seçici yok — paylaşım yalnız var olan içeriğe referanstır.

## 3. View senkronizasyonu — neyi taşır, neyi taşımaz

**Taşınır (DM → tüm oyuncular):**

- Hangi item aktif (entity card / resim / battle map / siyah ekran).
- Item içeriği (entity snapshot, resim ref, battle map snapshot: token, fog, grid, tur).

**Taşınmaz (her client'ta yerel):**

- Zoom seviyesi.
- Pan / kaydırma konumu.
- Drag (resim / harita gezinme).

Her oyuncu DM'den ve diğer oyunculardan bağımsız yakınlaştırır / kaydırır. DM'in kendi
ekranındaki yaklaştırma-sürükleme oyuncuya **gitmez**. (`battle_map_notifier.dart`
`ViewTransform` zaten local-only; online'da bu kural tüm içerik tiplerine genişler.
Offline'daki `viewportLocked` DM-kilidi online'da yok.)

## 4. DM view

### 4a. Aksiyonlar

- İçerik paylaş (§2 tablosu).
- Aktif item değiştir / yeni sekme / siyah ekran (blackout) — mevcut `projection_panel.dart`.
- Battle map: tüm token'ları serbest oynat (mevcut DM yetkisi).
- Battle map: turu ilerlet (`nextTurn`).
- Battle map: **tüm çizimleri temizle** — kendi + tüm oyuncuların. `clear_battlemap_marks` RPC.
- Projeksiyonu kapat.

### 4b. Offline + online birlikte

DM aynı anda yerel ikinci pencere ve online oyuncular için yayında olabilir. Tek
`ProjectionController` her iki çıkışı besler (mimari §3 madde 3 — fan-out).

## 5. Player view (`PlayerSecondScreenTab`)

### 5a. Render

- DM aktif item yoksa: "DM bekleniyor" placeholder (mevcut).
- Entity card → kart render (`EntityCardProjection`).
- Resim → resim render; oyuncu yerel zoom / pan.
- Battle map → harita + token + fog + grid + tur paneli; üstüne collab katmanı.

### 5b. Battle map etkileşimi — çizim

Oyuncu DM gibi çizebilir:

- **Ölçülü çizgi (ruler)** — iki uç, mesafe etiketi.
- **Ölçülü daire (circle)** — merkez + yarıçap, feet etiketi.
- **Serbest çizim** — free draw stroke.
- **Kendi çizimini sil** — yalnız kendi mark'larını. Başkasınınkine / DM'inkine dokunamaz.

Her oyuncunun çizimi **farklı renk** (üyeliğe göre atanan palet rengi). Kendi rengini
görür, başkalarınınkini ayrı renkte görür. DM'in ayrılmış rengi var.

DM **tüm** çizimleri tek aksiyonla siler.

### 5c. Battle map etkileşimi — token

Oyuncu **yalnız kendi karakterinin** token'ını oynatır, **yalnız o karakterin turu** iken:

- Sıra o karakterde değilse token kilitli (sürüklenemez).
- Sıra geldiğinde token sürüklenebilir; bırakınca `move_own_token` RPC server'da turu +
  sahipliği doğrular.
- Server reddederse token eski yerine snap-back.
- Oyuncu başka token'a, DM token'larına dokunamaz.

### 5d. Oyuncu yapamaz

- İçerik paylaşamaz (yalnız DM).
- Turu ilerletemez.
- Başkasının çizimini / token'ını değiştiremez.
- Aktif item'ı değiştiremez (DM ne paylaştıysa onu görür).

## 6. Yetki matrisi

| Yetenek | DM | Oyuncu |
|---|---|---|
| İçerik paylaş (entity / resim / galeri / harita) | ✓ | ✗ |
| Aktif item / blackout | ✓ | ✗ |
| Projeksiyon için dosya upload | ✗ (yasak) | ✗ (yasak) |
| Zoom / pan / drag (yerel) | ✓ | ✓ |
| Battle map çizim (stroke / ruler / circle) | ✓ | ✓ |
| Kendi çizimini sil | ✓ | ✓ |
| Tüm çizimleri sil | ✓ | ✗ |
| Token oynat — her token | ✓ | ✗ |
| Token oynat — kendi karakteri, kendi turu | ✓ | ✓ |
| Turu ilerlet | ✓ | ✗ |

## 7. Çizim rengi atama

- Palet: sabit N-renk listesi.
- Her dünya üyesine `world_members.joined_at` sırası (veya uid hash) ile stabil renk.
- DM rengi paletten ayrı (ör. mevcut annotation rengi).
- `world_battlemap_marks.color_hex` mark oluşturulurken yazılır → renk geçmişe sabit;
  üye ayrılsa bile eski çizimin rengi korunur.

## 8. Offline ↔ online parite

| Özellik | Offline pencere | Online player view |
|---|---|---|
| Entity card / resim / harita render | ✓ | ✓ |
| Bağımsız zoom / pan | ✓ (tek izleyici) | ✓ (her oyuncu) |
| `viewportLocked` (DM kilidi) | var | yok — daima per-client |
| Oyuncu çizimi | yok (tek pencere) | ✓ |
| Oyuncu token hareketi | yok | ✓ (turlu) |
| Transport | IPC MethodChannel | Supabase CDC + RPC |

## 9. Açık UX noktaları

- Oyuncu token'ı: sıra gelince görsel ipucu (token highlight / "Senin turun" rozeti).
- Çizim aracı UI: player tab'ında DM battle map araç çubuğunun alt kümesi
  (navigate / ruler / circle / draw / erase-own).
- Çok oyuncu aynı anda çizerken renk çakışması — palet ≥ makul üye sayısı olmalı.
- DM "sadece resmi paylaş" vs "kart paylaş" — kart resmine sağ-tık menüsü ile ayrılır.
- Oyuncu battle map'i kendi cihazında render ederken DM araç çubuğunun DM-only
  öğeleri (fog, tüm token oynatma) gizlenir.
