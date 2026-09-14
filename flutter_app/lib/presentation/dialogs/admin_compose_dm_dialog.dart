import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/datasources/remote/messages_remote_ds.dart';
import '../l10n/app_localizations.dart';

/// Admin panelden bir kullanıcıya DM göndermek için hızlı compose dialog.
/// Mevcut messaging altyapısını kullanır: `open_direct_conversation` RPC ile
/// konuşma açılır, sonra `messages.insert` ile gönderilir.
class AdminComposeDmDialog extends StatefulWidget {
  final String targetUserId;
  final String targetName;

  const AdminComposeDmDialog({
    super.key,
    required this.targetUserId,
    required this.targetName,
  });

  static Future<void> show(
    BuildContext context, {
    required String targetUserId,
    required String targetName,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => AdminComposeDmDialog(
        targetUserId: targetUserId,
        targetName: targetName,
      ),
    );
  }

  @override
  State<AdminComposeDmDialog> createState() => _AdminComposeDmDialogState();
}

class _AdminComposeDmDialogState extends State<AdminComposeDmDialog> {
  final _controller = TextEditingController();
  bool _sending = false;
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _controller.text.trim();
    if (body.isEmpty) {
      setState(() => _errorText = 'Message cannot be empty.');
      return;
    }
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId != null && widget.targetUserId == currentUserId) {
      setState(() => _errorText = 'You cannot message yourself.');
      return;
    }
    setState(() {
      _sending = true;
      _errorText = null;
    });
    try {
      final ds = MessagesRemoteDataSource();
      final conv = await ds.openDirect(widget.targetUserId);
      await ds.send(conv.id, body);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L10n.of(context)!.adminDmSent)),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      String errorMsg;
      if (msg.contains('invalid counterparty')) {
        errorMsg = 'Cannot open conversation with this user.';
      } else {
        errorMsg = 'Failed to send message. Please try again.';
      }
      setState(() {
        _sending = false;
        _errorText = errorMsg;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.chat_bubble_outline),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              L10n.of(context)!.adminDmTitle(widget.targetName),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: TextField(
          controller: _controller,
          maxLines: 5,
          maxLength: 4000,
          autofocus: true,
          enabled: !_sending,
          decoration: InputDecoration(
            hintText: L10n.of(context)!.adminDmHint,
            border: const OutlineInputBorder(),
            errorText: _errorText,
          ),
          onChanged: (_) {
            if (_errorText != null) setState(() => _errorText = null);
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(),
          child: Text(L10n.of(context)!.btnCancel),
        ),
        FilledButton.icon(
          icon: _sending
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send, size: 16),
          label: Text(L10n.of(context)!.btnSend),
          onPressed: _sending ? null : _send,
        ),
      ],
    );
  }
}
