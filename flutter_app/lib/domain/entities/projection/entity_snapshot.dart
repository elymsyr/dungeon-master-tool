import '../../services/content_translator.dart';

/// A serializable snapshot of an Entity for projection to the player
/// sub-window. Captures only the visual data the player view needs:
/// name, category, description, image paths, and a flat key→string fields
/// map (player view doesn't need the schema, just rendered values).
class EntitySnapshot {
  final String id;
  final String name;
  final String categorySlug;
  final String categoryName;
  final String categoryColorHex;
  final String description;
  final String source;
  final List<String> tags;
  final List<String> imagePaths;
  final List<EntityFieldSnapshot> fields;

  /// Ad ve açıklama çevrilebilir mi ([isSrdCard]) — homebrew ve başka
  /// kaynaklı paket kartında hayır. Eski gönderenlerde yok → true.
  final bool srd;

  const EntitySnapshot({
    required this.id,
    required this.name,
    required this.categorySlug,
    this.categoryName = '',
    this.categoryColorHex = '#888888',
    this.description = '',
    this.source = '',
    this.tags = const [],
    this.imagePaths = const [],
    this.fields = const [],
    this.srd = true,
  });

  /// SRD içerik çevirisiyle gösterilecek kopya — alıcı tarafta, yalnızca
  /// görüntü için. DM İngilizce gönderir, her alıcı kendi dilinde çevirir
  /// (docs/srd-tr ROADMAP Faz 6). [tr]: (scope, İngilizce) → gösterilecek.
  EntitySnapshot localized(String Function(String scope, String en) tr) {
    String s(String x) => tr(ContentTranslator.schemaScope, x);
    return EntitySnapshot(
      id: id,
      name: srd ? tr(categorySlug, name) : name,
      categorySlug: categorySlug,
      categoryName: s(categoryName),
      categoryColorHex: categoryColorHex,
      description: srd ? tr(categorySlug, description) : description,
      source: source,
      tags: tags,
      imagePaths: imagePaths,
      fields: [
        for (final f in fields)
          EntityFieldSnapshot(
            label: s(f.label),
            value: f.parts == null
                ? f.value
                : f.parts!.map((p) => tr(p.$1, p.$2)).join(', '),
            groupLabel: f.groupLabel == null ? null : s(f.groupLabel!),
            parts: f.parts,
          ),
      ],
      srd: srd,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'categorySlug': categorySlug,
        'categoryName': categoryName,
        'categoryColorHex': categoryColorHex,
        'description': description,
        'source': source,
        'tags': tags,
        'imagePaths': imagePaths,
        'fields': fields.map((f) => f.toJson()).toList(),
        if (!srd) 'srd': false,
      };

  factory EntitySnapshot.fromJson(Map<String, dynamic> json) => EntitySnapshot(
        id: json['id'] as String,
        name: json['name'] as String,
        categorySlug: json['categorySlug'] as String,
        categoryName: json['categoryName'] as String? ?? '',
        categoryColorHex: json['categoryColorHex'] as String? ?? '#888888',
        description: json['description'] as String? ?? '',
        source: json['source'] as String? ?? '',
        tags: (json['tags'] as List?)?.cast<String>() ?? const [],
        imagePaths: (json['imagePaths'] as List?)?.cast<String>() ?? const [],
        fields: (json['fields'] as List?)
                ?.map((e) => EntityFieldSnapshot.fromJson(
                      (e as Map).cast<String, dynamic>(),
                    ))
                .toList() ??
            const [],
        srd: json['srd'] as bool? ?? true,
      );
}

/// One key→displayValue field row for the player view. Hidden / DM-only
/// fields are filtered out by the builder before this struct is created.
class EntityFieldSnapshot {
  final String label;
  final String value;
  final String? groupLabel;

  /// [value]'nun çevrilebilir parçaları: (kapsam, İngilizce metin), `, ` ile
  /// birleşir. Metin, enum ve ilişki alanlarında dolu; alıcı kendi dilinde
  /// birleştirir. Eski gönderenlerde yok → [value] aynen.
  final List<(String, String)>? parts;

  const EntityFieldSnapshot({
    required this.label,
    required this.value,
    this.groupLabel,
    this.parts,
  });

  Map<String, dynamic> toJson() => {
        'label': label,
        'value': value,
        if (groupLabel != null) 'groupLabel': groupLabel,
        if (parts != null) 'parts': [for (final p in parts!) [p.$1, p.$2]],
      };

  factory EntityFieldSnapshot.fromJson(Map<String, dynamic> json) =>
      EntityFieldSnapshot(
        label: json['label'] as String,
        value: json['value'] as String,
        groupLabel: json['groupLabel'] as String?,
        parts: (json['parts'] as List?)
            ?.whereType<List>()
            .where((p) => p.length == 2 && p[0] is String && p[1] is String)
            .map((p) => (p[0] as String, p[1] as String))
            .toList(),
      );
}
