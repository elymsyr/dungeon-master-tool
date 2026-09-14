import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/profile_provider.dart';
import '../../domain/entities/user_profile.dart';
import '../l10n/app_localizations.dart';
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
  late bool _hiddenFromDiscover;

  bool get _isCreate => widget.existing == null;

  @override
  void initState() {
    super.initState();
    _usernameCtrl = TextEditingController(text: widget.existing?.username ?? '');
    _displayNameCtrl = TextEditingController(text: widget.existing?.displayName ?? '');
    _bioCtrl = TextEditingController(text: widget.existing?.bio ?? '');
    _avatarUrl = widget.existing?.avatarUrl;
    _hiddenFromDiscover = widget.existing?.hiddenFromDiscover ?? false;
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
            hiddenFromDiscover: _hiddenFromDiscover,
          );
    if (ok && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final l10n = L10n.of(context)!;
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
                label: Text(L10n.of(context)!.profileUploadAvatar, style: const TextStyle(fontSize: 12)),
                onPressed: isBusy ? null : () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(L10n.of(context)!.profileAvatarSoon)),
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
                labelText: L10n.of(context)!.profileUsername,
                prefixText: '@',
                helperText: L10n.of(context)!.profileUsernameHelper,
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
              decoration: InputDecoration(
                labelText: L10n.of(context)!.profileDisplayName,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bioCtrl,
              enabled: !isBusy,
              maxLines: 3,
              maxLength: 280,
              decoration: InputDecoration(
                labelText: L10n.of(context)!.profileBio,
                border: const OutlineInputBorder(),
              ),
            ),
            if (!_isCreate) ...[
              const SizedBox(height: 8),
              InkWell(
                borderRadius: palette.br,
                onTap: isBusy ? null : () => setState(() => _hiddenFromDiscover = !_hiddenFromDiscover),
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: Checkbox(
                        value: _hiddenFromDiscover,
                        onChanged: isBusy ? null : (v) => setState(() => _hiddenFromDiscover = v ?? false),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        side: BorderSide(color: palette.featureCardBorder),
                        activeColor: palette.featureCardAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(palette.borderRadius / 2)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(l10n.profileHideFromDiscover,
                          style: TextStyle(fontSize: 12, color: palette.tabText)),
                    ),
                  ],
                ),
              ),
            ],
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
            child: Text(L10n.of(context)!.btnCancel),
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
