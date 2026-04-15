import 'package:flutter/material.dart';

import '../../data/datasources/remote/messages_remote_ds.dart';

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
        const SnackBar(content: Text('Message sent.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _errorText = 'Failed to send: $e';
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
              'Message ${widget.targetName}',
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
            hintText: 'Type a message…',
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
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          icon: _sending
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send, size: 16),
          label: const Text('Send'),
          onPressed: _sending ? null : _send,
        ),
      ],
    );
  }
}
