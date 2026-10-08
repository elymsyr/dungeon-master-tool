import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/services/content_translator.dart';
import 'ui_state_provider.dart';

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

/// İçerik çevirisinin dili: bu cihazın ayarlardaki SRD dili (arayüz dilinden
/// bağımsız). Her cihaz SRD'yi kendi seçtiği dilde görür — çevrimiçi oyuncu
/// DM'in dilini değil kendininkini.
/// Ayrı motorda çalışan yerel projeksiyon pencereleri (ikinci pencere, ekran
/// yansıtma) bunu DM'in IPC ile gönderdiği dille override eder; onlar DM'in
/// kendi ekranıdır.
final contentLanguageProvider =
    Provider<String>((ref) => ref.watch(uiStateProvider.select((s) => s.srdLanguage)));

/// Seçili dilin içerik çevirmeni. Yüklenene kadar (ve hata olursa)
/// kimlik — ekran İngilizce görünür, hiçbir şey bozulmaz.
final contentTranslatorProvider = Provider<ContentTranslator>((ref) {
  final lang = ref.watch(contentLanguageProvider);
  return ref.watch(_contentTablesProvider(lang)).valueOrNull ??
      ContentTranslator.identity;
});
