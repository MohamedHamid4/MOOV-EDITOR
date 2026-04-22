import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/error_snackbar.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _staySignedIn = true;

  @override
  void initState() {
    super.initState();
    _emailCtrl.addListener(_clearError);
    _passwordCtrl.addListener(_clearError);
  }

  void _clearError() {
    final vm = context.read<AuthViewModel>();
    if (vm.error != null) vm.clearError();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    HapticFeedback.lightImpact();
    if (!_formKey.currentState!.validate()) return;
    final vm = context.read<AuthViewModel>();
    final ok = await vm.signIn(_emailCtrl.text.trim(), _passwordCtrl.text);
    if (!mounted) return;
    if (ok) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('stay_signed_in', _staySignedIn);
      if (mounted) Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  Future<void> _googleSignIn() async {
    HapticFeedback.lightImpact();
    final vm = context.read<AuthViewModel>();
    final l = AppLocalizations.of(context);
    final ok = await vm.signInWithGoogle();
    if (!mounted) return;
    if (ok) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('stay_signed_in', _staySignedIn);
      if (mounted) Navigator.of(context).pushReplacementNamed('/home');
    } else if (vm.error != null) {
      showErrorSnackbar(context, l.t(vm.error!));
    }
  }

  Future<void> _showResetDialog() async {
    HapticFeedback.lightImpact();
    final emailCtrl = TextEditingController();
    final l = AppLocalizations.of(context);
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l.t('forgot_password')),
        content: TextField(
          controller: emailCtrl,
          decoration: InputDecoration(labelText: l.t('email')),
          keyboardType: TextInputType.emailAddress,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: Text(l.t('cancel'))),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final vm = context.read<AuthViewModel>();
              final ok = await vm.sendPasswordReset(emailCtrl.text.trim());
              if (!mounted) return;
              if (ok) {
                showSuccessSnackbar(context, l.t('password_reset_sent'));
              } else if (vm.error != null) {
                showErrorSnackbar(context, l.t(vm.error!));
              }
            },
            child: Text(l.t('ok')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AuthViewModel>();
    final l = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    // Bug 1+3: theme-aware gradient that fills the full viewport.
    return Scaffold(
      // Match scaffold bg to gradient end so no bleed-through at bottom.
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      resizeToAvoidBottomInset: true,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF0F1729), AppColors.darkBackground],
                  stops: [0.0, 0.65],
                )
              : LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.07),
                    AppColors.lightBackground,
                  ],
                  stops: const [0.0, 0.55],
                ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),

                  // Logo with Hero
                  Center(
                    child: Hero(
                      tag: 'app_logo',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Image.asset(
                          'assets/icons/app_icon.png',
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  Text(
                    l.t('welcome_back'),
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l.t('welcome_subtitle'),
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.6),
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 36),

                  // Email
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: l.t('email'),
                      prefixIcon: const Icon(LucideIcons.mail, size: 18),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return l.t('invalid_email');
                      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(v.trim())) {
                        return l.t('invalid_email');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Password
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: l.t('password'),
                      prefixIcon: const Icon(LucideIcons.lock, size: 18),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? LucideIcons.eyeOff : LucideIcons.eye,
                          size: 18,
                        ),
                        onPressed: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return l.t('error_weak_password');
                      return null;
                    },
                  ),

                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _showResetDialog,
                      child: Text(
                        l.t('forgot_password'),
                        style: const TextStyle(color: AppColors.primary),
                      ),
                    ),
                  ),

                  // Stay signed in
                  CheckboxListTile(
                    title: Text(l.t('stay_signed_in')),
                    value: _staySignedIn,
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppColors.primary,
                    onChanged: (v) {
                      HapticFeedback.selectionClick();
                      setState(() => _staySignedIn = v ?? true);
                    },
                  ),

                  // Error banner
                  if (vm.error != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppColors.error.withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.alertCircle,
                              color: AppColors.error, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l.t(vm.error!),
                              style: const TextStyle(
                                  color: AppColors.error, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  AppButton(
                    label: l.t('login'),
                    onPressed: vm.isLoading ? null : _login,
                    isLoading: vm.isLoading,
                  ),
                  const SizedBox(height: 16),

                  const Row(children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('OR',
                          style: TextStyle(color: AppColors.darkTextSecondary)),
                    ),
                    Expanded(child: Divider()),
                  ]),
                  const SizedBox(height: 16),

                  // Bug 2: Google button — visible on both light and dark themes.
                  SizedBox(
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: vm.isLoading ? null : _googleSignIn,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: cs.onSurface,
                        side: const BorderSide(
                            color: AppColors.primary, width: 1.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                      ),
                      icon: const Text(
                        'G',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      label: Text(
                        l.t('continue_google'),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.of(context).pushNamed('/signup');
                    },
                    child: Text(
                      l.t('no_account'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
