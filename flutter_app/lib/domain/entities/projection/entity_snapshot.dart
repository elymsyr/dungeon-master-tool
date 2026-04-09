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
  });

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
      );
}

/// One key→displayValue field row for the player view. Hidden / DM-only
/// fields are filtered out by the builder before this struct is created.
class EntityFieldSnapshot {
  final String label;
  final String value;
  final String? groupLabel;

  const EntityFieldSnapshot({
    required this.label,
    required this.value,
    this.groupLabel,
  });

  Map<String, dynamic> toJson() => {
        'label': label,
        'value': value,
        if (groupLabel != null) 'groupLabel': groupLabel,
      };

  factory EntityFieldSnapshot.fromJson(Map<String, dynamic> json) =>
      EntityFieldSnapshot(
        label: json['label'] as String,
        value: json['value'] as String,
        groupLabel: json['groupLabel'] as String?,
      );
}
