import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/services/content_translator.dart';
import 'locale_provider.dart';

/// `assets/srd_l10n/<dil>/<scope>.json` tablolarını yükler (docs/srd-tr
/// ROADMAP §3). Tablosu olmayan dil → [ContentTranslator.identity].
final _contentTablesProvider =
    FutureProvider.family<ContentTranslator, String>((ref, lang) async {
  final prefix = 'assets/srd_l10n/$lang/';
  final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
  final tables = <String, Map<String, String>>{};
  for (final path in manifest.listAssets()) {
    if (!path.startsWith(prefix) || !path.endsWith('.json')) continue;
    final raw = (jsonDecode(await rootBundle.loadString(path, cache: false))
            as Map)
        .cast<String, String>()
      ..removeWhere((_, v) => v.isEmpty);
    if (raw.isNotEmpty) {
      tables[path.substring(prefix.length, path.length - '.json'.length)] =
          raw;
    }
  }
  return tables.isEmpty
      ? ContentTranslator.identity
      : ContentTranslator(tables);
});

/// Seçili dilin içerik çevirmeni. Yüklenene kadar (ve hata olursa)
/// kimlik — ekran İngilizce görünür, hiçbir şey bozulmaz.
final contentTranslatorProvider = Provider<ContentTranslator>((ref) {
  final lang = ref.watch(localeProvider).languageCode;
  return ref.watch(_contentTablesProvider(lang)).valueOrNull ??
      ContentTranslator.identity;
});
