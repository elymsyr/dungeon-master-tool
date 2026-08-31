import 'package:uuid/uuid.dart';

/// Blueprint → world/package wire-format dönüşümü.
///
/// `tool/content/` altındaki blueprint'ler (`world-blueprint.json` +
/// `blueprint.json`) ile uygulamanın entity satırları arasındaki **tek**
/// çeviri noktası. Daha önce bu mantık offline CLI ile
/// `BundledWorldsInstaller` içinde iki kez elle yazılmıştı ve ikisi
/// birbirinden ayrıştı: install tarafındaki kopya `trait` /
/// `creature-action` kategorilerini tanımıyordu, dolayısıyla dünyanın 82
/// entity'sinin 25'i sessizce DB'ye hiç yazılmıyordu. Kategori listesi artık
/// şemadan türetiliyor, kopya da yok.
///
/// Ref çözümleme sırası — `tool/content/README.md` kural 3 ve
/// `WORLD_CONTENT_ORDER.md` tier zinciriyle birebir:
///
///  1. **Tier-0 lookup** (`ability`, `language`, …) → `{_lookup, name}`.
///  2. **Aynı blueprint'te tanımlı** → `{_ref, name}` (hard ref, install
///     sırasında UUID'ye çözülür).
///  3. **Built-in SRD paketinde var** → `{slug, name}` soft ref. Kural 3:
///     SRD'de olan içerik yeniden üretilmez, referans verilir.
///  4. **Hiçbiri** → [BlueprintIssueLevel.error]. Soft ref yine yazılır ama
///     çağıran build'i kesmelidir: çözülemeyen soft ref okuma anında
///     *sessizce* düşer (bkz. `entity_ref.dart`), yani hata bastırılırsa
///     kullanıcı eksik listeyi hiç öğrenemez.
///
/// Kural 4 pratikte şunu zorlar: bir ekipmanı envantere koymadan önce onu
/// bir `weapon`/`armor`/`adventuring-gear` entity'si olarak eklemek zorundasın.
class WorldBlueprintConverter {
  WorldBlueprintConverter({
    required this.packageName,
    required this.sourceTitle,
    required this.tier0Slugs,
    required this.contentSlugs,
    this.knownNames = const {},
    this.fieldKeys = const {},
    this.relationTargets = const {},
    this.mediaResolver,
  });

  /// Deterministik UUIDv5 namespace'i — paket adıyla birlikte entity id'sini
  /// üretir. Sabit kalması şart: `package_entity_id` foreign key'leri bu
  /// id'lere bağlı.
  static const _namespace = '2f1c9b3e-6d54-4a7c-9f2b-0c5a8e1d7b40';
  static const _uuid = Uuid();

  /// `.pkg.json` `package_name` / world slug. Id namespace'ine girer.
  final String packageName;

  /// Her entity'nin `source` alanına yazılan başlık.
  final String sourceTitle;

  /// Install anında çözülen lookup kategorileri.
  final Set<String> tier0Slugs;

  /// Blueprint'in taşıyabileceği içerik kategorileri (Tier-1 + Tier-2).
  final Set<String> contentSlugs;

  /// Blueprint dışında **zaten var olan** isimler: `slug → {name}`. Tier-0
  /// seed satırları ve built-in SRD paketi buradan gelir.
  final Map<String, Set<String>> knownNames;

  /// Kategori başına yazılabilir alan anahtarları: `slug → {key}`. Boş
  /// bırakılırsa alan doğrulaması yapılmaz. Şemada olmayan bir anahtar
  /// `attributes` içinde ölü veri olarak kalır — hiçbir widget okumaz.
  final Map<String, Set<String>> fieldKeys;

  /// `slug → fieldKey → izin verilen hedef kategoriler`. Bir relation alanı
  /// şemada `[weapon, armor]` diyorsa oraya `spell` ref'i koymak sessiz veri
  /// kaybıdır — widget alanı okur, tipi tutmayan satırı atar.
  final Map<String, Map<String, Set<String>>> relationTargets;

  /// Relative medya yolunu (`media/Tokens/x.webp`) çözer. `null` dönerse
  /// dosya bulunamamış sayılır ve hata üretilir. Verilmezse medya yolları
  /// olduğu gibi bırakılır (CLI `.pkg.json` üretimi böyle çalışır — zip
  /// içinde relative kalmalılar).
  final String? Function(String relativePath)? mediaResolver;

  static final _mediaLike = RegExp(
    r'\.(webp|png|jpe?g|gif|svg|pdf|mp3|ogg|wav|gcs)$',
    caseSensitive: false,
  );

  String entityId(String slug, String name) =>
      _uuid.v5(_namespace, '$packageName:$slug:${name.toLowerCase().trim()}');

  /// [worldBlueprint] `categories` + [characterBlueprint] `characters` →
  /// id'ye göre anahtarlanmış wire entity map'i.
  BlueprintConversion convert({
    Map<String, dynamic>? worldBlueprint,
    Map<String, dynamic>? characterBlueprint,
  }) {
    final issues = <BlueprintIssue>[];
    final entities = <String, Map<String, dynamic>>{};

    // ── Pass 1: id'leri bas, blueprint-içi isim indeksini kur ────────────
    final localIndex = <String, Set<String>>{};
    final pending = <({String slug, Map<String, dynamic> mapping})>[];

    void register(String slug, Object? rawItem, String origin) {
      if (rawItem is! Map) {
        issues.add(BlueprintIssue.error(origin, '', 'entry is not an object'));
        return;
      }
      final mapping = rawItem['mapping'];
      if (mapping is! Map) {
        issues.add(BlueprintIssue.error(origin, '', 'entry has no `mapping`'));
        return;
      }
      final name = mapping['name'];
      if (name is! String || name.trim().isEmpty) {
        issues.add(BlueprintIssue.error(origin, 'name', 'missing entity name'));
        return;
      }
      if (!(localIndex[slug] ??= <String>{}).add(name)) {
        issues.add(BlueprintIssue.error(
          '$slug/$name',
          'name',
          'duplicate name in the same category — ids are name-derived, so one '
              'row would silently overwrite the other',
        ));
        return;
      }
      pending.add((slug: slug, mapping: Map<String, dynamic>.from(mapping)));
    }

    final categories = worldBlueprint?['categories'];
    if (categories is Map) {
      for (final entry in categories.entries) {
        final slug = '${entry.key}';
        if (!contentSlugs.contains(slug) && !tier0Slugs.contains(slug)) {
          issues.add(BlueprintIssue.error(
            'categories/$slug',
            '',
            'unknown category — not present in the world schema',
          ));
          continue;
        }
        final list = entry.value;
        if (list is! List) {
          issues.add(BlueprintIssue.error(
              'categories/$slug', '', 'value is not a list'));
          continue;
        }
        for (final item in list) {
          register(slug, item, 'categories/$slug');
        }
      }
    }

    final characters = characterBlueprint?['characters'];
    if (characters is List) {
      for (final item in characters) {
        register('player-character', item, 'characters');
      }
    }

    // ── Pass 2: entity gövdelerini kur, ref'leri çöz ─────────────────────
    for (final row in pending) {
      final name = row.mapping['name'] as String;
      final id = entityId(row.slug, name);
      entities[id] = _buildEntity(
        slug: row.slug,
        mapping: row.mapping,
        localIndex: localIndex,
        issues: issues,
      );
    }

    return BlueprintConversion(entities: entities, issues: issues);
  }

  Map<String, dynamic> _buildEntity({
    required String slug,
    required Map<String, dynamic> mapping,
    required Map<String, Set<String>> localIndex,
    required List<BlueprintIssue> issues,
  }) {
    final name = mapping['name'] as String;
    final origin = '$slug/$name';

    final allowed = fieldKeys[slug];
    final attrs = <String, dynamic>{};
    for (final entry in mapping.entries) {
      if (entry.key == 'name') continue;
      if (allowed != null && !allowed.contains(entry.key)) {
        issues.add(BlueprintIssue.error(
          origin,
          entry.key,
          'unknown field for category `$slug` — nothing reads it, so the value '
              'is dropped on the floor',
        ));
        continue;
      }
      attrs[entry.key] = _resolve(
        entry.value,
        origin: origin,
        path: entry.key,
        localIndex: localIndex,
        issues: issues,
        allowedTargets: relationTargets[slug]?[entry.key],
      );
    }

    String str(Object? v) => v is String ? v : '${v ?? ''}';
    List<String> strList(Object? v) =>
        v is List ? [for (final e in v) '$e'] : const <String>[];

    return {
      'name': name,
      'type': slug,
      'source': sourceTitle,
      'description': str(attrs.remove('description')),
      'image_path': str(attrs.remove('imagePath')),
      'images': strList(attrs.remove('images')),
      'tags': strList(attrs.remove('tags')),
      'dm_notes': str(attrs.remove('dmNotes')),
      'pdfs': strList(attrs.remove('pdfs')),
      'location_id': attrs.remove('locationId'),
      'attributes': attrs,
    };
  }

  dynamic _resolve(
    Object? value, {
    required String origin,
    required String path,
    required Map<String, Set<String>> localIndex,
    required List<BlueprintIssue> issues,
    Set<String>? allowedTargets,
  }) {
    if (value is Map) {
      // Elle yazılmış zarflar da doğrulanır. Önceden bunlar "zaten çözülmüş"
      // sayılıp olduğu gibi geçiriliyordu; blueprint'te `spell_refs` satırları
      // `{slug: 'gust-of-wind', name: 'Gust of Wind'}` biçiminde — yani slug
      // alanında *kategori* değil büyünün kendi slug'ı — yazılmıştı ve 26
      // NPC büyüsü/trait'i okuma anında sessizce düşüyordu.
      final refSlug = value['_lookup'] ?? value['_ref'] ?? value['slug'];
      final lookup = value['lookup'] ?? refSlug;
      final target =
          refSlug == null ? value['value'] : (value['name'] ?? value['value']);
      final byName = value['match'] == 'name' || refSlug != null;

      if (lookup is String && byName && target is String) {
        final envelope = _refEnvelope(
          slug: lookup,
          name: target,
          origin: origin,
          path: path,
          localIndex: localIndex,
          issues: issues,
          allowedTargets: allowedTargets,
        );
        // `equipped`, `quantity`, `prepared` gibi satır-yanı alanlar ref
        // zarfının dışında değil, içinde taşınır (inventory / spells_known
        // relation listeleri bunları okur).
        const consumed = {
          'lookup',
          'match',
          'value',
          '_lookup',
          '_ref',
          'slug',
          'name'
        };
        for (final extra in value.entries) {
          if (consumed.contains(extra.key)) continue;
          envelope['${extra.key}'] = extra.value;
        }
        return envelope;
      }

      return <String, dynamic>{
        for (final e in value.entries)
          '${e.key}': _resolve(
            e.value,
            origin: origin,
            path: '$path.${e.key}',
            localIndex: localIndex,
            issues: issues,
            allowedTargets: allowedTargets,
          ),
      };
    }

    if (value is List) {
      return [
        for (var i = 0; i < value.length; i++)
          _resolve(
            value[i],
            origin: origin,
            path: '$path[$i]',
            localIndex: localIndex,
            issues: issues,
            allowedTargets: allowedTargets,
          ),
      ];
    }

    if (value is String && _mediaLike.hasMatch(value)) {
      return _resolveMedia(value, origin: origin, path: path, issues: issues);
    }

    return value;
  }

  Map<String, dynamic> _refEnvelope({
    required String slug,
    required String name,
    required String origin,
    required String path,
    required Map<String, Set<String>> localIndex,
    required List<BlueprintIssue> issues,
    Set<String>? allowedTargets,
  }) {
    final known = knownNames[slug];

    if (allowedTargets != null && !allowedTargets.contains(slug)) {
      issues.add(BlueprintIssue.error(
        origin,
        path,
        'ref targets `$slug` but the field only accepts '
            '${(allowedTargets.toList()..sort()).join(', ')} — a mismatched '
            'row is dropped when the field is read',
      ));
    }

    if (tier0Slugs.contains(slug)) {
      final seeded = known?.contains(name) ?? false;
      final declared = localIndex[slug]?.contains(name) ?? false;
      if (!seeded && !declared) {
        issues.add(BlueprintIssue.error(
          origin,
          path,
          '`$slug` lookup "$name" is neither a seeded schema value nor '
              'declared in this blueprint. Add it under '
              '`categories.$slug` first, then reference it',
        ));
      }
      return {'_lookup': slug, 'name': name};
    }

    if (localIndex[slug]?.contains(name) ?? false) {
      return {'_ref': slug, 'name': name};
    }

    // Kural 3: SRD'de varsa yeniden üretme, referans ver.
    if (known != null && known.contains(name)) {
      return {'slug': slug, 'name': name};
    }

    if (!contentSlugs.contains(slug) && !tier0Slugs.contains(slug)) {
      issues.add(BlueprintIssue.error(
        origin,
        path,
        'ref targets unknown category `$slug`',
      ));
      return {'slug': slug, 'name': name};
    }

    issues.add(BlueprintIssue.error(
      origin,
      path,
      'unresolved ref `$slug` → "$name": not in this blueprint and not in the '
          'built-in SRD pack. Author it as a `$slug` entity first, then '
          'reference it (a dangling soft ref is dropped silently at read time)',
    ));
    return {'slug': slug, 'name': name};
  }

  String _resolveMedia(
    String value, {
    required String origin,
    required String path,
    required List<BlueprintIssue> issues,
  }) {
    final resolver = mediaResolver;
    if (resolver == null) return value;
    final resolved = resolver(value);
    if (resolved == null) {
      issues.add(BlueprintIssue.error(
        origin,
        path,
        'media file not found: $value',
      ));
      return value;
    }
    return resolved;
  }
}

enum BlueprintIssueLevel { warning, error }

class BlueprintIssue {
  const BlueprintIssue(this.level, this.entity, this.field, this.message);

  factory BlueprintIssue.error(String entity, String field, String message) =>
      BlueprintIssue(BlueprintIssueLevel.error, entity, field, message);

  factory BlueprintIssue.warning(String entity, String field, String message) =>
      BlueprintIssue(BlueprintIssueLevel.warning, entity, field, message);

  final BlueprintIssueLevel level;
  final String entity;
  final String field;
  final String message;

  @override
  String toString() {
    final where = field.isEmpty ? entity : '$entity · $field';
    return '${level == BlueprintIssueLevel.error ? 'ERROR' : 'WARN '} '
        '$where: $message';
  }
}

class BlueprintConversion {
  const BlueprintConversion({required this.entities, required this.issues});

  final Map<String, Map<String, dynamic>> entities;
  final List<BlueprintIssue> issues;

  Iterable<BlueprintIssue> get errors =>
      issues.where((i) => i.level == BlueprintIssueLevel.error);

  bool get hasErrors => errors.isNotEmpty;

  Map<String, int> get counts {
    final out = <String, int>{};
    for (final e in entities.values) {
      final t = e['type'] as String;
      out[t] = (out[t] ?? 0) + 1;
    }
    return out;
  }
}
