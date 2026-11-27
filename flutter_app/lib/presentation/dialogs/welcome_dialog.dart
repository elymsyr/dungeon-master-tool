import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../theme/markdown_theme.dart';

/// Uygulama ilk kez açıldığında gösterilen karşılama
/// dialog'u. Kullanıcıya sistemin kısa (markdown) tanıtımı,
/// online oyun, gelecek paketler ve GitHub linki iletir. Gösterildikten
/// sonra `uiStateProvider.welcomeSeen = true` set edilir, bir daha açılmaz.
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
                MarkdownBody(
                  data: [
                    l10n.welcomeSystemIntro,
                    l10n.welcomeOnlinePlay,
                    l10n.welcomeOnlineStorage,
                    l10n.welcomeRoadmap,
                    l10n.welcomeClosing,
                  ].join('\n\n'),
                  styleSheet: dmMarkdownStyle(ctx),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () =>
                      launchUrl(Uri.parse(githubUrl), mode: LaunchMode.externalApplication),
                  child: const Row(
                    children: [
                      Icon(Icons.code, size: 16),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          githubUrl,
                          style: TextStyle(
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
