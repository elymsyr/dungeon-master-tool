# Content Export Kuralları

## Amaç
Bu dizin, uygulama marketplace'ine eklenecek içerik modüllerini barındırır.
Modüller kullanıcılara oynaması için sunulur.

## Kurallar

### Kural 1 — İçerik Değiştirilemez
İçerik noktası virgülüne, kelimesi kelimesine aynı kalmalıdır.
Hiçbir dosya (PDF, görsel, karakter dosyası) üzerinde düzenleme yapılmaz.
Yalnızca `manifest.json` oluşturulur veya güncellenir.

### Kural 2 — Manifest İçeriğe Referans Verir
Metadata (başlık, yayıncı, lisans vb.) `manifest.json`'da tutulur.
İçerik dosyaları olduğu gibi paketlenir, manifest'te tekrar edilmez.

### Kural 3 — Dosya Yolları Relative Olmalıdır
Tüm dosya referansları modül dizinine göreceli olmalı.

### Kural 4 — Orijinal Dizin Yapısı Korunur
Mevcut klasör isimleri (`media/`, `Maps/`, `Handouts/` vb.) değişmez.

## Modül Formatı

```
tool/content/<modul-adı>/
├── manifest.json
├── <ana-dosya>.pdf
└── media/
    ├── maps/
    ├── handouts/
    ├── tokens/
    └── gcs-characters/        # .gcs (GURPS Character Sheet) dosyaları
```

## Manifest Şablonu

```json
{
  "slug": "99-devils-of-uzrahs-palace-shadowdark",
  "title": "99 Devils of Uzrah's Palace",
  "system": "shadowdark",
  "publisher": "",
  "author": "",
  "license": "",
  "attribution": "",
  "source_url": "",
  "version": "1.0.0",
  "description": "",
  "files": {
    "pdf": "99-Devils-of-Uzrahs-Palace-Shadowdark.pdf",
    "media": {
      "maps": [],
      "handouts": [],
      "tokens": [],
      "gcs_characters": []
    }
  }
}
```
