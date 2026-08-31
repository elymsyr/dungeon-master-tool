import 'package:flutter/material.dart';

import '../../domain/entities/character/effective_character.dart';
import '../../domain/entities/entity.dart';
import '../theme/dm_tool_colors.dart';

/// Sınıf/altsınıf/feat kaynaklı sayılabilir kaynaklar — Rage uses, Bardic
/// Inspiration, Channel Divinity, Focus Points, Sorcery Points…  Karakter
/// sayfasının "Class Resources" grubuna gömülür.
///
/// **Maksimum saklanmaz.** Her satırın kapasitesi `CharacterResolver`'ın
/// `resourcePools` çıktısıdır (seviye tablosu ya da `cha_mod_min_1` gibi bir
/// formül), harcanan kısım ise PC'nin `granted_pool_uses_remaining` alanında
/// durur. Kapasitenin türetilmiş kalması, kartın nereden geldiğinden bağımsız
/// olarak aynı görünmesinin tek sebebi: wizard'la elde kurulan karakter,
/// paketlenmiş dünyadan gelen karakter ve LAN'dan düşen karakter aynı satırı
/// üretir. (Eskiden level-up `class_resource_pools`'a bir kopya yazıyordu; onu
/// kimse okumadığı için sayfada hiç görünmüyordu.)
class ClassResourcesTracker extends StatelessWidget {
  final EffectiveCharacter effective;
  final Map<String, Entity> entities;
  final DmToolColors palette;

  /// Kalan kullanım, havuz entity id'si → kalan. Eksik anahtar = dolu.
  final Map<String, int> poolRemaining;

  /// Null ise salt-okunur (başkasının karakteri / projeksiyon).
  final ValueChanged<Map<String, int>>? onPoolRemainingChanged;

  /// Font of Magic dönüşümü için büyü yuvası durumu. Yoksa buton çıkmaz.
  final Map<int, int>? spellSlotsRemaining;
  final Map<int, int>? spellSlotsMax;
  final ValueChanged<Map<int, int>>? onSpellSlotsRemainingChanged;

  const ClassResourcesTracker({
    super.key,
    required this.effective,
    required this.entities,
    required this.palette,
    this.poolRemaining = const {},
    this.onPoolRemainingChanged,
    this.spellSlotsRemaining,
    this.spellSlotsMax,
    this.onSpellSlotsRemainingChanged,
  });

  /// Çizilebilir havuzlar: `pool_ref` çözülmüş bir id olmalı ve kapasite
  /// pozitif olmalı. Resolver artık zarfı id'ye çeviriyor; çözemediğinde
  /// satır atlanır (uydurma kapasiteli bir sayaç göstermektense).
  List<({String id, int max})> get entries {
    final out = <({String id, int max})>[];
    for (final p in effective.resourcePools) {
      final ref = p['pool_ref'];
      if (ref is! String || !entities.containsKey(ref)) continue;
      final raw = p['max'];
      final max = raw is int ? raw : int.tryParse('$raw') ?? 0;
      if (max <= 0) continue;
      out.add((id: ref, max: max));
    }
    return out;
  }

  /// `pool:bardic_inspiration` → "Bardic Inspiration".
  static String displayName(String raw) {
    if (!raw.startsWith('pool:')) return raw;
    final core = raw.substring(5).replaceAll('_', ' ');
    return core
        .split(' ')
        .where((s) => s.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final rows = entries;
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [for (final r in rows) _poolRow(r.id, r.max)],
    );
  }

  Widget _poolRow(String id, int max) {
    final rawName = entities[id]?.name ?? id;
    final name = displayName(rawName);
    final cur = (poolRemaining[id] ?? max).clamp(0, max);
    final sources = effective.grantSources[id] ?? const <String>[];
    final readOnly = onPoolRemainingChanged == null;

    void emit(int next) {
      if (readOnly) return;
      final clamped = next.clamp(0, max);
      final updated = Map<String, int>.from(poolRemaining);
      if (clamped == max) {
        updated.remove(id);
      } else {
        updated[id] = clamped;
      }
      onPoolRemainingChanged!(updated);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  sources.isEmpty ? name : '$name — ${sources.join(', ')}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: palette.srdInk,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '$cur / $max',
                style: TextStyle(fontSize: 12, color: palette.srdSubtitle),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                iconSize: 18,
                tooltip: 'Reset (long rest)',
                onPressed: readOnly || cur >= max ? null : () => emit(max),
                icon: const Icon(Icons.bedtime_outlined),
              ),
              if (rawName == 'pool:sorcery_points' &&
                  spellSlotsMax != null &&
                  spellSlotsRemaining != null &&
                  onSpellSlotsRemainingChanged != null &&
                  !readOnly)
                Builder(
                  builder: (context) => IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 28, minHeight: 28),
                    iconSize: 18,
                    tooltip: 'Font of Magic — convert',
                    onPressed: () => _openFontOfMagic(context, id, cur, max),
                    icon: const Icon(Icons.swap_horiz),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (var i = 0; i < max; i++)
                _UsePip(
                  // Soldan doldur: i < kalan ⇒ elde duruyor.
                  filled: i < cur,
                  color: palette.featureCardAccent,
                  borderRadius: palette.br,
                  // Dolu bir kutuya basmak onu harcar, boşa basmak geri alır.
                  onTap: readOnly ? null : () => emit(i < cur ? i : i + 1),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // SRD §2.4 Sorcerer Font of Magic dönüşüm tablosu. Anahtar = yuva seviyesi.
  static const _spToSlotCost = <int, int>{1: 2, 2: 3, 3: 5, 4: 6, 5: 7};

  Future<void> _openFontOfMagic(
    BuildContext context,
    String poolId,
    int spCurrent,
    int spMax,
  ) async {
    final maxBySlot = Map<int, int>.from(spellSlotsMax!);
    final remBySlot = Map<int, int>.from(spellSlotsRemaining!);
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            void writeSp(int next) {
              final updated = Map<String, int>.from(poolRemaining);
              if (next == spMax) {
                updated.remove(poolId);
              } else {
                updated[poolId] = next;
              }
              onPoolRemainingChanged!(updated);
            }

            void convertSlotToSp(int lvl) {
              final cur = remBySlot[lvl] ?? 0;
              if (cur <= 0) return;
              if (spCurrent + lvl > spMax) return;
              remBySlot[lvl] = cur - 1;
              spCurrent += lvl;
              onSpellSlotsRemainingChanged!(Map<int, int>.from(remBySlot));
              writeSp(spCurrent);
              setState(() {});
            }

            void convertSpToSlot(int lvl) {
              final cost = _spToSlotCost[lvl];
              if (cost == null) return;
              if (spCurrent < cost) return;
              final cap = maxBySlot[lvl] ?? 0;
              final cur = remBySlot[lvl] ?? 0;
              if (cur >= cap) return;
              spCurrent -= cost;
              remBySlot[lvl] = cur + 1;
              onSpellSlotsRemainingChanged!(Map<int, int>.from(remBySlot));
              writeSp(spCurrent);
              setState(() {});
            }

            return AlertDialog(
              title: const Text('Font of Magic'),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sorcery Points: $spCurrent / $spMax'),
                    const SizedBox(height: 12),
                    const Text(
                        'Slot → SP (refund slot for SP equal to slot level):',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final lvl in (maxBySlot.keys.toList()..sort()))
                          ElevatedButton(
                            onPressed: ((remBySlot[lvl] ?? 0) > 0 &&
                                    spCurrent + lvl <= spMax)
                                ? () => convertSlotToSp(lvl)
                                : null,
                            child: Text(
                                'L$lvl → +$lvl SP (${remBySlot[lvl] ?? 0}/${maxBySlot[lvl] ?? 0})'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('SP → Slot (spend SP to create a slot):',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final entry in _spToSlotCost.entries)
                          if (maxBySlot.containsKey(entry.key))
                            ElevatedButton(
                              onPressed: (spCurrent >= entry.value &&
                                      (remBySlot[entry.key] ?? 0) <
                                          (maxBySlot[entry.key] ?? 0))
                                  ? () => convertSpToSlot(entry.key)
                                  : null,
                              child: Text(
                                  '${entry.value} SP → L${entry.key} slot'),
                            ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Done'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Tek kullanım kutusu. Dolu = elde duran kullanım.
class _UsePip extends StatelessWidget {
  final bool filled;
  final Color color;
  final BorderRadius borderRadius;
  final VoidCallback? onTap;

  const _UsePip({
    required this.filled,
    required this.color,
    required this.borderRadius,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: borderRadius,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: filled ? color : Colors.transparent,
          borderRadius: borderRadius,
          border: Border.all(color: color, width: 1.5),
        ),
      ),
    );
  }
}
