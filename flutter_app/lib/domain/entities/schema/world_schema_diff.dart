import 'encounter_config.dart';
import 'world_schema.dart';

/// Compares two [WorldSchema] instances and returns a list of human-readable
/// change descriptions. Used by the drift dialog and campaign settings to
/// show the user what will change if they accept a template update.
///
/// Matching is done by semantic name (not ID), because IDs rotate on
/// fork / re-import but names are what the user recognises.
List<String> computeWorldSchemaDiff(WorldSchema oldSchema, WorldSchema newSchema) {
  final changes = <String>[];

  _diffCategories(oldSchema, newSchema, changes);
  _diffEncounterConfig(oldSchema.encounterConfig, newSchema.encounterConfig, changes);
  _diffEncounterLayouts(oldSchema, newSchema, changes);

  return changes;
}

// ---------------------------------------------------------------------------
// Categories + Fields
// ---------------------------------------------------------------------------

void _diffCategories(WorldSchema old, WorldSchema now, List<String> out) {
  final oldByName = {for (final c in old.categories) c.name: c};
  final newByName = {for (final c in now.categories) c.name: c};

  // Added categories
  for (final name in newByName.keys) {
    if (!oldByName.containsKey(name)) {
      out.add('Added category: $name');
    }
  }

  // Removed categories
  for (final name in oldByName.keys) {
    if (!newByName.containsKey(name)) {
      out.add('Removed category: $name');
    }
  }

  // Changed fields within surviving categories
  for (final name in newByName.keys) {
    final oldCat = oldByName[name];
    if (oldCat == null) continue;
    final newCat = newByName[name]!;

    final oldFields = {for (final f in oldCat.fields) f.label};
    final newFields = {for (final f in newCat.fields) f.label};

    for (final f in newFields) {
      if (!oldFields.contains(f)) {
        out.add('$name: added field $f');
      }
    }
    for (final f in oldFields) {
      if (!newFields.contains(f)) {
        out.add('$name: removed field $f');
      }
    }
  }
}

// ---------------------------------------------------------------------------
// EncounterConfig
// ---------------------------------------------------------------------------

void _diffEncounterConfig(EncounterConfig old, EncounterConfig now, List<String> out) {
  // Columns — compare by label
  final oldCols = {for (final c in old.columns) c.label};
  final newCols = {for (final c in now.columns) c.label};

  for (final label in newCols) {
    if (!oldCols.contains(label)) {
      out.add('Encounter: added column $label');
    }
  }
  for (final label in oldCols) {
    if (!newCols.contains(label)) {
      out.add('Encounter: removed column $label');
    }
  }

  // Conditions
  final oldConds = old.conditions.toSet();
  final newConds = now.conditions.toSet();
  final addedConds = newConds.difference(oldConds);
  final removedConds = oldConds.difference(newConds);
  if (addedConds.isNotEmpty) {
    out.add('Encounter: added conditions ${addedConds.join(', ')}');
  }
  if (removedConds.isNotEmpty) {
    out.add('Encounter: removed conditions ${removedConds.join(', ')}');
  }

  // Scalar settings
  if (old.combatStatsFieldKey != now.combatStatsFieldKey) {
    out.add('Encounter: combat stats field changed');
  }
  if (old.conditionStatsFieldKey != now.conditionStatsFieldKey) {
    out.add('Encounter: condition stats field changed');
  }
  if (old.statBlockFieldKey != now.statBlockFieldKey) {
    out.add('Encounter: stat block field changed');
  }
  if (old.sortBySubField != now.sortBySubField) {
    out.add('Encounter: sort field changed to ${now.sortBySubField}');
  }
  if (old.sortDirection != now.sortDirection) {
    out.add('Encounter: sort direction changed to ${now.sortDirection}');
  }
}

// ---------------------------------------------------------------------------
// EncounterLayouts
// ---------------------------------------------------------------------------

void _diffEncounterLayouts(WorldSchema old, WorldSchema now, List<String> out) {
  final oldByName = {for (final l in old.encounterLayouts) l.name};
  final newByName = {for (final l in now.encounterLayouts) l.name};

  for (final name in newByName) {
    if (!oldByName.contains(name)) {
      out.add('Added encounter layout: $name');
    }
  }
  for (final name in oldByName) {
    if (!newByName.contains(name)) {
      out.add('Removed encounter layout: $name');
    }
  }
}
