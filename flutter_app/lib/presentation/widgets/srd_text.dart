import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/content_translator_provider.dart';
import '../../application/providers/entity_provider.dart';
import '../../domain/entities/entity.dart';
import '../../domain/entities/session.dart';
import '../../domain/services/content_translator.dart';

/// SRD içerik çevirisi (docs/srd-tr/ROADMAP.md Faz 6): ekranda gösterilecek
/// metin. Veri, ref çözümü, arama anahtarı ve kayıt hep İngilizce adla
/// çalışır; çeviri yalnızca gösterirken, bu cihazın dilinde uygulanır.
/// Tablosu olmayan dil, eşleşmeyen ya da kullanıcının yazdığı metin aynen
/// döner.
///
/// Çevirmen `read` ile alınır; dil değişince yeniden çizim, sahibi olan
/// ekranın `ref.watch(contentTranslatorProvider)`'ından gelir. Üstte
/// `ProviderScope` yoksa (yalın widget testleri) metin aynen döner.
String srdText(BuildContext context, String scope, String en) {
  final scopeEl = context
      .getElementForInheritedWidgetOfExactType<UncontrolledProviderScope>();
  if (scopeEl == null) return en;
  return (scopeEl.widget as UncontrolledProviderScope)
      .container
      .read(contentTranslatorProvider)
      .tr(scope, en);
}

/// [e] kartının gösterilecek adı.
/// SRD olmayan kart ([isSrdCard]) çevrilmez.
String srdName(BuildContext context, Entity e) =>
    isSrdCard(e.linked, e.source)
        ? srdText(context, e.categorySlug, e.name)
        : e.name;

/// Ref zarfının (`{slug, name}`, `{_lookup, name}`, `{_ref, name}`)
/// gösterilecek adı; zarfın slug'ı kategori kapsamıdır. Ad yoksa null.
String? srdRefName(BuildContext context, Map ref) {
  final name = ref['name'];
  if (name is! String) return null;
  final scope = ref['slug'] ?? ref['_lookup'] ?? ref['_ref'];
  return scope is String ? srdText(context, scope, name) : name;
}

/// Savaşçının gösterilecek adı. Kaynağı bir kartsa ve ad hâlâ kartın adıysa
/// çevrilir; DM'in verdiği ad ("Goblin 2") aynen kalır.
String srdCombatantName(BuildContext context, Combatant c) {
  final id = c.entityId;
  if (id == null) return c.name;
  final scopeEl = context
      .getElementForInheritedWidgetOfExactType<UncontrolledProviderScope>();
  if (scopeEl == null) return c.name;
  final e = (scopeEl.widget as UncontrolledProviderScope)
      .container
      .read(entityProvider)[id];
  return e == null || e.name != c.name ? c.name : srdName(context, e);
}

/// Savaştaki bir durumun (`Blinded`…) gösterilecek adı.
String srdConditionName(BuildContext context, String name) =>
    srdText(context, 'condition', name);

/// [e] kartının gösterilecek açıklaması.
String srdDescription(BuildContext context, Entity e) =>
    isSrdCard(e.linked, e.source)
        ? srdText(context, e.categorySlug, e.description)
        : e.description;
