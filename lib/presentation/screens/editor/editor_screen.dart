import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/clip.dart' as e;
import '../../viewmodels/editor_viewmodel.dart';
import '../../widgets/preview/video_preview_widget.dart';
import '../../widgets/timeline/timeline_widget.dart';

class EditorScreen extends StatelessWidget {
  const EditorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<EditorViewModel>(
      builder: (context, vm, _) => Scaffold(
        backgroundColor: AppColors.darkBackground,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Compute the maximum height the properties panel may occupy so
              // that the Column never overflows regardless of screen size.
              const topBarH    = 52.0;
              const toolStripH = 56.0;
              const timelineH  = AppConstants.rulerHeight +
                  AppConstants.trackHeight * 3; // 28 + 240 = 268
              const minPreviewH = 80.0;
              final maxPanelH = (constraints.maxHeight -
                      topBarH -
                      toolStripH -
                      timelineH -
                      minPreviewH)
                  .clamp(0.0, 280.0);

              return Column(
                children: [
                  _TopBar(vm: vm),
                  const Expanded(child: VideoPreviewWidget()),
                  _ToolStrip(vm: vm),
                  const TimelineWidget(),
                  if (vm.propertiesPanelOpen)
                    SizedBox(
                      height: maxPanelH,
                      child: _PropertiesPanel(vm: vm),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ── Top Bar ──────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.vm});
  final EditorViewModel vm;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      height: 52,
      color: AppColors.darkSurface,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          // Back
          IconButton(
            icon: const Icon(LucideIcons.arrowLeft, size: 20),
            onPressed: () async {
              HapticFeedback.lightImpact();
              await vm.saveProject();
              if (context.mounted) Navigator.of(context).pop();
            },
          ),

          // Editable project name + pencil
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                _editProjectName(context);
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      vm.project.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(LucideIcons.pencil,
                      size: 13, color: AppColors.darkTextSecondary),
                ],
              ),
            ),
          ),

          // Auto-save status
          Text(
            vm.saveStatus ?? '',
            style: TextStyle(
              color: vm.isSaving ? AppColors.warning : AppColors.success,
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 6),

          // Undo — 36px circle
          _CircleIconBtn(
            icon: LucideIcons.undo2,
            enabled: vm.canUndo,
            onPressed: () {
              HapticFeedback.lightImpact();
              vm.undo();
            },
          ),

          const SizedBox(width: 4),

          // Redo — 36px circle
          _CircleIconBtn(
            icon: LucideIcons.redo2,
            enabled: vm.canRedo,
            onPressed: () {
              HapticFeedback.lightImpact();
              vm.redo();
            },
          ),

          const SizedBox(width: 6),

          // Export — gradient button
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              Navigator.of(context).pushNamed('/export', arguments: vm.project);
            },
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: AppColors.projectCardGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.upload,
                      size: 14, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(
                    l.t('export'),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  void _editProjectName(BuildContext context) {
    final ctrl = TextEditingController(text: vm.project.name);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename Project'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (ctrl.text.trim().isNotEmpty) {
                vm.renameProject(ctrl.text.trim());
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _CircleIconBtn extends StatelessWidget {
  const _CircleIconBtn({
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });
  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onPressed : null,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.darkSurfaceElevated,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.darkBorder, width: 0.5),
        ),
        child: Icon(
          icon,
          size: 16,
          color: enabled ? AppColors.darkTextPrimary : AppColors.darkTextDisabled,
        ),
      ),
    );
  }
}

// ── Tool Strip ───────────────────────────────────────────────────────────────

class _ToolStrip extends StatelessWidget {
  const _ToolStrip({required this.vm});
  final EditorViewModel vm;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final selected = vm.selectedClip;

    return Container(
      height: 56,
      color: AppColors.darkSurface,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          children: [
            _ToolBtn(
              icon: LucideIcons.plus,
              label: 'Import',
              onPressed: () => _importMedia(context),
            ),
            _ToolBtn(
              icon: LucideIcons.scissors,
              label: l.t('split'),
              onPressed: selected != null ? vm.splitClipAtPlayhead : null,
            ),
            _ToolBtn(
              icon: LucideIcons.trash2,
              label: l.t('delete'),
              onPressed: selected != null
                  ? () {
                      HapticFeedback.mediumImpact();
                      vm.deleteClip(selected.id);
                    }
                  : null,
            ),
            _ToolBtn(
              icon: LucideIcons.copy,
              label: l.t('duplicate'),
              onPressed: selected != null
                  ? () => vm.duplicateClip(selected.id)
                  : null,
            ),
            _ToolBtn(
              icon: LucideIcons.gauge,
              label: l.t('speed'),
              onPressed: selected != null
                  ? () => _showSpeedDialog(context, selected.id, selected.speed)
                  : null,
            ),
            _ToolBtn(
              icon: LucideIcons.volume2,
              label: l.t('volume'),
              onPressed: selected != null
                  ? () => vm.openPropertiesPanel(tab: 2)
                  : null,
            ),
            _ToolBtn(
              icon: LucideIcons.sliders,
              label: l.t('filters'),
              onPressed: selected != null
                  ? () => vm.openPropertiesPanel(tab: 1)
                  : null,
            ),
            _ToolBtn(
              icon: LucideIcons.arrowLeftRight,
              label: l.t('transitions'),
              onPressed: selected != null
                  ? () => vm.openPropertiesPanel(tab: 3)
                  : null,
            ),
            _ToolBtn(
              icon: LucideIcons.diamond,
              label: l.t('add_keyframe'),
              color: AppColors.keyframe,
              onPressed: selected != null
                  ? () => vm.upsertKeyframeAtPlayhead()
                  : null,
            ),
            _ToolBtn(
              icon: LucideIcons.type,
              label: l.t('text_overlay'),
              onPressed: () => _showAddTextDialog(context, vm),
            ),
            _ToolBtn(
              icon: LucideIcons.crop,
              label: l.t('crop'),
              onPressed: selected != null
                  ? () => vm.openPropertiesPanel(tab: 0)
                  : null,
            ),
            _ToolBtn(
              icon: vm.snapEnabled ? LucideIcons.grid : LucideIcons.grid,
              label: l.t('snap'),
              color: vm.snapEnabled ? AppColors.primary : null,
              onPressed: () {
                HapticFeedback.selectionClick();
                vm.toggleSnap();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _importMedia(BuildContext context) async {
    HapticFeedback.lightImpact();
    await showModalBottomSheet(
      context: context,
      builder: (_) => _ImportBottomSheet(vm: vm, stableContext: context),
    );
  }

  void _showSpeedDialog(
      BuildContext context, String clipId, double currentSpeed) {
    double speed = currentSpeed;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Speed'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${speed.toStringAsFixed(2)}×'),
              Slider(
                value: speed,
                min: 0.25,
                max: 4.0,
                divisions: 15,
                onChanged: (v) {
                  HapticFeedback.selectionClick();
                  setS(() => speed = v);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                vm.setClipSpeed(clipId, speed);
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolBtn extends StatelessWidget {
  const _ToolBtn({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ??
        (onPressed != null
            ? AppColors.darkTextPrimary
            : AppColors.darkTextDisabled);
    return InkWell(
      onTap: () {
        if (onPressed != null) {
          HapticFeedback.lightImpact();
          onPressed!();
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: c, size: 20),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: c, fontSize: 9)),
          ],
        ),
      ),
    );
  }
}

// ── Properties Panel ─────────────────────────────────────────────────────────

class _PropertiesPanel extends StatelessWidget {
  const _PropertiesPanel({required this.vm});
  final EditorViewModel vm;

  static const List<String> _tabs = ['Transform', 'Color', 'Audio', 'Effects'];

  @override
  Widget build(BuildContext context) {
    final clip = vm.selectedClip;
    if (clip == null) return const SizedBox.shrink();

    return Container(
      height: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.darkSurface,
        border: Border(top: BorderSide(color: AppColors.darkBorder, width: 0.5)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(_tabs.length, (i) {
                      final active = vm.selectedPropertiesTab == i;
                      return InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          vm.setPropertiesTab(i);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: active
                                    ? AppColors.primary
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                          child: Text(
                            _tabs[i],
                            style: TextStyle(
                              color: active
                                  ? AppColors.primary
                                  : AppColors.darkTextSecondary,
                              fontSize: 13,
                              fontWeight: active
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(LucideIcons.x, size: 18),
                onPressed: vm.closePropertiesPanel,
              ),
            ],
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildTabContent(context, clip),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent(BuildContext context, dynamic clip) {
    switch (vm.selectedPropertiesTab) {
      case 0:
        return _TransformTab(vm: vm, clip: clip);
      case 1:
        return _ColorTab(vm: vm, clip: clip);
      case 2:
        return _AudioTab(vm: vm, clip: clip);
      case 3:
        return _EffectsTab(vm: vm, clip: clip);
      default:
        return const SizedBox.shrink();
    }
  }
}

class _TransformTab extends StatelessWidget {
  const _TransformTab({required this.vm, required this.clip});
  final EditorViewModel vm;
  final dynamic clip;

  @override
  Widget build(BuildContext context) {
    final kf = vm.getInterpolatedTransform(clip as e.Clip);
    final isText = (clip as e.Clip).type == e.ClipType.text;
    final xyMin = isText ? -1.5 : -2.0;
    final xyMax = isText ? 1.5 : 2.0;
    return Column(
      children: [
        _SliderRow('Position X', kf.x.clamp(xyMin, xyMax), xyMin, xyMax,
            (v) => vm.upsertKeyframeAtPlayhead(x: v)),
        _SliderRow('Position Y', kf.y.clamp(xyMin, xyMax), xyMin, xyMax,
            (v) => vm.upsertKeyframeAtPlayhead(y: v)),
        _SliderRow('Scale', kf.scale, 0.1, 5.0,
            (v) => vm.upsertKeyframeAtPlayhead(scale: v)),
        _SliderRow('Rotation', kf.rotation, -180, 180,
            (v) => vm.upsertKeyframeAtPlayhead(rotation: v)),
        _SliderRow('Opacity', kf.opacity, 0.0, 1.0,
            (v) => vm.upsertKeyframeAtPlayhead(opacity: v)),
      ],
    );
  }
}

class _ColorTab extends StatelessWidget {
  const _ColorTab({required this.vm, required this.clip});
  final EditorViewModel vm;
  final dynamic clip;

  @override
  Widget build(BuildContext context) {
    final c = (clip as e.Clip).colorFilter;
    return Column(
      children: [
        _SliderRow('Brightness', c.brightness, -1.0, 1.0,
            (v) => vm.setColorFilter(clip.id, c.copyWith(brightness: v))),
        _SliderRow('Contrast', c.contrast, 0.0, 3.0,
            (v) => vm.setColorFilter(clip.id, c.copyWith(contrast: v))),
        _SliderRow('Saturation', c.saturation, 0.0, 3.0,
            (v) => vm.setColorFilter(clip.id, c.copyWith(saturation: v))),
        _SliderRow('Hue', c.hue, -180.0, 180.0,
            (v) => vm.setColorFilter(clip.id, c.copyWith(hue: v))),
        const SizedBox(height: 8),
        _LutPresets(vm: vm, clip: clip as e.Clip),
      ],
    );
  }
}

class _LutPresets extends StatelessWidget {
  const _LutPresets({required this.vm, required this.clip});
  final EditorViewModel vm;
  final e.Clip clip;

  static const presets = ['None', 'Cinematic', 'Vintage', 'B&W', 'Vivid', 'Muted'];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: presets.map((p) {
        final active = clip.colorFilter.lutPreset == (p == 'None' ? null : p);
        return ChoiceChip(
          label: Text(p, style: const TextStyle(fontSize: 11)),
          selected: active,
          onSelected: (_) => vm.setColorFilter(
            clip.id,
            clip.colorFilter.copyWith(lutPreset: p == 'None' ? null : p),
          ),
        );
      }).toList(),
    );
  }
}

class _AudioTab extends StatelessWidget {
  const _AudioTab({required this.vm, required this.clip});
  final EditorViewModel vm;
  final dynamic clip;

  @override
  Widget build(BuildContext context) {
    final c = clip as e.Clip;
    return Column(
      children: [
        _SliderRow('Volume', c.volume, 0.0, 2.0,
            (v) => vm.setClipVolume(c.id, v)),
      ],
    );
  }
}

class _EffectsTab extends StatelessWidget {
  const _EffectsTab({required this.vm, required this.clip});
  final EditorViewModel vm;
  final dynamic clip;

  @override
  Widget build(BuildContext context) {
    final c = clip as e.Clip;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Transition In',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        _TransitionPicker(
          selected: c.transitionIn.type,
          onChanged: (t) =>
              vm.setTransitionIn(c.id, c.transitionIn.copyWith(type: t)),
        ),
        const SizedBox(height: 12),
        const Text('Transition Out',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        _TransitionPicker(
          selected: c.transitionOut.type,
          onChanged: (t) =>
              vm.setTransitionOut(c.id, c.transitionOut.copyWith(type: t)),
        ),
      ],
    );
  }
}

class _TransitionPicker extends StatelessWidget {
  const _TransitionPicker({required this.selected, required this.onChanged});
  final e.TransitionType selected;
  final ValueChanged<e.TransitionType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      children: e.TransitionType.values.map((t) {
        return ChoiceChip(
          label: Text(t.name, style: const TextStyle(fontSize: 11)),
          selected: selected == t,
          onSelected: (_) {
            HapticFeedback.selectionClick();
            onChanged(t);
          },
        );
      }).toList(),
    );
  }
}

// ── Add-Text dialog (shared by ToolStrip and ImportBottomSheet) ──────────────

const _kTextColors = [
  ('#FFFFFF', Color(0xFFFFFFFF)),
  ('#000000', Color(0xFF000000)),
  ('#EF4444', Color(0xFFEF4444)),
  ('#F59E0B', Color(0xFFF59E0B)),
  ('#3B82F6', Color(0xFF3B82F6)),
  ('#10B981', Color(0xFF10B981)),
  ('#EC4899', Color(0xFFEC4899)),
  ('#8B5CF6', Color(0xFF8B5CF6)),
];

void _showAddTextDialog(BuildContext context, EditorViewModel vm) {
  final textCtrl = TextEditingController(text: 'Text');
  double fontSize = 48;
  String colorHex = '#FFFFFF';

  showDialog(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (ctx, setS) {
        final nav = Navigator.of(ctx);
        return AlertDialog(
          title: const Text('Add Text Overlay'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: textCtrl,
                autofocus: true,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Text',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Size', style: TextStyle(fontSize: 12)),
                  Expanded(
                    child: Slider(
                      value: fontSize,
                      min: 12,
                      max: 120,
                      divisions: 54,
                      onChanged: (v) {
                        HapticFeedback.selectionClick();
                        setS(() => fontSize = v);
                      },
                    ),
                  ),
                  SizedBox(
                    width: 28,
                    child: Text('${fontSize.round()}',
                        style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text('Color', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: _kTextColors.map(((String, Color) c) {
                  final selected = colorHex == c.$1;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setS(() => colorHex = c.$1);
                    },
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: c.$2,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected
                              ? AppColors.primary
                              : Colors.white30,
                          width: selected ? 2.5 : 1,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => nav.pop(), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                final t = textCtrl.text.trim();
                nav.pop();
                vm.addTextClip(
                  text: t.isEmpty ? 'Text' : t,
                  fontSize: fontSize,
                  colorHex: colorHex,
                );
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    ),
  );
}

// ── Import Bottom Sheet ──────────────────────────────────────────────────────

class _ImportBottomSheet extends StatelessWidget {
  const _ImportBottomSheet({required this.vm, required this.stableContext});
  final EditorViewModel vm;
  final BuildContext stableContext;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(LucideIcons.video),
            title: const Text('Video'),
            onTap: () async {
              Navigator.pop(context);
              await _pickVideo(stableContext);
            },
          ),
          ListTile(
            leading: const Icon(LucideIcons.image),
            title: const Text('Image'),
            onTap: () async {
              Navigator.pop(context);
              await _pickImage(stableContext);
            },
          ),
          ListTile(
            leading: const Icon(LucideIcons.music),
            title: const Text('Audio'),
            onTap: () async {
              Navigator.pop(context);
              await _pickAudio();
            },
          ),
          ListTile(
            leading: const Icon(LucideIcons.mic),
            title: const Text('Record Voiceover'),
            onTap: () {
              Navigator.pop(context);
              showDialog(
                context: stableContext,
                barrierDismissible: false,
                builder: (_) => _VoiceoverDialog(vm: vm),
              );
            },
          ),
          ListTile(
            leading: const Icon(LucideIcons.type),
            title: const Text('Add Text'),
            onTap: () {
              Navigator.pop(context);
              _showAddTextDialog(stableContext, vm);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _pickVideo(BuildContext context) async {
    await Permission.videos.request();
    final xfile = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (xfile == null) return;
    await vm.addVideoClip(xfile.path);
  }

  Future<void> _pickImage(BuildContext context) async {
    await Permission.photos.request();
    final xfile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (xfile == null) return;
    await vm.addImageClip(xfile.path);
  }

  Future<void> _pickAudio() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.first.path;
    if (path == null) return;
    await vm.addAudioClip(path);
  }
}

// ── Voiceover Dialog ─────────────────────────────────────────────────────────

class _VoiceoverDialog extends StatefulWidget {
  const _VoiceoverDialog({required this.vm});
  final EditorViewModel vm;

  @override
  State<_VoiceoverDialog> createState() => _VoiceoverDialogState();
}

class _VoiceoverDialogState extends State<_VoiceoverDialog> {
  final _recorder = AudioRecorder();
  bool _isRecording = false;
  int _seconds = 0;
  Timer? _timer;
  String? _filePath;

  @override
  void initState() {
    super.initState();
    _startRecording();
  }

  Future<void> _startRecording() async {
    final granted = await Permission.microphone.request().isGranted;
    if (!granted) {
      if (mounted) Navigator.pop(context);
      return;
    }
    final dir = await getApplicationDocumentsDirectory();
    _filePath =
        '${dir.path}/voiceover_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: _filePath!,
    );
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
    if (mounted) setState(() => _isRecording = true);
  }

  Future<void> _stopAndSave() async {
    HapticFeedback.mediumImpact();
    _timer?.cancel();
    await _recorder.stop();
    if (_filePath != null) {
      await widget.vm.addAudioClip(_filePath!);
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _cancel() async {
    _timer?.cancel();
    await _recorder.stop();
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mins = _seconds ~/ 60;
    final secs = _seconds % 60;
    return AlertDialog(
      title: const Text('Recording Voiceover'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.mic,
              color: _isRecording ? AppColors.error : AppColors.darkTextDisabled,
              size: 48),
          const SizedBox(height: 12),
          Text(
            '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}',
            style: const TextStyle(fontSize: 32, fontFamily: 'monospace'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: _cancel, child: const Text('Cancel')),
        TextButton(
          onPressed: _isRecording ? _stopAndSave : null,
          child: const Text('Stop & Save'),
        ),
      ],
    );
  }
}

// ── Slider Row ───────────────────────────────────────────────────────────────

class _SliderRow extends StatelessWidget {
  const _SliderRow(this.label, this.value, this.min, this.max, this.onChanged);
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(label, style: const TextStyle(fontSize: 12)),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(
            value.toStringAsFixed(2),
            style: const TextStyle(
                fontSize: 11, color: AppColors.darkTextSecondary),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}
