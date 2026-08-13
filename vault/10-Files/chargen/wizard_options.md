---
type: file-note
domain: chargen
path: flutter_app/lib/application/character_creation/wizard_options.dart
layer: application
language: dart
status: stable
updated: 2026-08-13
tags: [file]
---

# `wizard_options.dart`

> [!abstract] Primary Purpose
> Karakter yaratma sihirbazının **seçenek listelerini üreten saf yüklemler**.
> Adım widget'ları (`spells_step`, `subclass_step`, `feats_step`,
> `character_creation_wizard_screen`) bu fonksiyonları çağırır; U2'nin paket
> testleri de aynılarını çağırır — böylece "testte görünüyor ama ekranda yok"
> ayrımı mümkün değil. Var olma sebebi budur: aynı yüklem beş yere kopyalanmıştı
> ve kopyalardan biri sessizce ayrışmıştı.

## Inputs / Outputs
**Inputs**
- `Map<String, Entity> entities` — kampanyanın çözülmüş varlık haritası
  (gömülü SRD + kurulu paketler).
- Okunan alanlar: `spell.class_refs`, `spell.tags`, `subclass.parent_class_ref`,
  `subclass.granted_at_level`, `subspecies.parent_species_ref`.

**Outputs**
- `spellMatchesClass(spell, classEntity, entities)` / `spellMatchesClassName`
- `subclassesForClass(classId, entities, {candidates})` — `granted_at_level`,
  sonra ad sırasında
- `subclassGrantedAtLevel(entity)` — yoksa 1
- `subspeciesForSpecies(speciesId, entities)`
- Yan etki yok, provider yok, Flutter importu yok.

## Dependencies & Links
- Depends on: [[entity_ref]] (`resolveEntityRef`, `resolveEntityRefList`)
- Used by: `spells_step`, `subclass_step`, `feats_step`,
  `character_creation_wizard_screen` ([[character_draft]] akışı)
- Domain map: [[Character-System]]
- System flow: [[Ref-Resolution-Hard-vs-Soft]]
- Spec / reference: `flutter_app/docs/open5e_content_audit.md` §U1/U2

## Key Logic / Variables
- **Büyü → sınıf eşleşmesi iki yollu.** SRD büyüleri `class_refs` (UUID) taşır;
  içe aktarılan Open5e paketlerinde bu alan **her satırda boş**, sınıf adı
  sadece `tags` içinde. Ölçüm (2026-08-13): 1.297 paket büyüsünün **1.212'si
  yalnız `tags` ile görünüyor, 0'ı `class_refs` ile**, 85'i hiçbir yolla
  görünmüyor. `tags` bir yedek değil, tek yol — L3 önce `class_refs`'i
  doldurmadan `tags`'i emekliye ayıramaz.
- **`parent_class_ref` / `parent_species_ref` iki şekilli**: paket içi hedef için
  düz uuid, başka pakette/gömülüyse softRef `{slug, name}`. `resolveEntityRef`
  ikisini de çözer; çözülmeyen satır **hata değil**, listeden düşer.
- `subclassesForClass` isteğe bağlı `candidates` alır — sihirbaz W4 önbelleğinden
  gelen slug'a göre filtrelenmiş listeyi verir, tüm haritayı taramaz.
- `granted_at_level` yoksa 1 döner: kilit yalnız veri varken uygulanır.

## Notes
- Testi: `test/presentation/character_creation/wizard_pack_families_test.dart`
  (U2) — 12 chargen kategorisi taşıyan paketin her biri için 39 vaka.
- Bu dosya çıkarılırken bulunan hata: sihirbazın kendi `_validateSpells`'i sınıf
  büyülerini yalnız `class_refs` ile sayıyordu, dolayısıyla paket büyülerinde 0
  sayıp kendi kontrolünü susturuyordu. Artık aynı yüklemi kullanıyor.
