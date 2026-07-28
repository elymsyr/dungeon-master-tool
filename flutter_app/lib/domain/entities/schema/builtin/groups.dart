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
const grpMaps = 'grp-maps';

/// Groups of the shared "what this card grants" block (`_FB.grantBlock`).
/// Split by what a DM is looking for rather than by data shape, so a mostly
/// empty feat card stays scannable: the groups render collapsed in edit mode
/// and empty fields are hidden entirely in read mode.
const grpGrantsProficiency = 'grp-grants-proficiency';
const grpGrantsNumeric = 'grp-grants-numeric';
const grpGrantsDefense = 'grp-grants-defense';
const grpGrantsResources = 'grp-grants-resources';
const grpGrantsNotes = 'grp-grants-notes';

/// Two-column Identity + Lookup-Meta groups used by every Tier-0 row.
List<FieldGroup> lookupGroups() => const [
      FieldGroup(groupId: grpIdentity, name: 'Identity', gridColumns: 2, orderIndex: 0),
      FieldGroup(groupId: grpLookupMeta, name: 'Details', gridColumns: 2, orderIndex: 1),
    ];

/// The five [FieldGroup]s of the grant block, ordered from [from] onward.
/// Every category that calls `_FB.grantBlock()` splices these into its group
/// list so the layout is identical wherever the block appears.
List<FieldGroup> grantGroups(int from) => [
      FieldGroup(
          groupId: grpGrantsProficiency,
          name: 'Grants — Proficiencies & Spells',
          gridColumns: 2,
          orderIndex: from),
      FieldGroup(
          groupId: grpGrantsNumeric,
          name: 'Grants — Numeric Bonuses',
          gridColumns: 3,
          orderIndex: from + 1),
      FieldGroup(
          groupId: grpGrantsDefense,
          name: 'Grants — Defense, Senses & Movement',
          gridColumns: 2,
          orderIndex: from + 2),
      FieldGroup(
          groupId: grpGrantsResources,
          name: 'Resources & Player Choices',
          gridColumns: 1,
          orderIndex: from + 3),
      FieldGroup(
          groupId: grpGrantsNotes,
          name: 'Mechanical Notes',
          gridColumns: 1,
          orderIndex: from + 4),
    ];
