# Roadmap — Community & Content

> **Durum:** taslak. Öncelik sırası iş/yatırım/etki dengesine göre ayarlanmalı.
> **Tarih:** 2026-08-22
> **Bağlam:** Session-based online model için ayrı tasarım notu: `docs/online-session-model.md`.

Bu roadmap "make online" modelinin session modeline geçişi **dışındaki** planları
kapsar. (Session geçişi ayrı dokümanda.) Farklı büyüklükte bağımsız işler: içerik,
UI, VTT düzeltmesi, görseller, ses ve sync.

---

## 1. Marketplace — official filtresi

- Marketplace'te "official" içerikleri ayıran bir filtre eklenir (first-party catalog
  pack'leri / SRD tabanlı içerik).
- Bu filtre aynı zamanda misafir erişimiyle birleşir: misafir yalnız official içeriği
  görür/indirir (bkz. `online-session-model.md` §2).
- **Gerekli:** `official` işaretinin RLS/şemada net tanımı (karar §4.4).

## 2. Marketplace — 18+ içerik etiketi

- 18+ içerikler için ayrı bir etiket/filtre eklenir.
- Yayınlama tarafında zorunlu bildirim + görüntüleme tarafında filtre (varsayılan kapalı).
- **Gerekli:** şema alanı, listing akışında onay, arama/görüntüleme filtre uygulaması.

## 3. Ücretsiz D&D içeriği → ready-to-play world/paket/karakter

Uygun lisanslı ücretsiz içerikler import edilip **readytoplay world package / karakter**
olarak eklenir. Kaynaklar:

- https://www.dndbeyond.com/forums/dungeons-dragons-discussion/dungeon-masters-only/43718-list-of-free-dnd-campaigns
- https://1shotadventures.com/adventure-index/
- https://www.mtblackgames.com/blog/top-20-free-dnd-adventures
- https://itch.io/search?facets=m.free&q=dnd5e%20campaign

**Zorunlu ön koşul: lisans doğrulaması.** Her içeriğin lisansı (CC, OGL, açık izin)
tek tek doğrulanmalı; lisanssız içerik eklenmemeli. Open5e pipeline'ı (`tool/open5e_import`)
bu iş için örnek teşkil eder.

## 4. UI — D&D topluluğuna alışık tasarım

- Arayüz, D&D topluluğunun alışık olduğu görsel dile yaklaştırılır (parşömen/deri
  temalar, fantastik tipografi, sekmeli karakter sayfası düzeni vb.).
- Mevcut tema sistemi (`lib/presentation/theme/`) bu işin giriş noktası.

## 5. Battle Map — layer sistemi incelemesi

- `ShapeLayer { background, object, gm }` sistemi var (`map_shape.dart:21`); "çalışmıyor
  olabilir" raporu var. İncele + düzelt.
- Nokta: yeni çizilen şekiller `activeLayer`'a konuyor; background layer vektörleri
  canvas-space, object/GM ekran-space çiziliyor (`battle_map_painter.dart:418-498`).
  Z-order ve oyuncuya gitme davranışı doğrulanmalı.

## 6. Built-in D&D 5e paketi — görseller

- `tool/art_gen` pipeline'ı hazır: ~5.500 görsele değer kart, tek stil (Flux + STYLE
  sabiti), deterministik seed, resume destekli.
- **Eksik:** görseller henüz pakete gömülü değil. SRD core pack ile birlikte gömülecek:
  cover art, monster/species/class portrait'ları, eşya ikonları, spell glyph'leri.
- Bilinen açık konular (`art_gen/README.md`): karakter tiplerinde bej zemin sapması;
  LLM fiziksel tanım pass'ı script'e bağlanmadı.
- `srdCorePackVersion` bump'ı gerekecek (AGENTS.md kuralı).

## 7. Synced music — YouTube

- DM YouTube linki yapıştırır, oturumda track olarak çalar; bağlı tüm oyuncuların
  uygulamasında **senkron** duyulur (tüm masa aynı anda aynı şeyi duyar).
- **Not:** yasal çerçeve (lisans/kullanım) işe başlamadan netleştirilmeli.
- Ses altyapısı için `soundpad_engine.dart` (SoLoud) ve session transport için
  `online-session-model.md` referans.

## 8. Local Sync — tur iki

- **Silme ve yeniden adlandırma** Local Sync'te yayılmıyor (şu an yalnızca ekleme +
  güncelleme var). Düzeltilecek.
- **Şifreleme:** transfer kimlik doğrulamalı ama **şifreli değil**. Şifreleme eklenir.
- Referans: `vault/20-Systems/LAN-Sync-Flow.md`, `lan_sync_*` dosyaları.

---

## Önerilen sıralama

| Faz | İşler | Gerekçe |
|---|---|---|
| 1 | Marketplace filtreleri (official + 18+) | Küçük, yüksek etki, bağımsız |
| 2 | Battle map layer düzeltmesi | Bug düzeltmesi, net kapsam |
| 3 | Local Sync tur iki (silme/rename + şifreleme) | Veri bütünlüğü + güvenlik |
| 4 | Session model geçişi (`online-session-model.md`) | Büyük refactor, önce kararlar |
| 5 | Ücretsiz içerik importu | Lisans doğrulama seri iş; kaynak var |
| 6 | Built-in görseller (art_gen) | Pipeline hazır, üretim zamanı |
| 7 | UI yeniden tasarımı | Büyük, sona bırakıldı (session ile çakışma) |
| 8 | YouTube senkron müzik | Lisans netleşince |

Faz sıralaması öneridir — büyük işler (4, 7) aynı anda yürütülmemeli.