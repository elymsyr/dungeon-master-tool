import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

enum BuiltinWarningChoice { cancel, continueBuiltin, copyFirst }

/// Built-in template/package kullanılarak world/character/package
/// oluşturulmak üzereyken kullanıcıya gösterilen bilgilendirme dialog'u.
/// Çağıran yer `copyFirst` geldiğinde built-in'i forklayıp o fork üzerinden
/// oluşturma akışına devam eder.
class BuiltinWarningDialog {
  /// [offerCopyFirst] false ise "Copy built-in first" seçeneği gizlenir.
  /// Character akışında kullanılır — orada template world'den miras alınır,
  /// kopyalama ayrı bir akış olur (önce template, sonra world, sonra char).
  static Future<BuiltinWarningChoice> show(
    BuildContext context, {
    bool offerCopyFirst = true,
  }) async {
    final l10n = L10n.of(context)!;
    final choice = await showDialog<BuiltinWarningChoice>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.info_outline, size: 22),
            const SizedBox(width: 8),
            Expanded(child: Text(l10n.builtinWarningTitle)),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Text(
            l10n.builtinWarningBody,
            style: const TextStyle(height: 1.4, fontSize: 13),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(ctx, BuiltinWarningChoice.cancel),
            child: Text(l10n.btnCancel),
          ),
          if (offerCopyFirst)
            OutlinedButton(
              onPressed: () =>
                  Navigator.pop(ctx, BuiltinWarningChoice.copyFirst),
              child: Text(l10n.builtinWarningCopyFirst),
            ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, BuiltinWarningChoice.continueBuiltin),
            child: Text(l10n.builtinWarningContinue),
          ),
        ],
      ),
    );
    return choice ?? BuiltinWarningChoice.cancel;
  }
}
