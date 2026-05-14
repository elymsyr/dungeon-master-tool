import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/campaign_provider.dart';
import '../../application/providers/online_worlds_provider.dart';
import '../../application/providers/world_join_provider.dart';
import '../../core/config/supabase_config.dart';
import '../../data/network/no_op_world_membership_service.dart';
import '../../application/providers/world_membership_provider.dart';
import '../theme/dm_tool_colors.dart';

/// "Join with code" dialog. 8 karakter base32 (ambigous-free) kodu kabul eder.
class JoinWorldDialog extends ConsumerStatefulWidget {
  const JoinWorldDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const JoinWorldDialog(),
    );
  }

  @override
  ConsumerState<JoinWorldDialog> createState() => _JoinWorldDialogState();
}

class _JoinWorldDialogState extends ConsumerState<JoinWorldDialog> {
  final _ctrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _ctrl.text.trim().toUpperCase();
    if (code.length != 8) {
      setState(() => _error = 'Code must be 8 characters');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final svc = ref.read(worldJoinServiceProvider);
      final res = await svc.joinWithCode(code);
      ref.read(onlineWorldIdsProvider.notifier).add(res.worldId);
      // Hub listesini ve metadata cache'lerini invalidate et.
      ref.invalidate(campaignListProvider);
      ref.invalidate(campaignInfoListProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Joined world "${res.worldName}"')),
      );
    } catch (e) {
      setState(() {
        _error = _humanize(e);
        _busy = false;
      });
    }
  }

  String _humanize(Object e) {
    final s = e.toString();
    if (s.contains('P0002') || s.contains('invite not found')) {
      return 'Invite code not found';
    }
    if (s.contains('P0003') || s.contains('exhausted')) {
      return 'Invite has no uses left';
    }
    if (s.contains('P0004') || s.contains('expired')) {
      return 'Invite expired';
    }
    return 'Failed to join: $s';
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final offline = !SupabaseConfig.isConfigured ||
        ref.watch(worldMembershipServiceProvider) is NoOpWorldMembershipService;

    return AlertDialog(
      title: const Text('Join World'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (offline)
              Text(
                'Online features require sign-in and Supabase configuration.',
                style: TextStyle(
                  fontSize: 12,
                  color: palette.sidebarLabelSecondary,
                ),
              )
            else ...[
              const Text(
                'Enter the 8-character code from your DM:',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _ctrl,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                maxLength: 8,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 22,
                  letterSpacing: 6,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'[A-HJ-NP-Z2-9a-hj-np-z]'),
                  ),
                  UpperCaseTextFormatter(),
                ],
                decoration: InputDecoration(
                  hintText: 'XXXXXXXX',
                  errorText: _error,
                  counterText: '',
                ),
                onSubmitted: (_) => _submit(),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _busy || offline ? null : _submit,
          icon: _busy
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.login, size: 16),
          label: const Text('Join'),
        ),
      ],
    );
  }
}

/// TextField input formatter — küçük harf girince büyütür.
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
