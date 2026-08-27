import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../application/providers/auth_provider.dart';
import '../../application/services/account_deletion_service.dart';
import '../l10n/app_localizations.dart';
import '../theme/dm_tool_colors.dart';

/// Tek tuşla hesap + veri silme. Onaylanırsa
/// [deleteAccountAndData] çalışır; kullanıcı sign-out olur ve hub'ın auth
/// listener'ı landing'e götürür.
Future<void> confirmAndDeleteAccount(BuildContext context, WidgetRef ref) async {
  final l10n = L10n.of(context)!;
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context, rootNavigator: true);

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => _DeleteAccountConfirmDialog(ref: ref),
  );
  if (confirmed != true || !context.mounted) return;

  // Silme sırasında ekranı kilitle — yarıda kalan bir akışta kullanıcı başka
  // bir şeye dokunmasın.
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  final String uid;
  try {
    uid = await deleteCloudAccountData(ref);
  } catch (e) {
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.deleteAccountFailed(e.toString()))),
    );
    return;
  }

  // İlerleme dialog'u oturum kapanmadan ÖNCE kapanır: `signOut` hub listener'ı
  // üzerinden landing'e navigate ediyor, açık kalan route dispose olan bir
  // Navigator'da pop edilmiş oluyordu (`!_debugLocked` assert'i).
  navigator.pop();
  messenger.showSnackBar(SnackBar(content: Text(l10n.deleteAccountSuccess)));
  await finishAccountDeletion(ref, uid);
}

/// Silmenin önündeki sürtünme. İki tehdidi birden karşılar:
///
///   • **Sahipsiz cihaz / yanlış dokunuş** — kullanıcı hesabının e-postasını
///     harfi harfine yazmadan buton açılmaz.
///   • **Çalınmış oturum** — parola hesaplarında silmeden hemen önce taze bir
///     `signInWithPassword` isteniyor. Supabase oturumları uzun ömürlü ve
///     kendini yeniliyor; "yakın zamanda parola girmiş olma" garantisi başka
///     türlü yok. OAuth hesaplarında parola yok, orada e-posta yazımı tek
///     kapı kalıyor (provider'ı yeniden çağırmak ayrı bir iş).
class _DeleteAccountConfirmDialog extends StatefulWidget {
  const _DeleteAccountConfirmDialog({required this.ref});

  final WidgetRef ref;

  @override
  State<_DeleteAccountConfirmDialog> createState() =>
      _DeleteAccountConfirmDialogState();
}

class _DeleteAccountConfirmDialogState
    extends State<_DeleteAccountConfirmDialog> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _error;
  bool _busy = false;

  /// Hesabın e-postası — karşılaştırma bunun üzerinden yapılır.
  String get _accountEmail =>
      Supabase.instance.client.auth.currentUser?.email ?? '';

  /// `auth_provider.dart` ile aynı okuma: OAuth hesaplarında parola yok.
  bool get _needsPassword {
    final user = Supabase.instance.client.auth.currentUser;
    final provider = user?.appMetadata['provider'] as String? ?? 'email';
    return provider == 'email';
  }

  bool get _canDelete {
    if (_busy) return false;
    if (_accountEmail.isEmpty) return false;
    if (_emailController.text.trim().toLowerCase() !=
        _accountEmail.toLowerCase()) {
      return false;
    }
    return !_needsPassword || _passwordController.text.isNotEmpty;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = L10n.of(context)!;
    if (!_needsPassword) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await widget.ref
        .read(authProvider.notifier)
        .signIn(_accountEmail, _passwordController.text);
    if (!mounted) return;
    if (error != null) {
      // Ham Supabase mesajını göstermiyoruz: tek anlamlı sonuç "parola yanlış".
      setState(() {
        _busy = false;
        _error = l10n.deleteAccountReauthFailed;
      });
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final palette = Theme.of(context).extension<DmToolColors>()!;

    return AlertDialog(
      title: Text(l10n.deleteAccountConfirmTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.deleteAccountConfirmBody),
            const SizedBox(height: 20),
            Text(
              l10n.deleteAccountConfirmEmailLabel(_accountEmail),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _emailController,
              autocorrect: false,
              enableSuggestions: false,
              keyboardType: TextInputType.emailAddress,
              enabled: !_busy,
              onChanged: (_) => setState(() {}),
            ),
            if (_needsPassword) ...[
              const SizedBox(height: 14),
              Text(
                l10n.deleteAccountPasswordLabel,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _passwordController,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                enabled: !_busy,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _canDelete ? _submit() : null,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(fontSize: 12, color: palette.dangerBtnBg),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: Text(l10n.btnCancel),
        ),
        FilledButton.icon(
          icon: _busy
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.delete_forever, size: 16),
          label: Text(l10n.deleteAccount),
          onPressed: _canDelete ? _submit : null,
          style: FilledButton.styleFrom(
            backgroundColor: palette.dangerBtnBg,
            foregroundColor: palette.dangerBtnText,
          ),
        ),
      ],
    );
  }
}
