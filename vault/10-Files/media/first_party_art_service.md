---
type: file-note
domain: media
path: flutter_app/lib/data/services/first_party_art_service.dart
layer: data
language: dart
status: stable
updated: 2026-09-07
tags: [file]
---

# `first_party_art_service.dart`

> [!abstract] Primary Purpose
> `dmt-art://{uuid}.webp` ref'lerini diskteki bir dosyaya çözer — built-in SRD ve resmî Open5e/Cairn paketlerinin `tool/art_gen` üretimi kart görselleri (7413 adet). İki kaynağa bakar: önce app bundle (`assets/art/srd/`, sadece SRD'nin 1247 görseli), sonra R2 catalog'unun **public** GET route'u (`{worker}/catalog/art/…`, JWT yok, hesap yok). Ref hangi görselin nerede olduğunu **taşımaz** — bundle kapsamı değişince veri migrasyonu gerekmesin diye.

## Inputs / Outputs
**Inputs**
- Constructor deps: [[first_party_catalog_service]] (`fetchCatalogBytes`).
- Reads: `rootBundle` (`assets/art/srd/{uuid}.webp`); `AppPaths.cacheDir/art/` disk cache.
- Supabase / CDC: yok. Auth: yok — catalog GET public.
- Triggers: [[asset_ref_resolver]] `resolve()` bir `dmt-art://` ref gördüğünde.

**Outputs**
- Public API: `resolve(String name) → Future<File?>`; `bundleDir` sabiti.
- Writes: `cacheDir/art/{uuid}.webp` (tmp + rename).
- Events / Drift / Supabase yazımı: yok.

## Dependencies & Links
- Depends on: [[first_party_catalog_service]], `core/config/app_paths.dart`, `package:path`
- Used by: [[asset_ref_resolver]] (`firstPartyArtServiceProvider`, `first_party_catalog_provider.dart` içinde)
- Domain map: [[Media-and-Assets]]
- System flow: [[Media-Storage-Tiers]], [[Content-Pipeline]]
- Spec / reference: `tool/art_gen/OPERATIONS.md`

## Key Logic / Variables
- **Kaynak sırası** bundle → catalog. `rootBundle.load` miss'te fırlatır, yakalanır; bu yüzden bundle'da olmayan ~6.2k görsel için ilk çözümde bir yakalanmış exception vardır (dosya başına bir kez, sonrası disk cache).
- **Cache** `AppPaths.cacheDir/art/{uuid}.webp`. Yazma `tmp + rename` — yarıda kalan indirme sonsuza dek servis edilen bozuk dosya bırakmasın.
- **`prefetch(names)`** — kurulumda paketin bütün kart görsellerini 6'lı havuzla indirir. Lazy indirme paketi hafif gösterip her kartta bekletiyordu; artık boyut `CatalogEntry.downloadBytes` içinde `art_bytes` olarak duyuruluyor ve kurulum onu gerçekten indiriyor. Düşen görsel kurulumu düşürmez (ref pack'te kalır, render'da tekrar denenir).
- **Path guard:** `name` içinde `/`, `\`, `..` varsa null. Ref pack verisinden geliyor, cache dizininin dışına yazamamalı.
- **Bundle görselleri diskte iki kez yer kaplar** (APK içinde + cache'te), çünkü Flutter asset'i `File` olarak açılamaz. Sadece görüntülenenler için, cache silinebilir.
- Bundle q50 (~52 MB), R2 kopyası orijinal q82 (~762 MB). Aynı uuid, farklı kalite — bundle bir optimizasyon.
- **LRU/kota yok:** `ContentStore` sha-adresli, art ref'leri uuid-adresli olduğu için oraya girmiyorlar. Tüm bestiary gezilirse cache 762 MB'ye kadar büyüyebilir.

## Notes
- Görselleri `tool/art_gen/generate.py` üretir; `bundle_srd_art.py` bundle'ı, `stamp_art_refs.py` pack ref'lerini, `cloudflare/upload_art.sh` R2 kopyasını üretir.
- SRD tarafında ref'i `srd_core_pack.dart` pass 1 basıyor (`_artedSlugs`), pack asset'lerinde ise `stamp_art_refs.py`.
