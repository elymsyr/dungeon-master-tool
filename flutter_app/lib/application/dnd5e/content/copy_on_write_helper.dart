import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../data/database/app_database.dart';

/// Copy-on-write write helper for typed D&D 5e entities.
///
/// All typed content rows live in Drift tables that carry both a
/// `sourcePackageId` / `installedPackageId` column (package-owned SRD content)
/// and a `campaignId` column (world-owned homebrew). The app never mutates
/// package-owned rows — editing an `srd:*` entity writes a campaign-scoped
/// override row with a deterministic `hb:<cid>:<origId>` id, so the original
/// package row stays pristine (other worlds + reinstall still see vanilla
/// SRD content) while the edited campaign sees its override in the same
/// slot. The DAO read path hides package rows that have a campaign
/// override, so the user sees exactly one card per entity — their edited
/// version — not a duplicate.
///
/// Callers (editor dialogs) pass the current id + the updated body and we
/// return the id that was actually written.

/// Returns the id to write for a copy-on-write save. Homebrew ids owned by
/// the active campaign pass through; every other id (SRD, other-campaign
/// homebrew, imported) maps to a deterministic `hb:<activeCampaignId>:<origId>`
/// override so re-editing the same source lands on the same row.
String resolveWriteId({
  required String currentId,
  required String activeCampaignId,
}) {
  final prefix = 'hb:$activeCampaignId:';
  if (currentId.startsWith(prefix)) return currentId;
  return '$prefix$currentId';
}

/// Extracts the package-owned source id encoded in a campaign-override
/// id written by [resolveWriteId]. Returns `null` for ids that aren't
/// in the `hb:<cid>:<origId>` shape.
String? overriddenSourceId(String overrideId, String activeCampaignId) {
  final prefix = 'hb:$activeCampaignId:';
  if (!overrideId.startsWith(prefix)) return null;
  return overrideId.substring(prefix.length);
}

/// Saves an edited entity, forking to homebrew if the source row is
/// package-owned. Returns the id of the row written (new hb id when
/// forked, original id when already homebrew).
///
/// [categorySlug] selects the target Drift table. Supported slugs:
/// `spell`, `monster`, `item`, `feat`, `background`, `race`/`species`,
/// `subclass`, `class`, `condition`, `npc` (→ monsters table).
///
/// [extras] carries category-specific columns the tables require on
/// insert (spells: `level` + `schoolId`; items: `itemType` + optional
/// `rarityId`; subclass: `parentClassId`). Safe to omit for categories
/// that only use name + bodyJson.
Future<String> saveEditedEntity({
  required AppDatabase db,
  required String currentId,
  required String categorySlug,
  required String activeCampaignId,
  required String name,
  required Map<String, Object?> bodyJson,
  Map<String, Object?>? extras,
}) async {
  final writeId = resolveWriteId(
    currentId: currentId,
    activeCampaignId: activeCampaignId,
  );
  final body = jsonEncode(bodyJson);
  final campaignValue =
      writeId == currentId && currentId.startsWith('hb:')
          ? Value(activeCampaignId)
          : Value(activeCampaignId);
  final dao = db.dnd5eContentDao;

  switch (categorySlug) {
    case 'spell':
      await dao.upsertSpell(SpellsCompanion(
        id: Value(writeId),
        name: Value(name),
        level: Value((extras?['level'] as int?) ?? 0),
        schoolId: Value((extras?['schoolId'] as String?) ?? ''),
        bodyJson: Value(body),
        campaignId: campaignValue,
      ));
      break;
    case 'monster':
    case 'npc':
      await dao.upsertMonster(MonstersCompanion(
        id: Value(writeId),
        name: Value(name),
        statBlockJson: Value(body),
        campaignId: campaignValue,
      ));
      break;
    case 'item':
    case 'equipment':
      await dao.upsertItem(ItemsCompanion(
        id: Value(writeId),
        name: Value(name),
        itemType: Value((extras?['itemType'] as String?) ?? 'gear'),
        rarityId: Value(extras?['rarityId'] as String?),
        bodyJson: Value(body),
        campaignId: campaignValue,
      ));
      break;
    case 'feat':
      await dao.upsertFeat(FeatsCompanion(
        id: Value(writeId),
        name: Value(name),
        bodyJson: Value(body),
        campaignId: campaignValue,
      ));
      break;
    case 'background':
      await dao.upsertBackground(BackgroundsCompanion(
        id: Value(writeId),
        name: Value(name),
        bodyJson: Value(body),
        campaignId: campaignValue,
      ));
      break;
    case 'race':
    case 'species':
      await dao.upsertSpecies(SpeciesCatalogCompanion(
        id: Value(writeId),
        name: Value(name),
        bodyJson: Value(body),
        campaignId: campaignValue,
      ));
      break;
    case 'subclass':
      await dao.upsertSubclass(SubclassesCompanion(
        id: Value(writeId),
        name: Value(name),
        bodyJson: Value(body),
        parentClassId:
            Value((extras?['parentClassId'] as String?) ?? ''),
        campaignId: campaignValue,
      ));
      break;
    case 'class':
      await dao.upsertClassProgression(ClassProgressionsCompanion(
        id: Value(writeId),
        name: Value(name),
        bodyJson: Value(body),
        campaignId: campaignValue,
      ));
      break;
    case 'condition':
      await dao.upsertCondition(ConditionsCompanion(
        id: Value(writeId),
        name: Value(name),
        bodyJson: Value(body),
        sourcePackageId: const Value('homebrew'),
      ));
      break;
    default:
      throw ArgumentError(
          'saveEditedEntity: unsupported categorySlug "$categorySlug"');
  }

  return writeId;
}
