import '../field_group.dart';

/// Shared FieldGroup ids reused across categories.
/// Deterministic strings — categories reference these by id so
/// the FE renders the same layout across installs.
const grpIdentity = 'grp-identity';
const grpLookupMeta = 'grp-lookup-meta';
const grpAbilityScores = 'grp-ability-scores';
const grpCombat = 'grp-combat';
const grpResistances = 'grp-resistances';
const grpSensesLanguages = 'grp-senses-languages';
const grpTraitsActions = 'grp-traits-actions';
const grpSpells = 'grp-spells';
const grpMeta = 'grp-meta';
const grpRules = 'grp-rules';
const grpCostWeight = 'grp-cost-weight';
const grpProperties = 'grp-properties';
const grpProgression = 'grp-progression';
const grpSpellcasting = 'grp-spellcasting';
const grpFeatures = 'grp-features';

/// Two-column Identity + Lookup-Meta groups used by every Tier-0 row.
List<FieldGroup> lookupGroups() => const [
      FieldGroup(groupId: grpIdentity, name: 'Identity', gridColumns: 2, orderIndex: 0),
      FieldGroup(groupId: grpLookupMeta, name: 'Details', gridColumns: 2, orderIndex: 1),
    ];
