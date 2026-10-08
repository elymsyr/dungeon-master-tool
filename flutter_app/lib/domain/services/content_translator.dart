import '../entities/schema/builtin/srd_core/srd_core_pack.dart' show srdSourceTag;
import '../entities/schema/field_schema.dart';

/// Ekranda görünse de kimlik/anahtar olan metin alanları — çevrilmez
/// (docs/srd-tr/ROADMAP.md K10). Çıkarma aracı
/// (`tool/srd_l10n/bin/extract.dart`) da bu listeyi kullanır.
const srdL10nMachineTextKeys = {
  'source', // "SRD 5.2.1" — aynen kalır
  'icon_name',
  'color',
  'legacy_subspecies_key',
  'weapon_mastery_filter',
  'granted_tool_variant_group',
};

/// Kart asıl SRD içeriği mi — çeviri tabloları yalnızca bunlar için.
/// Düzenlenip forklanan kart (homebrew, `linked == false`) ve başka
/// kaynaklı paket kartları (Open5e, marketplace…) yazıldığı gibi kalır.
bool isSrdCard(bool linked, String source) =>
    linked && source == srdSourceTag;

/// SRD içerik çevirisi (docs/srd-tr/ROADMAP.md §3, Yaklaşım A): ekrana
/// basılan İngilizce metni seçili dildeki karşılığıyla değiştirir. Anahtar
/// birebir İngilizce kaynak metindir; eşleşmeyen ya da çevrilmemiş (`""`)
/// metin aynen döner. Sonuç yalnızca gösterilir — hiçbir kayıt yoluna
/// girmez (K3), veri İngilizce kalır.
class ContentTranslator {
  const ContentTranslator(this._tables);

  /// Çeviri tablosu olmayan diller için.
  static const identity = ContentTranslator({});

  /// Kategori adları, alan grubu adları, alan etiketleri, enum değerleri.
  static const schemaScope = '_schema';

  /// scope (kategori slug'ı ya da [schemaScope]) → İngilizce → çeviri.
  final Map<String, Map<String, String>> _tables;

  bool get isIdentity => _tables.isEmpty;

  static final _schemaOnly = Expando<ContentTranslator>();

  /// Bir kartın içeriğini çevirecek çevirmen ([srd] = [isSrdCard]). SRD
  /// olmayan kartın adı, açıklaması ve metin alanları SRD dilinden bağımsız,
  /// yazıldığı gibi kalır; şema sözcükleri (etiketler, enum değerleri,
  /// kategori adları) yine çevrilir.
  ContentTranslator forCard(bool srd) {
    if (srd || isIdentity) return this;
    return _schemaOnly[this] ??= ContentTranslator({
      if (_tables[schemaScope] case final s?) schemaScope: s,
    });
  }

  /// [scope]'taki çeviri; yoksa ya da boşsa [en] aynen.
  String tr(String scope, String en) {
    final t = _tables[scope]?[en];
    return t == null || t.isEmpty ? en : t;
  }

  /// Etiketi, yer tutucusu, yardım metni ve alt alan etiketleri çevrilmiş
  /// alan şeması. Değişen bir şey yoksa [f]'in kendisi döner.
  FieldSchema field(FieldSchema f) {
    if (!_tables.containsKey(schemaScope)) return f;
    String s(String x) => tr(schemaScope, x);
    var changed = false;
    final subs = <Map<String, String>>[];
    for (final m in f.subFields) {
      final l = m['label'];
      if (l != null && s(l) != l) {
        changed = true;
        subs.add({...m, 'label': s(l)});
      } else {
        subs.add(m);
      }
    }
    final label = s(f.label), ph = s(f.placeholder), help = s(f.helpText);
    if (!changed &&
        label == f.label &&
        ph == f.placeholder &&
        help == f.helpText) {
      return f;
    }
    return f.copyWith(
        label: label, placeholder: ph, helpText: help, subFields: subs);
  }

  /// [scope] kategorisindeki bir kartın [f] alanındaki [v] değerinin
  /// gösterilecek hali. Hangi alanların çevrildiği çıkarma aracıyla aynıdır:
  /// metin alanları, enum değerleri ([schemaScope]), seviye metin tablosu,
  /// sınıf özelliği / alt tür satırlarının ad + açıklaması, ekipman ve oyuncu
  /// seçimlerinin etiket + sorusu. Ref'ler, sayılar, zarlar dokunulmaz.
  dynamic value(String scope, FieldSchema f, dynamic v) {
    if (v == null || srdL10nMachineTextKeys.contains(f.fieldKey)) return v;
    Object? t(Object? x, [String? sc]) =>
        x is String ? tr(sc ?? scope, x) : x;
    Map row(Map r, List<String> keys) =>
        {...r, for (final k in keys) if (r[k] is String) k: t(r[k])};
    final hasScope = _tables.containsKey(scope);
    switch (f.fieldType) {
      case FieldType.text:
      case FieldType.textarea:
      case FieldType.markdown:
        return t(v);
      case FieldType.enum_:
        return v is List ? [for (final x in v) t(x, schemaScope)] : t(v, schemaScope);
      case FieldType.levelTextTable when hasScope && v is Map:
        return {for (final e in v.entries) e.key: t(e.value)};
      case FieldType.classFeatures || FieldType.subspeciesOptions
          when hasScope && v is List:
        return [
          for (final r in v) r is Map ? row(r, const ['name', 'description']) : r,
        ];
      case FieldType.equipmentChoiceGroups || FieldType.playerChoices
          when hasScope && v is List:
        return [
          for (final g in v)
            if (g is Map)
              {
                ...row(g, const ['label', 'prompt']),
                if (g['options'] is List)
                  'options': [
                    for (final o in g['options'] as List)
                      o is Map ? row(o, const ['label']) : o,
                  ],
              }
            else
              g,
        ];
      default:
        return v;
    }
  }
}
