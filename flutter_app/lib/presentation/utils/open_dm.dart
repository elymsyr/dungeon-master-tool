import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/auth_provider.dart';
import '../../application/providers/social_providers.dart';
import '../../core/utils/cached_provider.dart';
import '../l10n/app_localizations.dart';
import '../screens/social/messages_tab.dart';

/// Verilen kullanıcıyla DM aç: konuşma yarat + ChatScreen push.
/// Applicants panelleri / profil ekran / liste popup'ları bu helper'ı
/// kullanır — her yerde aynı hata ve snackbar semantikleri.
Future<void> openDmWithApplicant(
  BuildContext context,
  WidgetRef ref,
  String otherUserId,
  String? otherUsername,
) async {
  try {
    final conv = await ref.read(messagesRemoteDsProvider).openDirect(otherUserId);
    if (!context.mounted) return;
    final myUid = ref.read(authProvider)?.uid ?? '';
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChatScreen(conversation: conv, myUserId: myUid),
    ));
    invalidateCache('conversations');
    ref.invalidate(myConversationsProvider);
  } catch (e) {
    if (!context.mounted) return;
    final l10n = L10n.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.profileDmError('$e'))),
    );
  }
}
