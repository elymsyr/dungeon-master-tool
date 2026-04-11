import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../application/providers/auth_provider.dart';
import '../../../core/config/supabase_config.dart';
import '../../theme/dm_tool_colors.dart';

class SocialTab extends ConsumerWidget {
  const SocialTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<DmToolColors>()!;

    if (!SupabaseConfig.isConfigured) {
      return _buildNotConfigured(palette);
    }

    final authState = ref.watch(authProvider);

    return authState != null
        ? _buildProfile(context, ref, palette, authState)
        : _buildNotLoggedIn(context, palette);
  }

  // ── Not configured ──────────────────────────────────────────────

  Widget _buildNotConfigured(DmToolColors palette) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_outline, size: 64, color: palette.sidebarLabelSecondary),
          const SizedBox(height: 16),
          Text(
            'Social',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: palette.tabActiveText),
          ),
          const SizedBox(height: 8),
          Text(
            'Coming Soon',
            style: TextStyle(fontSize: 14, color: palette.sidebarLabelSecondary),
          ),
          const SizedBox(height: 24),
          Text(
            'Online sessions, player connections,\nand community features.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: palette.tabText),
          ),
        ],
      ),
    );
  }

  // ── Not logged in ───────────────────────────────────────────────

  Widget _buildNotLoggedIn(BuildContext context, DmToolColors palette) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.account_circle_outlined, size: 64, color: palette.sidebarLabelSecondary),
          const SizedBox(height: 16),
          Text(
            'Not Signed In',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: palette.tabActiveText),
          ),
          const SizedBox(height: 8),
          Text(
            'Sign in to access social features.',
            style: TextStyle(fontSize: 13, color: palette.sidebarLabelSecondary),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => context.go('/'),
            icon: Icon(Icons.login, size: 18, color: palette.featureCardAccent),
            label: Text('Sign In', style: TextStyle(color: palette.featureCardAccent)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: palette.featureCardAccent),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Signed-in profile ───────────────────────────────────────────

  Widget _buildProfile(BuildContext context, WidgetRef ref, DmToolColors palette, AuthState authState) {
    final initial = authState.email.isNotEmpty ? authState.email[0].toUpperCase() : '?';
    final providerLabel = switch (authState.provider) {
      'google' => 'Google',
      'facebook' => 'Facebook',
      'github' => 'GitHub',
      _ => 'Email',
    };
    final providerIcon = switch (authState.provider) {
      'google' => Icons.g_mobiledata,
      'facebook' => Icons.facebook,
      'github' => Icons.code,
      _ => Icons.email_outlined,
    };
    final joinDate = authState.createdAt != null ? DateFormat.yMMMd().format(authState.createdAt!) : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            children: [
              const SizedBox(height: 16),

              // ── Avatar ──
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      palette.featureCardAccent,
                      palette.featureCardAccent.withValues(alpha: 0.6),
                    ],
                  ),
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ── Email ──
              Text(
                authState.email,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: palette.tabActiveText),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(providerIcon, size: 14, color: palette.sidebarLabelSecondary),
                  const SizedBox(width: 4),
                  Text(
                    'Signed in with $providerLabel',
                    style: TextStyle(fontSize: 12, color: palette.sidebarLabelSecondary),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ── Account Info Card ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: palette.featureCardBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: palette.featureCardBorder),
                ),
                child: Column(
                  children: [
                    _infoRow(Icons.fingerprint, 'User ID', authState.uid, palette, selectable: true),
                    if (joinDate != null) ...[
                      Divider(height: 24, color: palette.featureCardBorder),
                      _infoRow(Icons.calendar_today, 'Joined', joinDate, palette),
                    ],
                    Divider(height: 24, color: palette.featureCardBorder),
                    _infoRow(Icons.verified_user_outlined, 'Status', 'Active', palette,
                        valueColor: palette.successBtnBg),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Coming Soon Features ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: palette.featureCardBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border(
                    left: BorderSide(color: palette.featureCardAccent, width: 3),
                    top: BorderSide(color: palette.featureCardBorder),
                    right: BorderSide(color: palette.featureCardBorder),
                    bottom: BorderSide(color: palette.featureCardBorder),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.auto_awesome, size: 16, color: palette.featureCardAccent),
                        const SizedBox(width: 8),
                        Text(
                          'Coming Soon',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: palette.tabActiveText),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _featureItem(Icons.groups, 'Co-op Sessions', 'Invite players to your table', palette),
                    const SizedBox(height: 8),
                    _featureItem(Icons.store, 'Community Market', 'Share and discover .dmt packages', palette),
                    const SizedBox(height: 8),
                    _featureItem(Icons.cloud_upload_outlined, 'Cloud Backup', 'Sync campaigns across devices', palette),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Sign Out ──
              SizedBox(
                width: double.infinity,
                height: 40,
                child: OutlinedButton.icon(
                  onPressed: () => ref.read(authProvider.notifier).signOut(),
                  icon: Icon(Icons.logout, size: 18, color: palette.dangerBtnBg),
                  label: Text('Sign Out', style: TextStyle(color: palette.dangerBtnBg)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: palette.dangerBtnBg.withValues(alpha: 0.4)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(
    IconData icon,
    String label,
    String value,
    DmToolColors palette, {
    bool selectable = false,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: palette.sidebarLabelSecondary),
        const SizedBox(width: 10),
        SizedBox(
          width: 70,
          child: Text(label, style: TextStyle(fontSize: 12, color: palette.sidebarLabelSecondary)),
        ),
        Expanded(
          child: selectable
              ? SelectableText(
                  value,
                  style: TextStyle(fontSize: 12, color: valueColor ?? palette.tabActiveText, fontFamily: 'monospace'),
                )
              : Text(
                  value,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: valueColor ?? palette.tabActiveText),
                ),
        ),
      ],
    );
  }

  Widget _featureItem(IconData icon, String title, String subtitle, DmToolColors palette) {
    return Row(
      children: [
        Icon(icon, size: 18, color: palette.sidebarLabelSecondary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: palette.tabActiveText)),
              Text(subtitle, style: TextStyle(fontSize: 11, color: palette.sidebarLabelSecondary)),
            ],
          ),
        ),
      ],
    );
  }
}
