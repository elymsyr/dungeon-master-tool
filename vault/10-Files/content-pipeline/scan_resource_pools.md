---
type: file-note
domain: content-pipeline
path: flutter_app/tool/scan_resource_pools.py
layer: tool
language: python
status: stable
updated: 2026-09-11
tags: [file]
---

# `scan_resource_pools.py`

> [!abstract] Primary Purpose
> `resource_pool_grants` denetçisi: builtin SRD kaynağı + `assets/open5e_packs/*` + `assets/worlds/**` içindeki **her** havuz satırını tarar ve [[character_resolver]]'ın `applyResourcePools` kurallarıyla karşılaştırır. Soru şu: bir kartın verdiği sayaç karakter sayfasında gerçekten çizilir mi, yoksa sessizce düşer mi — ve metin "uzun dinlenmede N kullanım" derken hiç sayaç verilmemiş mi.

## Inputs / Outputs
**Inputs**
- `python3 tool/scan_resource_pools.py` — tam liste (kaynak → kart → havuz → recharge) + bulgu özeti.
- `--quiet` — sadece bulgular. `--all` — üçüncü parti paketlerin metin sezgisini de göster. `--selftest` — denetçinin kendi assert'leri.
- Okur: `lib/domain/entities/schema/builtin/**/*.dart` (regex ile `'pool_ref'` blokları), `lib/domain/services/count_formula.dart`, `lookups.dart`'ın `_resourcePoolCategory` satırları, bütün `*.pkg.json` ve `*blueprint.json`.

**Outputs** — stdout. Hiçbir şey yazmaz. `DROP` sınıfı bulgu varsa exit 1 (CI'ya takılabilir).

## Dependencies & Links
- Kural kaynağı: [[character_resolver]] (`applyResourcePools`, `_applyLevelGatedSpells`), [[resource_pool_resolver]], `count_formula.dart`, `class_resources_card.dart`.
- Kardeşler: [[scan_pack]], [[check_findings]].
- Domain map: [[Content-Pipeline]] · Akış: [[Grant-Resolution]]

## Key Logic / Variables
- Kurallar **kopyalanmaz, kaynaktan okunur**: geçerli `count_formula` token'ları `count_formula.dart`'ın `case` satırlarından, geçerli builtin havuz id'leri `lookups.dart`'ın `_resourcePoolCategory` bloğundan çıkarılır. Böylece yeni bir formül eklenince denetçi yalan söylemez.
- **DROP** (sessiz kayıp — kart satırı hiç çizilmez): `pool_ref` çözülemiyor · `count`/`count_formula`/`count_by_level` üçünden hiçbiri yok · formül `evalCountFormula`'da tanımsız · aynı kartta yinelenen `pool_ref`.
- **WARN**: `recharge` yok (satır etiketsiz çizilir, kullanıcı büyü slotu sanar) · Tier-0'da duran ama hiçbir kartın vermediği havuz · kart metni kullanım sayısı diyor ama `resource_pool_grants` yok (`USES_RE` sezgisi; 5e ve Türkçe kalıpları).
- Builtin Dart tarafında satır sınırı `'pool_ref'` indeksinden geriye/ileriye **süslü parantez dengelemesiyle** bulunur (`row_text`) — Dart kaynağını ayrıştırmadan doğru bloğu kesmenin ucuz yolu. Builtin'in JSON hâli (`dnd5e-srd.pkg.json`, [[dump_srd]] çıktısı) ayrıca taranır, bu yüzden metin sezgisi builtin'i de kapsar.
- Üçüncü parti paketlerin (`open5e-*`) metin sezgisi varsayılan olarak susturulur: o prose bizim elimizde değil, 60+ satır gürültü üretiyor. Grant hataları orada da her zaman raporlanır.

## Notes
- 2026-09-11 ilk koşusunda tek `DROP` **Pact Magic** idi: `pool:pact_slots` sayısız veriliyordu, `max` null olduğu için kart zaten çizmiyordu — pact slot'ları `caster_progression.dart` (`CasterKind.pact`) büyü yuvası tablosundan geliyor, grant kaldırıldı.
- Kalan açık iş: 18 elle yazılmış SRD kartı (Fey-Touched, Shadow-Touched, Musician, Inspiring Leader, Telepathic, Stonecunning, Large Form, dev alt-ırkları…) metninde "PB/uzun dinlenme" diyor ama havuz vermiyor; 5 Tier-0 havuz satırı (`pool:item_charges`, `pool:legendary_resistance`, `pool:superiority_dice`, `pool:lay_on_hands_uses_per_long_rest`, `pool:pact_slots`) hiçbir kart tarafından verilmiyor.
