import '../catalog/content_reference.dart';

/// Spells a character currently has prepared (or always-known for sorcerer-like
/// classes that blur the distinction). Each entry stores an optional per-class
/// attribution so multiclass casters know which slot pool a spell came from.
class PreparedSpellEntry {
  final String spellId;
  final String? classId; // null = not class-bound (racial, feat-granted, ...)

  const PreparedSpellEntry._(this.spellId, this.classId);

  factory PreparedSpellEntry({required String spellId, String? classId}) {
    validateContentId(spellId);
    if (classId != null) validateContentId(classId);
    return PreparedSpellEntry._(spellId, classId);
  }

  @override
  bool operator ==(Object other) =>
      other is PreparedSpellEntry &&
      other.spellId == spellId &&
      other.classId == classId;

  @override
  int get hashCode => Object.hash(spellId, classId);

  @override
  String toString() =>
      'PreparedSpellEntry($spellId${classId == null ? '' : ' via $classId'})';
}

class PreparedSpells {
  final List<PreparedSpellEntry> entries;

  PreparedSpells(List<PreparedSpellEntry> entries)
      : entries = List.unmodifiable(entries);

  factory PreparedSpells.empty() => PreparedSpells(const []);

  bool contains(String spellId) =>
      entries.any((e) => e.spellId == spellId);

  PreparedSpells add(PreparedSpellEntry entry) {
    if (entries.any((e) =>
        e.spellId == entry.spellId && e.classId == entry.classId)) {
      return this;
    }
    return PreparedSpells([...entries, entry]);
  }

  PreparedSpells remove(String spellId, {String? classId}) => PreparedSpells(
        entries
            .where((e) => !(e.spellId == spellId && e.classId == classId))
            .toList(),
      );

  @override
  bool operator ==(Object other) =>
      other is PreparedSpells && _listEq(other.entries, entries);

  @override
  int get hashCode => Object.hashAll(entries);

  @override
  String toString() => 'PreparedSpells(${entries.length})';
}

bool _listEq(List<PreparedSpellEntry> a, List<PreparedSpellEntry> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
