import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/project.dart';
import '../../viewmodels/export_viewmodel.dart';
import '../../widgets/common/error_snackbar.dart';

class ExportScreen extends StatelessWidget {
  const ExportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final project = ModalRoute.of(context)?.settings.arguments as Project?;
    if (project == null) {
      return const Scaffold(body: Center(child: Text('No project')));
    }
    return ChangeNotifierProvider(
      create: (_) => ExportViewModel(),
      child: _ExportBody(project: project),
    );
  }
}

class _ExportBody extends StatelessWidget {
  const _ExportBody({required this.project});
  final Project project;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ExportViewModel>();
    final l = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l.t('export'))),
      body: vm.isExporting
          ? _ExportingView(vm: vm, l: l)
          : vm.isComplete
              ? _CompleteView(vm: vm, project: project, l: l)
              : _ConfigView(vm: vm, project: project, l: l),
    );
  }
}

// ── Config View ──────────────────────────────────────────────────────────────

class _ConfigView extends StatelessWidget {
  const _ConfigView({required this.vm, required this.project, required this.l});
  final ExportViewModel vm;
  final Project project;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Preview
          Center(
            child: AspectRatio(
              aspectRatio: _ar(vm.aspectRatio),
              child: Container(
                constraints: const BoxConstraints(maxHeight: 180),
                decoration: BoxDecoration(
                  color: AppColors.darkSurfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.movie_outlined, size: 48, color: AppColors.darkTextSecondary),
              ),
            ),
          ),
          const SizedBox(height: 24),

          _OptionGroup(
            title: l.t('aspect_ratio'),
            options: const ['16:9', '9:16', '1:1', '4:3'],
            selected: vm.aspectRatio,
            onChanged: vm.setAspectRatio,
          ),
          const SizedBox(height: 16),

          _OptionGroup(
            title: l.t('resolution'),
            options: const ['480p', '720p', '1080p', '4K'],
            selected: vm.resolution,
            onChanged: vm.setResolution,
          ),
          const SizedBox(height: 16),

          _OptionGroup(
            title: l.t('frame_rate'),
            options: const ['24', '30', '60'],
            selected: vm.fps.toString(),
            onChanged: (v) => vm.setFps(int.parse(v)),
          ),
          const SizedBox(height: 16),

          _OptionGroup(
            title: l.t('quality'),
            options: const ['Low', 'Medium', 'High', 'Ultra'],
            selected: vm.quality,
            onChanged: vm.setQuality,
          ),
          const SizedBox(height: 16),

          // Format (read-only)
          _InfoRow(label: l.t('format'), value: 'MP4 (H.264)'),
          _InfoRow(
            label: l.t('estimated_size'),
            value: '~${vm.estimatedSizeMb.toStringAsFixed(0)} MB',
          ),
          const SizedBox(height: 24),

          ElevatedButton.icon(
            icon: const Icon(Icons.file_download_outlined),
            label: Text(l.t('start_export')),
            onPressed: () => vm.startExport(project),
          ),
        ],
      ),
    );
  }

  double _ar(String ar) {
    switch (ar) {
      case '9:16': return 9 / 16;
      case '1:1': return 1.0;
      case '4:3': return 4 / 3;
      default: return 16 / 9;
    }
  }
}

// ── Exporting View ───────────────────────────────────────────────────────────

class _ExportingView extends StatelessWidget {
  const _ExportingView({required this.vm, required this.l});
  final ExportViewModel vm;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: vm.progress,
                    strokeWidth: 6,
                    color: AppColors.primary,
                  ),
                  Text(
                    '${(vm.progress * 100).round()}%',
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(l.t('exporting'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () async {
                await vm.cancelExport();
                if (context.mounted) Navigator.of(context).pop();
              },
              style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.error),
                  foregroundColor: AppColors.error),
              child: Text(l.t('cancel_export')),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Complete View ────────────────────────────────────────────────────────────

class _CompleteView extends StatelessWidget {
  const _CompleteView({required this.vm, required this.project, required this.l});
  final ExportViewModel vm;
  final Project project;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 16),
            Text(l.t('export_complete'),
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 32),

            // Bug 6: show auto-save result; allow manual retry if failed.
            if (vm.gallerySaved)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.4)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_outline,
                        color: AppColors.success, size: 18),
                    SizedBox(width: 8),
                    Text('Video saved to Gallery',
                        style: TextStyle(color: AppColors.success)),
                  ],
                ),
              )
            else
              ElevatedButton.icon(
                icon: vm.isSavingToGallery
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_alt),
                label: Text(l.t('save_to_gallery')),
                onPressed: vm.isSavingToGallery
                    ? null
                    : () async {
                        final ok = await vm.saveToGallery();
                        if (context.mounted) {
                          if (ok) {
                            showSuccessSnackbar(
                                context, '${l.t('save_to_gallery')} ✓');
                          } else {
                            showErrorSnackbar(context, 'Failed to save');
                          }
                        }
                      },
              ),
            const SizedBox(height: 12),

            // Upload to Cloud is hidden — Firebase Storage requires Blaze plan.
            // Re-enable this button once Storage is active.

            TextButton(
              onPressed: () {
                vm.reset();
                Navigator.of(context).pop();
              },
              child: const Text('Back to Editor'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

class _OptionGroup extends StatelessWidget {
  const _OptionGroup({
    required this.title,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final String title;
  final List<String> options;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: options.map((o) => ChoiceChip(
            label: Text(o),
            selected: selected == o,
            onSelected: (_) => onChanged(o),
          )).toList(),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.darkTextSecondary)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
