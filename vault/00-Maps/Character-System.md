---
type: moc
domain: chargen
updated: 2026-09-01
tags: [moc]
---

# Character System — Map of Content

> [!summary] Scope
> D&D 5e character creation + level-up + read-time stat resolution. Wizard state machine, multiclass, caster progression, ASI/feat picks, and the pure-function resolver that folds descriptive content entities into a typed `EffectiveCharacter`. Content itself comes from [[Content-Pipeline]] / [[World-and-Content]].

## Key Files
- [[character_resolver]] — pure read-time resolver; folds the 40 named grant-block fields a card can declare → [[effective_character]]. Core of [[Grant-Resolution]].
- [[entity_ref]] — hard (uuid) vs soft (slug+name) ref resolution. See [[Ref-Resolution-Hard-vs-Soft]].
- [[level_up_planner]] — `planLevelUp` delta: HP, prof bonus, features, ASI/feat flags, slots, pools.
- [[caster_progression]] — Full/Half/Pact spell tables (cantrips/known/prepared/slots).
- [[resource_pool_resolver]] — Rage/Ki/Sorcery/Lay-on-Hands pool sizing + `count_formula`.
- [[extra_attack_resolver]] — Extra Attack count by level/class.
- [[weapon_mastery_resolver]] — mastery count cap (SRD §1.7).
- [[ability_score_method]] · [[ability_score_validator]] — array/point-buy/roll + ASI validation.
- [[multiclass_helper]] — multiclass progression + grants.
- [[character_draft]] · [[character_draft_notifier]] — wizard Riverpod state.
- [[wizard_options]] — sihirbaz adımlarının seçenek yüklemleri (büyü→sınıf, alt sınıf→sınıf, alt tür→tür); adımlar ve U2 paket testleri aynı fonksiyonları çağırır.
- [[pending_choices]] — queued choice kinds (ASI, feat, subclass, spell, equipment…).
- [[effective_character]] — computed view (AC, init, prof, immunities, warnings).

> [!warning] Bir mekaniğin "alanda değeri var" olması sayfaya ulaştığı anlamına gelmiyor — audit **M1** (2026-08-13)
> `test/domain/services/bundled_pack_resolve_test.dart` artık 19 paketin oyuncuya dönük kartlarının yazdığı **her** alanı gezip [[character_resolver]] üzerinden bir `EffectiveCharacter` etkisi istiyor: **68 (paket, mekanik alan) çifti, 227 iddia**. Bir alan ya bir sayfa probuna, ya `notResolverRead`'e (okuyucusu adlandırılmış 24 alan), ya da `unreadByAnyone`'a düşmek zorunda; başka her şey testi kırar. İlk koşuda **hiçbir paket feat'inin ASI'sini uygulamadığı** ortaya çıktı — `asi_ability_options` kurulumdan sonra id tutuyor, sezgisel ise yalnız `{_lookup, name}` okuyordu; tek okuyucu [[entity_ref]]`.abilityAbbrevFromRef` oldu.

> [!info] Sahiplik multiplayer'a bağlı değil — 2026-09-01
> `ownerId` düzenleme iznini ([[character_editor_screen]] `_canEdit`) ve hub Characters sekmesi görünürlüğünü kapatır, ama claim/release yalnız online dünyalarda ([[character_claim_service]] RPC'leri) vardı. Marketplace'ten kurulan bir dünyanın PC'leri sahipsiz (veya yazarın uid'i ile) geldiği için kalıcı read-only kalıyordu. Şimdi:
> - **Offline dünya = yerel sahiplik.** `characters_sidebar._OfflineCharacterRow` menüsünde Claim/Release var; `characterListProvider.update()` ile sadece `ownerId` patch'lenir (mirror push zaten online olmayan dünyada erken döner).
> - **Mirror'lanmamış dünyada düzenleme her zaman açık** — sahipliği doğrulayacak server satırı yok (`_canEdit`: `!onlineWorldIds.contains(worldId)` → true).
> - **Guest release marker.** Çıkış yapmış kullanıcı için `ownerId == null` = "benim", dolayısıyla release'i ifade edemez; `kGuestReleasedOwnerId` (`character_ext.dart`) yerel işareti kullanılır. Tek sahiplik predicate'i `Character.isOwnedBy(selfUid)`; `normalizedOwnerId` marker'ı buluta çıkmadan `null`'a çevirir (`_mirrorPush`). Guard: `test/domain/entities/character_ownership_test.dart`.

## Data Flow
Wizard draft ([[character_draft_notifier]]) → [[level_up_planner]] emits deltas + [[pending_choices]] → picks persisted → at read time [[character_resolver]] folds class/subclass/feat/species entities + effects into [[effective_character]].

## Related Domains
- [[World-and-Content]] (entity store) · [[Content-Pipeline]] (where effects originate) · [[Combat-and-VTT]] (consumes effective stats).

## Source Docs
- Chargen mechanics wiring completed (C1-C7 mapper fields + D1-D9 species/feat/bg typed grants; 2026-06-01 to Jun 9) — doc removed after completion.
- `flutter_app/docs/` audit docs: `character_creation_level_audit.md`, `missing_mechanical_effects_audit.md`.
