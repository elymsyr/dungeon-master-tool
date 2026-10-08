import '../entities/entity.dart';
import 'entity_ref.dart';

/// Picker search + context suggestions for `showEntitySelectorDialog`.
///
/// No index, no DSL: every row gets one lowercased text snapshot (cached per
/// [Entity] instance), and a keystroke is a handful of `indexOf` calls per
/// row over those snapshots.

/// Lowercased search text of one entity, built once per [Entity] instance.
/// Bundled SRD rows live for the whole app session, so reopening a picker
/// never rebuilds them; an edited card is a new instance and rebuilds lazily.
class EntitySearchDoc {
  final String name;
  /// Tags + category ("magic-item" → "magic item").
  final String meta;
  /// Description + every non-id string in `fields` (soft-ref names included).
  final String text;
  /// Id-shaped string values in `fields` — hard refs to other cards.
  final Set<String> refIds;

  EntitySearchDoc._(this.name, this.meta, this.text, this.refIds);

  static final _cache = Expando<EntitySearchDoc>();

  static EntitySearchDoc of(Entity e) => _cache[e] ??= _build(e);

  static final _uuid = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$');

  static EntitySearchDoc _build(Entity e) {
    final text = StringBuffer(e.description);
    final refIds = <String>{};
    // SRD spells repeat the description in a `description` field and magic
    // items in `effects` — a third of all SRD text. Scanning it twice per
    // keystroke buys nothing.
    final seen = <String>{e.description};
    void walk(Object? v, int depth) {
      if (v is String) {
        if (v.isEmpty) return;
        if (v.length == 36 && _uuid.hasMatch(v)) {
          refIds.add(v);
        } else if (seen.add(v)) {
          text
            ..write('\n')
            ..write(v);
        }
      } else if (depth < 4 && v is List) {
        for (final x in v) {
          walk(x, depth + 1);
        }
      } else if (depth < 4 && v is Map) {
        for (final x in v.values) {
          walk(x, depth + 1);
        }
      }
    }

    walk(e.fields, 0);
    return EntitySearchDoc._(
      searchFold(e.name),
      '${e.tags.join(' ')} ${e.categorySlug.replaceAll('-', ' ')}'
          .toLowerCase(),
      text.toString().toLowerCase(),
      refIds,
    );
  }
}

/// Arama için küçük harfe indirme. Dart `'İ'.toLowerCase()` → `i̇` (i + nokta
/// birleştiricisi) verir; Türkçe ad "İksir" "iksir" aramasıyla eşleşsin diye
/// önce düz `i` yapılır.
String searchFold(String s) => s.replaceAll('İ', 'i').toLowerCase();

bool _isWordChar(int c) =>
    (c >= 0x61 && c <= 0x7a) || (c >= 0x30 && c <= 0x39) || c > 0x7f;

/// 2 = [t] starts a word in [hay], 1 = only inside words, 0 = absent.
int _hit(String hay, String t) {
  var i = hay.indexOf(t);
  if (i < 0) return 0;
  for (; i >= 0; i = hay.indexOf(t, i + 1)) {
    if (i == 0 || !_isWordChar(hay.codeUnitAt(i - 1))) return 2;
  }
  return 1;
}

/// True when [w] appears in [hay] as a whole word (plural "s" allowed), so
/// "elf" does not hit "itself" and "human" does not hit "humanoid".
bool _hasWord(String hay, String w) {
  for (var i = hay.indexOf(w); i >= 0; i = hay.indexOf(w, i + 1)) {
    if (i > 0 && _isWordChar(hay.codeUnitAt(i - 1))) continue;
    var end = i + w.length;
    if (end < hay.length && hay.codeUnitAt(end) == 0x73) end++; // 's'
    if (end >= hay.length || !_isWordChar(hay.codeUnitAt(end))) return true;
  }
  return false;
}

/// Ranks [pool] (name-sorted) for [query]. A row stays when any token hits:
/// its name anywhere (the old picker's rule, so results only ever grow), or
/// the start of a word in its tags/category/text. More matched tokens first;
/// then the per-token best tier (name word-start 4 > name 3 > tag/category 2
/// > text 1) summed, +2 for [suggested]; then name.
///
/// [shownNames]: id → ekranda gösterilen ad, [searchFold] edilmiş (SRD içerik
/// çevirisi; yalnızca İngilizce addan farklı olanlar). Ad katmanı iki adla da
/// eşleşir, eşitlikte gösterilen ada göre sıralanır.
List<Entity> rankEntities(
  List<Entity> pool,
  String query, {
  Set<String> suggested = const {},
  Map<String, String> shownNames = const {},
}) {
  final tokens = searchFold(query).split(' ')
    ..removeWhere((t) => t.isEmpty);
  if (tokens.isEmpty) return pool;
  final hits = <(Entity, int)>[];
  for (final e in pool) {
    final d = EntitySearchDoc.of(e);
    var matched = 0, score = 0;
    for (final t in tokens) {
      final shown = shownNames[e.id];
      final hn = _hit(d.name, t), hs = shown == null ? 0 : _hit(shown, t);
      final inName = hn > hs ? hn : hs;
      final tier = inName > 0
          ? inName + 2
          : _hit(d.meta, t) == 2
              ? 2
              : _hit(d.text, t) == 2
                  ? 1
                  : 0;
      if (tier > 0) {
        matched++;
        score += tier;
      }
    }
    if (matched == 0) continue;
    if (suggested.contains(e.id)) score += 2;
    hits.add((e, matched * 100 + score));
  }
  hits.sort((a, b) {
    final c = b.$2.compareTo(a.$2);
    return c != 0
        ? c
        : (shownNames[a.$1.id] ?? EntitySearchDoc.of(a.$1).name)
            .compareTo(shownNames[b.$1.id] ?? EntitySearchDoc.of(b.$1).name);
  });
  return [for (final h in hits) h.$1];
}

/// [rankEntities] for one open picker. Typing on inside the last word only
/// drops rows (every hit for "fire" was a hit for "fir"), so that query ranks
/// the previous hits instead of the whole pool; a repeated query (a rebuild
/// after ticking a row) is free.
class EntityRanking {
  EntityRanking(this.pool,
      {this.suggested = const {}, this.shownNames = const {}});

  final List<Entity> pool;
  final Set<String> suggested;
  final Map<String, String> shownNames;
  String _query = '';
  List<Entity> _hits = const [];

  List<Entity> rank(String query) {
    final q = searchFold(query);
    if (q.trim().isEmpty) return pool;
    if (q == _query) return _hits;
    final narrow = _query.trim().isNotEmpty &&
        !_query.endsWith(' ') &&
        q.startsWith(_query) &&
        !q.substring(_query.length).contains(' ');
    _hits = rankEntities(narrow ? _hits : pool, q,
        suggested: suggested, shownNames: shownNames);
    _query = q;
    return _hits;
  }
}

/// Card kinds that describe *who* a character is. Only these become picker
/// context — languages, skills or alignment would make every row "relevant".
const _contextSlugs = {
  'class', 'subclass', 'species', 'subspecies', 'background', //
};

/// Ids in [pool] that fit the card being edited: [fields] (that card's
/// values) points at identity cards (e.g. the Wizard class), and a row fits
/// when it refs one of them (a spell's `class_refs`, an item's
/// `attunement_class_refs`) or names one as a whole word anywhere in its text
/// or tags (`attunement_prereq: 'Sorcerer, Warlock, or Wizard'`, a homebrew
/// item tagged "wizard"). [byId] resolves refs and must hold every source.
Set<String> suggestedEntityIds(
  List<Entity> pool,
  Map<String, dynamic> fields,
  Map<String, Entity> byId,
) {
  final keys = <String>{};
  final words = <String>{};
  for (final v in fields.values) {
    for (final raw in v is List ? v : [v]) {
      // Relation lists store `{id, equipped}` rows; refs are bare/envelopes.
      final id = resolveEntityRef(raw is Map ? raw['id'] ?? raw : raw, byId);
      final e = id == null ? null : byId[id];
      if (e == null || !_contextSlugs.contains(e.categorySlug)) continue;
      keys.add('${e.categorySlug}::${e.name.toLowerCase()}');
      words.add(e.name.toLowerCase());
    }
  }
  if (keys.isEmpty) return const {};
  // The same Wizard exists once per source (campaign, SRD, package) under
  // different ids; a candidate may ref any of them.
  final ctxIds = <String>{
    for (final e in byId.values)
      if (_contextSlugs.contains(e.categorySlug) &&
          keys.contains('${e.categorySlug}::${e.name.toLowerCase()}'))
        e.id,
  };
  return {
    for (final e in pool)
      if (_fits(EntitySearchDoc.of(e), ctxIds, words)) e.id,
  };
}

bool _fits(EntitySearchDoc d, Set<String> ctxIds, Set<String> words) {
  if (d.refIds.any(ctxIds.contains)) return true;
  for (final w in words) {
    if (_hasWord(d.name, w) || _hasWord(d.meta, w) || _hasWord(d.text, w)) {
      return true;
    }
  }
  return false;
}
