/// Legacy content → Template v3 value converter (docs/new_system/content-convert.md).
///
/// Per-field-**value** transformations applied when a legacy (v2-era) card value
/// meets a v3 template field whose type — and therefore stored wire-shape —
/// changed. Per content-convert §Tooling the SAME code runs in three places so
/// the conversion is identical everywhere:
///
///   1. the offline pack CLI (`tool/convert_packs_v3.dart`),
///   2. the on-open shim for user personal packages,
///   3. the world-entity migration during the v3 upgrade prompt.
///
/// Every function here is **deterministic and idempotent**: re-running it on
/// already-converted content returns that content byte-identical (content-convert
/// §Verification). This module is intentionally template-agnostic — callers pass
/// the resolved parameters (e.g. a pouch's pip `count`) so the same primitives
/// serve the built-in PC sheet and any custom template that adopts the v3 types.
///
/// Scope note: this is the first slice of the PR-T9 converter. It currently
/// carries the content-convert §2 pip-integer → `checkboxPouch` value migration
/// (the only value-migrating swap the built-in PC-category type swap needs —
/// roadmap PR-T6 / PR-2.3 slice B). The remaining per-kind mappings
/// (content-convert §3-7) land with the bundled-pack conversion wave (PR-T9).
library;

/// content-convert §2 — integer pip field → `checkboxPouch` value.
///
/// The v2 built-in stored death-save successes/failures and heroic inspiration
/// as a clamped `0..count` integer; the v3 PC template declares them as
/// `checkboxPouch` fields whose wire is `{count, states[bool]}` (the byte-
/// identical `slot` wire — field_schema.dart). This maps the stored int `n` →
///
/// ```json
/// {"count": <count>, "states": [true × n, false × (count − n)]}
/// ```
///
/// so `n` of the `count` pips read as filled and the field renders correctly the
/// first time it is opened on a v3 build (the `_SlotFieldWidget` returns an empty
/// pouch for a bare int, so without this migration the stored value would be
/// silently lost).
///
/// **Idempotent.** A value already in the canonical `{count, states}` shape — or
/// the legacy `{count, filled}` shape the renderer also tolerates — is
/// renormalised against [count] (filled pips counted, never doubled), so running
/// the converter twice yields a byte-identical map. A `null`/garbage value yields
/// an all-`false` pouch (the field's zero value), never an exception.
Map<String, dynamic> migratePipIntToCheckboxPouch(
  dynamic value, {
  required int count,
}) {
  final filled = _coercePipFilled(value, count);
  return <String, dynamic>{
    'count': count,
    'states': <bool>[for (var i = 0; i < count; i++) i < filled],
  };
}

/// Resolves how many pips of a `checkboxPouch` value are filled, clamped to
/// `[0, count]`, from any of the shapes a pip field may legitimately hold:
///   * a bare integer (the v2 stored form) → its own value,
///   * the canonical `{count, states[bool]}` map → the number of `true` states,
///   * the legacy `{count, filled}` map → `filled`,
/// falling back to `0` for null / unrecognised input.
int _coercePipFilled(dynamic value, int count) {
  if (value is num) {
    return value.toInt().clamp(0, count);
  }
  if (value is Map) {
    final states = value['states'];
    if (states is List) {
      final trueCount = states.where((dynamic s) => s == true).length;
      return trueCount.clamp(0, count);
    }
    final filled = value['filled'];
    if (filled is num) {
      return filled.toInt().clamp(0, count);
    }
  }
  return 0;
}
