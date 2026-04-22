import 'dart:io';
import 'dart:math';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/statistics.dart';
import '../../core/utils/file_utils.dart';
import '../../domain/entities/clip.dart';
import '../../domain/entities/keyframe.dart';
import '../../domain/entities/project.dart';

class ExportConfig {
  const ExportConfig({
    this.width = 1920,
    this.height = 1080,
    this.fps = 30,
    this.crf = 23,
    this.preset = 'medium',
    this.audioBitrate = '192k',
  });

  final int width;
  final int height;
  final int fps;
  final int crf;
  final String preset;
  final String audioBitrate;

  static ExportConfig fromSettings({
    required String resolution,
    required int fps,
    required String quality,
    required String aspectRatio,
  }) {
    final dim = _resolutionDimensions(resolution, aspectRatio);
    final crf = _qualityCrf(quality);
    final preset = _qualityPreset(quality);
    return ExportConfig(
      width: dim.$1,
      height: dim.$2,
      fps: fps,
      crf: crf,
      preset: preset,
    );
  }

  static (int, int) _resolutionDimensions(String res, String ar) {
    final arVal = _arValue(ar);
    switch (res) {
      case '480p':
        return arVal >= 1 ? (854, 480) : (480, 854);
      case '720p':
        return arVal >= 1 ? (1280, 720) : (720, 1280);
      case '4K':
        return arVal >= 1 ? (3840, 2160) : (2160, 3840);
      default:
        return arVal >= 1 ? (1920, 1080) : (1080, 1920);
    }
  }

  static double _arValue(String ar) {
    switch (ar) {
      case '9:16': return 9 / 16;
      case '1:1':  return 1.0;
      case '4:3':  return 4 / 3;
      default:     return 16 / 9;
    }
  }

  static int _qualityCrf(String q) {
    switch (q) {
      case 'Low':   return 28;
      case 'High':  return 20;
      case 'Ultra': return 17;
      default:      return 23;
    }
  }

  static String _qualityPreset(String q) {
    switch (q) {
      case 'Ultra': return 'slow';
      case 'High':  return 'medium';
      case 'Low':   return 'fast';
      default:      return 'medium';
    }
  }
}

class ExportResult {
  const ExportResult({required this.outputPath, this.error});
  final String? outputPath;
  final String? error;
  bool get success => outputPath != null && error == null;
}

class VideoExportService {
  VideoExportService._();

  static int? _activeSessionId;

  // Public entry point — wraps _exportInternal in a top-level try/catch so
  // any native or Dart exception returns a clean error rather than crashing.
  static Future<ExportResult> export({
    required Project project,
    required ExportConfig config,
    void Function(double progress)? onProgress,
  }) async {
    try {
      return await _exportInternal(
          project: project, config: config, onProgress: onProgress);
    } catch (e) {
      return ExportResult(outputPath: null, error: 'Export error: $e');
    }
  }

  static Future<ExportResult> _exportInternal({
    required Project project,
    required ExportConfig config,
    void Function(double progress)? onProgress,
  }) async {
    // ── Gather clips ──────────────────────────────────────────────────────────

    // Track 0: video AND image clips in timeline order.
    // Both are concatenated sequentially to form the main video track.
    final track0Clips = project.clips
        .where((c) => c.trackIndex == 0 && c.filePath != null)
        .where((c) => File(c.filePath!).existsSync())
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    // Track 1: audio clips whose files actually exist.
    // A missing file would cause the AAC encoder to crash natively.
    final audioClips = project.clips
        .where((c) => c.trackIndex == 1 && c.filePath != null)
        .where((c) => File(c.filePath!).existsSync())
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    // Track 2, non-text: image overlays composited on top of the main track.
    final imageOverlays = project.clips
        .where((c) =>
            c.trackIndex == 2 &&
            c.type != ClipType.text &&
            c.filePath != null)
        .where((c) => File(c.filePath!).existsSync())
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    // Track 2, text type: rendered via FFmpeg drawtext.
    final textOverlays = project.clips
        .where((c) => c.trackIndex == 2 && c.type == ClipType.text)
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    if (track0Clips.isEmpty) {
      return const ExportResult(
          outputPath: null, error: 'No video/image clips in project.');
    }

    final dir = await FileUtils.getExportsDir();
    final outPath =
        '${dir.path}/export_${DateTime.now().millisecondsSinceEpoch}.mp4';

    final totalMs = project.durationMs > 0
        ? project.durationMs.toDouble()
        : track0Clips
            .map((c) => c.endTime.inMilliseconds)
            .reduce((a, b) => a > b ? a : b)
            .toDouble();

    // ── Build FFmpeg inputs and filter_complex ────────────────────────────────
    //
    // Input ordering in the final command:
    //   [0 .. track0Clips.length-1]           track-0 clips (video + image)
    //   [track0Clips.length .. +overlays-1]   track-2 image overlays
    //   [track0Clips.length+overlays .. end]  track-1 audio clips (audioArgs)
    //
    // Image clips use per-input flags: -loop 1 -t {dur} -i "file"
    // Video clips use:                 -i "file"
    // Both are added to `inputs` so their relative order is preserved.

    final inputs      = <String>[];   // flat token list joined with spaces
    final filterParts = <String>[];
    final segLabels   = <String>[];

    // ── Track-0 segments ──────────────────────────────────────────────────────
    for (int i = 0; i < track0Clips.length; i++) {
      final clip    = track0Clips[i];
      final segLbl  = '[seg$i]';
      final cf      = clip.colorFilter;
      final eqArgs  =
          'eq=brightness=${cf.brightness.toStringAsFixed(3)}:'
          'contrast=${cf.contrast.toStringAsFixed(3)}:'
          'saturation=${cf.saturation.toStringAsFixed(3)}';

      if (clip.type == ClipType.image) {
        // Images are looped for their timeline duration then converted to a
        // fixed-fps video segment matching the export dimensions.
        final clipDurSec =
            (clip.endTime - clip.startTime).inMilliseconds / 1000.0;
        inputs.addAll([
          '-loop', '1',
          '-t', clipDurSec.toStringAsFixed(3),
          '-i', '"${clip.filePath!}"',
        ]);
        filterParts.add(
          '[$i:v]'
          'scale=${config.width}:${config.height}:'
          'force_original_aspect_ratio=decrease,'
          'pad=${config.width}:${config.height}:(ow-iw)/2:(oh-ih)/2:black,'
          'setsar=1,'
          'fps=${config.fps},'
          '$eqArgs'
          '$segLbl',
        );
      } else {
        // Video clip: trim to [sourceIn, sourceOut], apply speed, scale, pad.
        final trimStart = clip.sourceIn.inMilliseconds / 1000.0;
        final trimEnd   = clip.sourceOut.inMilliseconds / 1000.0;
        final speedPts  = clip.speed != 1.0
            ? ',setpts=${(1.0 / clip.speed).toStringAsFixed(4)}*PTS'
            : '';
        inputs.addAll(['-i', '"${clip.filePath!}"']);
        filterParts.add(
          '[$i:v]'
          'trim=start=${trimStart.toStringAsFixed(3)}:'
          'end=${trimEnd.toStringAsFixed(3)},'
          'setpts=PTS-STARTPTS$speedPts,'
          'scale=${config.width}:${config.height}:'
          'force_original_aspect_ratio=decrease,'
          'pad=${config.width}:${config.height}:(ow-iw)/2:(oh-ih)/2:black,'
          'setsar=1,'
          'fps=${config.fps},'
          '$eqArgs'
          '$segLbl',
        );
      }
      segLabels.add(segLbl);
    }

    // Concatenate all track-0 segments into [vconcat].
    if (track0Clips.length == 1) {
      filterParts.add('[seg0]copy[vconcat]');
    } else {
      final joined = segLabels.join('');
      filterParts.add(
          '${joined}concat=n=${track0Clips.length}:v=1:a=0[vconcat]');
    }

    // ── Image overlays (track 2, non-text) ───────────────────────────────────
    String currentVideoLabel = '[vconcat]';
    int overlayInputIndex = track0Clips.length;

    for (int oi = 0; oi < imageOverlays.length; oi++) {
      final clip   = imageOverlays[oi];
      final outLbl = '[vov$oi]';

      inputs.addAll(['-i', '"${clip.filePath!}"']);

      final kf       = _effectiveKeyframe(clip);
      final startSec = clip.startTime.inMilliseconds / 1000.0;
      final endSec   = clip.endTime.inMilliseconds / 1000.0;

      final nomW = (config.width  * 0.25 * kf.scale).round().clamp(16, config.width);
      final nomH = (config.height * 0.25 * kf.scale).round().clamp(16, config.height);

      final xExpr = _buildPositionExpr(kf, clip, config.width,  isX: true,  nomSize: nomW);
      final yExpr = _buildPositionExpr(kf, clip, config.height, isX: false, nomSize: nomH);

      final rotDeg   = kf.rotation;
      final rotRad   = (rotDeg * pi / 180).toStringAsFixed(6);
      String imgFilter = '[$overlayInputIndex:v]'
          'scale=$nomW:$nomH:force_original_aspect_ratio=decrease,'
          'pad=$nomW:$nomH:(ow-iw)/2:(oh-ih)/2:black@0';
      if (rotDeg.abs() > 0.5) {
        imgFilter += ',rotate=$rotRad:fillcolor=none';
      }
      imgFilter += '[ovimg$oi]';
      filterParts.add(imgFilter);

      final opacity  = kf.opacity.clamp(0.0, 1.0);
      final blendStr = opacity < 0.999
          ? ':format=auto,colorchannelmixer=aa=$opacity'
          : '';
      filterParts.add(
        '$currentVideoLabel[ovimg$oi]overlay='
        "x='$xExpr':y='$yExpr':"
        "enable='between(t,$startSec,$endSec)'"
        "$blendStr$outLbl",
      );

      currentVideoLabel = outLbl;
      overlayInputIndex++;
    }

    // ── Text overlays (track 2, text type) via drawtext ──────────────────────
    for (int ti = 0; ti < textOverlays.length; ti++) {
      final clip = textOverlays[ti];
      final td   = clip.textData;
      if (td == null) continue;

      final outLbl   = '[vtxt$ti]';
      final kf       = _effectiveKeyframe(clip);
      final startSec = clip.startTime.inMilliseconds / 1000.0;
      final endSec   = clip.endTime.inMilliseconds / 1000.0;

      final safeText  = td.text.replaceAll("'", "\\'").replaceAll(':', '\\:');
      final hexColor  = td.colorHex.replaceAll('#', '');
      final fontSizePx = (td.fontSize * kf.scale).round().clamp(8, 400);

      final xOffset = (kf.x * config.width  / 2).toStringAsFixed(1);
      final yOffset = (kf.y * config.height / 2).toStringAsFixed(1);

      filterParts.add(
        '$currentVideoLabel'
        "drawtext=text='$safeText':"
        'fontsize=$fontSizePx:fontcolor=0x$hexColor:'
        "x='(w-tw)/2+$xOffset':y='(h-th)/2+$yOffset':"
        "enable='between(t,$startSec,$endSec)'"
        '$outLbl',
      );
      currentVideoLabel = outLbl;
    }

    // Final video label.
    filterParts.add('$currentVideoLabel copy [vout]');

    // ── Audio (track 1) ───────────────────────────────────────────────────────
    String audioArgs    = '';
    String audioMapping = '-an';
    final audioLabels   = <String>[];

    if (audioClips.isNotEmpty) {
      final audioInputs      = <String>[];
      final audioFilterParts = <String>[];

      for (int i = 0; i < audioClips.length; i++) {
        final clip      = audioClips[i];
        final ai        = overlayInputIndex + i;
        audioInputs.addAll(['-i', '"${clip.filePath!}"']);
        final trimStart = clip.sourceIn.inMilliseconds / 1000.0;
        final trimEnd   = clip.sourceOut.inMilliseconds / 1000.0;
        final delayMs   = clip.startTime.inMilliseconds;
        audioFilterParts.add(
          '[$ai:a]'
          'atrim=start=${trimStart.toStringAsFixed(3)}:'
          'end=${trimEnd.toStringAsFixed(3)},'
          'asetpts=PTS-STARTPTS,'
          'adelay=$delayMs|$delayMs,'
          'volume=${clip.volume.toStringAsFixed(3)}[a$i]',
        );
        audioLabels.add('[a$i]');
      }

      final aMix = audioLabels.join('');
      audioFilterParts.add(
          '${aMix}amix=inputs=${audioClips.length}:duration=longest[aout]');
      audioArgs    = audioInputs.join(' ');
      filterParts.add(audioFilterParts.join(';'));
      audioMapping =
          '-map [aout] -c:a aac -b:a ${config.audioBitrate}';
    }

    // ── Assemble and execute ──────────────────────────────────────────────────
    final filterComplex = filterParts.join(';');
    final inputArgs     = inputs.join(' ');

    final cmd =
        '$inputArgs $audioArgs '
        '-filter_complex "$filterComplex" '
        '-map [vout] '
        '$audioMapping '
        '-c:v libx264 -preset ${config.preset} -crf ${config.crf} '
        '-r ${config.fps} -pix_fmt yuv420p '
        '-movflags +faststart '
        '"$outPath"';

    FFmpegKitConfig.enableStatisticsCallback((Statistics stats) {
      if (totalMs > 0) {
        onProgress?.call((stats.getTime() / totalMs).clamp(0.0, 1.0));
      }
    });

    final session = await FFmpegKit.execute(cmd);
    _activeSessionId = session.getSessionId();
    final rc = await session.getReturnCode();
    FFmpegKitConfig.enableStatisticsCallback(null);

    if (ReturnCode.isSuccess(rc)) {
      return ExportResult(outputPath: outPath);
    } else {
      final logs = await session.getOutput();
      return ExportResult(
        outputPath: null,
        error: logs ?? 'Export failed with code ${rc?.getValue()}',
      );
    }
  }

  static Future<void> cancel() async {
    if (_activeSessionId != null) {
      await FFmpegKit.cancel(_activeSessionId!);
    } else {
      await FFmpegKit.cancel();
    }
  }

  static Future<int?> getVideoDurationMs(String path) async {
    try {
      final session = await FFprobeKit.getMediaInformation(path);
      final info    = session.getMediaInformation();
      final dur     = info?.getDuration();
      if (dur == null) return null;
      return (double.parse(dur) * 1000).round();
    } catch (_) {
      return null;
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  static Keyframe _effectiveKeyframe(Clip clip) {
    if (clip.keyframes.isEmpty) return const Keyframe(timeMs: 0);
    final sorted = List<Keyframe>.from(clip.keyframes)
      ..sort((a, b) => a.timeMs.compareTo(b.timeMs));
    return sorted.first;
  }

  static String _buildPositionExpr(
    Keyframe kf,
    Clip clip,
    int dimension, {
    required bool isX,
    required int nomSize,
  }) {
    if (clip.keyframes.length <= 1) {
      final norm = isX ? kf.x : kf.y;
      final px   = (dimension / 2 + norm * (dimension / 2) - nomSize / 2).round();
      return px.toString();
    }

    final sorted = List<Keyframe>.from(clip.keyframes)
      ..sort((a, b) => a.timeMs.compareTo(b.timeMs));

    final clipStartSec = clip.startTime.inMilliseconds / 1000.0;

    String buildSegment(int idx) {
      if (idx >= sorted.length - 1) {
        final kfLast = sorted.last;
        final norm   = isX ? kfLast.x : kfLast.y;
        final px     = (dimension / 2 + norm * (dimension / 2) - nomSize / 2).round();
        return px.toString();
      }
      final kf0   = sorted[idx];
      final kf1   = sorted[idx + 1];
      final t0    = clipStartSec + kf0.timeMs / 1000.0;
      final t1    = clipStartSec + kf1.timeMs / 1000.0;
      final norm0 = isX ? kf0.x : kf0.y;
      final norm1 = isX ? kf1.x : kf1.y;
      final px0   = (dimension / 2 + norm0 * (dimension / 2) - nomSize / 2).toStringAsFixed(1);
      final px1   = (dimension / 2 + norm1 * (dimension / 2) - nomSize / 2).toStringAsFixed(1);
      final span  = (t1 - t0).toStringAsFixed(6);
      final t0Str = t0.toStringAsFixed(3);
      final t1Str = t1.toStringAsFixed(3);
      final next  = buildSegment(idx + 1);
      return "if(lt(t,$t0Str),$px0,if(between(t,$t0Str,$t1Str),$px0+($px1-$px0)*(t-$t0Str)/$span,$next))";
    }

    return buildSegment(0);
  }
}
