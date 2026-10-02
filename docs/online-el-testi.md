# Online — elle doğrulama listesi (2026-09-23, güncelleme 2026-10-02)

`online-sync-redesign.md`'deki bütün "bekleyen doğrulama" maddeleri, tek
oturumda koşulacak sırayla. Yıkıcı adımlar (multiplayer'ı kapatma, paket
silme) en sonda.

**Bu tur sıfırdan ve log'suz.** Aegis, `aegis-act1.zip`'ten A'ya (DM, admin
hesabı) yeni kurulup online yapılıyor (§0). Cihazlar release derlemesinde,
terminal ve log açık değil. "Log'da …" diye geçen satırları atla; adımın
ekrandaki beklentisi ve SQL'i yeterli. Bir adım ❌ olursa log'u uygulamanın
içinden al: **Hata Bildir** (hub'da böcek simgesi; telefonda profil menüsü)
→ "Son günlükler" kutusu son 200 satırı gösteriyor, seçip kopyala. Raporu
göndermek şart değil.

**Cihazlar**

| Kısa ad | Ne | Hesap |
|---|---|---|
| **A** | DM'in bilgisayarı — görsellerin özgün dosyaları burada | DM hesabı |
| **B** | DM'in ikinci cihazı (telefon) | aynı DM hesabı |
| **P** | Oyuncu cihazı | **başka** bir hesap |

Aegis dünyasının id'si zip kurulumunda yeniden üretiliyor (eski
`47272f9a-…` artık geçersiz). §0.6'da SQL'den bulup buraya yaz:
`<W>` = `________________________________`. Aşağıda `<W>` bu id demek. Hub'daki
adı **"Aegis — Meridia: Birinci Perde"**; metinde kısaca Aegis.

**Hangi faz nerede.** Biten her fazın elle görülecek davranışı en az bir
adımda. Bir fazı tek başına doğrulamak istersen buradan başla.

| Faz | Ne | Adımlar |
|---|---|---|
| 0 | Worker'ın hız sınırı KV'siz | 1.4 |
| 1 | `.dmtz` dışa/içe aktarma | 10.3, 11.7, 16.1–16.3 |
| 2.5 | Dünya kimliği isimden id'ye | 16.4, 16.5 |
| 3 | Bulut şeması + RLS | 1.1 (`verify_094`) |
| 3.5 | `dmt-content://` medya ref'i | 1.3, 3.2, 3.5 |
| 4a | Dünya push'u | 1.3, 2.1–2.3 |
| 4b | Paket + karakter push'u | 6.2, 6.5, 7.1, 7.2 |
| 5a | Dünya pull'u, echo guard | 1.2, 2.1–2.5 |
| 5b | Canlı sinyal, sunucu tarafı LWW | 2.1, 2.5, 4.4 |
| 5c | İkinci cihaza indirme | 2.0, 2.6, 7.3 |
| 5d | Dünya medyası R2'de | 0.5, 0.6, 3, 4, 5.2, 5.4, 9.1, 9.3 |
| 5e | Paket medyası, arka plan uzlaştırması | 12 |
| 5f (1. kısım) | Arka plan uzlaştırması, kota bildirimi, süre log'ları | 4.2–4.4, 8, 11.4 |
| 5g | Karakterin kendi kapsamı | 6.6, 13 |
| 5.5a | Oyuncunun ikinci cihazı, davet kodsuz | 14 |
| 5.5b + ek + 103 | Kartlar buluttan, oyuncuda yerelde, gri kart | 5, 15 |
| 6 | LAN kalktı | 10 |
| 9 | İşlem geri bildirimi | 11 |

---

## 0. Hazırlık

**0.1 Derleme (log'suz).** Üç cihazı da çalışma ağacının son haliyle,
**release** modunda ve üç `--dart-define`'la derle. Eski derlemeli bir cihaz
testleri geçersiz kılar (103'ten beri eski sürümün paylaşımı düşüyor).

```bash
cd flutter_app
D="--dart-define=SUPABASE_URL=… --dart-define=SUPABASE_ANON_KEY=… --dart-define=DMT_WORKER_URL=…"
flutter build linux --release $D   # → build/linux/x64/release/bundle/dungeon_master_tool
flutter build apk --release $D     # → adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Supabase → SQL Editor'ü açık tut.

**0.2 Test dosyaları.** `~/Desktop/online-el-testi-gorseller/` — yapay zekasız,
rastgele gürültü + üstünde büyük etiket (hangi görselin geldiği ekrandan
okunuyor). Hepsi farklı içerikte, yani farklı sha256. Aegis'e eklenmedi;
adımlarda sen ekleyeceksin. Telefon tarafında gerekenleri (6.6, 13, 14)
telefona kopyala. "MB" burada MiB (limitler de öyle: 5 MB = 5 242 880 bayt).

| Klasör | Dosyalar | Nerede |
|---|---|---|
| `01-kucuk/` | `kucuk-1..3.jpg` (0.2 / 0.5 / 0.9 MB) | 0.8 Deneme, 3.2, 5.4, 9.1, 11.5 |
| `02-orta-tur1..3/` | her birinde 15 görsel, 1.5–3 MB (set başına ~34 MB) | 4.1 → tur1, 4.2 → tur2, 4.3 → tur3 |
| `03-kart-limit/` | `kart-4.8MB-sinir-alti.jpg` (gitmeli), `kart-7MB-limit-ustu.jpg` (gitmemeli) | 3.3, 0.8 Deneme |
| `04-harita/` | `harita-8MB.jpg` (gitmeli), `harita-12MB-limit-ustu.jpg` (gitmemeli), `savas-haritasi-3MB.jpg` | 3.4, 0.8 Deneme |
| `05-portre/` | `portre-1.jpg`, `portre-2.jpg` (1 MB), `portre-5MB-limit-ustu.jpg` (portre limiti 4 MB) | 6.6, 13.1, 13.7, 13.12 |
| `06-paket/` | `paket-1.png`, `paket-2.png`, `paket-3-yeni.jpg`, `paket-6MB-limit-ustu.jpg` | 7.1, 12.1, 12.3 |
| `07-metin/` | `aciklama-310KB.txt` (bulut satır sınırı 256 KB) | 11.4 |

Yeniden üretmek gerekirse (yeni sha'lar): aynı klasördeki betik,
`python3 uret.py <yeni-klasör>` (Pillow yeterli; depoda değil).

**0.3 Bulutu sıfırla (official içerik kalır).** Aegis'in kart id'leri
blueprint'ten sabit (uuidv5), bulutta `world_entities.id` ise tüm dünyalar
arasında tekil. Bulutta eski bir Aegis (bugün dört tane var) dururken aynı
kartları yeni bir dünyayla push etmek satırları ondan çeker. Bu yüzden
kullanıcı içeriğinin hepsini siliyoruz. Hesaplar, adminlik, bildirimler ve
official katalog kalıyor.

1. **Cihazlar kapalı.** Üç cihazda da uygulamayı kapat. Açık kalan bir cihaz
   yerelde online işaretli dünyayı ya da karakteri silme sırasında geri
   yazabilir.
2. **Tablolar.** SQL Editor'de `supabase/scripts/wipe_user_content.sql`.
   Önce olduğu gibi çalıştır (ROLLBACK ile biter): tablodaki sayıların hepsi
   0 olmalı, yalnız hesap/admin/bildirim/hata raporu tabloları dolu
   kalabilir. TRUNCATE hata verirse dur, hatayı bana getir. Doğruysa sondaki
   `ROLLBACK`'i `COMMIT` yap, yeniden çalıştır.
3. **Supabase Storage.** Dashboard → Storage'da şu bucket'ları boşalt (ya
   da `BUCKET=<ad> supabase/scripts/wipe_storage.sh`, service role key'le):
   `shared-payloads` (marketplace içerikleri), `free-media` (ücretsiz
   medya), `post-images` (gönderi görselleri). `avatars`'a dokunma (profil
   fotoğrafı, hesaba ait). `campaign-backups` bucket'ı 077'de kalktı; hâlâ
   görünüyorsa onu da boşalt.
4. **R2** (Cloudflare → R2 → `dmt-assets`). **`catalog/` hariç** bütün kök
   klasörleri sil: `worlds/`, `packages/`, `characters/`, `pub/`,
   `transient/` ve adı UUID olan eski kullanıcı klasörleri
   (`{userId}/…`). Worker'ın `/admin/purge-all` ucunu **kullanma**:
   `catalog/`'u da siler.
5. **Cihazların yerel verisi.** Üçünü de sıfırla (aşağıdaki uyarıdaki yol).
   Yerelde "online" işaretli kalan dünya, paket ya da karakter, bulutta
   satırı olmayan bir şeyi push etmeye çalışır. Masaüstünde klasörün adını
   değiştirmek yerel dünyalarını yedek olarak tutar. P'ye Aegis'i **kendisi
   kurdurma** (ne zip ne katalog): aynı kart id'leri §15.13'teki soruna
   düşer.
6. Kontrol: `select count(*) from worlds;` → 0. Hub → Marketplace'te
   official katalog hâlâ listeleniyor.

**0.4 Zip'ten kur.** A'da Admin → "Dünya zip dosyası içe aktar" →
`flutter_app/assets/worlds/aegis/aegis-act1.zip` (zip'in kökünde
`aegis-act1/` klasörü var, olduğu gibi seç; açmaya gerek yok).
- Beklenen: "Dünya içe aktarılıyor…" overlay'i, ardından snackbar. Hub'da
  "Aegis — Meridia: Birinci Perde", multiplayer kapalı. Açınca ~217 kart,
  dünya haritası pinleriyle, kart görselleri yerinde.

**0.5 Kotayı aşan dünya yayınlanmıyor (Faz 5d, isteğe bağlı).** Tavanı
geçici düşür:

```sql
create or replace function public.world_media_user_cap_bytes()
returns bigint language sql immutable set search_path = public, pg_temp
as $$ select 1::bigint $$;
```

A'da Aegis → Multiplayer On.
- Beklenen: "Bu dünyanın medyası X yer istiyor, bulutta ise Y kaldı…" ve
  dünya online olmuyor (davet kodu yok, `select count(*) from worlds` hâlâ 0).
- Sonra tavanı geri al: aynı fonksiyon, `1::bigint * 1024 * 1024 * 1024`.

**0.6 Multiplayer aç (Faz 5d).** A'da Aegis → Multiplayer On. Kronometreyi
başlat (§8 için).
- Beklenen: "Dünya medyası yükleniyor n/N" overlay'i doluyor; N 200 civarı
  (zip'te 218 medya dosyası, kullanılmayanlar sayılmaz). Aegis'in bütün
  görselleri 5 MB altında, bitince limit üstü listesi **çıkmamalı**.
- Beklenen: davet kodu görünüyor. Kayıt simgesi kısa süre bulut-ok, sonra
  bulut-tik (§11.2).
- `<W>`'yi bul ve en üste yaz:

```sql
select id, world_name, created_at from worlds where world_name like 'Aegis%';
```

- Log'da (sonraki tur): `multiplayer açıldı <W>: N satır … ms` ve
  `multiplayer medya <W> ↑N <bayt> … ms (toplam)`.

**0.7 Başlangıç sayıları.** Buraya yaz, sonraki adımlar bunlarla
kıyaslanacak:

```sql
select uploaded, count(*), sum(bytes) from world_media
 where world_id = '<W>' group by 1;
select revision from world_revisions where world_id = '<W>';
select count(*) from world_entities where world_id = '<W>';
select count(*) from entity_shares where world_id = '<W>';  -- blueprint'in paylaşım tohumu: 54 + ilişki zinciri
```

**0.8 Deneme.** A'da **Deneme** adında yeni bir dünya oluştur (multiplayer
kapalı): 5–6 kart, çoğuna `01-kucuk/`'tan ya da
`kart-4.8MB-sinir-alti.jpg` görsel, birine `kart-7MB-limit-ustu.jpg`; dünya haritası
`04-harita/harita-8MB.jpg`. 9.3 ve 11.2 bunu kullanıyor (multiplayer'ı
kapatmak yıkıcı, Aegis'te yapılmaz).

> **İki şeyi yapma.**
> - **Aegis'i hub'dan kopyalama.** Dünya kopyalama bugün asıl dünyayı
>   boşaltıyor: kartlar ve öteki satırlar kopyaya taşınıyor
>   (`docs/KNOWN_ISSUES.md`). Kopya gereken her yerde Deneme'yi kullan.
> - **B'de online dünyayı ya da paketi uygulamadan silme.** DM'in silmesi
>   bulut kopyasını da siler; A'dan da gider. "Bulutta, bu cihazda yok"
>   listesine düşmek için B'yi sıfırla: Android'de Ayarlar → Uygulamalar →
>   uygulama → Depolama → Verileri temizle, sonra yeniden giriş;
>   masaüstünde uygulama kapalıyken `<dataRoot>/users/<uid>` klasörünün
>   adını değiştir (test bitince eski adına döndürürsün).

---

## 1. Temel sağlık — tek cihaz (A)

**1.1 Migration doğrulamaları.** SQL Editor'de `supabase/scripts/` altındaki
şu dosyaların içeriğini sırayla çalıştır: `verify_088_089.sql`,
`verify_094.sql`, `verify_096.sql`, `verify_097.sql`, `verify_098.sql`,
`verify_099.sql`, `verify_100.sql`, `verify_102.sql`, `verify_103.sql`.
Hepsi `ROLLBACK` ile bitiyor, kalıcı bir şey yazmıyor.
- Beklenen: her biri tek satır `NNN OK` (ilki `088+089 OK`).
- `verify_094`'te `5.1 OYUNCU world_entities OKUYABILIYOR` ya da `6.4 DM'E
  OZEL ALAN OYUNCUYA SIZDI` patlarsa gizlilik hatası: dur ve bana getir.

**1.2 Echo guard.** A'da dünyayı aç, **hiçbir şeye dokunmadan** 30 sn bekle,
kapat. Bunu üç kez yap. Her seferinde:

```sql
select revision from world_revisions where world_id = '<W>';
```

- Beklenen: sayı **sabit** kalır.
- Artıyorsa: `supabase/scripts/which_bumped.sql` ile hangi satır olduğunu bul
  ve bana getir. Bu test tutmazsa diğer adımlara geçme.

**1.3 Bulut sayımı.**

```sql
select count(*) from world_entities where world_id = '<W>';
select substr(image_path,1,14) from world_entities
 where world_id = '<W>' and image_path <> '' limit 5;
```

- Beklenen: sayı A'daki kart sayısıyla aynı; `image_path` hep `dmt-content://`.
  `/home/...` görünmemeli.

**1.4 Hesapsız katalog (Faz 0).** Hesaptan çık. Marketplace'te resmi
kataloğu aç, bu cihazda olmayan bir **paketi** kur (dünya değil: aynı
katalog dünyasını iki kez kurmak kartları taşır, §15.13). Sonra yeniden
giriş yap.
- Beklenen: liste geliyor, paket kuruluyor, "çok fazla istek" hatası yok.
  Worker'ın hız sınırı artık KV'ye yazmıyor; Cloudflare panelinde KV yazma
  sayısı bu sırada artmamalı (bakması isteğe bağlı).

---

## 2. DM'in iki cihazı — içerik (A + B)

**2.0 B'ye ilk indirme (Faz 5c).** B 0.3'te sıfırlandı. DM hesabıyla gir.
Hub → Dünyalar → "Bulutta, bu cihazda yok" → Aegis → İndir. Kronometreyi
tut (§8).
- Beklenen: ilerleme çubuğu doluyor, dünya yerel listeye geçiyor, buluttaki
  listeden düşüyor.
- Beklenen: dünyayı aç. Kartlar (0.7'deki sayı), dünya haritası ve pinleri
  A'daki gibi; görseller kaydırdıkça birkaç saniyede geliyor. Kırık ikon
  kalıyorsa üstüne gel (mobilde basılı tut), nedenini yaz (§11.5).
- Beklenen: açılışta satır buluta geri gitmiyor — 0.7'deki `revision`
  sorgusu B'yi açınca artmamalı.

A ve B'de aynı dünya açık olsun.

**2.1 Canlı düzenleme.** A'da bir kartın adını değiştir.
- Beklenen: birkaç saniye içinde B'de yeni ad görünür.
- Log'da (sonraki tur): B'de `CloudSync: pull +1`.

**2.2 Silme.** A'da bir kart sil.
- Beklenen: B'den kalkar.

**2.3 Ters yön.** B'de bir kart düzenle.
- Beklenen: A'ya gelir.

**2.4 Savaş (atlanmaması gereken test).** A'da savaş başlat: 3–4 combatant,
birkaç tur ilerlet, HP düşür, bir combatant'a durum etkisi ver (Poisoned vb.).
A'yı tamamen kapat. B'de dünyayı aç, savaş ekranına git.
- Beklenen: sıra, tur, HP ve durum etkileri A'da bıraktığın gibi.

**2.5 Çatışma.** A'yı **uçak moduna** al. A'da bir kartın açıklamasını "A"
yap. 1 dk sonra B'de aynı kartın açıklamasını "B" yap. Sonra A'nın internetini
aç, dünyayı kapatıp yeniden aç.
- Beklenen: iki cihazda da "B" (sonra düzenlenen kazanır, varış sırası değil).

**2.6 Düzenlenmiş dünyanın yeniden indirilmesi (Faz 5c).** 2.0'dan farkı:
artık dünyada düzenleme, silme ve savaş var. B'yi yeniden sıfırla (§0'daki
uyarı), DM hesabıyla gir, 2.0'daki gibi indir.
- Beklenen: dünyayı aç. 2.1–2.5'teki değişiklikler, oturumlar, mind map ve
  2.4'teki savaş (sıra, tur, HP, durum etkileri) A'daki gibi.
- Beklenen: `revision` B'yi açınca artmıyor.
- Log'da (sonraki tur): `CloudSync: indirme <W> +N … ms`; `push <W> ↑N`
  görünürse N 0.

---

## 3. Dünya medyası — DM (A + B)

**3.1 Onaylı sayı.** A'da dünya açık. 0.6'dan 1–2 dk sonra:

```sql
select uploaded, count(*) from world_media where world_id = '<W>' group by 1;
```

- Beklenen: `true` satırı 0.6'daki N kadar (200 civarı); `false` satırı ya
  hiç yok ya da 0'a iniyor.
- Beklenmeyen: `false` sayısı sabit kalıyorsa Hata Bildir'deki log'u getir.
- Log'da (sonraki tur): `CloudSync: medya <W> ↑N`, tur bitince bir kez;
  eksik yoksa hiç yazılmaz.

**3.2 Yeni görsel.** A'da bir karta `01-kucuk/kucuk-1.jpg` ekle.
- Beklenen: B'de o kartı aç: "KÜÇÜK 1" yazan görsel gelir. Hemen gelmezse
  **ekranı kapatmadan** en çok ~30 sn bekle; kendiliğinden gelmeli. 3.1'deki
  `true` sayısı 1 arttı.

**3.3 Limit uyarısı.** A'da bir karta `03-kart-limit/kart-7MB-limit-ustu.jpg`
ekle. Başka bir karta `kart-4.8MB-sinir-alti.jpg`.
- Beklenen: A'da ~3 sn sonra "Boyut limitinin üstünde, oyunculara
  gitmeyecek: …" snackbar'ı, yalnız 7 MB'lık için. B'de 7 MB'lık kırık ikon,
  4.8 MB'lık geliyor. A'da ikisi de normal görünür.

**3.4 Harita.** A'da dünya haritasını `04-harita/harita-8MB.jpg` yap.
Ardından bir encounter'a savaş haritası arka planı olarak
`savas-haritasi-3MB.jpg` koy.
- Beklenen: ikisi de B'ye gelir (harita sınıfının limiti 10 MB, kartınki 5).
  Dünya haritası ekrana sığmamış açılırsa "görünümü sıfırla" düzeltir
  (bilinen sınır).
- İsteğe bağlı: haritayı `harita-12MB-limit-ustu.jpg` yap → limit
  snackbar'ı, B'de eski harita ya da kırık ikon. Sonra Aegis'in kendi
  haritasına (`Maps/Aegis.webp`) ya da 8 MB'lığa geri dön.

**3.5 DM çevrimdışıyken ikinci cihaz.** A'yı tamamen kapat. B'de dünyayı
kapatıp aç, kartları kaydır, dünya haritasına ve savaş haritasına git.
- Beklenen: bütün görseller geliyor, kırık ikon yok.
- Log'da (sonraki tur): B'de `AssetRefResolver: ... indirilemedi` yok.

**3.6 Kotayı aşan dünya.** 0.5'te yapıldı.

**3.7 Limit üstü listesi (Faz 5d).** A'da Deneme → Multiplayer On. 9.3 ve
11.2 bu online Deneme'yi kullanıyor.
- Beklenen: "Dünya medyası yükleniyor n/N" overlay'i doluyor. Bitince limit
  üstü dosyaların listesi: `kart-7MB-limit-ustu.jpg` (0.8). 8 MB'lık harita
  listede **yok**.

```sql
select id from worlds where world_name = 'Deneme';    -- <Deneme id>
select count(*), sum(bytes) from world_media
 where world_id = '<Deneme id>' and uploaded;   -- limit altı dosya sayısı
```

---

## 4. Yarım kalan yükleme (A + B)

Tasarım belgesindeki (§4.8.3) 8. adım. Asıl sorulan şey: "internet kesildi, eksikler sonra
yüklenecek mi?"

Her tur **ayrı set** kullanıyor: aynı görsel aynı sha256, bulutta zaten
varsa yüklenecek bir şey kalmaz ve test boşa geçer. Görselleri tek seferde
çoklu seçimle ekle.

**4.1 Uygulama açıkken bağlantının geri gelmesi.**
1. A'da dünya açık. Yeni bir kart (**Yükleme-1**) aç ve ona
   `02-orta-tur1/`'in 15 görselini ekle.
2. Görselleri ekledikten **2–3 sn sonra**, hepsi yüklenmeden A'nın
   internetini kes.
3. 1 dk bekle, interneti geri aç. Uygulamaya ve dünyaya dokunma.
4. En çok 10 dk bekle.

Kontrol:

```sql
select uploaded, count(*) from world_media where world_id = '<W>' group by 1;
```

- Beklenen: kesinti sırasında A'nın kayıt simgesi üstü çizili bulut (§11.3).
  İnternet gelince en çok ~10 dk içinde bulut-tik. `true` sayısı 15 artar,
  `false` 0'a iner. B'de Yükleme-1 15 görseliyle ("ORTA 1-01 … 1-15") gelir.
- Yükleme kesintiden önce bitmişse (`true` hemen +15) test geçersiz: bir
  sonraki sette interneti daha erken kes.
- Log'da (sonraki tur): `medya <W> hata=offline`, `30 sn sonra yeniden`
  (60, 120 … en çok 600), sonra `catchUp` ve `medya <W> ↑N`.

**4.2 Uygulamanın kapanıp açılması — dünyayı açmadan.**
1. 4.1'i **Yükleme-2** kartı ve `02-orta-tur2/` ile tekrarla, ama internet
   kesikken **uygulamayı tamamen kapat**.
2. Sorguyu çalıştır, `false` sayısını not et (> 0 olmalı).
3. İnterneti aç, uygulamayı aç. **Dünyayı açma**, hub'da bekle.

- Beklenen (Faz 5f): hub'dayken, dünya açılmadan sorgu tamamlanır (`false`
  → 0, `true` +15). Önceden bu ancak dünya açılınca oluyordu. B'de
  Yükleme-2 görselleriyle geliyor.
- Log'da (sonraki tur): `catchUp <W>`, ardından `medya <W> ↑N <bayt> … ms`.

**4.3 Hub'dayken bağlantının geri gelmesi.** 4.2'yi **Yükleme-3** ve
`02-orta-tur3/` ile tekrarla, ama uygulamayı internet **kapalıyken** aç.
Hub'da 1 dk bekle (sorgu değişmemeli), sonra interneti aç.
- Beklenen: dünya açılmadan sorgu tamamlanır, B'de Yükleme-3 geliyor.
- Log'da (sonraki tur): `bağlantı geri geldi`, `catchUp <W>`, `medya <W> ↑N`.

**4.4 Çevrimdışı açılan dünya.** İnternet kapalıyken A'da dünyayı aç, bir
kartın adını değiştir. Dünyayı kapatmadan interneti aç.
- Beklenen: A'nın simgesi üstü çizili buluttan birkaç saniyede bulut-tik'e
  döner; B'ye yeni ad gelir. Önceden bu, dünya yeniden açılana kadar
  gitmiyordu.
- Log'da (sonraki tur): `bağlantı geri geldi`, `catchUp <W>`, `push <W> ↑1`.

---

## 5. Oyuncu — katılım ve kart paylaşımı (A + P)

Temel akış. Faz 5.5b'nin ayrıntılı adımları (sırlar, gri kart, yerelde
doğrulama, DM'in ikinci cihazı) §15'te.

Zip'teki blueprint 54 kartı paylaşıma işaretli getiriyor; 0.6'da
multiplayer açılınca bunlar (ilişki zinciriyle birlikte) oyunculara açıldı.
5.2 ve 5.3 için menüsünde "Paylaş" **işaretsiz** kart seç.

**5.1 Katılım.** A'da dünyanın Multiplayer bölümünden davet kodunu kopyala.
P'de hub → Dünyalar → "Katıl" → kodu gir.
- Beklenen: "\"Aegis — Meridia: Birinci Perde\" dünyasına katıldın" ve
  "Oyuncu olarak katıldın".
- Beklenen: P'nin kenar çubuğunda tohum kartları (0.7'deki `entity_shares`
  sayısı kadar) görselleriyle; hiçbirinde Secrets / DM Notes yok.

**5.2 Kart paylaşma (görselli).** A'da **görseli olan**, paylaşılmamış bir
kartın menüsünde "Paylaş"ı işaretle.
- Beklenen: A'da "Tüm oyuncularla paylaşıldı" snackbar'ı. P'de kart görünür,
  görseli de gelir.

```sql
select count(*) from entity_shares where world_id = '<W>';  -- 1 artar
```

**5.3 İkinci kart.** Başka bir homebrew kartın menüsünde "Paylaş"ı işaretle.
- Beklenen: P'de görünür. (Tek tek oyunculara paylaşma bugün arayüzde yok;
  sunucu `shared_with`'i destekliyor ama onu yazan diyalog kullanılmıyor.)

**5.4 Paylaşılan karta sonradan görsel.** A'da 5.2'deki karta **yeni** bir
görsel ekle (`01-kucuk/kucuk-2.jpg`).
- Beklenen: P'de karttaki görsel güncellenir. Kırık ikon çıkarsa ekranı
  kapatmadan ~30 sn bekle, kendiliğinden gelmeli.

**5.5 Paylaşılan kartın düzenlenmesi.** A'da 5.2'deki kartın açıklamasını
değiştir.
- Beklenen: P'ye gelir.

**5.6 Gizli alan.** Paylaşılan kartta DM'e özel (secret) bir alan varsa
doldur.
- Beklenen: P'de o alan **görünmez**. Bu bir gizlilik testi; görünürse hemen
  dur ve bana getir.

**5.7 Paylaşımı kaldırma.** A'da 5.3'teki kartın menüsünde "Paylaş"
işaretini kaldır.
- Beklenen: A'da "Oyuncularla paylaşım durduruldu". P'de kart **kalkmaz**,
  soluk görünür; üstüne gelince "DM bu kartı artık paylaşmıyor" (§2.5,
  ayrıntısı §15.4).

**5.8 DM çevrimdışıyken oyuncu.** A'yı tamamen kapat. P'de uygulamayı kapatıp
aç, dünyaya gir.
- Beklenen: paylaşılan kartlar görselleriyle orada, savaş haritası da.

---

## 6. Oyuncu — karakter (A + P)

**6.1 Karakter yaratma.** P'de hub → Karakterler → yeni karakter. Sihirbazı
sonuna kadar götür, kaydet. Bu sihirbaz SRD paketini kullanıyor. Gerekli
kartlar P'de yoksa (tür, sınıf listesi boş gelirse) not et, ayrı bir sorun.
- Beklenen: karakter P'nin listesinde.

**6.2 Dünyaya aktarma.** P'de dünyanın Karakterler kenar çubuğu → "Karakter
İçe Aktar" → 6.1'deki karakter.
- Beklenen: "\"<ad>\" bu dünyaya aktarıldı". A'nın dünyasında da görünür.

```sql
select id, template_name, owner_id, updated_at, referenced_entity_ids
  from world_characters where world_id = '<W>';
```

- Beklenen: `owner_id` P'nin hesabı; `updated_at` düzenleme saati (sunucu
  saati değil); `referenced_entity_ids` gerçek bir dizi, tırnaklı string değil.

**6.3 DM'in yarattığı karakter.** A'da dünyada bir karakter yarat, menüsünden
"Oyuncuya ata..." → P. Ya da atamadan bırak ve P'de "Sahiplenilebilir"
listesinden "Sahiplen".
- Beklenen: P'de "Karakterin" altında görünür.

**6.4 Karakter düzenleme, iki yön.** P'de karakterin HP'sini değiştir →
A'ya gelir. A'da o karakterin bir alanını değiştir → P'ye gelir.

**6.5 Çevrimdışı düzenleme (atlanmaması gereken test).** P'yi uçak moduna al.
Karakterde HP ya da ekipman değiştir, kaydet. İnterneti aç, dünyayı kapatıp aç.
- Beklenen: değişiklik buluta çıkar (6.2'deki sorgu, `updated_at` ilerler) ve
  A'ya gelir. Eski sistemde bu düzenleme sessizce kayboluyordu.

**6.6 Karakter görseli.** Karaktere portre ekle (`05-portre/portre-1.jpg`).
İsteğe bağlı: `portre-5MB-limit-ustu.jpg` (portre limiti 4 MB) → limit
uyarısı, A'da kırık ikon.
- Beklenen: A'da birkaç saniyede görünür. Faz 5g'den beri karakter medyası
  bulutta (`characters/{id}/`); ayrıntısı §13.7 ve §13.12.

**6.7 Savaşta oyuncu.** A'da bir encounter'a P'nin karakterini ekle, savaşı
başlat, P'ye projekte et.
- Beklenen: P savaş haritasını ve kendi token'ını görür. Bunu zaten denedin;
  karakter eklenmiş haliyle tekrar bak.

---

## 7. Paketler (A + B)

**7.1 Paketi online yapma.** A'da birkaç kartlık yeni bir paket aç (SRD Core
2721 kart, yavaş). Paketi aç → Save & Sync → "Paketi Online Yap".

```sql
select id, name, revision from user_packages;
select count(*) from user_package_entities where package_id = '<paket id>';
select count(*) from user_package_schemas  where package_id = '<paket id>';
```

- Beklenen: kart ve şema sayısı yereldekiyle tutar; satırların `owner_id`'si
  oturumun uid'i.

**7.2 Paket düzenleme.** A'da bir kartın adını değiştir, bir kart sil; B'de
paketi aç.
- Beklenen: ikisi de yansır. Paket görselleri 5e'den beri B'de **gelir**
  (§12).
- Beklenen: silinen kart bulutta da yok:
  `select count(*) from user_package_entities where package_id = '<paket id>'`
  bir azaldı.

**7.3 Yarıda kalan indirme (5c'nin tek eksiği).** B'yi sıfırla (§0'daki
uyarı — paketi ya da dünyayı uygulamadan **silme**). Hub → "Bulutta, bu
cihazda yok" → İndir. İlerleme çubuğu yarıdayken B'nin internetini kes.
- Beklenen: yarım dünya/paket listede **görünmez**. İnternet gelince tekrar
  "İndir" çalışır ve tamamlanır.

---

## 8. Ölçüm (Faz 5f'ye veri)

**Bu tur yalnız kronometre.** Log satırlı ölçümler (aşağıdaki
`CloudSync:` satırları) log'lu tura kaldı. Bu turda şunları elle tut, cihazı
(A masaüstü / B telefon) ve bağlantıyı (Wi-Fi / mobil) yanına yaz:
- 0.6 Multiplayer On → overlay'in kapanması.
- 2.0 İndir → dünya yerel listede; aç → ekrandaki bütün görseller geldi.
- Dünyayı açma: hub'da tıkla → kart listesi görünür (A ve B'de üçer kez).
- 4.1'deki 15 görselin internet gelince B'de görünmesi.

Log'lu turda: her satırı olduğu gibi kopyala.

- [ ] **Dünya açılışı.** A'da ve B'de dünyayı üç kez aç-kapat:
      `açılış <W> yerel=… ms toplam=… ms`. `toplam − yerel` bulut beklemesi.
- [ ] **Multiplayer aç.** 0.6'daki iki satır (Aegis; 3.7'deki Deneme de):
      `multiplayer açıldı <id>: N satır … ms` ve
      `multiplayer medya <id> ↑N <bayt> … ms (toplam)`.
- [ ] **Arka plan yüklemesi.** A'da bir karta 10–15 görsel ekle:
      `medya <W> ↑N <bayt> … ms`.
- [ ] **Satır turu.** Aynı sırada `push <W> ↑N ✕M … ms` ve B'de
      `pull <W> +N -M rev=… ms`.
- [ ] **İkinci cihazın ilk senkronu.** B'de dünyanın sıfırdan indirilmesi
      (7.3'ün kesintisiz hali): `indirme <W> +N … ms`. Görsellerin gelmesi
      log'da tek satır değil; dünyayı açıp kartları kaydırırken ekrandaki
      bütün görsellerin gelmesini kronometreyle tut.
- [ ] Cloudflare paneli → Workers → `dmt-assets` → istek sayısı. 3.1 ve 3.5
      sırasında istek sayısı tek haneli olmalı (200 görsel ≈ 2 imza isteği).
- [ ] (İsteğe bağlı) Genel profil: A'da `flutter run --profile`. Konsola 20
      sn'de bir `── PerfProbe ──` dökümü düşer (kare build/raster
      süreleri). Dünyayı aç, kart listesini kaydır, haritaya geç; o
      dakikaların dökümünü getir.

---

## 9. Yıkıcı adımlar — en son

**9.1 Yetim temizliği.** A'da 3.2'deki görseli karttan çıkar. **10 dk**
bekle, dünyayı kapatıp aç.

```sql
select count(*) from world_media where world_id = '<W>' and sha256 = '<sha>';
```

- `<sha>`: `kucuk-1.jpg` için `4ccfaa2d33ff49c2e38f8b8c6dd2f1c9923bf5b77d6091755fe25721f69d13a9`
  (yeniden ürettiysen `sha256sum 01-kucuk/kucuk-1.jpg`).
- Beklenen: 0. Görsel başka bir kartta da duruyorsa satır kalır, doğru
  davranış.

**9.2 Paket silme.** A'da 7.1'deki online paketi sil.
- Beklenen: `select * from user_packages where id = '<id>'` boş. B'de o
  paketi aç, bir kartı düzenle → B'deki paket offline'a düşer, bulutta
  yeniden belirmez.

**9.3 Multiplayer'ı kapatma.** Deneme'yle yap (3.7'de multiplayer açıldı),
asıl dünyayla değil; kapatma bütün üye verisini buluttan siler. Kopya
kullanma (§0). Deneme → "Çok Oyunculu Kapalı".

```sql
select count(*) from world_media where world_id = '<Deneme id>';            -- 0
select count(*) from r2_evict_queue where r2_key like 'worlds/<Deneme id>/%'; -- > 0
```

- Beklenen: en çok 1 saat sonra (cron) ikinci sorgu 0. Cloudflare → R2 →
  `dmt-assets` içinde `worlds/<Deneme id>/` boş.
- Beklenen: A'da Deneme yerel bir dünya olarak duruyor; kartları ve
  görselleri yerinde.

---

## 10. Faz 6 — LAN kalktı (tek cihaz, her platform)

Yıkıcı değil, istediğin zaman koşulabilir. Faz 6 bulut koduna dokunmadı;
buradaki şey silinen LAN'ın yanında giden bir şey olmadığını görmek.

**10.1 Eski veritabanı.** LAN kullanılmış (ya da kullanılmamış) eski bir
kurulumda uygulamayı aç.
- Beklenen: açılış normal, dünyalar yerinde. Veritabanında tablo yok:

```bash
sqlite3 "<dataRoot>/users/<uid>/db/dmt.sqlite" \
  "select name from sqlite_master where name = 'lan_paired_devices';"   # boş
```

**10.2 Menüler.** Profil menüsü ve bir dünyanın içindeki Save & Sync paneli.
- Beklenen: "Local Sync" hiçbir yerde yok; panel boşluk bırakmadan
  bitiyor.

**10.3 `.dmtz` gidiş-dönüş.** Görselli bir dünyayı dışa aktar, başka bir
kurulumda (ya da dünyayı sildikten sonra) içe aktar.
- Beklenen: kartlar, harita, görseller aynen geliyor. (Codec'ten yalnız
  LAN'ın kullandığı iki metot çıktı; bu adım bunu doğruluyor.)

**10.4 Masaüstü OAuth (macOS Release öncelikli).** Google ya da GitHub ile
giriş.
- Beklenen: tarayıcıdan dönüşte oturum açılıyor. macOS'ta `network.server`
  yetkisi bunun için kaldı; kırılırsa ilk bakılacak yer
  `macos/Runner/Release.entitlements`.

**10.5 Android.** Temiz kurulum.
- Beklenen: kamera izni hiç istenmiyor. Giriş, online dünya açma ve görsel
  yükleme çalışıyor — cleartext izni kalktı, Supabase ve R2 `https`
  olduğu için etkilenmemeli.

**10.6 iOS.** Temiz kurulum.
- Beklenen: "yerel ağdaki cihazları bulmak istiyor" sorusu çıkmıyor.

---

## 11. Faz 9 — işlem geri bildirimi (A, gerekirse B)

Çoğu adım §1–§7 koşulurken yan gözle bakılabilir. Simge, dünya ya da paket
içindeki araç çubuğundaki kayıt simgesi.

**11.1 Yerel dünya.** Multiplayer kapalı bir dünyada bir kart düzenle.
- Beklenen: simge eskisi gibi yalnız kayıt (dolu disket ↔ boş disket).
  Bulut simgesi **hiç** görünmüyor, 3 sn'de bir titreme yok.

**11.2 Online dünya — eşit ve eşitleniyor.** Multiplayer açık dünyada kart
düzenle, eli çek.
- Beklenen: kısa süre bulut-ok simgesi (eşitleniyor), sonra bulut-tik.
  Save & Sync diyaloğunda "BULUT · Son eşitleme HH:mm".
- Kapatma kısmını yalnız Deneme'de yap, Aegis'te değil (bulut verisini
  siler; 9.3 ile birleştirebilirsin): multiplayer'ı kapat → simge hemen
  yalnız kayda döner (bulut simgesi ya da rozet kalmaz). Aynısı online
  paketi "Yerele Al"la.

**11.3 Çevrimdışı bekliyor.** Online dünyadayken ağı kes, bir kart düzenle.
- Beklenen: simge üstü çizili bulut; tooltip "Çevrimdışı — değişiklikler bu
  cihazda kayıtlı…"; diyalogda Yeniden dene düğmesi. Ağı aç → birkaç saniye
  içinde bulut-tik'e döner. Ayrıca: **uygulamayı çevrimdışı aç**, online
  dünyayı aç, bir şey düzenle → yine "bekliyor".

**11.4 Sorun.** Ağ kesintisi sorun değil "bekliyor" sayılır; gerçek sorunu
zorlamak için online dünyada bir kartın açıklamasına 300 KB'tan uzun metin
yapıştır: `07-metin/aciklama-310KB.txt`'nin tamamı (bulut satır sınırı
256 KB). İsteğe bağlı: kotayı geçici düşür
(`online-sync-redesign.md` §4.8.4 doğrulama 5).
- Beklenen: kırmızı uyarı simgesi + rozette sayı; diyalogda kırmızı satır
  ("1 değişiklik buluta yazılamadı" / "Bulut medya alanı dolu"). Metni
  kısaltınca bir sonraki başarılı turda sorun kendiliğinden kalkar.

**11.5 Görsel nedeni.** B'de, A'nın henüz yüklemediği bir görseli olan kartı
aç (A'da görsel ekle, A'yı hemen kapat). Ayrıca ağ kapalıyken bulutta olan
ama B'ye inmemiş bir görsel.
- Beklenen: kırık görselin üstüne gelince (mobilde basılı tut) sırasıyla
  "Henüz bulutta değil…" ve "İndirilemedi — bağlantını kontrol et".

**11.6 Paket zaman aşımı.** Online bir paketi çok yavaş ağda aç (ya da
açarken ağı kes).
- Beklenen: 8 sn sonra paket açılıyor ve "Bulut eşitlemesi zamanında
  bitmedi…" snackbar'ı çıkıyor.

**11.7 `.dmtz`.** Büyük, görselli bir dünyayı dışa, sonra içe aktar.
- Beklenen: dosya seçiminden sonra ekranı kaplayan "… dışa aktarılıyor" /
  "İçe aktarılıyor…" overlay'i; bitince snackbar.

**11.8 Misafir → hesap.** Çıkış yap, misafir olarak bir dünya oluştur, giriş
yap.
- Beklenen: hub'a düşünce "Misafir olarak oluşturduğun … hesabına taşındı".

**11.9 Dil.** Uygulama dilini Türkçe yap; dünya aç/kapat, paket aç/oluştur.
- Beklenen: overlay'ler ("… dünyası açılıyor", "Kaydediliyor...") ve
  açılış ekranı Türkçe; İngilizce kalıntı yok.

---

## 12. Faz 5e — paket medyası ve arka plan uzlaştırması (A + B)

**12.0 Deploy — yapıldı.** Önce `supabase/migrations/100_package_media.sql`, sonra
`supabase/scripts/verify_100.sql` → `100 OK` (ve `verify_099.sql` → `099 OK`).
**Hemen ardından** `wrangler deploy` (arada imza ucu 502 döner). Sonra iki
cihazda da uygulamanın yeni derlemesi — eskisi dünya medyası yükleyemez.

**12.1 Hub'dan online yap.** A'da görselli (kart görseli, bir PDF alanı) bir
paket: kartlara `06-paket/paket-1.png`, `paket-2.png` ve
`paket-6MB-limit-ustu.jpg`. Hub → paketin ayarları (dişli) → "Paketi Online Yap".
- Beklenen: "Paket medyası yükleniyor n/N" overlay'i, bitince "Paket artık
  çevrimiçi". liste diyaloğunda ("öteki cihazlarına
  gitmeyecekler") yalnız `paket-6MB-limit-ustu.jpg`.

```sql
select count(*), sum(bytes) from world_media
 where package_id = '<paket id>' and uploaded;
```

**12.2 İkinci cihaz.** B'de hub → "Bulutta, bu cihazda yok" → paketi indir,
aç.
- Beklenen: kart görselleri ("PAKET 1", "PAKET 2") geliyor (çıkış kriteri
  1); 6 MB'lık kırık ikon.

**12.3 Açılmadan çıkış.** A'da paketi aç, interneti kes, bir kartın adını
değiştir ve yeni bir görsel ekle (`06-paket/paket-3-yeni.jpg`), paketi
kapat (hub'a dön). İnterneti aç.
- Beklenen: paketi açmadan, birkaç saniye içinde `world_media`'da yeni
  görselin satırı `uploaded` (12.1'deki sorgu +1) (çıkış kriteri 2). B'de
  paketi aç: yeni ad ve "PAKET 3" orada.
- Log'da (sonraki tur): `CloudSync: push paket … ↑` ve `pull paket …`.

**12.4 Açık paket çekilmez.** B'de paketi açık tut, A'da aynı paketin bir
kartını değiştir (A'da paket kapalıyken `reconcileAll` onu push eder).
B'de interneti kesip aç.
- Beklenen: B'nin açık ekranındaki kart **ezilmedi** (A'nın değişikliği
  görünmüyor). B paketi kapatıp yeniden açınca A'nın değişikliği görünür.
- Log'da (sonraki tur): B'de yalnız `push paket`, `pull paket` yok.

**12.5 Yerele al.** A'da hub → paketin ayarları → "Paketi Yerele Al".
- Beklenen: `world_media`'da paketin satırı kalmıyor, `r2_evict_queue`'da
  `packages/<id>/…` key'leri; cron'dan (≤1 sa) sonra R2'de `packages/<id>/`
  boş (çıkış kriteri 3). B'de paketi aç (ya da uygulamayı yeniden başlat):
  paket offline'a düşüyor, silinmiyor.

**12.6 Kota.** Kotayı geçici düşür (`online-sync-redesign.md` §4.8.4
doğrulama 5) ve görselli bir paketi online yapmayı dene.
- Beklenen: "Bu paketin medyası X yer istiyor, bulutta ise Y kaldı" ve paket
  yayınlanmıyor. Online bir pakete görsel ekleyince kota dolarsa "Bulut medya
  alanı dolu…" snackbar'ı (çıkış kriteri 4).

## 13. Faz 5g — karakterin kendi kapsamı (iki cihaz, SQL yok)

Bu bölüm baştaki A/B/P düzenini kullanmıyor. İki cihaz var, **X** ve **Y**;
iki hesap var, **H1** ve **H2**. Veritabanına bakılmıyor: "bulutta mı?"
sorusunun cevabı öbür cihazın ekranında.

- **Kısım A:** X ve Y ikisi de H1 ile açık, yani aynı kişinin iki cihazı.
- **Kısım B:** Y, H1'den çıkıp H2 ile giriyor. X'teki H1 DM, Y'deki H2
  oyuncu oluyor. Hesap değişince Y'deki H1 verisi silinmiyor; her hesabın
  cihazda ayrı veritabanı var.

"Birkaç saniye" en çok 5 sn demek. Karakter düzenlemeden 1 sn sonra gidiyor,
öbür cihaz sinyali aldıktan 1 sn sonra çekiyor. 10 sn'yi geçerse ❌.

Log isteğe bağlı. Bir adım ❌ olursa o anki `CloudSync` satırlarını Hata
Bildir → "Son günlükler"den kopyala.

**13.0 Hazırlık**
- [x] Deploy sırası (yapıldı): `100` → `101_character_scope.sql` → `wrangler deploy`.
      Sonra iki cihaza da yeni derleme. Eski derleme karakteri eski yoldan
      yazar; öyle bir cihaz varsa test geçersiz.
- [ ] X'te multiplayer'ı kapalı bir dünya: **Yerel**. Karakter yaratmak bir
      dünya istiyor.
- [ ] X'te iki farklı portre görseli: `05-portre/portre-1.jpg`, `portre-2.jpg`.

### Kısım A — aynı hesap (X: H1, Y: H1)

**13.1 Anahtar kapalı başlıyor.** X'te Yerel dünyasında **K1** adında
karakter yarat ve portre koy. Hub → Karakterler → K1'in dişlisi.
- Beklenen: "Karakteri Online Yap" düğmesi görünüyor.
- Beklenen: Y'de hub → Karakterler'in altındaki "Bulutta, bu cihazda yok"
  bölümünde K1 **yok** (çıkış kriteri 4).

**13.2 Online yap.** X'te K1'in dişlisi → "Karakteri Online Yap".
- Beklenen: X'te "Karakter artık çevrimiçi" mesajı çıkıyor, düğmenin yerine
  "Karakter çevrimiçi" rozeti geliyor.
- Beklenen: Y'de, uygulamayı yeniden açmadan, birkaç saniye içinde
  "Bulutta, bu cihazda yok" altında K1 görünüyor.

**13.3 İndir.** Y'de K1 → "İndir". Sonra K1'i aç.
- Beklenen: K1 açılıyor. Yerel dünyası Y'de olmadığı halde "dünya
  bulunamadı" uyarısı çıkmıyor.
- Beklenen: portre birkaç saniye içinde geliyor (çıkış kriteri 2).
- Beklenen: K1 "Bulutta, bu cihazda yok" listesinden çıkıyor; dişlisinde
  "Karakter çevrimiçi" yazıyor.

**13.4 Canlı, X'ten Y'ye.** K1 iki cihazda da açık. X'te HP'yi değiştir.
- Beklenen: Y'de yeni HP birkaç saniye içinde, ekrandan çıkmadan
  (çıkış kriteri 1).

**13.5 Canlı, Y'den X'e; dünya bağı.** Y'de K1'in HP'sini değiştir.
- Beklenen: X'te değer birkaç saniye içinde değişiyor.
- Beklenen: X'te K1'in dişlisinde dünya hâlâ "Yerel". "Dünya atanmamış"
  yazıyorsa Y karakteri dünyasından koparmış demek: ❌.

**13.6 Hızlı düzenleme.** X'te HP'yi art arda, aralarında 1 sn'den az
bekleyerek 6–8 kez değiştir, sonra dur.
- Beklenen: Y'de birkaç saniye içinde **son** değer görünüyor. X'e bir daha
  dokunmadan da doğru olmalı. Bu adım incelemede düzeltilen bir hatanın
  testi: tur sürerken aynı saniyede yapılan düzenleme kayboluyordu.

**13.7 Portre değişimi.** X'te K1'in portresini ikinci görselle değiştir.
- Beklenen: Y'de birkaç saniye içinde yeni portre geliyor. Gelmezse
  karakteri kapatıp aç; o zaman da gelmezse ❌.

**13.8 Çevrimdışı düzenleme.** Y'de interneti kes, K1'in HP'sini değiştir
ve uygulamayı kapat. İnterneti aç, Y'de uygulamayı aç ama K1'e dokunma.
- Beklenen: X'te Y'nin değeri birkaç saniye içinde görünüyor (çıkış
  kriteri 3).

**13.9 Yerele al.** X'te K1'in dişlisi → "Karakteri Yerele Al" → onayla.
- Beklenen: X'te "Karakter artık yalnızca yerel" mesajı çıkıyor, düğme
  "Karakteri Online Yap" oluyor.
- Beklenen: Y'de K1 duruyor, çöpe gitmiyor; birkaç saniye içinde
  dişlisinde "Karakteri Online Yap" görünüyor.
- Beklenen: X'te K1'in HP'sini değiştir. Y'de değişmiyor (çıkış kriteri 4).

**13.10 Silme yayılır.** X'te **K2** yarat, online yap, Y'de indir. Sonra
X'te K2'yi sil.
- Beklenen: Y'de K2 birkaç saniye içinde Karakterler'den kalkıyor ve
  Ayarlar → Çöp Kutusu'nda görünüyor. Oradan geri yüklenebiliyor.

**13.10b Dünyasız karakter.** X'te hub → Karakterler → yeni karakter;
sihirbazın dünya seçicisinde dünya yerine "Yerleşik SRD (varsayılan)"ı
bırak. **K3**'ü kaydet, online yap; Y'de indir. İki cihazda da
K3 açıkken X'te HP'yi değiştir.
- Beklenen: Y'de birkaç saniyede değişiyor — canlı senkron dünyasız
  karakterde de (çıkış kriteri 1). K3'ün dişlisinde dünya atanmamış.

### Kısım B — farklı hesap (X: H1 DM, Y: H2 oyuncu)

Y'de H1'den çık, H2 ile gir.

**13.11 Masa.** X'te **Masa** adında dünya yarat, multiplayer'ı aç, davet
kodunu kopyala. Y'de "Dünyaya Katıl" ile kodu gir.
- Beklenen: Y'de "Masa dünyasına katıldın" mesajı.

**13.12 Oyuncunun karakteri.** Y'de Masa'da **P1** adında karakter yarat ve
portre koy.
- Beklenen: X'te P1, Masa'nın karakter listesinde birkaç saniye içinde
  portresiyle görünüyor.
- Beklenen: Y'de P1'in dişlisinde ya da Save & Sync diyaloğunda
  "Çevrimiçi — dünyası multiplayer" yazıyor; kapatma düğmesi yok.

**13.13 Canlı, oyuncudan DM'e.** Y'de P1'in HP'sini değiştir.
- Beklenen: X'te değer birkaç saniye içinde değişiyor.

**13.14 Canlı, DM'den oyuncuya.** X'te Masa'da bir karşılaşma aç, P1'i ekle,
HP'sini savaş ekranından değiştir. Y'de P1 açık olsun.
- Beklenen: Y'de yeni HP birkaç saniye içinde görünüyor.

**13.15 Oyuncunun çevrimdışı düzenlemesi.** Y'de interneti kes, P1'in
HP'sini değiştir ve uygulamayı kapat. İnterneti aç, Y'de uygulamayı aç ama
P1'e dokunma.
- Beklenen: X'te Y'nin değeri birkaç saniye içinde görünüyor (çıkış
  kriteri 3).

**13.16 DM'in koyduğu portre, DM'in bırakması.** X'te Masa'da **D1** adında
karakter yarat ve portre koy. Birkaç saniye bekle. X'te hub → Karakterler →
D1 → "Bırak" → onayla. Y'de Masa'nın karakter listesinde D1 →
"Sahiplen".
- Beklenen: X'te D1 bıraktıktan sonra Masa'nın listesinde, sahipsiz olarak
  duruyor. Kaybolursa bu kapatılan "DM'in cihazı karakteri buluttan siliyor"
  hatası: ❌.
- Beklenen: D1 Y'nin Karakterler sekmesinde portresiyle görünüyor (çıkış
  kriteri 2'nin ikinci yarısı).

**13.17 Oyuncu bırakıyor, karakter dünyada kalıyor.** Y'de P1 → "Bırak" →
onayla. Birkaç saniye bekle, X'te Masa'da herhangi bir şeyi düzenle, yine
bekle.
- Beklenen: P1 Y'nin Karakterler sekmesinden kalkıyor.
- Beklenen: X'te P1 Masa'nın listesinde sahipsiz olarak duruyor. X'i kapatıp
  açınca da duruyor.
- Sonra Y'de P1'i yeniden "Sahiplen". 13.18 bunu kullanıyor.

**13.18 Multiplayer'ı kapat (yıkıcı, en son).** X'in Masa'da kendine ait
bir karakteri olsun: **D2** yarat. Sonra X'te Masa → "Çok Oyunculu Kapalı" →
onayla.
- Beklenen: hata mesajı çıkmıyor.
- Beklenen: X'te D2 duruyor; dişlisinde kilit kalkmış, "Karakter çevrimiçi"
  ve "Karakteri Yerele Al" görünüyor.
- Beklenen: Y'de P1 duruyor, açılıyor, dişlisinde "Karakter çevrimiçi"
  yazıyor. Silinmişse ❌: sahipli karakter multiplayer kapanınca online
  kalmalı.

**13.19 Kapanış: sahipli karakter bulutta kaldı mı.** Y'de H2'den çık, H1
ile gir. Hub → Karakterler.
- Beklenen: "Bulutta, bu cihazda yok" altında D2 var. Bu, D2'nin Masa
  kapandıktan sonra da bulutta kaldığını gösteriyor. İndir; portresi ve HP'si
  X'teki gibi olmalı.
- Beklenen: K1 bu listede yok (yerele alındı, Y'de zaten var), K2 de yok
  (silindi).

## 14. Faz 5.5a — oyuncunun ikinci cihazı, davet kodsuz (iki cihaz, SQL yok)

§13'ün düzeni: cihazlar **X** ve **Y**, hesaplar **H1** (DM) ve **H2**
(oyuncu). Oyuncunun "ikinci cihazı" X'te H2'ye geçilerek elde ediliyor: her
hesabın cihazda ayrı veritabanı var, X'teki H2 veritabanı boş. Oyuncunun
dünyayı hub'dan silmesi **dünyadan ayrılmak** demek, onunla taklit edilemez.

**14.0 Hazırlık**
- [ ] İki cihazda da yeni derleme. Migration ya da worker değişmedi.
- [ ] §13 Kısım B'nin sonundaki gibi: X'te H1'in multiplayer dünyası
      **Masa**, Y'de H2 Masa'ya katılmış ve portreli bir karakteri var
      (**P1**). DM Masa'da en az bir kartı paylaşmış.

**14.1 Liste.** X'te H1'den çık, H2 ile gir. Hub → Dünyalar.
- Beklenen: "Bulutta, bu cihazda yok" altında Masa var. Açıklama metni
  oyuncu olarak katılınan dünyaları ve "davet kodu gerekmez"i anıyor.
- Beklenen: H1'in başka dünyaları bu listede yok.

**14.2 Kabuk.** Masa'nın yanında İndir.
- Beklenen: bir iki saniyede "indirildi" bildirimi; Masa yerel listeye
  geçiyor, buluttaki listeden düşüyor. Davet kodu sorulmuyor.

**14.3 İçerik.** Masa'yı aç.
- Beklenen: oyuncu ekranı açılıyor (DM ekranı değil).
- Beklenen: Karakterler sekmesinde "Your" altında P1, portresiyle. P1 için
  "Available to Claim" altında ikinci bir kopya yok.
- Beklenen: DM'in paylaştığı kart görünüyor. Log'da
  `CloudSync: paylaşılan kartlar <dünya> +N` (N paylaşılan homebrew kart
  sayısı; boş cihaz hepsini indiriyor). Masa'dan çıkıp yeniden girince `+0`.

**14.4 Canlı.** Y'de (H2) P1'in HP'sini değiştir.
- Beklenen: X'te P1 açıkken birkaç saniyede değişiyor (5g'nin sahip kapsamı).

**14.5 Geri dönüş.** X'te H2'den çık, H1 ile gir. Masa'yı aç → üyeler.
- Beklenen: H2 üyelerde bir kez görünüyor. Masa'nın davet kodu hâlâ
  çalışıyor (tek kullanımlıksa ve §13'te kullanıldıysa zaten tükenmişti; bu
  adımda bir hak daha gitmemeli — emin değilsen atla).

## 15. Faz 5.5b — oyuncunun kartları buluttan (iki cihaz, SQL yok)

Kartın gövdesi artık paylaşım satırından değil, DM'in bulut aynasından
(`get_shared_entities`) geliyor ve oyuncunun cihazına yazılıyor. Sır alanları
sunucuda kırpılıyor. Açılışta yalnız doğrulama: değişmeyen kart yeniden inmez.
Düzen §14 gibi: X'te **H1** (DM), Y'de **H2** (oyuncu), dünya **Masa**.

**15.0 Hazırlık**
- [x] 102 ve 103 uygulandı (2026-10-02). İsteğe bağlı:
      `supabase/scripts/verify_103.sql` → `103 OK`. İki cihaz da yeni
      derlemede olmalı (eski sürümün paylaşımı 103'ten sonra düşer).
- [ ] İki cihazda da yeni derleme. Worker değişmedi.
- [ ] X'te Masa'da bir NPC kartı **K1** yarat: portre koy, açıklama yaz,
      "Secrets (DM-only)" alanına `GİZLİ-1`, DM Notes'a `GİZLİ-2` yaz.
      Kartın menüsünde "Paylaş"ı işaretle.

**15.1 Paylaşım.** Y'de Masa açık.
- Beklenen: K1 birkaç saniyede kenar çubuğunda beliriyor (yeni kart DM'in
  push turunu bekliyor, ~3–5 sn). Açıklama ve portre görünüyor.
- Beklenen: kartta ne `GİZLİ-1` ne `GİZLİ-2` var; Secrets ve DM Notes
  bölümleri hiç yok.

**15.2 Düzeltme yeniden paylaşmadan gidiyor.** X'te K1'in açıklamasını
değiştir, paylaşıma dokunma.
- Beklenen: Y'de K1 açıkken birkaç saniyede yeni açıklama.
- X'te K1'in Secrets alanını değiştir (`GİZLİ-3`). Beklenen: Y'de hiçbir yerde
  görünmüyor.

**15.3 Eski kartı paylaşmak.** X'te uzun zamandır duran, hiç paylaşılmamış bir
kart **K2**'yi paylaş.
- Beklenen: Y'de birkaç saniyede beliriyor.

**15.4 Geri çekme — gri kart.** X'te K1'in paylaşımını kapat.
- Beklenen: Y'de K1 kenar çubuğunda kalıyor ama soluk; üstüne gelince
  "DM bu kartı artık paylaşmıyor". Açınca kartın en üstünde aynı etiket.
- X'te K1'i yeniden paylaş. Beklenen: Y'de soluk hâl ve etiket kalkıyor.

**15.5 Yeniden açılış.** K1'in paylaşımını tekrar kapat. Y'de Masa'dan çık,
yeniden gir.
- Beklenen: K1 hâlâ gri ve etiketli. K2 var.
- Beklenen: log'da `CloudSync: paylaşılan kartlar <dünya> +0` (hiçbir kart
  yeniden inmedi).
- X'te K1'i geri çekiliyken düzenle, sonra yeniden paylaş. Beklenen: Y'de gri
  hâl kalkıyor ve yeni hali geliyor.

**15.5b Çevrimdışı açılış.** X'te K1'in paylaşımını yeniden kapat (Y'de
griye döner). Y'nin ağını kes, uygulamayı kapatıp aç, Masa'yı aç.
- Beklenen: K1 ve K2 görünüyor (kartlar cihazda). K1 çevrimdışıyken gri
  **değil**: gri hâli paylaşım listesi veriyor, liste ağdan geliyor (bilinen
  sınır). Ağı aç — K1 griye dönüyor.

**15.6 Çevrimdışı.** Y'nin ağını kes, X'te K2'yi düzenle, Y'nin ağını aç.
- Beklenen: kanal yeniden bağlanınca K2'nin yeni hali geliyor. Log'da
  `CloudSync: paylaşılan kartlar ... offline` satırı kesinti sırasında
  görülebilir.

**15.7 DM kartı siliyor.** X'te K2'yi sil.
- Beklenen: Y'de K2 birkaç saniyede soluk ve etiketli ("DM bu kartı artık
  paylaşmıyor"); kalkmıyor. Normal görünmeye devam ederse ❌ — paylaşım
  satırı silmede duruyor, gri hâli doğrulamanın listesi veriyor.

**15.8 Yeni kart diyaloğundan paylaşım.** X'te kenar çubuğundan yeni bir NPC
kartı **K3** yarat; diyalogdaki "Oyuncularla paylaş" kutusu işaretli gelir,
öyle bırak.
- Beklenen: K3 Y'de birkaç saniyede beliriyor.
- Beklenen: aynı diyalogda Monster kategorisini seçince kutu işaretsiz
  geliyor (canavar ve loot kendiliğinden paylaşılmaz).

**15.9 İlişki zinciri.** X'te paylaşılmamış bir NPC kartı **K4** yarat.
Başka bir homebrew kart **K5**'in bir ilişki alanına (ör. Location ya da
Faction) K4'ü bağla, sonra yalnız K5'i paylaş.
- Beklenen: Y'de K5 ve K4 ikisi de görünüyor; K5'teki ilişki satırı boş
  değil, K4'e açılıyor. (X'te K4'ün menüsünde "Paylaş" işaretsiz kalır:
  zincir yalnız bulut satırını yazıyor, DM'in işaretini değil — bugünkü
  davranış.)

**15.10 Paket kartı.** X'te bir SRD kartını (ör. bir canavar) aç, menüsüne
bak.
- Beklenen: "Yerleşik — her zaman paylaşılır" (işaretli, değiştirilemez).
  Y'de aynı kart paylaşmaya gerek kalmadan görünüyor: gövdesi Y'nin kurulu
  SRD paketinden gelir, buluttan inmez (log'daki `+N` artmaz).

**15.11 Önceden işaretleme (publish tohumu).** X'te multiplayer kapalı yeni
bir dünya **Tohum** yarat, iki homebrew kart ekle. Birinin menüsünde
"Paylaş"ı işaretle.
- Beklenen: "Paylaşıma işaretlendi — dünya online olunca gidecek".
- Tohum'da multiplayer'ı aç, davet kodunu Y'ye ver, Y katılsın, Tohum'u
  açsın. Beklenen: Y'de yalnız işaretli kart görünüyor, öteki yok.

**15.12 DM'in ikinci cihazı — sırlar yerinde.** Y'de H2'den çık, H1 ile gir.
Hub → Dünyalar → "Bulutta, bu cihazda yok" → Masa → İndir, aç. K1'i aç.
- Beklenen: K1'in Secrets'ında `GİZLİ-3`, DM Notes'unda `GİZLİ-2` duruyor;
  portre görünüyor. Sırlar boşsa ❌: DM'in cihazına oyuncu için kırpılmış
  kart yazılmış demek.
- X'te K1'in açıklamasını değiştir. Beklenen: Y'de (H1) yeni açıklama
  geliyor, sırlar hâlâ yerinde.
- Bitince Y'de H1'den çıkıp H2'ye dönebilirsin.

**15.13 Aynı katalog dünyası iki tarafta (isteğe bağlı).** X'te resmi
katalogdan bir dünya kur, multiplayer aç, bir **homebrew** kartını paylaş;
Y o dünyaya katılmadan önce aynı katalog dünyasını kendisi de kursun, sonra
davet koduyla katılsın.
- Beklenen: Y'nin kendi kopyasındaki o kart yerinde kalıyor, kaybolmuyor.
  X'in dünyasında o kart Y'de görünmüyor (bilinen sınır: katalog dünyasının
  kart id'leri iki cihazda aynı). Log'da
  `CloudSync: paylaşılan kart … başka dünyada, atlandı`.
- Aynı katalog dünyasını **tek cihaza iki kez** kurma: ikinci kurulum
  birincinin kartlarını kendine taşır (kopyalamadaki hatanın aynısı).

## 16. Yerel temeller — Faz 1 ve 2.5 (tek cihaz, SQL yok)

Yıkıcı değil. **Multiplayer'ı kapalı** dünya, paket ve karakterle yap:
online birini silmek bulut kopyasını da siler.

**16.1 `.dmtz` paket.** Görselli yerel bir paketi dışa aktar, paketi sil,
dosyayı içe aktar.
- Beklenen: paket kartları, şeması ve görselleriyle geri geliyor.

**16.2 `.dmtz` karakter.** Portreli yerel bir karakteri dışa aktar, sil,
içe aktar.
- Beklenen: karakter portresi ve bütün alanlarıyla geri geliyor.

**16.3 Birleştirme.** Yerel bir dünyayı dışa aktar. Sonra o dünyada bir
kartın (**M1**) açıklamasını değiştir ve başka bir kartı (**M2**) sil.
Dosyayı içe aktar.
- Beklenen: soru sorulmadan mevcut dünyanın üzerine birleşiyor; M2 geri
  geliyor (silme yayılmaz), M1 senin yeni açıklamanla kalıyor (sonra
  düzenlenen kazanır).

**16.4 Aynı adlı iki dünya.** **İkiz** adında iki dünya oluştur, ikisine de
farklı görselli birer kart koy. Biri açıp kapat, sonra ötekini.
- Beklenen: hub ikisini de listeliyor; her biri kendi kartını ve görselini
  açıyor. Birini kapatınca ötekinin görseli kırılmıyor (medya klasörü id
  ile ayrı).

**16.5 Yeniden adlandırma.** Görselli, oturumu ve kurulu paketi olan bir
dünyanın adını değiştir.
- Beklenen: görseller, oturumlar ve paketler duruyor.

---

## Sonuçları bana nasıl getireceksin

Her adım için ✅ ya da ❌. ❌ olanlarda:
- ne yaptın, ne bekliyordun, ne oldu;
- log: Hata Bildir → "Son günlükler"den seçip kopyala (terminal gerekmez;
  son 200 satır, ❌'dan hemen sonra al);
- ilgili SQL sorgusunun çıktısı (§13'te SQL yok).
