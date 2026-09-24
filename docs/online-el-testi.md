# Online — elle doğrulama listesi (2026-09-23)

`online-sync-redesign.md`'deki bütün "bekleyen doğrulama" maddeleri, tek
oturumda koşulacak sırayla. Yıkıcı adımlar (multiplayer'ı kapatma, paket
silme) en sonda.

**Cihazlar**

| Kısa ad | Ne | Hesap |
|---|---|---|
| **A** | DM'in bilgisayarı — görsellerin özgün dosyaları burada | DM hesabı |
| **B** | DM'in ikinci cihazı (telefon) | aynı DM hesabı |
| **P** | Oyuncu cihazı | **başka** bir hesap |

Aegis dünyasının id'si: `47272f9a-baf7-4eb6-acdf-267f8dfc6b4e`. Aşağıda
`<W>` bu id demek.

---

## 0. Hazırlık

- [ ] Üç cihazı da çalışma ağacının son haliyle ve üç `--dart-define`'la
      derle. Faz 5f'nin 1. kısmı (paralel yükleme, arka plan uzlaştırması,
      süre log'ları) henüz commit'lenmedi; derleme onu içermeli.
- [ ] Log'u açık tut. Masaüstünde `flutter run` konsolu; Android'de
      `adb logcat | grep -E "CloudSync|AssetRefResolver|WorldMediaSync"`.
      Her adımda log'u da not et.
- [ ] Supabase → SQL Editor'ü açık tut.
- [ ] A'da test görselleri hazırla:
  - Birkaç küçük görsel (< 1 MB).
  - Bir karta eklemek için 10–15 orta boy görsel (4. adım).
  - **5 MB'tan büyük** bir görsel.
  - **10 MB'tan küçük** bir harita görseli.
- [ ] Başlangıç sayıları. Buraya yaz, sonraki adımlar bunlarla kıyaslanacak:

```sql
select uploaded, count(*), sum(bytes) from world_media
 where world_id = '<W>' group by 1;
select revision from world_revisions where world_id = '<W>';
select count(*) from world_entities where world_id = '<W>';
```

---

## 1. Temel sağlık — tek cihaz (A)

**1.1 Migration doğrulamaları.** SQL Editor'de sırayla
`supabase/scripts/verify_096.sql` ve `verify_099.sql` dosyalarının içeriğini
çalıştır.
- Beklenen: `096 OK`, `099 OK`.

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

---

## 2. DM'in iki cihazı — içerik (A + B)

A ve B'de aynı dünya açık olsun.

**2.1 Canlı düzenleme.** A'da bir kartın adını değiştir.
- Beklenen: birkaç saniye içinde B'de yeni ad görünür. B'nin log'unda
  `CloudSync: pull +1`.

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

---

## 3. Dünya medyası — DM (A + B)

**3.1 Onaylı sayı.** A'da dünya açık. Log'da `CloudSync: medya <W> ↑N`
satırını bekle. Bu satır tur bitince **bir kez** yazılır; eksik yoksa hiç
yazılmaz. 1–2 dk sonra sorguya geç.

```sql
select uploaded, count(*) from world_media where world_id = '<W>' group by 1;
```

- Beklenen: `true` satırı yaklaşık 179; `false` satırı ya hiç yok ya da 0'a
  iniyor.
- Beklenmeyen: `false` sayısı sabit kalıyorsa log'daki hatayı getir.

**3.2 Yeni görsel.** A'da bir karta küçük bir görsel ekle.
- Beklenen: birkaç saniye sonra A'nın log'unda `CloudSync: medya ... ↑1`.
  B'de o kartı aç: görsel gelir. Hemen gelmezse **ekranı kapatmadan** en çok
  ~30 sn bekle; kendiliğinden gelmeli.

**3.3 Limit uyarısı.** A'da bir karta 5 MB'tan büyük görsel ekle.
- Beklenen: A'da ~3 sn sonra "Boyut limitinin üstünde, oyunculara
  gitmeyecek: …" snackbar'ı. B'de o görsel kırık ikon. A'da normal görünür.

**3.4 Harita.** A'da dünya haritasını değiştir (< 10 MB). Ardından bir
encounter'a savaş haritası arka planı koy.
- Beklenen: ikisi de B'ye gelir. Dünya haritası ekrana sığmamış açılırsa
  "görünümü sıfırla" düzeltir (bilinen sınır).

**3.5 DM çevrimdışıyken ikinci cihaz.** A'yı tamamen kapat. B'de dünyayı
kapatıp aç, kartları kaydır, dünya haritasına ve savaş haritasına git.
- Beklenen: bütün görseller geliyor. B'nin log'unda
  `AssetRefResolver: ... indirilemedi` yok.

---

## 4. Yarım kalan yükleme (A + B)

Tasarım belgesindeki (§4.8.3) 8. adım. Asıl sorulan şey: "internet kesildi, eksikler sonra
yüklenecek mi?"

**4.1 Uygulama açıkken bağlantının geri gelmesi.**
1. A'da dünya açık. Yeni bir kart aç ve ona 10–15 görsel ekle.
2. Görselleri ekledikten **2–3 sn sonra**, hepsi yüklenmeden A'nın
   internetini kes. `↑` satırı ancak tur bitince yazıldığı için onu bekleme.
3. 1 dk bekle, interneti geri aç. Uygulamaya ve dünyaya dokunma.
4. En çok 10 dk bekle.

Kontrol:

```sql
select uploaded, count(*) from world_media where world_id = '<W>' group by 1;
```

- Beklenen: kesinti sırasında log'da `CloudSync: medya <W> hata=offline` ve
  `CloudSync: medya <W> 30 sn sonra yeniden` (sonra 60, 120 … en çok 600 sn).
  İnternet gelince bir sonraki denemede `CloudSync: catchUp`, ardından
  `CloudSync: medya <W> ↑N`. `true` sayısı kartın görselleri kadar artar. B'de
  kart bütün görselleriyle gelir.

**4.2 Uygulamanın kapanıp açılması — dünyayı açmadan.**
1. 4.1'i tekrarla, ama internet kesikken **uygulamayı tamamen kapat**.
2. İnterneti aç, uygulamayı aç. **Dünyayı açma**, hub'da bekle.

- Beklenen (Faz 5f): açılış ekranı kapandıktan birkaç saniye sonra log'da
  `CloudSync: catchUp <W>`, ardından `CloudSync: medya <W> ↑N <bayt> … ms`.
  Sorgu 4.1'deki gibi tamamlanır. Önceden bu ancak dünya açılınca oluyordu.

**4.3 Hub'dayken bağlantının geri gelmesi.** 4.2'yi tekrarla, ama uygulamayı
internet **kapalıyken** aç. Hub'da bekle, sonra interneti aç.
- Beklenen: `CloudSync: bağlantı geri geldi`, ardından `catchUp <W>` ve
  `medya <W> ↑N`. Sorgu tamamlanır.

**4.4 Çevrimdışı açılan dünya.** İnternet kapalıyken A'da dünyayı aç, bir
kartın adını değiştir. Dünyayı kapatmadan interneti aç.
- Beklenen: `CloudSync: bağlantı geri geldi`, kanal kurulunca `catchUp <W>`
  ve `push <W> ↑1`. B'ye yeni ad gelir. Önceden bu, dünya yeniden açılana
  kadar gitmiyordu.

---

## 5. Oyuncu — katılım ve kart paylaşımı (A + P)

**5.1 Katılım.** A'da dünyanın Multiplayer bölümünden davet kodunu kopyala.
P'de hub → Dünyalar → "Katıl" → kodu gir.
- Beklenen: "\"Aegis\" dünyasına katıldın" ve "Oyuncu olarak katıldın".

**5.2 Kart paylaşma (görselli).** A'da **görseli olan** bir kartın menüsünden
"Paylaş" → "Tüm oyuncularla paylaş".
- Beklenen: P'de kart görünür, görseli de gelir.

```sql
select count(*) from entity_shares where world_id = '<W>';  -- 1 artar
```

**5.3 Tek oyuncuya paylaşma.** Başka bir kartı "Tek tek oyuncular" ile P'nin
hesabına paylaş.
- Beklenen: P'de görünür. İkinci bir oyuncu hesabın varsa o hesapta görünmemeli.

**5.4 Paylaşılan karta sonradan görsel.** A'da 5.2'deki karta **yeni** bir
görsel ekle.
- Beklenen: P'de karttaki görsel güncellenir. Kırık ikon çıkarsa ekranı
  kapatmadan ~30 sn bekle, kendiliğinden gelmeli.

**5.5 Paylaşılan kartın düzenlenmesi.** A'da 5.2'deki kartın açıklamasını
değiştir.
- Beklenen: P'ye gelir.

**5.6 Gizli alan.** Paylaşılan kartta DM'e özel (secret) bir alan varsa
doldur.
- Beklenen: P'de o alan **görünmez**. Bu bir gizlilik testi; görünürse hemen
  dur ve bana getir.

**5.7 Paylaşımı kaldırma.** A'da 5.3'teki kartta "Paylaşımı kaldır".
- Beklenen: P'de kart kalkar. Gri kart + etiket Faz 5.5'in işi; şimdilik ne
  olduğunu not et.

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

**6.6 Karakter görseli.** Karaktere portre ekle.
- Beklenen, bugünkü kodla: A'da **görünmez** (bilinen sınır, karakter medyası
  henüz buluta çıkmıyor). Görünürse haber ver, belgeyi düzeltelim.

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
```

- Beklenen: kart sayısı tutar.

**7.2 Paket düzenleme.** A'da bir kartın adını değiştir, bir kart sil; B'de
paketi aç.
- Beklenen: ikisi de yansır. Paket görselleri B'de **gelmez** (Faz 5e,
  bilinen).

**7.3 Yarıda kalan indirme (5c'nin tek eksiği).** B'de paketi ya da dünyayı
sil. Hub → "Bulutta, bu cihazda yok" → İndir. İlerleme çubuğu yarıdayken
B'nin internetini kes.
- Beklenen: yarım dünya/paket listede **görünmez**. İnternet gelince tekrar
  "İndir" çalışır ve tamamlanır.

---

## 8. Ölçüm (Faz 5f'ye veri)

Süreler artık log'da (hepsi `CloudSync:` önekli). Her satırı olduğu gibi
kopyala; cihazı (A masaüstü / B telefon) ve bağlantıyı (Wi-Fi / mobil) yanına
yaz.

- [ ] **Dünya açılışı.** A'da ve B'de dünyayı üç kez aç-kapat:
      `açılış <W> yerel=… ms toplam=… ms`. `toplam − yerel` bulut beklemesi.
- [ ] **Multiplayer aç.** Aegis'in bir kopyasında (9.3'teki kopya işe
      yarar) "Multiplayer On": `multiplayer açıldı <id>: N satır … ms` ve
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

- Beklenen: 0. Sha'yı bilmiyorsan toplam sayının 1 azaldığına bak.

**9.2 Paket silme.** A'da 7.1'deki online paketi sil.
- Beklenen: `select * from user_packages where id = '<id>'` boş. B'de o
  paketi aç, bir kartı düzenle → B'deki paket offline'a düşer, bulutta
  yeniden belirmez.

**9.3 Multiplayer'ı kapatma.** Aegis'in bir kopyasıyla yap, asıl dünyayla
değil; kapatma bütün üye verisini buluttan siler. Kopyayı multiplayer aç,
3.1'deki gibi yüklenmesini bekle, sonra "Çok Oyunculu Kapalı".

```sql
select count(*) from world_media where world_id = '<kopya id>';            -- 0
select count(*) from r2_evict_queue where r2_key like 'worlds/<kopya id>/%'; -- > 0
```

- Beklenen: en çok 1 saat sonra (cron) ikinci sorgu 0. Cloudflare → R2 →
  `dmt-assets` içinde `worlds/<kopya id>/` boş.

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
  Sonra multiplayer'ı kapat → simge hemen yalnız kayda döner (bulut simgesi
  ya da rozet kalmaz). Aynısı online paketi "Online kapat"la.

**11.3 Çevrimdışı bekliyor.** Online dünyadayken ağı kes, bir kart düzenle.
- Beklenen: simge üstü çizili bulut; tooltip "Çevrimdışı — değişiklikler bu
  cihazda kayıtlı…"; diyalogda Yeniden dene düğmesi. Ağı aç → birkaç saniye
  içinde bulut-tik'e döner. Ayrıca: **uygulamayı çevrimdışı aç**, online
  dünyayı aç, bir şey düzenle → yine "bekliyor".

**11.4 Sorun.** Ağ kesintisi sorun değil "bekliyor" sayılır; gerçek sorunu
zorlamak için online dünyada bir kartın açıklamasına 300 KB'tan uzun metin
yapıştır (bulut satır sınırı 256 KB). İsteğe bağlı: kotayı geçici düşür
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

## Sonuçları bana nasıl getireceksin

Her adım için ✅ ya da ❌. ❌ olanlarda:
- ne yaptın, ne bekliyordun, ne oldu;
- o anki `CloudSync` / `AssetRefResolver` log satırları;
- ilgili SQL sorgusunun çıktısı.
