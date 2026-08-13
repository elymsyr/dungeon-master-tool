/// Wizard sayfalarının seçenek listelerini üreten saf okuyucular.
///
/// Adım widget'ları bu fonksiyonları çağırır; U2'nin paket testleri de aynı
/// fonksiyonları çağırır. Tek kaynak olması önemli — daha önce aynı yüklem
/// (`class_refs` ya da `tags`) beş yerde kopyalanmıştı ve kopyalardan biri
/// (`_validateSpells`) `tags` yarısını hiç okumuyordu, yani paket büyüsü
/// gören adım ile saymayan doğrulayıcı aynı fikirde değildi.
library;

import '../../domain/entities/entity.dart';
import '../../domain/services/entity_ref.dart';

/// Bir büyü verilen sınıfa ait mi?
///
/// SRD büyüleri sınıfa UUID ile bağlanır (`class_refs`); içe aktarılan Open5e
/// paketlerinde bu alan **her satırda boş**, sınıf adı sadece `tags` içinde
/// taşınır. İkisini de kabul et, yoksa paket büyüleri sessizce elenir.
bool spellMatchesClass(
  Entity spell,
  Entity classEntity,
  Map<String, Entity> entities,
) {
  if (resolveEntityRefList(spell.fields['class_refs'], entities)
      .contains(classEntity.id)) {
    return true;
  }
  return spellMatchesClassName(spell, classEntity.name);
}

/// [spellMatchesClass]'ın sadece-ad yarısı: elde `Entity` yokken (feat
/// spell-list seçimleri sınıfı adıyla anar) kullanılır.
bool spellMatchesClassName(Entity spell, String className) {
  final lower = className.toLowerCase();
  return spell.tags.any((t) => t.toLowerCase() == lower);
}

/// [classId] sınıfının alt sınıfları — `parent_class_ref` paket içinde düz id,
/// temel sınıf başka pakette/gömülü olduğunda softRef `{slug, name}` olur;
/// [resolveEntityRef] ikisini de çözer.
///
/// `granted_at_level`, sonra ad sırasına dizilir (adımın gösterdiği sıra).
List<Entity> subclassesForClass(
  String? classId,
  Map<String, Entity> entities, {
  Iterable<Entity>? candidates,
}) {
  if (classId == null || classId.isEmpty) return const [];
  final out = [
    for (final e in candidates ?? entities.values)
      if (e.categorySlug == 'subclass' &&
          resolveEntityRef(e.fields['parent_class_ref'], entities) == classId)
        e,
  ]..sort((a, b) {
      final la = subclassGrantedAtLevel(a);
      final lb = subclassGrantedAtLevel(b);
      if (la != lb) return la.compareTo(lb);
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
  return out;
}

/// Alt sınıfın açıldığı seviye. Yoksa 1 — kilitleme sadece veri varken uygulanır.
int subclassGrantedAtLevel(Entity e) {
  final v = e.fields['granted_at_level'];
  if (v is int) return v;
  if (v is String) return int.tryParse(v) ?? 1;
  return 1;
}

/// [speciesId] türüne `parent_species_ref` ile bağlı birinci sınıf `subspecies`
/// satırları. Eski `subspecies_options` gömülü satırları burada değil, çağıran
/// tarafta ekleniyor (onların id'si yok, adı var).
List<Entity> subspeciesForSpecies(
  String? speciesId,
  Map<String, Entity> entities,
) {
  if (speciesId == null || speciesId.isEmpty) return const [];
  return [
    for (final e in entities.values)
      if (e.categorySlug == 'subspecies' &&
          resolveEntityRef(e.fields['parent_species_ref'], entities) ==
              speciesId)
        e,
  ];
}
