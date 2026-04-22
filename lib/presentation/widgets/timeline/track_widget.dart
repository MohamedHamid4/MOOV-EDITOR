import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/clip.dart' as e;
import '../../../presentation/viewmodels/editor_viewmodel.dart';
import 'clip_widget.dart';

class TrackWidget extends StatelessWidget {
  const TrackWidget({
    super.key,
    required this.trackIndex,
    required this.clips,
    required this.vm,
    required this.totalWidth,
  });

  final int trackIndex;
  final List<e.Clip> clips;
  final EditorViewModel vm;
  final double totalWidth;

  // Track 0 = Media (blue), Track 1 = Audio (teal), Track 2 = Text (amber)
  static const List<Color> _trackColors = [
    AppColors.trackVideo,  // blue
    AppColors.trackAudio,  // teal
    AppColors.trackText,   // amber
  ];

  static const List<String> _trackLabels = ['Media', 'Audio', 'Text'];

  Color get _color => _trackColors[trackIndex.clamp(0, 2)];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppConstants.trackHeight,
      decoration: const BoxDecoration(
        color: AppColors.trackBackground,
        border: Border(
          bottom: BorderSide(color: AppColors.darkBorder, width: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Track label
          Container(
            width: 52,
            color: AppColors.darkSurface,
            alignment: Alignment.center,
            child: RotatedBox(
              quarterTurns: 3,
              child: Text(
                _trackLabels[trackIndex.clamp(0, 2)].toUpperCase(),
                style: TextStyle(
                  color: _color,
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),

          // Clip area
          Expanded(
            child: Stack(
              children: [
                for (final clip in clips) _buildClip(clip),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClip(e.Clip clip) {
    final left       = clip.startTime.inMilliseconds / 1000.0 * vm.zoom;
    final isConflict = vm.conflictingClipIds.contains(clip.id);

    return Positioned(
      left:   left,
      top:    0,
      bottom: 0,
      child: ClipWidget(
        key:        ValueKey(clip.id),
        clip:       clip,
        zoom:       vm.zoom,
        isSelected: vm.selectedClip?.id == clip.id,
        isConflict: isConflict,
        trackColor: _color,
        onTap:      () => vm.selectClip(clip.id),
        onDragUpdate: (newStart) =>
            vm.movingClip(clip.id, newStart, clip.trackIndex),
        onDragEnd:  () => vm.commitClipMove(clip.id),
        onTrimLeft:  (srcIn)  => vm.trimClip(clip.id, newSourceIn:  srcIn),
        onTrimRight: (srcOut) => vm.trimClip(clip.id, newSourceOut: srcOut),
        onKeyframeTap: (ms) => vm.setPlayheadPosition(
          clip.startTime + Duration(milliseconds: ms),
        ),
        onKeyframeLongPress: (ms) => vm.deleteKeyframe(clip.id, ms),
      ),
    );
  }
}
