import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/auth_provider.dart';
import '../../../core/config/supabase_config.dart';
import '../../theme/dm_tool_colors.dart';

class SocialTab extends ConsumerStatefulWidget {
  const SocialTab({super.key});

  @override
  ConsumerState<SocialTab> createState() => _SocialTabState();
}

class _SocialTabState extends ConsumerState<SocialTab> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _isSignUp = true;
  bool _loading = false;
  String? _error;
  String? _info;

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

    if (!SupabaseConfig.isConfigured) {
      return _buildNotConfigured(palette);
    }

    final authState = ref.watch(authProvider);

    return authState != null
        ? _buildProfile(palette, authState)
        : _buildAuthForm(palette);
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

  // ── Sign Up / Sign In form ──────────────────────────────────────

  Widget _buildAuthForm(DmToolColors palette) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Center(
                child: Column(
                  children: [
                    Icon(Icons.account_circle_outlined, size: 64, color: palette.featureCardAccent),
                    const SizedBox(height: 12),
                    Text(
                      'Account',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: palette.tabActiveText),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Create an account to unlock online features.',
                      style: TextStyle(fontSize: 13, color: palette.sidebarLabelSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Email
              Text('Email', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: palette.tabActiveText)),
              const SizedBox(height: 6),
              TextField(
                controller: _emailController,
                enabled: !_loading,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'you@example.com',
                  filled: true,
                  fillColor: palette.featureCardBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: palette.featureCardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: palette.featureCardBorder),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),

              // Password
              Text('Password', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: palette.tabActiveText)),
              const SizedBox(height: 6),
              TextField(
                controller: _passwordController,
                enabled: !_loading,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'Min 6 characters',
                  filled: true,
                  fillColor: palette.featureCardBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: palette.featureCardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: palette.featureCardBorder),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),

              // Confirm password (sign-up only)
              if (_isSignUp) ...[
                const SizedBox(height: 16),
                Text('Confirm Password', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: palette.tabActiveText)),
                const SizedBox(height: 6),
                TextField(
                  controller: _confirmController,
                  enabled: !_loading,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: 'Re-enter password',
                    filled: true,
                    fillColor: palette.featureCardBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: palette.featureCardBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: palette.featureCardBorder),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
              ],

              // Error message
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(fontSize: 12, color: palette.dangerBtnBg),
                ),
              ],

              // Info message (e.g. "Check your email")
              if (_info != null) ...[
                const SizedBox(height: 12),
                Text(
                  _info!,
                  style: TextStyle(fontSize: 12, color: palette.successBtnBg),
                ),
              ],

              const SizedBox(height: 20),

              // Submit button
              SizedBox(
                width: double.infinity,
                height: 44,
                child: FilledButton(
                  onPressed: _loading ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.featureCardAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          _isSignUp ? 'Sign Up' : 'Sign In',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
              const SizedBox(height: 12),

              // Toggle sign-up / sign-in
              Center(
                child: TextButton(
                  onPressed: _loading
                      ? null
                      : () {
                          setState(() {
                            _isSignUp = !_isSignUp;
                            _error = null;
                            _info = null;
                            _confirmController.clear();
                          });
                        },
                  child: Text(
                    _isSignUp ? 'Already have an account? Sign In' : "Don't have an account? Sign Up",
                    style: TextStyle(fontSize: 12, color: palette.featureCardAccent),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Signed-in profile ───────────────────────────────────────────

  Widget _buildProfile(DmToolColors palette, AuthState authState) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            children: [
              const SizedBox(height: 32),
              Icon(Icons.account_circle, size: 72, color: palette.featureCardAccent),
              const SizedBox(height: 16),
              Text(
                authState.email,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: palette.tabActiveText),
              ),
              const SizedBox(height: 4),
              SelectableText(
                authState.uid,
                style: TextStyle(fontSize: 11, color: palette.sidebarLabelSecondary),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: 200,
                child: OutlinedButton(
                  onPressed: () => ref.read(authProvider.notifier).signOut(),
                  child: Text(
                    'Sign Out',
                    style: TextStyle(color: palette.dangerBtnBg),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Validation & submit ─────────────────────────────────────────

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    // Basic validation
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
      // If sign-up succeeded but no session yet → email confirmation required
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
}
