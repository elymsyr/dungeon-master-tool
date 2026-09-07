# Aegis

**Aegis** evreninin, **Aethelgard** bölgesi merkezli özgün bir masaüstü RPG dünyası
olarak yazıldığı depo. Taban DnD 5e; sapmalar açıkça işaretlenir.

Hedef: bu depodaki lore'un
[dungeon-master-tool](https://github.com/elymsyr/dungeon-master-tool) için
paketlenmiş bir **dünyaya** (`assets/worlds/aegis/` → `aegis.pkg.json`) dönüşmesi.
Cairn'den farkı: Aegis üçüncü tarafın kural setinin aktarımı değil, **kendi evrenimiz** —
lore birincil içerik, mekanik ikincil.

## Ne olacak

| Katman | İçerik |
|---|---|
| Lore | Gizli tarih, kronoloji, tanrılar, Aethel'in soyu, bilgi katmanları |
| Coğrafya | Aethelgard bölgesi, köyler, şatolar, limanlar (`lore/archive/media/`) |
| Halklar | Bölgeye özgü ırklar / soylar (`species`, `subspecies`) |
| Karakter | Bölgeye özgü background'lar, roller, başlangıç karakterleri |
| Bestiary | Suretsiz ve türevleri, bölgesel yaratıklar (`monster`, `creature-action`) |
| Macera | Kapsamlı hikayeler — **sonraki aşama**, lore oturmadan yazılmaz |

## Şu anki durum

Depoda yalnızca `lore/archive/` var: dağınık, kısmen çelişen taslaklar
(Notion dışa aktarımı + eski PDF/MD'ler). Henüz blueprint yok.

Sıradaki iş: arşivi tek bir kanonik ağaca damıtmak, sonra
[tool/content/README.md](https://github.com/elymsyr/dungeon-master-tool/blob/main/flutter_app/tool/content/README.md)
kurallarına göre blueprint'e çevirmek.

## Temel ilkeler

1. **DM Kitabı önce yazılır**, Oyuncu Kitabı ondan damıtılır.
2. **Tarih bugüne varmak için kurgulanmaz** — bugün, kazaların birikmiş sonucudur.
3. **Hikaye belirli karakterlere bağlanmaz**; rol yuvaları kullanılır.
4. Çelişkide [00 · Proje Yönergesi](lore/archive/update/) kazanır.

Dil: İngilizce.
