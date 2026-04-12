import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/profile_provider.dart';
import '../../domain/entities/user_profile.dart';
import '../theme/dm_tool_colors.dart';
import '../widgets/profile_avatar.dart';

/// Yeni kullanıcı sign-in olduğunda zorunlu açılır (username seçimi).
/// Mevcut kullanıcılar için Profile menu → Edit Profile'dan açılır.
/// [existing] null ise create modu, doluysa update modu.
class ProfileEditDialog extends ConsumerStatefulWidget {
  final UserProfile? existing;
  const ProfileEditDialog({super.key, this.existing});

  static Future<void> show(BuildContext context, {UserProfile? existing}) {
    return showDialog(
      context: context,
      barrierDismissible: existing != null,
      builder: (ctx) => ProfileEditDialog(existing: existing),
    );
  }

  @override
  ConsumerState<ProfileEditDialog> createState() => _ProfileEditDialogState();
}

class _ProfileEditDialogState extends ConsumerState<ProfileEditDialog> {
  late final TextEditingController _usernameCtrl;
  late final TextEditingController _displayNameCtrl;
  late final TextEditingController _bioCtrl;
  String? _avatarUrl;
  String? _localError;

  bool get _isCreate => widget.existing == null;

  @override
  void initState() {
    super.initState();
    _usernameCtrl = TextEditingController(text: widget.existing?.username ?? '');
    _displayNameCtrl = TextEditingController(text: widget.existing?.displayName ?? '');
    _bioCtrl = TextEditingController(text: widget.existing?.bio ?? '');
    _avatarUrl = widget.existing?.avatarUrl;
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _displayNameCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  String? _validateUsername(String value) {
    if (value.length < 3 || value.length > 20) {
      return 'Username must be 3-20 characters';
    }
    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(value)) {
      return 'Only lowercase letters, digits and underscores';
    }
    return null;
  }

  Future<void> _save() async {
    final username = _usernameCtrl.text.trim().toLowerCase();
    final err = _validateUsername(username);
    if (err != null) {
      setState(() => _localError = err);
      return;
    }
    setState(() => _localError = null);

    final notifier = ref.read(profileEditProvider.notifier);
    final ok = _isCreate
        ? await notifier.createProfile(
            username: username,
            displayName: _displayNameCtrl.text.trim().isEmpty ? null : _displayNameCtrl.text.trim(),
            bio: _bioCtrl.text.trim().isEmpty ? null : _bioCtrl.text.trim(),
            avatarUrl: _avatarUrl,
          )
        : await notifier.updateProfile(
            username: username == widget.existing!.username ? null : username,
            displayName: _displayNameCtrl.text.trim(),
            bio: _bioCtrl.text.trim(),
            avatarUrl: _avatarUrl,
          );
    if (ok && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final editState = ref.watch(profileEditProvider);
    final isBusy = editState.isBusy;
    final remoteError = editState.errorMessage;

    return AlertDialog(
      title: Text(_isCreate ? 'Choose your username' : 'Edit Profile'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: ProfileAvatar(
                avatarUrl: _avatarUrl,
                fallbackText: _usernameCtrl.text.isEmpty ? '?' : _usernameCtrl.text,
                size: 64,
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: TextButton.icon(
                icon: const Icon(Icons.upload, size: 14),
                label: const Text('Upload avatar', style: TextStyle(fontSize: 12)),
                onPressed: isBusy ? null : () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Avatar upload coming soon')),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _usernameCtrl,
              enabled: !isBusy,
              autofocus: _isCreate,
              maxLength: 20,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9_]')),
              ],
              decoration: InputDecoration(
                labelText: 'Username',
                prefixText: '@',
                helperText: 'Lowercase letters, digits, underscores',
                errorText: _localError,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _displayNameCtrl,
              enabled: !isBusy,
              maxLength: 40,
              decoration: const InputDecoration(
                labelText: 'Display name (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bioCtrl,
              enabled: !isBusy,
              maxLines: 3,
              maxLength: 280,
              decoration: const InputDecoration(
                labelText: 'Bio',
                border: OutlineInputBorder(),
              ),
            ),
            if (remoteError != null) ...[
              const SizedBox(height: 8),
              Text(remoteError, style: TextStyle(color: palette.dangerBtnBg, fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        if (!_isCreate)
          TextButton(
            onPressed: isBusy ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        FilledButton(
          onPressed: isBusy ? null : _save,
          child: isBusy
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(_isCreate ? 'Create profile' : 'Save'),
        ),
      ],
    );
  }
}
