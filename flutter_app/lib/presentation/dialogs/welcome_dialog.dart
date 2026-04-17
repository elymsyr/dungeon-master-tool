import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';

/// Uygulama ilk kez açıldığında gösterilen karşılama + beta bildirim
/// dialog'u. Kullanıcıya beta durumu, gelecek paketler ve GitHub linkini
/// iletir. Gösterildikten sonra `uiStateProvider.welcomeSeen = true` set
/// edilir, bir daha açılmaz.
class WelcomeDialog {
  static const githubUrl = 'https://github.com/elymsyr/dungeon-master-tool';

  static Future<void> show(BuildContext context) async {
    final l10n = L10n.of(context)!;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.celebration_outlined, size: 22),
            const SizedBox(width: 8),
            Expanded(child: Text(l10n.welcomeTitle)),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.welcomeBetaNotice,
                  style: const TextStyle(height: 1.4, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.welcomeRoadmap,
                  style: const TextStyle(height: 1.4, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.welcomeClosing,
                  style: const TextStyle(
                    height: 1.4,
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () =>
                      launchUrl(Uri.parse(githubUrl), mode: LaunchMode.externalApplication),
                  child: Row(
                    children: [
                      const Icon(Icons.code, size: 16),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          githubUrl,
                          style: const TextStyle(
                            fontSize: 12,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.welcomeContinue),
          ),
        ],
      ),
    );
  }
}
