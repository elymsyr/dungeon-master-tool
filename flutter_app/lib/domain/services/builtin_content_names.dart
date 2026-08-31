import '../entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import '../entities/schema/builtin/lookups.dart' show tier0Slugs;
import '../entities/schema/builtin/srd_core/srd_core_pack.dart'
    show srdRawRowsBySlug;

/// Blueprint dışında **zaten var olan** her içerik adı: `slug → {name}`.
///
/// İki kaynak birleşir:
///  * Tier-0 lookup seed satırları (`ability`, `language`, `condition`, …),
///  * built-in SRD 5.2.1 paketi (Tier-1 içerik: weapon, armor, spell, feat,
///    monster, trait, creature-action, …).
///
/// [WorldBlueprintConverter.knownNames] bunu iki iş için kullanır: SRD'de var
/// olan içeriği yeniden üretmek yerine referanslamak (README kural 3) ve
/// hiçbir yerde olmayan bir ismi build-time hatası yapmak.
///
/// `srdRawRowsBySlug` bilerek `buildSrdCorePack` yerine çağrılıyor — sadece
/// isimler gerekli, UUID basmaya ve ref çözmeye gerek yok.
Map<String, Set<String>> builtinContentNames() {
  final out = <String, Set<String>>{};

  for (final entry in generateBuiltinDnd5eV2Schema().seedRows.entries) {
    for (final row in entry.value) {
      final name = row['name'];
      if (name is String) (out[entry.key] ??= <String>{}).add(name);
    }
  }

  for (final entry in srdRawRowsBySlug().entries) {
    for (final row in entry.value) {
      final name = row['name'];
      if (name is String) (out[entry.key] ??= <String>{}).add(name);
    }
  }

  return out;
}

/// Blueprint'in taşıyabileceği kategoriler — şemadaki her kategori eksi
/// Tier-0 lookup'lar. Elle tutulan bir liste değil: yeni bir içerik
/// kategorisi şemaya eklendiği anda blueprint'ler de onu taşıyabilir.
Set<String> blueprintContentSlugs() {
  final tier0 = tier0Slugs.toSet();
  return {
    for (final c in generateBuiltinDnd5eV2Schema().schema.categories)
      if (!tier0.contains(c.slug)) c.slug,
  };
}

/// Install anında çözülen lookup kategorileri — şemanın Tier-0 listesi.
Set<String> blueprintTier0Slugs() => tier0Slugs.toSet();

/// Şemadaki her kategori için yazılabilir alan anahtarları — `slug → {key}`.
/// Her entity'de bulunan taban alanlar da dahil.
///
/// [WorldBlueprintConverter.fieldKeys] bunu blueprint'teki yazım hatalarını
/// build-time'da yakalamak için kullanır. Şemada olmayan bir anahtar
/// `attributes` içine düşer, hiçbir widget onu okumaz ve veri sessizce
/// kaybolur — 99 Devils'ta iki PC'nin büyü listesi `spells_known` yerine
/// `spell_refs` yazıldığı için tam olarak böyle kaybolmuştu.
Map<String, Set<String>> blueprintFieldKeys() {
  const baseKeys = {
    'name',
    'description',
    'imagePath',
    'images',
    'dmNotes',
    'tags',
    'pdfs',
    'locationId',
  };
  return {
    for (final c in generateBuiltinDnd5eV2Schema().schema.categories)
      c.slug: {...baseKeys, for (final f in c.fields) f.fieldKey},
  };
}

/// `slug → fieldKey → izin verilen hedef kategoriler`, şemadaki relation
/// alanlarının `allowedTypes` kısıtından türetilir.
///
/// [WorldBlueprintConverter.relationTargets] bunu, bir ref'in yanlış
/// kategoriyi hedeflemesini build-time'da yakalamak için kullanır: `monster`
/// `gear_refs` yalnız `adventuring-gear`/`weapon`/`armor` kabul eder, oraya
/// konan bir `magic-item` satırı okunurken atılır.
Map<String, Map<String, Set<String>>> blueprintRelationTargets() {
  final out = <String, Map<String, Set<String>>>{};
  for (final c in generateBuiltinDnd5eV2Schema().schema.categories) {
    final fields = <String, Set<String>>{};
    for (final f in c.fields) {
      final targets = f.validation.allowedTypes;
      if (targets != null && targets.isNotEmpty) fields[f.fieldKey] = {...targets};
    }
    if (fields.isNotEmpty) out[c.slug] = fields;
  }
  return out;
}
