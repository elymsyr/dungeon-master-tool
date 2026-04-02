import 'package:flutter/material.dart';

import '../theme/dm_tool_colors.dart';

class HpBar extends StatelessWidget {
  final int hp;
  final int maxHp;
  final DmToolColors palette;

  const HpBar({required this.hp, required this.maxHp, required this.palette, super.key});

  @override
  Widget build(BuildContext context) {
    final ratio = maxHp > 0 ? (hp / maxHp).clamp(0.0, 1.0) : 0.0;
    final color = ratio > 0.5 ? palette.hpBarHigh : ratio > 0.25 ? palette.hpBarMed : palette.hpBarLow;

    return Row(
      children: [
        Expanded(
          child: Container(
            height: 16,
            decoration: BoxDecoration(
              color: palette.hpWidgetBg,
              borderRadius: BorderRadius.circular(3),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: ratio,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text('$hp/$maxHp', style: TextStyle(fontSize: 11, color: palette.tabActiveText, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
