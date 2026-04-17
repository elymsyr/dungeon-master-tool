import 'package:uuid/uuid.dart';

import '../../domain/entities/entity.dart';
import '../../domain/entities/schema/entity_category_schema.dart';
import '../../domain/entities/schema/field_schema.dart';
import '../../domain/entities/schema/world_schema.dart';
import '../providers/entity_provider.dart';

const _uuid = Uuid();

/// Paket entity'lerini aktif kampanyaya import eder.
///
/// - Yeni UUID'ler atar
/// - categorySlug'ı isim bazlı eşler
/// - Dünyada olmayan field'ları atar, eksik field'lara default verir
/// - Relation field'larındaki eski ID'leri yeni ID'lere çevirir
/// - Kuralları (RuleV2) yok sayar
/// - Tüm import tek bir undo adımı olarak kaydedilir
class PackageImportService {
  /// Import işlemini gerçekleştir.
  /// Dönen değer: import edilen entity sayısı.
  int importPackage({
    required Map<String, dynamic> packageEntities,
    required WorldSchema packageSchema,
    required WorldSchema worldSchema,
    required EntityNotifier entityNotifier,
  }) {
    if (packageEntities.isEmpty) return 0;

    // Kategori eşleme: paket kategori adı → dünya slug
    final worldCatByName = {
      for (final c in worldSchema.categories) c.name: c,
    };
    final pkgCatByName = {
      for (final c in packageSchema.categories) c.name: c,
    };
    // Paket slug → paket kategori adı
    final pkgSlugToName = {
      for (final c in packageSchema.categories) c.slug: c.name,
    };

    // Eski ID → yeni ID mapping (relation fix-up için)
    final idMapping = <String, String>{};
    for (final oldId in packageEntities.keys) {
      idMapping[oldId] = _uuid.v4();
    }

    // Mevcut state'i undo stack'e kaydet (tek adım)
    entityNotifier.pushUndo(entityNotifier.currentEntities);

    var importCount = 0;
    final newEntities = <String, Entity>{};

    for (final entry in packageEntities.entries) {
      final oldId = entry.key;
      final newId = idMapping[oldId]!;
      final entityMap = Map<String, dynamic>.from(entry.value as Map);

      // Kategori eşleme
      final pkgSlug = ((entityMap['type'] as String?) ?? 'npc')
          .toLowerCase()
          .replaceAll(' ', '-');
      final catName = pkgSlugToName[pkgSlug];
      if (catName == null) continue; // Bilinmeyen kategori — atla

      final worldCat = worldCatByName[catName];
      if (worldCat == null) continue; // Dünyada bu kategori yok — atla

      final pkgCat = pkgCatByName[catName];

      // Field eşleme
      final pkgAttrs =
          (entityMap['attributes'] as Map?)?.cast<String, dynamic>() ?? {};
      final mappedFields = _mapFields(
        pkgAttrs: pkgAttrs,
        pkgCat: pkgCat,
        worldCat: worldCat,
        idMapping: idMapping,
      );

      final entity = Entity(
        id: newId,
        name: (entityMap['name'] as String?) ?? 'Unknown',
        categorySlug: worldCat.slug,
        source: (entityMap['source'] as String?) ?? '',
        description: (entityMap['description'] as String?) ?? '',
        images: _toStringList(entityMap['images']),
        imagePath: (entityMap['image_path'] as String?) ?? '',
        tags: _toStringList(entityMap['tags']),
        dmNotes: (entityMap['dm_notes'] as String?) ?? '',
        pdfs: _toStringList(entityMap['pdfs']),
        locationId: entityMap['location_id'] as String?,
        fields: mappedFields,
      );

      newEntities[newId] = entity;
      importCount++;
    }

    if (newEntities.isEmpty) return 0;

    // State'e ekle ve sync et
    entityNotifier.addEntities(newEntities);

    return importCount;
  }

  /// Package field'larını dünya schema'sına göre eşle.
  Map<String, dynamic> _mapFields({
    required Map<String, dynamic> pkgAttrs,
    required EntityCategorySchema? pkgCat,
    required EntityCategorySchema worldCat,
    required Map<String, String> idMapping,
  }) {
    final worldFields = <String, FieldSchema>{};
    for (final f in worldCat.fields) {
      worldFields[f.fieldKey] = f;
    }

    // Paket field key → label mapping (label bazlı eşleme için)
    final pkgLabelToKey = <String, String>{};
    if (pkgCat != null) {
      for (final f in pkgCat.fields) {
        pkgLabelToKey[f.label] = f.fieldKey;
      }
    }

    final result = <String, dynamic>{};

    // Dünya schema'sındaki her field için değer ata
    for (final worldField in worldFields.values) {
      final key = worldField.fieldKey;

      // 1. Aynı key ile paket'te var mı?
      if (pkgAttrs.containsKey(key)) {
        var value = pkgAttrs[key];
        // Relation field'larında ID'leri güncelle
        if (worldField.fieldType == FieldType.relation) {
          value = _remapRelation(value, idMapping);
        }
        result[key] = value;
        continue;
      }

      // 2. Label bazlı eşleme: aynı label'a sahip paket field'ı var mı?
      final pkgKey = pkgLabelToKey[worldField.label];
      if (pkgKey != null && pkgAttrs.containsKey(pkgKey)) {
        var value = pkgAttrs[pkgKey];
        if (worldField.fieldType == FieldType.relation) {
          value = _remapRelation(value, idMapping);
        }
        result[key] = value;
        continue;
      }

      // 3. Default değer
      result[key] = _defaultValue(worldField);
    }

    return result;
  }

  /// Relation field değerindeki eski ID'leri yeni ID'lere çevir.
  dynamic _remapRelation(dynamic value, Map<String, String> idMapping) {
    if (value is String && idMapping.containsKey(value)) {
      return idMapping[value];
    }
    if (value is List) {
      return value
          .map((e) =>
              (e is String && idMapping.containsKey(e)) ? idMapping[e] : e)
          .toList();
    }
    return value;
  }

  /// Field tipi bazlı default değer üret.
  dynamic _defaultValue(FieldSchema field) {
    if (field.defaultValue != null) return field.defaultValue;
    if (field.isList) return <dynamic>[];
    return switch (field.fieldType) {
      FieldType.text || FieldType.textarea || FieldType.markdown => '',
      FieldType.integer => 0,
      FieldType.float_ => 0.0,
      FieldType.boolean_ => false,
      FieldType.enum_ => '',
      FieldType.relation => '',
      FieldType.tagList => <String>[],
      FieldType.statBlock => {
          'STR': 10,
          'DEX': 10,
          'CON': 10,
          'INT': 10,
          'WIS': 10,
          'CHA': 10,
        },
      FieldType.combatStats => {
          'hp': '',
          'max_hp': '',
          'ac': '',
          'speed': '',
          'cr': '',
          'xp': '',
          'initiative': '',
        },
      FieldType.dice => '',
      FieldType.proficiencyTable => const {'rows': <dynamic>[]},
      _ => null,
    };
  }

  List<String> _toStringList(dynamic value) {
    if (value is List) return value.map((e) => e.toString()).toList();
    return [];
  }
}
