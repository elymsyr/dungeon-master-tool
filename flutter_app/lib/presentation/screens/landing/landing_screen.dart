import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../application/providers/auth_provider.dart';
import '../../../application/providers/locale_provider.dart';
import '../../../application/providers/user_session_provider.dart';
import '../../../core/config/supabase_config.dart';
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

  ValueNotifier<String?>? _banMessageNotifier;

  @override
  void initState() {
    super.initState();
    if (SupabaseConfig.isConfigured) {
      // If already logged in (persisted session), activate user session
      // and go to hub. Otherwise auth UI renders for sign-in.
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final auth = ref.read(authProvider);
        if (mounted && auth != null) {
          await ref.read(userSessionProvider.notifier).activate(auth.uid);
          if (!mounted) return;
          context.go('/hub');
        }
        // Startup sonrası ban dialog'u zaten set olmuşsa hemen göster.
        _maybeShowBanDialog();
      });
      // Ban mesajı dinleyicisi — auto sign-out (startup/stream/login) tek
      // noktadan buradan tetiklenir. Notifier referansını snapshot alıyoruz
      // çünkü dispose() sırasında ref.read kullanmak ProviderScope teardown
      // sonrası "ref after dispose" hatasına yol açıyor.
      _banMessageNotifier = ref.read(authProvider.notifier).banMessageNotifier
        ..addListener(_maybeShowBanDialog);
    } else {
      // Supabase off — no auth flow exists, skip landing entirely.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/hub');
      });
    }
  }

  @override
  void dispose() {
    _banMessageNotifier?.removeListener(_maybeShowBanDialog);
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _maybeShowBanDialog() {
    final notifier = ref.read(authProvider.notifier).banMessageNotifier;
    final msg = notifier.value;
    if (msg == null || !mounted) return;
    notifier.value = null; // Idempotent — dialog bir kez açılsın.
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final l10n = L10n.of(context)!;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.block, size: 48, color: palette.dangerBtnBg),
        title: Text(l10n.landingAccountBanned),
        content: Text(msg, textAlign: TextAlign.center),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.landingOk),
          ),
        ],
      ),
    );
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
        if (!context.mounted) return;
        context.go('/hub');
      }
    });

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: showAuth ? _buildAuthLanding(palette) : _buildRedirectSplash(),
      ),
    );
  }

  // No-auth-needed or already-signed-in: initState's postFrameCallback is
  // about to navigate to /hub. Render a splash so the user sees a smooth
  // hand-off instead of a "Start" button.
  Widget _buildRedirectSplash() {
    const bg = Color(0xFF1A1814);
    const gold = Color(0xFFC8A24B);
    return Container(
      color: bg,
      child: const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation<Color>(gold),
          ),
        ),
      ),
    );
  }

  // ── Auth landing ──────────────────────────────────────────────────

  Widget _buildAuthLanding(DmToolColors palette) {
    final l10n = L10n.of(context)!;
    final size = MediaQuery.sizeOf(context);
    final isWide = size.width > 700;

    // viewInsets okumayı bu üst widget'tan ÇIKARIYORUZ — keyboard her
    // animasyon frame'inde tüm landing'i rebuild ediyordu (palette/l10n/bg
    // tekrar inşa). Scaffold.resizeToAvoidBottomInset zaten içeriği yukarı
    // iter; tagline ve scroll padding ayrı widget'larda viewInsets okur.
    return Stack(
      children: [
        RepaintBoundary(child: _buildBackground(palette)),
        SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isWide ? 48 : 24,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ── Header ──
                        AppIconImage(size: isWide ? 48 : 36),
                        const SizedBox(height: 8),
                        Text(
                          l10n.appTitle,
                          style: TextStyle(
                            fontSize: isWide ? 24 : 20,
                            fontWeight: FontWeight.bold,
                            color: palette.tabActiveText,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.landingSubtitle,
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
              );
            },
          ),
        ),
        const Positioned(
          bottom: 24,
          left: 0,
          right: 0,
          child: _KeyboardAwareTagline(),
        ),
        // Language picker — top-right, floating over background.
        Positioned(
          top: 8,
          right: 8,
          child: SafeArea(
            child: _buildLanguagePicker(palette),
          ),
        ),
      ],
    );
  }

  Widget _buildLanguagePicker(DmToolColors palette) {
    final l10n = L10n.of(context)!;
    final currentCode = ref.watch(localeProvider).languageCode;
    return Material(
      color: Colors.black.withValues(alpha: 0.32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: PopupMenuButton<String>(
        tooltip: l10n.lblLanguage,
        onSelected: (code) =>
            ref.read(localeProvider.notifier).setLocale(code),
        itemBuilder: (_) => [
          for (final entry in const [
            ('en', 'English'),
            ('tr', 'Türkçe'),
            ('de', 'Deutsch'),
            ('fr', 'Français'),
          ])
            PopupMenuItem(
              value: entry.$1,
              child: Row(
                children: [
                  Icon(
                    entry.$1 == currentCode
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(entry.$2),
                ],
              ),
            ),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.language, size: 16, color: palette.tabActiveText),
              const SizedBox(width: 6),
              Text(
                currentCode.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: palette.tabActiveText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Wide layout: OAuth left | OR | Email right ────────────────────

  Widget _buildWideAuthContent(DmToolColors palette) {
    final l10n = L10n.of(context)!;
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
                child: Text(l10n.landingOr, style: TextStyle(fontSize: 11, color: palette.sidebarLabelSecondary)),
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
    final l10n = L10n.of(context)!;
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
              child: Text(l10n.landingOr, style: TextStyle(fontSize: 11, color: palette.sidebarLabelSecondary)),
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
    final l10n = L10n.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _oauthButton(palette, icon: Icons.g_mobiledata, label: l10n.landingOauthGoogle, provider: OAuthProvider.google),
        const SizedBox(height: 10),
        _oauthButton(palette, icon: Icons.code, label: l10n.landingOauthGithub, provider: OAuthProvider.github),
      ],
    );
  }

  // ── Email/password form ───────────────────────────────────────────

  Widget _buildEmailForm(DmToolColors palette) {
    final l10n = L10n.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(l10n.landingFieldEmail, palette),
        const SizedBox(height: 4),
        _buildField(_emailController, l10n.landingHintEmail, palette, keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 10),
        _buildLabel(l10n.landingFieldPassword, palette),
        const SizedBox(height: 4),
        _buildField(_passwordController, l10n.landingHintPasswordMin, palette, obscure: true),
        if (_isSignUp) ...[
          const SizedBox(height: 10),
          _buildLabel(l10n.landingFieldConfirmPassword, palette),
          const SizedBox(height: 4),
          _buildField(_confirmController, l10n.landingHintReenterPassword, palette, obscure: true),
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
                : Text(_isSignUp ? l10n.landingSignUp : l10n.landingSignIn, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
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
              _isSignUp ? l10n.landingToggleToSignIn : l10n.landingToggleToSignUp,
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
    final l10n = L10n.of(context)!;
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = l10n.landingErrFillAll);
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _error = l10n.landingErrInvalidEmail);
      return;
    }
    if (password.length < 6) {
      setState(() => _error = l10n.landingErrPasswordShort);
      return;
    }
    if (_isSignUp && password != _confirmController.text) {
      setState(() => _error = l10n.landingErrPasswordMismatch);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });

    final notifier = ref.read(authProvider.notifier);
    String? error;

    if (_isSignUp) {
      error = await notifier.signUp(email, password);
      if (error == null && ref.read(authProvider) == null) {
        setState(() {
          _loading = false;
          _info = l10n.landingInfoConfirmEmail;
        });
        return;
      }
    } else {
      error = await notifier.signIn(email, password);
      // Ban kontrolü auth stream dinleyicisi tarafından otomatik yapılır;
      // banlıysa `banMessageNotifier` dolar ve aşağıdaki listener dialog açar.
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

// Tagline isolated so that only this widget rebuilds on keyboard animation
// frames — parent _buildAuthLanding no longer reads viewInsets.
class _KeyboardAwareTagline extends StatelessWidget {
  const _KeyboardAwareTagline();

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    if (keyboardOpen) return const SizedBox.shrink();
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final l10n = L10n.of(context)!;
    return IgnorePointer(
      child: Text(
        l10n.landingTagline,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, color: palette.sidebarLabelSecondary),
      ),
    );
  }
}
