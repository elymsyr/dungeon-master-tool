# İçerik Kaynakları — Nereden Bulunur

Taslak, 2026-09-05. URL'ler ve lisans etiketleri doğrulanmadı.

Amaç: telifsiz macera/görsel/veri kaynaklarına somut giriş noktaları.
(5eTools incelendi — `data/` ve `img/` tamamen telifli WotC materyali, MIT
lisansı sadece koda ait. Alınamaz, bu dokümanın konusu değil.)

## 1. Kobold Press CC içeriği

`koboldpress.com/kpstore/product/` **değil** → `github.com/open5e/open5e-api`
deposundaki `data/` klasörü. Tome of Beasts, Creature Codex, Deep Magic, Vault
of Magic hepsi orada; `tool/open5e_import` zaten bunu okuyor.

Görseller API'de yok. Kobold'un CC-BY sanat dökümü ayrı: KP'nin 2023 ORC/CC
geçiş duyuru sayfasından linklenen asset paketleri. **Her paketin kökünde
`LICENSE` var — okumadan hiçbir dosya alınmayacak.**

## 2. Open5e görselleri

`api.open5e.com/v2/creatures/` → her kayıtta `img_main` alanı. Çoğu boş, dolu
olanlar CC-BY. Toplu çekmek için tek bir script yeter, `tool/open5e_import`
içine sığar.

## 3. Dyson Logos haritaları

`dysonlogos.blog` → sağ kenardaki "Commercial Use Maps" / "Dyson's Free Maps"
kategorisi. Kural net: "commercial use" etiketli postlar atıfla ticari kullanıma
açık, Patreon-only olanlar değil. **Blanket lisans yok — etiket post bazında
kontrol edilecek.**

## 4. Watabou (üretim, indirme değil)

`watabou.github.io` → City Generator, Village Generator, One Page Dungeon.
Üretilen çıktı bize ait, ticari kullanım serbest (jeneratörün kendi FAQ'unda).
En temiz seçenek: asset indirmiyoruz, üretiyoruz — lisans takibi de yok.

## 5. game-icons.net

`game-icons.net/download.html` → tüm set tek zip, SVG, ~4000 ikon, birkaç MB.
CC-BY 3.0; sanatçı adı `ATTRIBUTION.md`'ye yazılacak. Medya boyutu problemimiz
için ideal.

## 6. Public domain sanat

`archive.org` + `commons.wikimedia.org` → "Doré Bible", "Beardsley Malory",
"Book of Hours". Wikimedia'da her dosyanın lisans kutusu var; aranan etiket
**`PD-old-100`**. Fransız/Alman tarama hakkı iddiaları ABD'de geçersiz —
pratikte sorun çıkmıyor ama kaynak kaydedilecek.

---

## Uyarı: bulmak kolay, atıf zor

Yukarıdakiler hafızadan yazıldı; URL'ler ve lisans etiketleri değişmiş olabilir.
Pipeline'a sokmadan önce o sayfadaki lisans metni bizzat okunacak ve kopyası
repoya alınacak.

İşin asıl zahmetli kısmı **atıfı takip etmek**. CC-BY her asset için isim +
lisans + link zorunlu kılıyor ve bu bilgi paketle birlikte son kullanıcıya
ulaşmak zorunda. Entity `attributes` içinde şu an `license` ve `attribution`
alanı yok.

**Bu alanlar eklenmeden hiçbir CC-BY görsel bundle edilmeyecek.**

## Sıradaki adım

1. Kaynakları canlı fetch ile doğrula, kullanılabilir olanları işaretle.
2. `license` + `attribution` alanlarını şemaya ekle.
3. Mundane ekipmanı SRD 5.2.1'den doldur (bağımsız, en küçük iş).
