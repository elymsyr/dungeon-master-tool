# Tanıtım Videosu — Çekim Listesi

Hedef: ~75 sn ana video (16:9, İngilizce) + 9:16 kısa kesim. Aynı klipler hem Clueso'ya hem elle kurguya gider.
Arayüz dili **English**, demo dünyası **Aegis — Meridia: Act One EN** (`assets/worlds/aegis-en/`).
Tırnak içindeki etiketler uygulamadaki gerçek İngilizce metinler (`app_en.arb`).

## 0. Hazırlık (bir kere)

**Demo verisi**
- [ ] İki hesap: **DM** (demo) ve **Player** (demo). Kullanıcı adları nötr olsun (ör. `dm_demo`, `player_demo`).
- [ ] Aegis EN'i kur: admin ayarlarındaki **Import world zip** ile `assets/worlds/aegis-en/aegis-act1-en.zip`.
- [ ] Battlemap: **Black Sail** gemi haritası (`media/Maps/Kara-Yelken.webp`). 3–4 oyuncu tokenı, 2–3 **Orc Warrior**, bir **Orc Captain**, güvertenin bir kısmı sisli.
- [ ] Player hesabıyla bir karakter oluştur, dünyaya katıl, DM kabul etsin.
- [ ] Bir **Free Template (Beta)** şablonu aç, iki üç alanı dolu, gerisi boş kalsın. Canlı düzenleme çekilecek.
- [ ] Ekranda gerçek isim, e-posta ya da kişisel mesaj kalmasın (Social > Messages dahil).
- [ ] **Spoiler kontrolü:** Aegis'i oyuncuların izleyebileceği bir videoda gösteriyorsun. Secrets / DM Notes bölümleri açık kart çekme, ya da masanın zaten geçtiği kartları seç (ör. Silverwater, Duran).

**Uygulama**
- [ ] Release build (debug banner yok), `flutter_app/` içinden:
  `~/flutter-3.47/bin/flutter run -d linux --release --dart-define=SUPABASE_URL=… --dart-define=SUPABASE_ANON_KEY=…`
- [ ] Settings: dil **English**, tema tek ve sabit (koyu tema videoda daha iyi durur), zar teması sabit.
- [ ] Bildirimleri kapat (işletim sistemi + uygulama), masaüstünü temizle, görev çubuğunu gizle.

**OBS**
- Tuval ve çıktı 1920×1080, 60 fps, kayıt formatı MKV (çökerse dosya kurtulur). Sonra *File > Remux Recordings* ile MP4'e çevir.
- Kalite: "Indistinguishable Quality" ya da CQP 16–18.
- Kaynak: *Window Capture*, sadece uygulama penceresi. İki pencereli sahnelerde (02, 04) *Screen Capture*.
- İmleç masaüstü kliplerinde açık, telefon kliplerinde kapalı.
- Ses kaydetme, seslendirme sonra gelecek. İstersen Soundpad sahnesinde (09c) uygulama sesini al.

**Telefon görüntüsü (P klipleri)**
- Pencereyi **~430×930**'a daralt. Kısa kenar 600 px'in altına inince uygulama telefon düzenine geçer.
- Pencereyi daraltmak için: `wmctrl -r :ACTIVE: -e 0,100,60,430,930`. Ya da elle sürükle, ölçüyü OBS'te kontrol et.
- 16:9 videoda telefon çerçevesi içinde kullanılacak, bu çözünürlük yeter.
- İstersen sonra Android'den `scrcpy --record=P_xx.mp4` ile daha net çekim alırsın. Klip kodları aynı kalır.

## Her klip için kurallar

1. **Tek klip = tek aksiyon**, 5–15 sn. Uzun tek kayıt alma.
2. Başta ve sonda **2 sn hiç kıpırdama** (kurgu payı).
3. Mouse'u **yavaş ve düz** hareket ettir. Tıklamadan önce yarım saniye bekle, Clueso zoom'u tıklamaya göre yapıyor.
4. Bir şey ters giderse durma, aynı klibi baştan al. Sonra en iyisini seçersin.
5. Dosya adı = kod + kısa ad (`03d_dice.mkv`). Aynı klibin tekrarı: `03d_dice_2.mkv`. D = masaüstü, P = telefon.

## Çekimler

### 01 — Açılış (0–8 sn)
| Kod | Tür | Ne çekilecek | Süre |
|---|---|---|---|
| 01a | D | Hub, **Worlds** sekmesi. Fare **Aegis — Meridia: Act One EN** kapağına gider, tıklar, dünya açılır | 6 sn |
| 01b | D | **Codex** sekmesi: **Duran** NPC kartı açılır. Görsel ve Description görünür, yavaşça aşağı kaydır (Secrets'a inmeden dur) | 8 sn |
| 01c | P | Aynı kart telefon düzeninde, yavaşça kaydır | 6 sn |

### 02 — İki ekran / projeksiyon (8–18 sn)
*Screen Capture*: solda DM penceresi, sağda projeksiyon penceresi.
| Kod | Tür | Ne çekilecek | Süre |
|---|---|---|---|
| 02a | D | **Session** sekmesinde **Player Screen** ile projeksiyon penceresi açılır | 8 sn |
| 02b | D | Bir görselin üstünde sağ tık → **Project image**. Sağdaki pencerede anında belirir (ör. **Lucid Triton** veya **Black Sail** görseli) | 6 sn |
| 02c | D | **Blackout** açılır (ekran kararır), kapanır, ardından battlemap projekte edilir (**Project battle map to player screen**) | 7 sn |
| 02d | — | *(Opsiyonel ama çok etkili)* Telefonla gerçek masa çekimi: laptopta DM ekranı, arkadaki TV/monitörde projeksiyon | 5 sn |

### 03 — Battlemap ve zar (18–30 sn)
| Kod | Tür | Ne çekilecek | Süre |
|---|---|---|---|
| 03a | D | Black Sail battlemap: bir oyuncu tokenını sürükleyip yeni konuma bırak | 6 sn |
| 03b | D | **Erase Fog** ile güvertenin sisli kısmını aç, Orc'lar görünür | 6 sn |
| 03c | D | Bir Orc Warrior tokenına sağ tık, menüden hasar ver, HP çubuğu düşer | 6 sn |
| 03d | D | Sağ alttaki zar butonu (**Roll dice**) → 3D zar yuvarlanıp durur. **En çok satan sahne bu, 3 farklı atış al** (tek d20, birkaç zar birden, yüksek sonuç) | 6 sn |
| 03e | D | **Session** sekmesi: initiative sırası, **Next Turn** ile sıra geçer, zar günlüğü görünür | 7 sn |
| 03f | P | Telefonda zar atışı | 5 sn |

### 04 — DM ve oyuncu gözünden (30–40 sn)
İki instance yan yana: solda DM (geniş pencere), sağda Player (430×930). *Screen Capture* ile bütün masaüstünü **tek kayıtta** al, ikisinin aynı anda değiştiği görünsün.
| Kod | Tür | Ne çekilecek | Süre |
|---|---|---|---|
| 04a | D+P | DM bir kartta **Share with players** der, oyuncunun ekranında kart belirir (ör. **Hidden Harbor** konumu) | 8 sn |
| 04b | D+P | Oyuncunun sırası: oyuncu ekranında **Your turn**, oyuncu kendi tokenını yürütür, DM'in haritasında da hareket eder | 8 sn |
| 04c | D+P | Oyuncu zar atar, sonuç DM'in Session günlüğüne düşer | 6 sn |
| 04d | P | Oyuncunun karakter sayfası, yavaşça kaydır | 6 sn |

### 05 — Marketplace ve paylaşım (40–50 sn)
| Kod | Tür | Ne çekilecek | Süre |
|---|---|---|---|
| 05a | D | **Social** > **Marketplace**: listede gezin, bir öğenin detayını aç | 7 sn |
| 05b | D | **Download** → indirilen paket **Packages** sekmesinde belirir | 6 sn |
| 05c | D | Kendi içeriğini yayınlama: **Publish** diyaloğu açılır, Title / Tags doldurulur, **Publish** butonunda durulur (basmak şart değil) | 7 sn |
| 05d | P | Telefonda Social akışı veya oyun ilanları, yavaşça kaydır | 5 sn |

### 06 — Free Template (Beta) (50–56 sn)
| Kod | Tür | Ne çekilecek | Süre |
|---|---|---|---|
| 06a | D | **Templates** → kendi şablonun (**Beta** rozeti görünsün): yeni bir alan ekle, kart önizlemesi anında değişsin | 8 sn |
| 06b | D | Bu şablonla oluşturulmuş bir kart veya karakter sayfası | 5 sn |

### 07 — Dışa/içe aktarma (56–62 sn)
| Kod | Tür | Ne çekilecek | Süre |
|---|---|---|---|
| 07a | D | Aegis EN'de **Transfer** → **Export to file (.dmtz)** → "Saved: …" bildirimi | 6 sn |
| 07b | P | Telefon düzeninde (ya da ikinci kullanıcıda) **Transfer** → **Import from file (.dmtz)** → "… imported", dünya listede belirir | 6 sn |

### 08 — Online / offline, hesaplı / hesapsız (62–70 sn)
| Kod | Tür | Ne çekilecek | Süre |
|---|---|---|---|
| 08a | D | Çıkış yapılmış açılış ekranı → **Continue without an account** → doğrudan Worlds'e girer | 5 sn |
| 08b | D | Aegis EN'de **Multiplayer On** → "World is now online", davet kodu görünür, kopyalanır ("Invite code copied") | 7 sn |
| 08c | P | Oyuncu tarafı: **Join World** → 8 haneli kodu yazar → "Join request sent…" | 5 sn |
| 08d | — | *Çekim yok*: dört kutulu grafik kurguda yapılacak (Offline · Online · No account · Account) | — |

### 09 — Kısa kapsam montajı (70–75 sn, her biri 1–2 sn kullanılır, 4 sn çek)
| Kod | Tür | Ne çekilecek |
|---|---|---|
| 09a | D | **Mind Map**: birkaç düğümü sürükle |
| 09b | D | **Map**: Meridia dünya haritası, pinler görünür, yakınlaştır |
| 09c | D | **Soundpad**: bir ambiyans başlat |
| 09d | D | **PDF** sekmesi açık, sayfa çevir |
| 09e | D | Karakter oluşturma sihirbazından bir adım |

### 10 — Kapanış
Çekim yok. Kurguda logo, platformlar (Windows · macOS · Linux · Android · iOS) ve link.

## Kayıt sonrası
- [ ] Tüm MKV'leri MP4'e remux et.
- [ ] Her kodun en iyi çekimini `secilen/` klasörüne kopyala (ör. `secilen/03d_dice.mp4`).
- [ ] Toplam kontrol: 01–09 arası **33 klip** (02d opsiyonel).
- [ ] Senaryo (İngilizce seslendirme metni) ve Clueso prompt'u ayrı dosyada gelecek.
