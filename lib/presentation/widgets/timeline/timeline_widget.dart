import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../presentation/viewmodels/editor_viewmodel.dart';
import 'playhead_widget.dart';
import 'timeline_ruler.dart';
import 'track_widget.dart';

class TimelineWidget extends StatefulWidget {
  const TimelineWidget({super.key});

  @override
  State<TimelineWidget> createState() => _TimelineWidgetState();
}

class _TimelineWidgetState extends State<TimelineWidget> {
  final ScrollController _hScrollController = ScrollController();
  double _scrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _hScrollController.addListener(() {
      setState(() => _scrollOffset = _hScrollController.offset);
    });
  }

  @override
  void dispose() {
    _hScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<EditorViewModel>();
    final totalDuration = vm.totalDuration;
    final zoom = vm.zoom;

    final totalWidth = ((totalDuration.inMilliseconds / 1000.0) * zoom + 200)
        .clamp(MediaQuery.of(context).size.width, double.infinity);

    // Compute height from constants — no hard-coded magic number.
    const trackCount = 3;
    const totalHeight =
        AppConstants.rulerHeight + AppConstants.trackHeight * trackCount;

    return ColoredBox(
      color: AppColors.darkBackground,
      child: SizedBox(
        height: totalHeight,
        child: GestureDetector(
          onScaleUpdate: (d) {
            if (d.scale != 1.0) vm.setZoom(zoom * d.scale);
          },
          child: SingleChildScrollView(
            controller: _hScrollController,
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            child: SizedBox(
              width: totalWidth,
              height: totalHeight,
              child: Stack(
                children: [
                  Column(
                    children: [
                      TimelineRuler(
                        totalDuration: totalDuration,
                        zoom: zoom,
                        scrollOffset: _scrollOffset,
                      ),
                      TrackWidget(
                        trackIndex: 0,
                        clips: vm.mediaClips,
                        vm: vm,
                        totalWidth: totalWidth,
                      ),
                      TrackWidget(
                        trackIndex: 1,
                        clips: vm.audioClips,
                        vm: vm,
                        totalWidth: totalWidth,
                      ),
                      TrackWidget(
                        trackIndex: 2,
                        clips: vm.textClips,
                        vm: vm,
                        totalWidth: totalWidth,
                      ),
                    ],
                  ),

                  // Playhead overlay (spans ruler + all tracks)
                  PlayheadWidget(
                    position: vm.playheadPosition,
                    zoom: zoom,
                    totalHeight: totalHeight,
                    onDrag: (pos) => vm.setPlayheadPosition(pos),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
