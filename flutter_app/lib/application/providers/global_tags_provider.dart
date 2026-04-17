import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'campaign_provider.dart';
import 'character_provider.dart';
import 'package_provider.dart';
import 'template_provider.dart';

/// Kullanıcının yerelindeki tüm item'lardan toplanan global tag havuzu.
/// Autocomplete için kullanılır — yazarken önceki tag'lerden öneri verir.
///
/// Kaynaklar:
///   - characters: entity.tags
///   - templates: metadata['tags'] (WorldSchema metadata — eklenecek)
///   - worlds (campaigns) ve packages: Henüz metadata alanı yok — geri
///     dönüş boş liste. Phase 2'de eklenince bu provider otomatik toplar.
final globalTagsProvider = Provider<Set<String>>((ref) {
  final out = <String>{};

  final characters = ref.watch(characterListProvider).valueOrNull;
  if (characters != null) {
    for (final c in characters) {
      out.addAll(c.entity.tags.where((t) => t.trim().isNotEmpty));
    }
  }

  final templates = ref.watch(allTemplatesProvider).valueOrNull;
  if (templates != null) {
    for (final t in templates) {
      final rawTags = t.metadata['tags'];
      if (rawTags is List) {
        out.addAll(rawTags
            .whereType<String>()
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty));
      }
    }
  }

  // Packages & Campaigns — metadata alanları Phase 2'de eklenecek. Şu an
  // sadece isim/template bilgisi olduğu için tag çıkarılmıyor.
  ref.watch(campaignInfoListProvider);
  ref.watch(packageListProvider);

  return out;
});
