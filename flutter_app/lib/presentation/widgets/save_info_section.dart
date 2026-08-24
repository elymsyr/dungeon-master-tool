import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../theme/dm_tool_colors.dart';

/// Son yerel kayıt zamanı. Bulut kopyası yok — her şey yerelde yaşıyor,
/// cihazlar arası aktarım LAN sync ile. Hesap durumundan bağımsız.
class SaveInfoSection extends StatelessWidget {
  final DateTime? localUpdatedAt;

  const SaveInfoSection({super.key, required this.localUpdatedAt});

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final l10n = L10n.of(context)!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.save_outlined, size: 14, color: palette.sidebarLabelSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.saveInfoLocalLabel,
                style: TextStyle(
                  fontSize: 10,
                  color: palette.sidebarLabelSecondary,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                localUpdatedAt == null
                    ? l10n.saveInfoNever
                    : DateFormat.yMMMd().add_Hm().format(localUpdatedAt!.toLocal()),
                style: TextStyle(fontSize: 12, color: palette.tabActiveText),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
