import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/duration_formatter.dart';
import '../../../domain/entities/clip.dart' as e;
import '../../../domain/entities/keyframe.dart';
import '../../../presentation/viewmodels/editor_viewmodel.dart';

// Track-2 text clips use a normalised coordinate system:
//   kf.x = 0, kf.y = 0  →  centre of preview
//   kf.x = ±1           →  right / left edge
//   kf.y = ±1           →  bottom / top edge
// screen_cx = previewW/2 + kf.x * previewW/2

const double _kHalfW  = 120.0;
const double _kHalfH  = 70.0;
const double _kHandleR = 9.0;
const double _kRotOff  = 40.0;

class VideoPreviewWidget extends StatefulWidget {
  const VideoPreviewWidget({super.key});

  @override
  State<VideoPreviewWidget> createState() => _VideoPreviewWidgetState();
}

class _VideoPreviewWidgetState extends State<VideoPreviewWidget> {
  // ── Controller state ───────────────────────────────────────────────────────
  VideoPlayerController? _controller;
  // Tracked by clip ID (null for image clips and gaps, which need no controller).
  String? _loadedClipId;
  bool _isLoadingController = false;
  // Prevents stale async results from committing after a newer load started.
  int _loadGeneration = 0;

  // ── Playback state ─────────────────────────────────────────────────────────
  // Single source of truth for whether playback is active. Decoupled from the
  // VideoPlayerController so it persists across clip transitions (video→image).
  bool _isPlaying = false;
  // Drives the playhead for image clips, gaps, and the brief window when a
  // video controller is loading. Fires at ~30 fps.
  Timer? _playheadTicker;

  // ── Transition guard ───────────────────────────────────────────────────────
  // Prevents the end-of-clip listener from firing the transition more than once
  // while the async controller swap is in progress.
  bool _handlingEnd = false;
  // Timestamp (ms) of the last throttled position debug log.
  int _lastPositionLogMs = -9999;

  @override
  void dispose() {
    _playheadTicker?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  // ── Clip lookup ────────────────────────────────────────────────────────────

  // Strict upper bound: playhead == endTime means the clip is DONE.
  e.Clip? _bgClipAt(EditorViewModel vm) => vm.mediaClips
      .where((c) =>
          c.startTime <= vm.playheadPosition && vm.playheadPosition < c.endTime)
      .firstOrNull;

  // ── Play / pause API ───────────────────────────────────────────────────────

  void _togglePlayPause() {
    if (_isPlaying) {
      _pauseAll();
    } else {
      setState(() => _isPlaying = true);
      _resumePlayback();
    }
  }

  void _pauseAll() {
    setState(() => _isPlaying = false);
    _controller?.pause();
    _playheadTicker?.cancel();
    _playheadTicker = null;
  }

  // Start or resume playback from the current playhead position.
  void _resumePlayback() {
    final vm = context.read<EditorViewModel>();
    final bgClip = _bgClipAt(vm);
    if (bgClip?.type == e.ClipType.video &&
        _controller?.value.isInitialized == true) {
      // Video clip with a ready controller — hand off to the controller.
      _controller!.play();
    } else {
      // Image clip, gap, or video controller still loading.
      // The ticker bridges to the next state; _ensureClipLoaded will auto-play
      // when the video controller becomes ready.
      _startPlayheadTicker();
    }
  }

  // Timer that advances the playhead at ~30 fps for non-video phases.
  void _startPlayheadTicker() {
    _playheadTicker?.cancel();
    String? prevTickerClipId = _bgClipAt(context.read<EditorViewModel>())?.id;
    _playheadTicker = Timer.periodic(const Duration(milliseconds: 33), (_) {
      if (!mounted) return;
      if (!_isPlaying) return;
      final vm = context.read<EditorViewModel>();

      // If a video controller just became ready, let it take over.
      final bgClip = _bgClipAt(vm);
      if (bgClip?.type == e.ClipType.video &&
          _controller?.value.isInitialized == true) {
        _playheadTicker?.cancel();
        _playheadTicker = null;
        if (!_controller!.value.isPlaying) _controller!.play();
        return;
      }

      // Log clip boundary crossings driven by the ticker.
      final curId = bgClip?.id;
      if (curId != prevTickerClipId) {
        debugPrint(
            'Clip ${prevTickerClipId ?? 'gap'} ended, advancing to ${curId ?? 'end'}');
        prevTickerClipId = curId;
      }

      // Advance playhead by one tick interval.
      final next =
          vm.playheadPosition + const Duration(milliseconds: 33);
      if (next >= vm.totalDuration) {
        vm.setPlayheadPosition(vm.totalDuration);
        _pauseAll();
      } else {
        vm.setPlayheadPosition(next);
      }
    });
  }

  // ── Controller management ──────────────────────────────────────────────────

  // Called from build() without await. Idempotent when the correct controller
  // is already alive. Forces a reload when _controller is null (killed by the
  // end-detection branch) even if the clip ID hasn't changed.
  //
  // [forceClipId]: when provided (end-of-clip transitions), the clip is looked
  // up by ID rather than by playhead position, avoiding the race where a
  // backward-synced playhead resolves to the wrong clip.
  Future<void> _ensureClipLoaded(e.Clip? clip, {String? forceClipId}) async {
    // When called from end-detection, resolve the target clip by explicit ID.
    if (forceClipId != null) {
      if (!mounted) return;
      final vm = context.read<EditorViewModel>();
      clip = vm.mediaClips.where((c) => c.id == forceClipId).firstOrNull;
      debugPrint('[LOAD] Force-loading specific clip $forceClipId'
          ' (type: ${clip?.type.name ?? 'not found'})');
    }

    final newId = (clip?.type == e.ClipType.video) ? clip?.id : null;

    // Skip only when the right controller is already alive and loaded.
    if (newId == _loadedClipId && _controller != null && !_isLoadingController) {
      return;
    }
    // No controller needed and none exists — nothing to do.
    if (newId == null && _loadedClipId == null && _controller == null) return;

    if (_isLoadingController) return;
    _isLoadingController = true;
    _lastPositionLogMs = -9999;
    final myGeneration = ++_loadGeneration;

    if (_controller == null && newId == _loadedClipId) {
      debugPrint('[FORCE] Controller is null, forcing reload of'
          ' ${newId ?? 'gap/image'}');
    } else {
      debugPrint('[Preview] _ensureClipLoaded:'
          ' ${_loadedClipId ?? 'gap'} → ${newId ?? 'gap/image'}');
    }

    // Release whatever controller wasn't already disposed by the listener.
    final prev = _controller;
    if (mounted) {
      setState(() {
        _controller = null;
        _loadedClipId = null;
      });
    } else {
      _controller = null;
      _loadedClipId = null;
    }
    await prev?.dispose();

    if (newId == null) {
      if (mounted) {
        setState(() => _isLoadingController = false);
        if (_isPlaying) _startPlayheadTicker();
      } else {
        _isLoadingController = false;
      }
      return;
    }

    // Video clip — initialise a new controller.
    final path = clip!.filePath!;
    final file = File(path);
    if (!file.existsSync()) {
      debugPrint('[Preview] file not found — $path');
      if (mounted) {
        setState(() => _isLoadingController = false);
      } else {
        _isLoadingController = false;
      }
      return;
    }

    final nc = VideoPlayerController.file(file);
    try {
      await nc.initialize();
      await nc.setLooping(false);
    } catch (err) {
      debugPrint('[Preview] init failed — $err');
      await nc.dispose();
      if (mounted && myGeneration == _loadGeneration) {
        setState(() => _isLoadingController = false);
      } else {
        _isLoadingController = false;
      }
      return;
    }

    if (!mounted || myGeneration != _loadGeneration) {
      await nc.dispose();
      _isLoadingController = false;
      return;
    }

    // Seek to the correct source-file position: sourceIn + intra-clip offset.
    final vm = context.read<EditorViewModel>();
    var intraClip = vm.playheadPosition - clip.startTime;
    if (intraClip < Duration.zero) intraClip = Duration.zero;
    if (intraClip > clip.duration) intraClip = clip.duration;
    final seekTarget = clip.sourceIn + intraClip;
    await nc.seekTo(seekTarget);
    debugPrint('[Preview] New clip loaded: ${clip.id},'
        ' seeking to ${seekTarget.inMilliseconds}ms'
        ' (sourceIn=${clip.sourceIn.inMilliseconds}ms'
        ' sourceOut=${clip.sourceOut.inMilliseconds}ms'
        ' fileDuration=${nc.value.duration.inMilliseconds}ms)');

    if (!mounted || myGeneration != _loadGeneration) {
      await nc.dispose();
      _isLoadingController = false;
      return;
    }

    // ── Position listener ────────────────────────────────────────────────────
    // Guards:
    //   • _handlingEnd — bail immediately once end-detection has fired;
    //     prevents any further logging or playhead sync from this dead clip.
    nc.addListener(() {
      if (!mounted || !nc.value.isInitialized) return;
      if (_handlingEnd) return; // This clip is done — ignore all further frames.

      final posMs = nc.value.position.inMilliseconds;
      final srcOutMs = clip!.sourceOut.inMilliseconds;
      final fileDurMs = nc.value.duration.inMilliseconds;

      // Throttled position log — once every 500 ms of source playback time.
      if (posMs - _lastPositionLogMs >= 500) {
        debugPrint('[Preview] Position: ${posMs}ms'
            ' / sourceOut: ${srcOutMs}ms'
            ' / fileDuration: ${fileDurMs}ms');
        _lastPositionLogMs = posMs;
      }

      if (nc.value.isPlaying) {
        // Sync global playhead: translate source position → timeline position.
        final timelinePos = clip.startTime + (nc.value.position - clip.sourceIn);
        context.read<EditorViewModel>().setPlayheadPosition(timelinePos);

        // End detection: compare against sourceOut (the user's trim-out point),
        // NOT nc.value.duration (the full source file length).
        if (posMs >= srcOutMs - 100) {
          _handlingEnd = true; // Block all further listener callbacks immediately.
          nc.pause();          // Stop decoding — synchronous.

          final vmNow = context.read<EditorViewModel>();
          final currentPlayheadMs = vmNow.playheadPosition.inMilliseconds;

          // Find the next clip by startTime — do this BEFORE the microtask so
          // the reference is captured before any state changes.
          final nextClip = vmNow.mediaClips
              .where((c) => c.startTime >= clip!.endTime)
              .firstOrNull;

          debugPrint('[END] DETECTED for clip ${clip.id}'
              ' at position ${posMs}ms'
              ' (currentPlayhead=${currentPlayheadMs}ms)');

          // Dispose the controller asynchronously. We cannot await inside a
          // synchronous listener — schedule on the next microtask so this
          // call frame fully unwinds before we dispose the controller that
          // owns this listener.
          Future.microtask(() async {
            if (!mounted) return;
            final oldId = clip!.id;
            final ctrl = _controller;
            setState(() {
              _controller = null;
              _loadedClipId = null;
            });
            await ctrl?.dispose();
            debugPrint('[KILL] Controller disposed for clip $oldId');

            if (!mounted) return;

            if (nextClip == null) {
              debugPrint('[END] No next clip, pausing');
              _pauseAll();
            } else {
              // Push playhead to the EXACT start of the next clip — always
              // forward, never back. Do NOT use clip.endTime ± offset because
              // position sync may have already moved the playhead past endTime.
              debugPrint('[PUSH] Pushing playhead from'
                  ' ${vmNow.playheadPosition.inMilliseconds}ms'
                  ' FORWARD to ${nextClip.startTime.inMilliseconds}ms');
              debugPrint('[NEXT] Next clip is ${nextClip.id},'
                  ' setting playhead to'
                  ' ${nextClip.startTime.inMilliseconds}ms');
              vmNow.setPlayheadPosition(nextClip.startTime);
              // Load by explicit ID — bypass the playhead-based lookup that
              // could resolve to the wrong clip if setPlayheadPosition hasn't
              // propagated yet.
              _ensureClipLoaded(null, forceClipId: nextClip.id);
              if (_isPlaying) _startPlayheadTicker();
            }
          });
        }
      }

      if (mounted) setState(() {});
    });

    setState(() {
      _controller = nc;
      _loadedClipId = newId;
      _isLoadingController = false;
    });

    if (_isPlaying) {
      _playheadTicker?.cancel();
      _playheadTicker = null;
      nc.play();
    }

    // New controller is live — clear the guard so this clip's listener can
    // detect its own end when the time comes.
    _handlingEnd = false;
    debugPrint('[LOADED] New controller ready for ${clip.id}, starting playback');
  }

  // ── Layout ─────────────────────────────────────────────────────────────────

  static double _arValue(String ar) {
    switch (ar) {
      case '9:16': return 9 / 16;
      case '1:1':  return 1.0;
      case '4:3':  return 4 / 3;
      default:     return 16 / 9;
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<EditorViewModel>();
    final bgClip = _bgClipAt(vm);

    // Trigger controller load/unload without awaiting — guarded internally.
    _ensureClipLoaded(bgClip);

    final arValue = _arValue(vm.project.aspectRatio);
    final ctrl = _controller;
    final isLoading = _isLoadingController ||
        (bgClip?.type == e.ClipType.video &&
            (ctrl == null || !ctrl.value.isInitialized));

    return Container(
      color: Colors.black,
      child: LayoutBuilder(builder: (_, constraints) {
        final availW = constraints.maxWidth;
        final availH = constraints.maxHeight;
        double pw, ph;
        if (availW / availH > arValue) {
          ph = availH;
          pw = ph * arValue;
        } else {
          pw = availW;
          ph = pw / arValue;
        }
        final ps = Size(pw, ph);

        return Center(
          child: SizedBox(
            width: pw,
            height: ph,
            child: ClipRect(
              child: Stack(
                children: [
                  // Background tap area: deselects text clip or toggles play.
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: () {
                        if (vm.selectedClip?.trackIndex == 2) {
                          vm.selectClip(null);
                        } else {
                          _togglePlayPause();
                        }
                      },
                      child: Container(color: Colors.transparent),
                    ),
                  ),

                  // Track 0: background media (video or image).
                  // IgnorePointer prevents the Container from absorbing taps
                  // that belong to the GestureDetector above.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: _BackgroundMedia(
                        controller: ctrl,
                        clip: bgClip,
                        vm: vm,
                      ),
                    ),
                  ),

                  // Track 2: text overlays.
                  ..._buildTextOverlays(vm, ps),

                  // Timecode overlay.
                  Positioned(
                    bottom: 6,
                    right: 8,
                    child: IgnorePointer(
                      child: _TimecodeDisplay(
                        current: vm.playheadPosition,
                        total: vm.totalDuration,
                      ),
                    ),
                  ),

                  // Loading spinner while controller initialises.
                  if (isLoading)
                    const IgnorePointer(
                      child: Center(
                        child: SizedBox(
                          width: 36,
                          height: 36,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white54,
                          ),
                        ),
                      ),
                    )
                  // Play / Pause indicator (hidden while playing, shown while paused).
                  else if (vm.selectedClip?.trackIndex != 2)
                    IgnorePointer(
                      child: Center(
                        child: AnimatedOpacity(
                          opacity: _isPlaying ? 0.0 : 1.0,
                          duration: const Duration(milliseconds: 200),
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  List<Widget> _buildTextOverlays(EditorViewModel vm, Size ps) {
    return vm.textClips
        .where((c) =>
            c.startTime <= vm.playheadPosition &&
            c.endTime > vm.playheadPosition)
        .map((clip) => _OverlayClipWidget(
              key: ValueKey(clip.id),
              clip: clip,
              vm: vm,
              previewSize: ps,
              isSelected: vm.selectedClip?.id == clip.id,
            ))
        .toList();
  }
}

// ── Background media (video or image on Track 0) ──────────────────────────────

class _BackgroundMedia extends StatelessWidget {
  const _BackgroundMedia({
    required this.controller,
    required this.clip,
    required this.vm,
  });

  final VideoPlayerController? controller;
  final e.Clip? clip;
  final EditorViewModel vm;

  @override
  Widget build(BuildContext context) {
    final clip = this.clip;

    if (clip == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Icon(
            Icons.movie_creation_outlined,
            color: AppColors.darkTextSecondary,
            size: 48,
          ),
        ),
      );
    }

    final kf = vm.getInterpolatedTransform(clip);
    final transform = Matrix4.translationValues(kf.x * 80.0, kf.y * 80.0, 0.0)
      ..multiply(Matrix4.diagonal3Values(kf.scale, kf.scale, 1.0))
      ..rotateZ(kf.rotation * pi / 180);

    // Image clip
    if (clip.type == e.ClipType.image && clip.filePath != null) {
      return Transform(
        alignment: Alignment.center,
        transform: transform,
        child: Opacity(
          opacity: kf.opacity.clamp(0.0, 1.0),
          child: SizedBox.expand(
            child: Image.file(
              File(clip.filePath!),
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, __, ___) => Container(
                color: Colors.black,
                child: const Center(
                  child: Icon(Icons.broken_image,
                      color: Colors.white54, size: 48),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Video clip — show placeholder until controller is ready.
    final c = controller;
    if (c == null || !c.value.isInitialized) {
      return const ColoredBox(color: Colors.black);
    }

    return AnimatedBuilder(
      animation: c,
      builder: (_, __) => Transform(
        alignment: Alignment.center,
        transform: transform,
        child: Opacity(
          opacity: kf.opacity.clamp(0.0, 1.0),
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: c.value.size.width,
              height: c.value.size.height,
              child: VideoPlayer(c),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Text overlay with interactive handles ─────────────────────────────────────

class _OverlayClipWidget extends StatefulWidget {
  const _OverlayClipWidget({
    super.key,
    required this.clip,
    required this.vm,
    required this.previewSize,
    required this.isSelected,
  });

  final e.Clip clip;
  final EditorViewModel vm;
  final Size previewSize;
  final bool isSelected;

  @override
  State<_OverlayClipWidget> createState() => _OverlayClipWidgetState();
}

class _OverlayClipWidgetState extends State<_OverlayClipWidget> {
  double _scaleBase = 1.0;
  double _cornerScaleBase = 1.0;
  Offset _cornerDragStart = Offset.zero;
  double _rotBase = 0.0;
  Offset _rotDragStart = Offset.zero;

  Keyframe get _kf => widget.vm.getInterpolatedTransform(widget.clip);

  Offset _toScreen(double lx, double ly, double rotRad) => Offset(
        lx * cos(rotRad) - ly * sin(rotRad),
        lx * sin(rotRad) + ly * cos(rotRad),
      );

  @override
  Widget build(BuildContext context) {
    final kf  = _kf;
    final ps  = widget.previewSize;
    final cx  = ps.width  / 2 + kf.x * ps.width  / 2;
    final cy  = ps.height / 2 + kf.y * ps.height / 2;
    final sc  = kf.scale;
    final rotRad = kf.rotation * pi / 180;

    final hw = _kHalfW * sc;
    final hh = _kHalfH * sc;

    final dTL  = _toScreen(-hw, -hh,            rotRad);
    final dTR  = _toScreen( hw, -hh,            rotRad);
    final dBL  = _toScreen(-hw,  hh,            rotRad);
    final dBR  = _toScreen( hw,  hh,            rotRad);
    final dRot = _toScreen(  0, -hh - _kRotOff, rotRad);

    final ptTL  = Offset(cx + dTL.dx,  cy + dTL.dy);
    final ptTR  = Offset(cx + dTR.dx,  cy + dTR.dy);
    final ptBL  = Offset(cx + dBL.dx,  cy + dBL.dy);
    final ptBR  = Offset(cx + dBR.dx,  cy + dBR.dy);
    final ptRot = Offset(cx + dRot.dx, cy + dRot.dy);

    final contentTransform = Matrix4.diagonal3Values(sc, sc, 1.0)..rotateZ(rotRad);

    return Stack(children: [
      // ── Text content ─────────────────────────────────────────────────────
      Positioned(
        left:   cx - _kHalfW,
        top:    cy - _kHalfH,
        width:  _kHalfW * 2,
        height: _kHalfH * 2,
        child: Transform(
          alignment: Alignment.center,
          transform: contentTransform,
          child: Opacity(
            opacity: kf.opacity.clamp(0.0, 1.0),
            child: _buildTextContent(kf),
          ),
        ),
      ),

      // ── Transparent gesture layer ─────────────────────────────────────────
      Positioned(
        left:   cx - _kHalfW,
        top:    cy - _kHalfH,
        width:  _kHalfW * 2,
        height: _kHalfH * 2,
        child: Transform(
          alignment: Alignment.center,
          transform: contentTransform,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => widget.vm.selectClip(widget.clip.id),
            onScaleStart: !widget.isSelected
                ? null
                : (d) { _scaleBase = kf.scale; },
            onScaleUpdate: !widget.isSelected
                ? null
                : (d) {
                    final currentKf =
                        widget.vm.getInterpolatedTransform(widget.clip);
                    if (d.pointerCount >= 2) {
                      final ns = (_scaleBase * d.scale).clamp(0.1, 5.0);
                      widget.vm.upsertKeyframeAtPlayhead(scale: ns);
                    } else {
                      final ldx = d.focalPointDelta.dx;
                      final ldy = d.focalPointDelta.dy;
                      final sdx = ldx * cos(rotRad) - ldy * sin(rotRad);
                      final sdy = ldx * sin(rotRad) + ldy * cos(rotRad);
                      final nx = (currentKf.x + sdx / (ps.width  / 2)).clamp(-1.8, 1.8);
                      final ny = (currentKf.y + sdy / (ps.height / 2)).clamp(-1.8, 1.8);
                      widget.vm.upsertKeyframeAtPlayhead(x: nx, y: ny);
                    }
                  },
            child: Container(color: Colors.transparent),
          ),
        ),
      ),

      // ── Selection handles ─────────────────────────────────────────────────
      if (widget.isSelected) ...[
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _SelectionBorderPainter(pts: [ptTL, ptTR, ptBR, ptBL]),
            ),
          ),
        ),
        _cornerHandle(ptTL, kf),
        _cornerHandle(ptTR, kf),
        _cornerHandle(ptBL, kf),
        _cornerHandle(ptBR, kf),
        _rotationHandle(ptRot, kf),

        // Delete button
        Positioned(
          left: ptTR.dx + 4,
          top:  ptTR.dy - _kHandleR * 3,
          child: GestureDetector(
            onTap: () => widget.vm.deleteClip(widget.clip.id),
            child: Container(
              width:  _kHandleR * 2,
              height: _kHandleR * 2,
              decoration: const BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 12, color: Colors.white),
            ),
          ),
        ),
      ],
    ]);
  }

  Widget _buildTextContent(Keyframe kf) {
    final clip = widget.clip;
    if (clip.textData == null) {
      return Container(
        color: AppColors.trackText.withValues(alpha: 0.2),
        child: const Center(
          child: Icon(Icons.text_fields, color: Colors.white54, size: 32),
        ),
      );
    }
    final td = clip.textData!;
    return Center(
      child: Text(
        td.text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: td.fontFamily,
          fontSize: td.fontSize,
          color: _parseColor(td.colorHex),
          shadows: td.shadowBlur > 0
              ? [Shadow(blurRadius: td.shadowBlur, color: Colors.black54)]
              : null,
        ),
      ),
    );
  }

  Widget _cornerHandle(Offset pt, Keyframe kf) {
    return Positioned(
      left: pt.dx - _kHandleR,
      top:  pt.dy - _kHandleR,
      child: GestureDetector(
        onPanStart: (d) {
          _cornerScaleBase = kf.scale;
          _cornerDragStart = d.globalPosition;
        },
        onPanUpdate: (d) {
          final delta = d.globalPosition - _cornerDragStart;
          final diag  = (delta.dx + delta.dy) / 120.0;
          final ns = (_cornerScaleBase + diag).clamp(0.1, 5.0);
          widget.vm.upsertKeyframeAtPlayhead(scale: ns);
        },
        child: Container(
          width:  _kHandleR * 2,
          height: _kHandleR * 2,
          decoration: BoxDecoration(
            color:  Colors.white,
            border: Border.all(color: AppColors.primary, width: 2),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  Widget _rotationHandle(Offset pt, Keyframe kf) {
    final cx = widget.previewSize.width  / 2 + kf.x * widget.previewSize.width  / 2;
    final cy = widget.previewSize.height / 2 + kf.y * widget.previewSize.height / 2;
    return Positioned(
      left: pt.dx - _kHandleR,
      top:  pt.dy - _kHandleR,
      child: GestureDetector(
        onPanStart: (d) {
          _rotBase       = kf.rotation;
          _rotDragStart  = d.globalPosition;
        },
        onPanUpdate: (d) {
          final cur        = d.globalPosition;
          final startAngle = atan2(_rotDragStart.dy - cy, _rotDragStart.dx - cx);
          final curAngle   = atan2(cur.dy - cy, cur.dx - cx);
          widget.vm.upsertKeyframeAtPlayhead(
              rotation: _rotBase + (curAngle - startAngle) * 180 / pi);
        },
        child: Container(
          width:  _kHandleR * 2,
          height: _kHandleR * 2,
          decoration: BoxDecoration(
            color:  AppColors.primary,
            shape:  BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.5),
          ),
          child: const Icon(Icons.rotate_right, size: 11, color: Colors.white),
        ),
      ),
    );
  }

  static Color _parseColor(String hex) {
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return Colors.white;
    }
  }
}

// ── Selection border painter ──────────────────────────────────────────────────

class _SelectionBorderPainter extends CustomPainter {
  const _SelectionBorderPainter({required this.pts});
  final List<Offset> pts; // [TL, TR, BR, BL]

  @override
  void paint(Canvas canvas, Size size) {
    if (pts.length < 4) return;
    final paint = Paint()
      ..color      = AppColors.primary
      ..strokeWidth = 1.5
      ..style       = PaintingStyle.stroke;
    canvas.drawPath(
      Path()
        ..moveTo(pts[0].dx, pts[0].dy)
        ..lineTo(pts[1].dx, pts[1].dy)
        ..lineTo(pts[2].dx, pts[2].dy)
        ..lineTo(pts[3].dx, pts[3].dy)
        ..close(),
      paint,
    );
  }

  @override
  bool shouldRepaint(_SelectionBorderPainter old) => old.pts != pts;
}

// ── Timecode display ──────────────────────────────────────────────────────────

class _TimecodeDisplay extends StatelessWidget {
  const _TimecodeDisplay({required this.current, required this.total});
  final Duration current;
  final Duration total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '${DurationFormatter.formatTimecode(current)} / ${DurationFormatter.formatTimecode(total)}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}
