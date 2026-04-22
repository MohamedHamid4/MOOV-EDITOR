import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/duration_formatter.dart';
import '../../../domain/entities/project.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/home_viewmodel.dart';
import '../../viewmodels/settings_viewmodel.dart';
import '../../widgets/common/error_snackbar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _navIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProjects());
  }

  Future<void> _loadProjects() async {
    final uid = context.read<AuthViewModel>().user?.uid;
    if (uid == null) return;
    await context.read<HomeViewModel>().loadProjects(uid);
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Future<void> _showCreateDialog() async {
    final l = AppLocalizations.of(context);
    final ctrl = TextEditingController(text: 'Untitled Project');
    final arSettings = context.read<SettingsViewModel>().defaultAspectRatio;
    String selectedAr = arSettings;

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(l.t('create_project')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                decoration: InputDecoration(labelText: l.t('project_name')),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedAr, // ignore: deprecated_member_use
                decoration: InputDecoration(labelText: l.t('aspect_ratio')),
                items: ['16:9', '9:16', '1:1', '4:3']
                    .map((ar) => DropdownMenuItem(value: ar, child: Text(ar)))
                    .toList(),
                onChanged: (v) => setDialogState(() => selectedAr = v ?? selectedAr),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.t('cancel'))),
            TextButton(
              onPressed: () async {
                if (ctrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                await _createProject(ctrl.text.trim(), selectedAr);
              },
              child: Text(l.t('create_project')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createProject(String name, String aspectRatio) async {
    HapticFeedback.mediumImpact();
    final uid = context.read<AuthViewModel>().user?.uid ?? '';
    final project = await context.read<HomeViewModel>().createProject(
      name: name,
      ownerUid: uid,
      aspectRatio: aspectRatio,
    );
    if (!mounted) return;
    _openEditor(project);
  }

  void _openEditor(Project project) {
    HapticFeedback.lightImpact();
    Navigator.of(context).pushNamed('/editor', arguments: project);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final vm = context.watch<HomeViewModel>();
    final authVm = context.watch<AuthViewModel>();
    final displayName = authVm.user?.displayName ?? '';
    final firstName = displayName.split(' ').first;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _greeting() + (firstName.isNotEmpty ? ', $firstName' : ''),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            Text(
              l.t('app_name'),
              style: const TextStyle(
                  fontSize: 11, color: AppColors.darkTextSecondary),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.search, size: 20),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(LucideIcons.settings, size: 20),
            onPressed: () => Navigator.of(context).pushNamed('/settings'),
          ),
          GestureDetector(
            onTap: () => Navigator.of(context).pushNamed('/profile'),
            child: Padding(
              padding: const EdgeInsets.only(right: 16, left: 4),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primary,
                child: Text(
                  displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final uid = authVm.user?.uid;
          if (uid != null) await context.read<HomeViewModel>().refreshFromCloud(uid);
        },
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverToBoxAdapter(
                child: _NewProjectCard(onTap: () {
                  HapticFeedback.lightImpact();
                  _showCreateDialog();
                }),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(
                child: Text(l.t('recent_projects'),
                    style: Theme.of(context).textTheme.titleMedium),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            if (vm.isLoading)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (_, __) => const _ShimmerCard(),
                    childCount: 4,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.8,
                  ),
                ),
              )
            else if (vm.projects.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.darkSurface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.darkBorder),
                        ),
                        child: const Icon(LucideIcons.film,
                            size: 36, color: AppColors.darkTextSecondary),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No projects yet',
                        style: TextStyle(
                            color: AppColors.darkTextPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Tap the card above to create your first project',
                        style: TextStyle(
                            color: AppColors.darkTextSecondary, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _ProjectCard(
                      project: vm.projects[i],
                      onOpen: () => _openEditor(vm.projects[i]),
                      onRename: (n) => vm.renameProject(vm.projects[i].id, n),
                      onDuplicate: () => vm.duplicateProject(vm.projects[i].id),
                      onDelete: () {
                        HapticFeedback.mediumImpact();
                        vm.deleteProject(vm.projects[i].id);
                      },
                      onSync: () async {
                        await vm.syncToCloud(vm.projects[i].id);
                        if (!mounted) return;
                        // ignore: use_build_context_synchronously
                        showSuccessSnackbar(context, 'Synced ✓');
                      },
                    ),
                    childCount: vm.projects.length,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.8,
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _navIndex,
        onTap: (i) {
          HapticFeedback.selectionClick();
          setState(() => _navIndex = i);
          if (i == 3) Navigator.of(context).pushNamed('/profile');
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(LucideIcons.home), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(LucideIcons.layoutGrid), label: 'Templates'),
          BottomNavigationBarItem(
              icon: Icon(LucideIcons.download), label: 'Exports'),
          BottomNavigationBarItem(icon: Icon(LucideIcons.user), label: 'Profile'),
        ],
      ),
    );
  }
}

class _NewProjectCard extends StatefulWidget {
  const _NewProjectCard({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_NewProjectCard> createState() => _NewProjectCardState();
}

class _NewProjectCardState extends State<_NewProjectCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      lowerBound: 0,
      upperBound: 1,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.97).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          height: 120,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: AppColors.projectCardGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(LucideIcons.plus, color: Colors.white, size: 28),
              SizedBox(width: 12),
              Text(
                'New Project',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShimmerCard extends StatelessWidget {
  const _ShimmerCard();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.darkSurface,
      highlightColor: AppColors.darkSurfaceElevated,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({
    required this.project,
    required this.onOpen,
    required this.onRename,
    required this.onDuplicate,
    required this.onDelete,
    required this.onSync,
  });

  final Project project;
  final VoidCallback onOpen;
  final ValueChanged<String> onRename;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return GestureDetector(
      onTap: onOpen,
      child: Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.darkSurfaceElevated,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                ),
                alignment: Alignment.center,
                child: Text(
                  project.name.isNotEmpty ? project.name[0].toUpperCase() : '?',
                  style: const TextStyle(
                      fontSize: 48,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          project.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          DurationFormatter.formatHuman(project.duration),
                          style: const TextStyle(
                              color: AppColors.darkTextSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    iconSize: 18,
                    onSelected: (val) {
                      switch (val) {
                        case 'rename':
                          _showRenameDialog(context, l);
                          break;
                        case 'duplicate':
                          onDuplicate();
                          break;
                        case 'delete':
                          onDelete();
                          break;
                        case 'sync':
                          onSync();
                          break;
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'rename', child: Text(l.t('rename'))),
                      PopupMenuItem(
                          value: 'duplicate', child: Text(l.t('duplicate'))),
                      PopupMenuItem(
                          value: 'sync', child: Text(l.t('sync_cloud'))),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(l.t('delete'),
                            style: const TextStyle(color: AppColors.error)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(BuildContext context, AppLocalizations l) {
    final ctrl = TextEditingController(text: project.name);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l.t('rename')),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: Text(l.t('cancel'))),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (ctrl.text.trim().isNotEmpty) onRename(ctrl.text.trim());
            },
            child: Text(l.t('save')),
          ),
        ],
      ),
    );
  }
}
