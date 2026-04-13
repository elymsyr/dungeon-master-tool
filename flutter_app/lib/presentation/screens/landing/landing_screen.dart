import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../application/providers/auth_provider.dart';
import '../../../application/providers/user_session_provider.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/constants.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/dm_tool_colors.dart';
import '../../widgets/app_icon_image.dart';

class LandingScreen extends ConsumerStatefulWidget {
  const LandingScreen({super.key});

  @override
  ConsumerState<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends ConsumerState<LandingScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _isSignUp = true;
  bool _loading = false;
  String? _error;
  String? _info;

  @override
  void initState() {
    super.initState();
    // If already logged in (persisted session), activate user session and go to hub.
    if (SupabaseConfig.isConfigured) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final auth = ref.read(authProvider);
        if (mounted && auth != null) {
          await ref.read(userSessionProvider.notifier).activate(auth.uid);
          if (mounted) context.go('/hub');
        }
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final authState = ref.watch(authProvider);
    final showAuth = SupabaseConfig.isConfigured && authState == null;

    // Auto-navigate to hub on successful sign-in.
    ref.listen(authProvider, (prev, next) async {
      if (prev == null && next != null) {
        await ref.read(userSessionProvider.notifier).activate(next.uid);
        if (mounted) context.go('/hub');
      }
    });

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: showAuth ? _buildAuthLanding(palette) : _buildStartLanding(palette),
      ),
    );
  }

  // ── Original Start landing ────────────────────────────────────────

  Widget _buildStartLanding(DmToolColors palette) {
    final size = MediaQuery.sizeOf(context);
    return Stack(
      children: [
        _buildBackground(palette),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIconImage(size: size.width > 600 ? 96 : 72),
              const SizedBox(height: 16),
              Text(
                'Dungeon Master Tool',
                style: TextStyle(
                  fontSize: size.width > 600 ? 32 : 24,
                  fontWeight: FontWeight.bold,
                  color: palette.tabActiveText,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(appReleaseTag, style: TextStyle(fontSize: 13, color: palette.sidebarLabelSecondary)),
              const SizedBox(height: 48),
              SizedBox(
                width: 200,
                height: 48,
                child: FilledButton(
                  onPressed: () => context.go('/hub'),
                  style: FilledButton.styleFrom(backgroundColor: palette.featureCardAccent),
                  child: const Text('Start', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
        _buildTagline(palette),
      ],
    );
  }

  // ── Auth landing ──────────────────────────────────────────────────

  Widget _buildAuthLanding(DmToolColors palette) {
    final size = MediaQuery.sizeOf(context);
    final isWide = size.width > 700;

    return Stack(
      children: [
        _buildBackground(palette),
        SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: isWide ? 48 : 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Header ──
                  AppIconImage(size: isWide ? 48 : 36),
                  const SizedBox(height: 8),
                  Text(
                    'Dungeon Master Tool',
                    style: TextStyle(
                      fontSize: isWide ? 24 : 20,
                      fontWeight: FontWeight.bold,
                      color: palette.tabActiveText,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Create an account to unlock online features.',
                    style: TextStyle(fontSize: 12, color: palette.sidebarLabelSecondary),
                  ),
                  SizedBox(height: isWide ? 28 : 16),

                  // ── Auth content — wide: side by side, narrow: stacked ──
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: isWide ? 780 : 400),
                    child: isWide
                        ? _buildWideAuthContent(palette)
                        : _buildNarrowAuthContent(palette),
                  ),

                  SizedBox(height: isWide ? 16 : 10),
                ],
              ),
            ),
          ),
        ),
        _buildTagline(palette),
      ],
    );
  }

  // ── Wide layout: OAuth left | OR | Email right ────────────────────

  Widget _buildWideAuthContent(DmToolColors palette) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Left: OAuth
        Expanded(child: _buildOAuthPanel(palette)),
        // Vertical OR divider
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 1, height: 40, color: palette.featureCardBorder),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('OR', style: TextStyle(fontSize: 11, color: palette.sidebarLabelSecondary)),
              ),
              Container(width: 1, height: 40, color: palette.featureCardBorder),
            ],
          ),
        ),
        // Right: Email form
        Expanded(child: _buildEmailForm(palette)),
      ],
    );
  }

  // ── Narrow layout: OAuth top, OR, Email bottom ────────────────────

  Widget _buildNarrowAuthContent(DmToolColors palette) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildOAuthPanel(palette),
        const SizedBox(height: 14),
        // Horizontal OR divider
        Row(
          children: [
            Expanded(child: Divider(color: palette.featureCardBorder)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('OR', style: TextStyle(fontSize: 11, color: palette.sidebarLabelSecondary)),
            ),
            Expanded(child: Divider(color: palette.featureCardBorder)),
          ],
        ),
        const SizedBox(height: 14),
        _buildEmailForm(palette),
      ],
    );
  }

  // ── OAuth buttons panel ───────────────────────────────────────────

  Widget _buildOAuthPanel(DmToolColors palette) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _oauthButton(palette, icon: Icons.g_mobiledata, label: 'Continue with Google', provider: OAuthProvider.google),
        const SizedBox(height: 10),
        _oauthButton(palette, icon: Icons.code, label: 'Continue with GitHub', provider: OAuthProvider.github),
      ],
    );
  }

  // ── Email/password form ───────────────────────────────────────────

  Widget _buildEmailForm(DmToolColors palette) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Email', palette),
        const SizedBox(height: 4),
        _buildField(_emailController, 'you@example.com', palette, keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 10),
        _buildLabel('Password', palette),
        const SizedBox(height: 4),
        _buildField(_passwordController, 'Min 6 characters', palette, obscure: true),
        if (_isSignUp) ...[
          const SizedBox(height: 10),
          _buildLabel('Confirm Password', palette),
          const SizedBox(height: 4),
          _buildField(_confirmController, 'Re-enter password', palette, obscure: true),
        ],
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(fontSize: 12, color: palette.dangerBtnBg)),
        ],
        if (_info != null) ...[
          const SizedBox(height: 8),
          Text(_info!, style: TextStyle(fontSize: 12, color: palette.successBtnBg)),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 40,
          child: FilledButton(
            onPressed: _loading ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: palette.featureCardAccent,
              shape: RoundedRectangleBorder(borderRadius: palette.br),
            ),
            child: _loading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(_isSignUp ? 'Sign Up' : 'Sign In', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 2),
        Center(
          child: TextButton(
            onPressed: _loading
                ? null
                : () => setState(() {
                      _isSignUp = !_isSignUp;
                      _error = null;
                      _info = null;
                      _confirmController.clear();
                    }),
            child: Text(
              _isSignUp ? 'Already have an account? Sign In' : "Don't have an account? Sign Up",
              style: TextStyle(fontSize: 11, color: palette.featureCardAccent),
            ),
          ),
        ),
      ],
    );
  }

  // ── Shared UI helpers ─────────────────────────────────────────────

  Widget _buildBackground(DmToolColors palette) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [palette.canvasBg, palette.featureCardBg],
        ),
      ),
    );
  }

  Widget _buildTagline(DmToolColors palette) {
    return Positioned(
      bottom: 24,
      left: 0,
      right: 0,
      child: Text(
        'Campaign Management for Tabletop RPGs',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, color: palette.sidebarLabelSecondary),
      ),
    );
  }

  Align _buildLabel(String text, DmToolColors palette) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: palette.tabActiveText)),
    );
  }

  Widget _buildField(
    TextEditingController controller,
    String hint,
    DmToolColors palette, {
    bool obscure = false,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      enabled: !_loading,
      obscureText: obscure,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: palette.featureCardBg,
        border: OutlineInputBorder(
          borderRadius: palette.br,
          borderSide: BorderSide(color: palette.featureCardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: palette.br,
          borderSide: BorderSide(color: palette.featureCardBorder),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }

  Widget _oauthButton(
    DmToolColors palette, {
    required IconData icon,
    required String label,
    required OAuthProvider provider,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: OutlinedButton.icon(
        onPressed: _loading ? null : () => _signInWithOAuth(provider),
        icon: Icon(icon, size: 24),
        label: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: palette.featureCardBorder),
          shape: RoundedRectangleBorder(borderRadius: palette.br),
        ),
      ),
    );
  }

  // ── Auth logic ────────────────────────────────────────────────────

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Please fill in all fields.');
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _error = 'Please enter a valid email address.');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    if (_isSignUp && password != _confirmController.text) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });

    final notifier = ref.read(authProvider.notifier);
    final String? error;

    if (_isSignUp) {
      error = await notifier.signUp(email, password);
      if (error == null && ref.read(authProvider) == null) {
        setState(() {
          _loading = false;
          _info = 'Check your email to confirm your account.';
        });
        return;
      }
    } else {
      error = await notifier.signIn(email, password);
    }

    if (mounted) {
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  Future<void> _signInWithOAuth(OAuthProvider provider) async {
    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });

    var error = await ref.read(authProvider.notifier).signInWithOAuth(provider);

    // Replace sentinel with localised message.
    if (error == oauthDeepLinkTimeout && mounted) {
      final l10n = L10n.of(context);
      error = l10n?.oauthSignInFailed(
              'com.elymsyr.dungeonmastertool://auth-callback') ??
          error;
    }

    if (mounted) {
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }
}
