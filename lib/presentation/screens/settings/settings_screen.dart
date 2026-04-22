import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_fonts.dart';
import '../../../core/utils/file_utils.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/settings_viewmodel.dart';
import '../../widgets/common/error_snackbar.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _version = '${info.version}+${info.buildNumber}');
    } catch (e) {
      debugPrint('PackageInfo: $e');
      if (mounted) setState(() => _version = '1.0.0');
    }
    if (mounted) {
      await context.read<SettingsViewModel>().refreshCacheSize();
    }
  }

  Future<void> _confirmLogOut() async {
    HapticFeedback.mediumImpact();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await context.read<AuthViewModel>().signOut();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    }
  }

  Future<void> _confirmClearCache() async {
    HapticFeedback.mediumImpact();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text(
          'This will delete all cached thumbnails and temporary files. '
          'Thumbnails will be regenerated as needed.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final vm = context.read<SettingsViewModel>();
    await vm.clearCache();
    if (mounted) showSuccessSnackbar(context, 'Cache cleared');
  }

  Future<void> _launchRateUs() async {
    final market = Uri.parse('market://details?id=com.moov.editor');
    final web = Uri.parse(
        'https://play.google.com/store/apps/details?id=com.moov.editor');
    try {
      if (await canLaunchUrl(market)) {
        await launchUrl(market);
      } else {
        await launchUrl(web, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('_launchRateUs: $e');
      if (mounted) showErrorSnackbar(context, 'Could not open the Play Store');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final vm = context.watch<SettingsViewModel>();

    return Scaffold(
      appBar: AppBar(title: Text(l.t('settings'))),
      body: ListView(
        children: [
          _SectionHeader(l.t('appearance')),
          _SettingsCard(children: [
            _RadioSetting(
              title: l.t('theme'),
              options: [
                (l.t('theme_light'), 'light'),
                (l.t('theme_dark'), 'dark'),
                (l.t('theme_system'), 'system'),
              ],
              selected: vm.theme,
              onChanged: vm.setTheme,
            ),
            const Divider(height: 1),
            _DropdownSetting(
              title: l.t('language'),
              options: const [('English', 'en'), ('العربية', 'ar')],
              selected: vm.language,
              onChanged: vm.setLanguage,
            ),
          ]),

          _SectionHeader(l.t('preferences')),
          _SettingsCard(children: [
            _SwitchSetting(
              title: l.t('auto_save'),
              value: vm.autoSave,
              onChanged: vm.setAutoSave,
            ),
            const Divider(height: 1),
            _CloudSyncTile(vm: vm),
            const Divider(height: 1),
            _DropdownSetting(
              title: l.t('default_aspect_ratio'),
              options: const [
                ('16:9', '16:9'),
                ('9:16', '9:16'),
                ('1:1', '1:1'),
                ('4:3', '4:3'),
              ],
              selected: vm.defaultAspectRatio,
              onChanged: vm.setDefaultAspectRatio,
            ),
            const Divider(height: 1),
            _DropdownSetting(
              title: l.t('default_quality'),
              options: const [
                ('Low', 'Low'),
                ('Medium', 'Medium'),
                ('High', 'High'),
                ('Ultra', 'Ultra'),
              ],
              selected: vm.defaultQuality,
              onChanged: vm.setDefaultQuality,
            ),
          ]),

          _SectionHeader(l.t('storage')),
          _SettingsCard(children: [
            ListTile(
              leading: const Icon(LucideIcons.hardDrive,
                  size: 18, color: AppColors.darkTextSecondary),
              title: Text(l.t('cache_size')),
              trailing: vm.isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      FileUtils.formatBytes(vm.cacheSizeBytes),
                      style: const TextStyle(color: AppColors.darkTextSecondary),
                    ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(LucideIcons.trash2,
                  size: 18, color: AppColors.error),
              title: Text(l.t('clear_cache'),
                  style: const TextStyle(color: AppColors.error)),
              onTap: vm.isLoading ? null : _confirmClearCache,
            ),
          ]),

          _SectionHeader(l.t('account')),
          _SettingsCard(children: [
            ListTile(
              leading: const Icon(LucideIcons.user,
                  size: 18, color: AppColors.darkTextSecondary),
              title: Text(l.t('edit_profile')),
              onTap: () => Navigator.of(context).pushNamed('/profile'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(LucideIcons.logOut,
                  size: 18, color: AppColors.error),
              title: Text(l.t('logout'),
                  style: const TextStyle(color: AppColors.error)),
              onTap: _confirmLogOut,
            ),
          ]),

          _SectionHeader(l.t('about')),
          _SettingsCard(children: [
            ListTile(
              title: Text(l.t('version')),
              trailing: Text(
                _version.isEmpty ? '…' : _version,
                style: const TextStyle(color: AppColors.darkTextSecondary),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              title: Text(l.t('terms')),
              trailing: const Icon(LucideIcons.chevronRight, size: 18),
              onTap: () => Navigator.of(context).pushNamed('/terms'),
            ),
            const Divider(height: 1),
            ListTile(
              title: Text(l.t('privacy')),
              trailing: const Icon(LucideIcons.chevronRight, size: 18),
              onTap: () => Navigator.of(context).pushNamed('/privacy'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(LucideIcons.star,
                  size: 18, color: AppColors.warning),
              title: Text(l.t('rate_us')),
              trailing:
                  const Icon(LucideIcons.externalLink, size: 16),
              onTap: _launchRateUs,
            ),
          ]),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _CloudSyncTile extends StatelessWidget {
  const _CloudSyncTile({required this.vm});
  final SettingsViewModel vm;

  void _showUnavailableDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(LucideIcons.cloudOff, color: AppColors.warning),
            SizedBox(width: 8),
            Text('Cloud Sync Unavailable'),
          ],
        ),
        content: const Text(
          'Cloud Sync requires Firebase Storage.\n\n'
          'Please upgrade to the Blaze plan from Firebase Console to enable '
          'automatic project backup and export uploads.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Row(
        children: [
          Text(AppLocalizations.of(context).t('cloud_sync')),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'Blaze',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.warning,
              ),
            ),
          ),
        ],
      ),
      subtitle: const Text(
        'Requires Firebase Storage upgrade',
        style: TextStyle(fontSize: 12, color: AppColors.darkTextSecondary),
      ),
      value: vm.cloudSync,
      activeThumbColor: AppColors.primary,
      onChanged: (v) {
        if (v) {
          _showUnavailableDialog(context);
        } else {
          vm.setCloudSync(false);
        }
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: AppFonts.label(context).copyWith(
          fontSize: 11,
          letterSpacing: 1.2,
          color: AppColors.darkTextSecondary,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(children: children),
    );
  }
}

class _SwitchSetting extends StatelessWidget {
  const _SwitchSetting({
    required this.title,
    required this.value,
    required this.onChanged,
  });
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(title),
      value: value,
      onChanged: (v) {
        HapticFeedback.selectionClick();
        onChanged(v);
      },
      activeThumbColor: AppColors.primary,
    );
  }
}

class _RadioSetting extends StatelessWidget {
  const _RadioSetting({
    required this.title,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final String title;
  final List<(String, String)> options;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppFonts.body(context)),
          const SizedBox(height: 8),
          Row(
            children: options.map((opt) {
              return Expanded(
                child: InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onChanged(opt.$2);
                  },
                  child: Row(
                    children: [
                      Radio<String>(
                        value: opt.$2,
                        groupValue: selected, // ignore: deprecated_member_use
                        onChanged: (v) { // ignore: deprecated_member_use
                          HapticFeedback.selectionClick();
                          onChanged(v ?? opt.$2);
                        },
                        activeColor: AppColors.primary,
                      ),
                      Flexible(
                        child: Text(opt.$1, style: AppFonts.label(context)),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _DropdownSetting extends StatelessWidget {
  const _DropdownSetting({
    required this.title,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final String title;
  final List<(String, String)> options;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      trailing: DropdownButton<String>(
        value: selected,
        underline: const SizedBox.shrink(),
        items: options
            .map((o) => DropdownMenuItem(value: o.$2, child: Text(o.$1)))
            .toList(),
        onChanged: (v) {
          if (v != null) {
            HapticFeedback.selectionClick();
            onChanged(v);
          }
        },
      ),
    );
  }
}
