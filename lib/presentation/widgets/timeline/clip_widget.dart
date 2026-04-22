import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/clip.dart' as e;
import '../../../services/video/video_thumbnail_service.dart';

class ClipWidget extends StatelessWidget {
  const ClipWidget({
    super.key,
    required this.clip,
    required this.zoom,
    required this.isSelected,
    required this.trackColor,
    this.isConflict = false,
    required this.onTap,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onTrimLeft,
    required this.onTrimRight,
    required this.onKeyframeTap,
    required this.onKeyframeLongPress,
  });

  final e.Clip clip;
  final double zoom;
  final bool isSelected;
  final bool isConflict;
  final Color trackColor;
  final VoidCallback onTap;
  final ValueChanged<Duration> onDragUpdate;
  final VoidCallback onDragEnd;
  final ValueChanged<Duration> onTrimLeft;
  final ValueChanged<Duration> onTrimRight;
  final ValueChanged<int> onKeyframeTap;
  final ValueChanged<int> onKeyframeLongPress;

  double get _width => (clip.duration.inMilliseconds / 1000.0) * zoom;

  @override
  Widget build(BuildContext context) {
    final width = _width.clamp(4.0, double.infinity);
    return SizedBox(
      width: width,
      height: AppConstants.trackHeight,
      child: Stack(
        children: [
          // ── Clip body ───────────────────────────────────────────────────
          Positioned.fill(
            child: GestureDetector(
              onTap: onTap,
              onHorizontalDragUpdate: (d) {
                final deltaSec = d.delta.dx / zoom;
                final newStart = clip.startTime +
                    Duration(milliseconds: (deltaSec * 1000).round());
                onDragUpdate(Duration(
                    milliseconds: newStart.inMilliseconds.clamp(0, 3600000)));
              },
              onHorizontalDragEnd: (_) => onDragEnd(),
              child: Container(
                decoration: BoxDecoration(
                  color: trackColor.withValues(alpha: isConflict ? 0.35 : 0.85),
                  borderRadius: BorderRadius.circular(4),
                  border: isConflict
                      ? Border.all(color: AppColors.error, width: 2)
                      : isSelected
                          ? Border.all(color: AppColors.primary, width: 2)
                          : Border.all(
                              color: trackColor.withValues(alpha: 0.5), width: 1),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: _buildContent(),
                ),
              ),
            ),
          ),

          // ── Keyframe diamonds (selected only) ───────────────────────────
          if (isSelected) ..._buildKeyframeDiamonds(width),

          // ── Trim handles (selected only) ────────────────────────────────
          if (isSelected) ...[
            _TrimHandle(
              side: _TrimSide.left,
              onDragUpdate: (d) {
                final deltaSec = d.delta.dx / zoom;
                final newSrcIn = clip.sourceIn +
                    Duration(milliseconds: (deltaSec * 1000).round());
                if (newSrcIn >= Duration.zero && newSrcIn < clip.sourceOut) {
                  onTrimLeft(newSrcIn);
                }
              },
            ),
            _TrimHandle(
              side: _TrimSide.right,
              onDragUpdate: (d) {
                final deltaSec = d.delta.dx / zoom;
                final newSrcOut = clip.sourceOut +
                    Duration(milliseconds: (deltaSec * 1000).round());
                if (newSrcOut > clip.sourceIn) {
                  onTrimRight(newSrcOut);
                }
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (clip.type) {
      case e.ClipType.video:
        return _VideoClipContent(clip: clip);
      case e.ClipType.image:
        return _ImageClipContent(clip: clip);
      case e.ClipType.audio:
        return _AudioClipContent(clip: clip, trackColor: trackColor);
      case e.ClipType.text:
        return _TextClipContent(clip: clip);
    }
  }

  List<Widget> _buildKeyframeDiamonds(double totalWidth) {
    return clip.keyframes.map((kf) {
      final x = (kf.timeMs / 1000.0) * zoom - 6;
      return Positioned(
        left: x.clamp(0.0, totalWidth - 12),
        top: 2,
        child: GestureDetector(
          onTap: () => onKeyframeTap(kf.timeMs),
          onLongPress: () => onKeyframeLongPress(kf.timeMs),
          child: const _DiamondWidget(color: AppColors.keyframe),
        ),
      );
    }).toList();
  }
}

// ── Trim handle ────────────────────────────────────────────────────────────────

enum _TrimSide { left, right }

class _TrimHandle extends StatelessWidget {
  const _TrimHandle({required this.side, required this.onDragUpdate});
  final _TrimSide side;
  final ValueChanged<DragUpdateDetails> onDragUpdate;

  @override
  Widget build(BuildContext context) {
    final isLeft = side == _TrimSide.left;
    return Positioned(
      left:   isLeft ? 0 : null,
      right:  isLeft ? null : 0,
      top:    0,
      bottom: 0,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: onDragUpdate,
        child: Container(
          width: AppConstants.clipHandleWidth,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.35),
            borderRadius: isLeft
                ? const BorderRadius.only(
                    topLeft:    Radius.circular(3),
                    bottomLeft: Radius.circular(3))
                : const BorderRadius.only(
                    topRight:    Radius.circular(3),
                    bottomRight: Radius.circular(3)),
          ),
          child: const Icon(Icons.drag_indicator, size: 10, color: Colors.white70),
        ),
      ),
    );
  }
}

// ── Video clip — filmstrip ─────────────────────────────────────────────────────

class _VideoClipContent extends StatefulWidget {
  const _VideoClipContent({required this.clip});
  final e.Clip clip;

  @override
  State<_VideoClipContent> createState() => _VideoClipContentState();
}

class _VideoClipContentState extends State<_VideoClipContent> {
  // Shared cache: cacheKey → frames
  static final Map<String, List<Uint8List>> _cache = {};

  List<Uint8List>? _frames;

  String get _cacheKey =>
      '${widget.clip.filePath}_${widget.clip.duration.inMilliseconds}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_VideoClipContent old) {
    super.didUpdateWidget(old);
    if (old.clip.filePath != widget.clip.filePath ||
        old.clip.duration != widget.clip.duration) {
      setState(() => _frames = null);
      _load();
    }
  }

  Future<void> _load() async {
    final path = widget.clip.filePath;
    if (path == null) return;

    final key = _cacheKey;
    if (_cache.containsKey(key)) {
      if (mounted) setState(() => _frames = _cache[key]);
      return;
    }

    // One frame every ~2 seconds, capped at 8.
    final secs   = widget.clip.duration.inSeconds.clamp(1, 9999);
    final count  = ((secs / 2).ceil()).clamp(1, 8);
    final frames = await VideoThumbnailService.generateFilmstripData(
      videoPath:     path,
      videoDuration: widget.clip.duration,
      frameCount:    count,
    );
    _cache[key] = frames;
    if (mounted) setState(() => _frames = frames);
  }

  @override
  Widget build(BuildContext context) {
    final frames = _frames;
    if (frames == null || frames.isEmpty) {
      return const _Shimmer(color: AppColors.trackVideo);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: frames
          .map((bytes) => Expanded(
                child: Image.memory(
                  bytes,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                  gaplessPlayback: true,
                ),
              ))
          .toList(),
    );
  }
}

// ── Image clip — fills the clip width with the source image ───────────────────

class _ImageClipContent extends StatelessWidget {
  const _ImageClipContent({required this.clip});
  final e.Clip clip;

  @override
  Widget build(BuildContext context) {
    final path = clip.filePath;
    if (path == null) {
      return Container(
        color: AppColors.trackVideo.withValues(alpha: 0.4),
        child: const Center(
          child: Icon(Icons.image, color: Colors.white54, size: 24),
        ),
      );
    }
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, __, ___) => Container(
        color: AppColors.trackVideo.withValues(alpha: 0.4),
        child: const Center(
          child: Icon(Icons.broken_image, color: Colors.white54, size: 24),
        ),
      ),
    );
  }
}

// ── Audio clip — waveform ─────────────────────────────────────────────────────

class _AudioClipContent extends StatelessWidget {
  const _AudioClipContent({required this.clip, required this.trackColor});
  final e.Clip clip;
  final Color trackColor;

  @override
  Widget build(BuildContext context) {
    if (clip.waveformData.isEmpty) {
      return Container(
        color: AppColors.trackAudio.withValues(alpha: 0.3),
        alignment: Alignment.center,
        child: const Icon(Icons.audiotrack, color: Colors.white54, size: 16),
      );
    }
    return CustomPaint(
      painter: _WaveformPainter(data: clip.waveformData, color: trackColor),
    );
  }
}

// ── Text clip — shows text content on a coloured background ──────────────────

class _TextClipContent extends StatelessWidget {
  const _TextClipContent({required this.clip});
  final e.Clip clip;

  @override
  Widget build(BuildContext context) {
    final td = clip.textData;
    return Container(
      color: AppColors.trackText.withValues(alpha: 0.35),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          const Icon(Icons.title, color: Colors.white60, size: 14),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              td?.text ?? 'Text',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shimmer placeholder ────────────────────────────────────────────────────────

class _Shimmer extends StatefulWidget {
  const _Shimmer({required this.color});
  final Color color;

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.25, end: 0.55).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        color: widget.color.withValues(alpha: _anim.value),
      ),
    );
  }
}

// ── Waveform painter ──────────────────────────────────────────────────────────

class _WaveformPainter extends CustomPainter {
  const _WaveformPainter({required this.data, required this.color});
  final List<double> data;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    final barWidth = size.width / data.length;
    for (int i = 0; i < data.length; i++) {
      final h   = data[i] * size.height * 0.8;
      final x   = i * barWidth + barWidth / 2;
      final mid = size.height / 2;
      canvas.drawLine(Offset(x, mid - h / 2), Offset(x, mid + h / 2), paint);
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) => old.data != data;
}

// ── Keyframe diamond ──────────────────────────────────────────────────────────

class _DiamondWidget extends StatelessWidget {
  const _DiamondWidget({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: 0.785398,
      child: Container(width: 10, height: 10, color: color),
    );
  }
}
