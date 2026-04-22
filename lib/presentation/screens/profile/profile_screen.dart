import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/file_utils.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/profile_viewmodel.dart';
import '../../widgets/common/error_snackbar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = context.read<AuthViewModel>().user?.uid;
      if (uid != null) context.read<ProfileViewModel>().load(uid);
    });
  }

  Future<void> _pickAvatar() async {
    HapticFeedback.lightImpact();
    await Permission.photos.request();
    final xfile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (xfile == null || !mounted) return;

    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final avatarDir = Directory('${docsDir.path}/avatars');
      if (!avatarDir.existsSync()) avatarDir.createSync(recursive: true);
      final dest = File('${avatarDir.path}/profile_avatar.jpg');
      await File(xfile.path).copy(dest.path);

      if (!mounted) return;
      final ok = await context.read<ProfileViewModel>().saveAvatar(dest.path);
      if (mounted) {
        if (ok) {
          showSuccessSnackbar(context, 'Profile photo updated');
        } else {
          showErrorSnackbar(context, 'Failed to save photo');
        }
      }
    } catch (e) {
      debugPrint('_pickAvatar: $e');
      if (mounted) showErrorSnackbar(context, 'Failed to update photo');
    }
  }

  Future<void> _editName() async {
    HapticFeedback.lightImpact();
    final authVm = context.read<AuthViewModel>();
    final ctrl = TextEditingController(text: authVm.user?.displayName ?? '');
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Name'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Display name'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final name = ctrl.text.trim();
    if (name.isEmpty) return;

    final ok = await authVm.updateDisplayName(name);
    if (mounted) {
      if (ok) {
        showSuccessSnackbar(context, 'Name updated');
      } else {
        showErrorSnackbar(context, authVm.error ?? 'Failed to update name');
      }
    }
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return 'Edited ${diff.inMinutes}m ago';
    if (diff.inDays < 1) return 'Edited ${diff.inHours}h ago';
    if (diff.inDays < 7) return 'Edited ${diff.inDays}d ago';
    return 'Edited on ${DateFormat.MMMd().format(dt)}';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final authVm = context.watch<AuthViewModel>();
    final profileVm = context.watch<ProfileViewModel>();
    final user = authVm.user;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l.t('profile'))),
        body: const Center(child: Text('Not logged in')),
      );
    }

    final avatarPath = profileVm.avatarPath;

    return Scaffold(
      appBar: AppBar(title: Text(l.t('profile'))),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Bug 1 & 5: theme-aware hero header ─────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32),
              decoration: BoxDecoration(
                gradient: isDark
                    ? const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF0F1729), AppColors.darkBackground],
                      )
                    : LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.primary.withValues(alpha: 0.1),
                          Theme.of(context).scaffoldBackgroundColor,
                        ],
                      ),
              ),
              child: Column(
                children: [
                  // Avatar
                  GestureDetector(
                    onTap: _pickAvatar,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: AppColors.primary,
                          backgroundImage: avatarPath != null
                              ? FileImage(File(avatarPath)) as ImageProvider
                              : user.photoUrl != null
                                  ? NetworkImage(user.photoUrl!)
                                  : null,
                          child: (avatarPath == null && user.photoUrl == null)
                              ? Text(
                                  user.displayName.isNotEmpty
                                      ? user.displayName[0].toUpperCase()
                                      : 'U',
                                  style: const TextStyle(
                                      fontSize: 40, color: Colors.white),
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: cs.surface, width: 2),
                            ),
                            child: const Icon(LucideIcons.camera,
                                size: 14, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Name
                  GestureDetector(
                    onTap: _editName,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          user.displayName,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(LucideIcons.pencil,
                            size: 14,
                            color: cs.onSurface.withValues(alpha: 0.5)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.email,
                    style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.6)),
                  ),
                ],
              ),
            ),

            // ── Bug 5: theme-aware stats row ────────────────────────────────
            if (profileVm.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: CircularProgressIndicator(),
              )
            else
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _StatItem(
                      value: profileVm.projectsCount.toString(),
                      label: l.t('projects_count'),
                    ),
                    VerticalDivider(
                        width: 1, thickness: 1, color: cs.outlineVariant),
                    _StatItem(
                      value: profileVm.minutesEdited.toString(),
                      label: l.t('total_minutes'),
                    ),
                    VerticalDivider(
                        width: 1, thickness: 1, color: cs.outlineVariant),
                    _StatItem(
                      value: profileVm.exportsCount.toString(),
                      label: l.t('exports_count'),
                    ),
                  ],
                ),
              ),

            // ── Local Storage Card ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                child: ListTile(
                  leading: const Icon(LucideIcons.hardDrive,
                      color: AppColors.primary, size: 20),
                  title: const Text('Local Storage Used'),
                  trailing: Text(
                    FileUtils.formatBytes(profileVm.localStorageBytes),
                    style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Recent Activity ─────────────────────────────────────────────
            if (!profileVm.isLoading && profileVm.recentActivity.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.t('recent_activity'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Column(
                        children: profileVm.recentActivity
                            .map((a) => _ActivityItem(
                                  label: a.name,
                                  subtitle: _relativeTime(a.updatedAt),
                                ))
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: cs.onSurface),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.6), fontSize: 12),
        ),
      ],
    );
  }
}

class _ActivityItem extends StatelessWidget {
  const _ActivityItem({required this.label, required this.subtitle});
  final String label;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(LucideIcons.film,
          size: 18,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
      title: Text(label,
          style: const TextStyle(fontSize: 13),
          overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle,
          style: TextStyle(
              fontSize: 11,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.5))),
    );
  }
}
