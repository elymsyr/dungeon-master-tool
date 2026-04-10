import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/schema/world_schema.dart';
import '../../domain/entities/schema/world_schema_diff.dart';
import '../../domain/entities/schema/world_schema_hash.dart';
import '../providers/template_provider.dart';

/// Payload describing a detected template-vs-campaign drift. Surfaced via
/// [pendingTemplateUpdateProvider] when a campaign is loaded with a stale
/// template hash, so the UI can prompt the user to update or skip.
class TemplateUpdatePrompt {
  final String campaignName;
  final String templateId;
  final String templateName;
  final String? oldHash;
  final String newHash;
  final WorldSchema newTemplate;
  final List<String> diffSummary;

  const TemplateUpdatePrompt({
    required this.campaignName,
    required this.templateId,
    required this.templateName,
    required this.oldHash,
    required this.newHash,
    required this.newTemplate,
    this.diffSummary = const [],
  });
}

/// Single-slot prompt the UI listens to. Set when a campaign load detects
/// drift; cleared by the prompt dialog after the user makes a choice.
final pendingTemplateUpdateProvider =
    StateProvider<TemplateUpdatePrompt?>((ref) => null);

/// Lazy template-sync logic. Compares a freshly loaded campaign's recorded
/// template hash against the current on-disk template's content hash and
/// returns a prompt payload if they differ. Returns null if there is no
/// matching template, no recorded provenance, or hashes match.
class TemplateSyncService {
  final Ref _ref;
  TemplateSyncService(this._ref);

  /// Inspects [campaignData] (the raw map returned by
  /// `CampaignRepository.load`) and returns a [TemplateUpdatePrompt] when
  /// the campaign is out of sync with its source template.
  ///
  /// Resolution strategy (in order):
  ///   1. Look up the source template by `template_original_hash` — the
  ///      frozen lineage identifier that survives template edits AND
  ///      schemaId rotations. This is the preferred path because it is
  ///      content-derived and matches "the same template" across forks
  ///      and re-imports.
  ///   2. Fall back to `template_id` (the schemaId) for legacy campaigns
  ///      that were saved before the originalHash field landed.
  ///
  /// Returns null when:
  ///   - the campaign has neither `template_original_hash` nor `template_id`
  ///   - no on-disk template matches either lookup
  ///   - the recorded `template_hash` matches the freshly recomputed
  ///     current hash of the resolved template (no drift)
  ///
  /// Legacy campaigns (created before template tracking landed) will have
  /// `template_id == 'builtin-dnd5e-default'` (set by the loader's fallback)
  /// and a null `template_hash`. Those are treated as "out of sync" on
  /// first open so the user gets a one-time chance to refresh against the
  /// current built-in template.
  Future<TemplateUpdatePrompt?> checkDrift({
    required String campaignName,
    required Map<String, dynamic> campaignData,
  }) async {
    final templateId = campaignData['template_id'] as String?;
    final originalHash = campaignData['template_original_hash'] as String?;
    if (templateId == null && originalHash == null) return null;

    // Permanently muted — user chose "Do not show again" for this campaign.
    final muted = campaignData['template_updates_muted'] as bool? ?? false;
    if (muted) return null;
    final recordedHash = campaignData['template_hash'] as String?;

    final all = await _ref.read(allTemplatesProvider.future);
    WorldSchema? template;
    // 1) Prefer lineage match: find any template whose frozen
    //    originalHash equals the campaign's recorded one. This works even
    //    after a re-import or schemaId change.
    if (originalHash != null) {
      for (final t in all) {
        if (t.originalHash == originalHash) {
          template = t;
          break;
        }
      }
    }
    // 2) Legacy fallback: match by schemaId. Used by campaigns persisted
    //    before originalHash existed.
    if (template == null && templateId != null) {
      for (final t in all) {
        if (t.schemaId == templateId) {
          template = t;
          break;
        }
      }
    }
    if (template == null) {
      // Source template was deleted — nothing to sync against. Stay quiet.
      return null;
    }

    final currentHash = computeWorldSchemaContentHash(template);
    if (currentHash == recordedHash) return null;

    // User previously dismissed this exact template version — stay quiet
    // until the template is edited again (producing a new hash).
    final dismissedHash = campaignData['template_dismissed_hash'] as String?;
    if (currentHash == dismissedHash) return null;

    // Compute a human-readable diff between the campaign's current schema
    // and the updated template so the UI can show what will change.
    List<String> diff = const [];
    final oldSchemaMap = campaignData['world_schema'] as Map<String, dynamic>?;
    if (oldSchemaMap != null) {
      try {
        final oldSchema = WorldSchema.fromJson(
          Map<String, dynamic>.from(oldSchemaMap),
        );
        diff = computeWorldSchemaDiff(oldSchema, template);
      } catch (_) {
        // Malformed schema — skip diff, still show the prompt.
      }
    }

    return TemplateUpdatePrompt(
      campaignName: campaignName,
      templateId: template.schemaId,
      templateName: template.name,
      oldHash: recordedHash,
      newHash: currentHash,
      newTemplate: template,
      diffSummary: diff,
    );
  }
}

final templateSyncServiceProvider = Provider<TemplateSyncService>((ref) {
  return TemplateSyncService(ref);
});
