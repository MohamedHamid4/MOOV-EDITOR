import 'keyframe.dart';

enum ClipType { video, audio, text, image }

enum TransitionType { none, fade, dissolve, slideLeft, slideRight, wipe, zoom }

/// A segment of media on the timeline.
class Clip {
  const Clip({
    required this.id,
    required this.type,
    required this.trackIndex,
    required this.startTime,
    required this.duration,
    this.sourceIn = Duration.zero,
    Duration? sourceOut,
    this.filePath,
    this.thumbnailPath,
    this.speed = 1.0,
    this.volume = 1.0,
    this.fadeInMs = 0,
    this.fadeOutMs = 0,
    this.keyframes = const [],
    this.colorFilter = const ClipColorFilter(),
    this.textData,
    this.transitionIn = const ClipTransition(),
    this.transitionOut = const ClipTransition(),
    this.waveformData = const [],
  }) : sourceOut = sourceOut ?? duration;

  final String id;
  final ClipType type;
  final int trackIndex;

  /// Position on the project timeline.
  final Duration startTime;

  /// Rendered duration (may differ from source duration when speed ≠ 1).
  final Duration duration;

  /// Source trim start.
  final Duration sourceIn;

  /// Source trim end.
  final Duration sourceOut;

  final String? filePath;
  final String? thumbnailPath;

  final double speed;
  final double volume;
  final int fadeInMs;
  final int fadeOutMs;

  final List<Keyframe> keyframes;
  final ClipColorFilter colorFilter;
  final TextClipData? textData;
  final ClipTransition transitionIn;
  final ClipTransition transitionOut;

  /// Pre-computed waveform amplitude data (0-1 per bar).
  final List<double> waveformData;

  Duration get endTime => startTime + duration;

  Clip copyWith({
    String? id,
    ClipType? type,
    int? trackIndex,
    Duration? startTime,
    Duration? duration,
    Duration? sourceIn,
    Duration? sourceOut,
    String? filePath,
    String? thumbnailPath,
    double? speed,
    double? volume,
    int? fadeInMs,
    int? fadeOutMs,
    List<Keyframe>? keyframes,
    ClipColorFilter? colorFilter,
    TextClipData? textData,
    ClipTransition? transitionIn,
    ClipTransition? transitionOut,
    List<double>? waveformData,
  }) {
    return Clip(
      id: id ?? this.id,
      type: type ?? this.type,
      trackIndex: trackIndex ?? this.trackIndex,
      startTime: startTime ?? this.startTime,
      duration: duration ?? this.duration,
      sourceIn: sourceIn ?? this.sourceIn,
      sourceOut: sourceOut ?? this.sourceOut,
      filePath: filePath ?? this.filePath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      speed: speed ?? this.speed,
      volume: volume ?? this.volume,
      fadeInMs: fadeInMs ?? this.fadeInMs,
      fadeOutMs: fadeOutMs ?? this.fadeOutMs,
      keyframes: keyframes ?? this.keyframes,
      colorFilter: colorFilter ?? this.colorFilter,
      textData: textData ?? this.textData,
      transitionIn: transitionIn ?? this.transitionIn,
      transitionOut: transitionOut ?? this.transitionOut,
      waveformData: waveformData ?? this.waveformData,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'trackIndex': trackIndex,
        'startTimeMs': startTime.inMilliseconds,
        'durationMs': duration.inMilliseconds,
        'sourceInMs': sourceIn.inMilliseconds,
        'sourceOutMs': sourceOut.inMilliseconds,
        'filePath': filePath,
        'thumbnailPath': thumbnailPath,
        'speed': speed,
        'volume': volume,
        'fadeInMs': fadeInMs,
        'fadeOutMs': fadeOutMs,
        'keyframes': keyframes.map((k) => k.toJson()).toList(),
        'colorFilter': colorFilter.toJson(),
        'textData': textData?.toJson(),
        'transitionIn': transitionIn.toJson(),
        'transitionOut': transitionOut.toJson(),
        'waveformData': waveformData,
      };

  factory Clip.fromJson(Map<String, dynamic> json) => Clip(
        id: json['id'] as String,
        type: ClipType.values.firstWhere((e) => e.name == json['type']),
        trackIndex: json['trackIndex'] as int,
        startTime: Duration(milliseconds: json['startTimeMs'] as int),
        duration: Duration(milliseconds: json['durationMs'] as int),
        sourceIn: Duration(milliseconds: (json['sourceInMs'] as int?) ?? 0),
        sourceOut: Duration(milliseconds: (json['sourceOutMs'] as int?) ?? json['durationMs'] as int),
        filePath: json['filePath'] as String?,
        thumbnailPath: json['thumbnailPath'] as String?,
        speed: (json['speed'] as num?)?.toDouble() ?? 1.0,
        volume: (json['volume'] as num?)?.toDouble() ?? 1.0,
        fadeInMs: (json['fadeInMs'] as int?) ?? 0,
        fadeOutMs: (json['fadeOutMs'] as int?) ?? 0,
        keyframes: (json['keyframes'] as List<dynamic>?)
                ?.map((k) => Keyframe.fromJson(k as Map<String, dynamic>))
                .toList() ??
            [],
        colorFilter: json['colorFilter'] != null
            ? ClipColorFilter.fromJson(json['colorFilter'] as Map<String, dynamic>)
            : const ClipColorFilter(),
        textData: json['textData'] != null
            ? TextClipData.fromJson(json['textData'] as Map<String, dynamic>)
            : null,
        transitionIn: json['transitionIn'] != null
            ? ClipTransition.fromJson(json['transitionIn'] as Map<String, dynamic>)
            : const ClipTransition(),
        transitionOut: json['transitionOut'] != null
            ? ClipTransition.fromJson(json['transitionOut'] as Map<String, dynamic>)
            : const ClipTransition(),
        waveformData: (json['waveformData'] as List<dynamic>?)
                ?.map((v) => (v as num).toDouble())
                .toList() ??
            [],
      );
}

/// Color grading parameters for a clip.
class ClipColorFilter {
  const ClipColorFilter({
    this.brightness = 0.0,
    this.contrast = 1.0,
    this.saturation = 1.0,
    this.hue = 0.0,
    this.lutPreset,
  });

  final double brightness;
  final double contrast;
  final double saturation;
  final double hue;
  final String? lutPreset;

  ClipColorFilter copyWith({
    double? brightness,
    double? contrast,
    double? saturation,
    double? hue,
    String? lutPreset,
  }) {
    return ClipColorFilter(
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
      saturation: saturation ?? this.saturation,
      hue: hue ?? this.hue,
      lutPreset: lutPreset ?? this.lutPreset,
    );
  }

  Map<String, dynamic> toJson() => {
        'brightness': brightness,
        'contrast': contrast,
        'saturation': saturation,
        'hue': hue,
        'lutPreset': lutPreset,
      };

  factory ClipColorFilter.fromJson(Map<String, dynamic> json) => ClipColorFilter(
        brightness: (json['brightness'] as num?)?.toDouble() ?? 0.0,
        contrast: (json['contrast'] as num?)?.toDouble() ?? 1.0,
        saturation: (json['saturation'] as num?)?.toDouble() ?? 1.0,
        hue: (json['hue'] as num?)?.toDouble() ?? 0.0,
        lutPreset: json['lutPreset'] as String?,
      );
}

/// Text overlay clip data.
class TextClipData {
  const TextClipData({
    this.text = 'Text',
    this.fontFamily = 'Inter',
    this.fontSize = 32.0,
    this.colorHex = '#FFFFFF',
    this.strokeColorHex = '#000000',
    this.strokeWidth = 0.0,
    this.shadowBlur = 0.0,
    this.alignment = 'center',
  });

  final String text;
  final String fontFamily;
  final double fontSize;
  final String colorHex;
  final String strokeColorHex;
  final double strokeWidth;
  final double shadowBlur;
  final String alignment;

  TextClipData copyWith({
    String? text,
    String? fontFamily,
    double? fontSize,
    String? colorHex,
    String? strokeColorHex,
    double? strokeWidth,
    double? shadowBlur,
    String? alignment,
  }) {
    return TextClipData(
      text: text ?? this.text,
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      colorHex: colorHex ?? this.colorHex,
      strokeColorHex: strokeColorHex ?? this.strokeColorHex,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      shadowBlur: shadowBlur ?? this.shadowBlur,
      alignment: alignment ?? this.alignment,
    );
  }

  Map<String, dynamic> toJson() => {
        'text': text,
        'fontFamily': fontFamily,
        'fontSize': fontSize,
        'colorHex': colorHex,
        'strokeColorHex': strokeColorHex,
        'strokeWidth': strokeWidth,
        'shadowBlur': shadowBlur,
        'alignment': alignment,
      };

  factory TextClipData.fromJson(Map<String, dynamic> json) => TextClipData(
        text: json['text'] as String? ?? 'Text',
        fontFamily: json['fontFamily'] as String? ?? 'Inter',
        fontSize: (json['fontSize'] as num?)?.toDouble() ?? 32.0,
        colorHex: json['colorHex'] as String? ?? '#FFFFFF',
        strokeColorHex: json['strokeColorHex'] as String? ?? '#000000',
        strokeWidth: (json['strokeWidth'] as num?)?.toDouble() ?? 0.0,
        shadowBlur: (json['shadowBlur'] as num?)?.toDouble() ?? 0.0,
        alignment: json['alignment'] as String? ?? 'center',
      );
}

/// A transition applied to the in or out edge of a clip.
class ClipTransition {
  const ClipTransition({
    this.type = TransitionType.none,
    this.durationMs = 500,
  });

  final TransitionType type;
  final int durationMs;

  ClipTransition copyWith({TransitionType? type, int? durationMs}) {
    return ClipTransition(
      type: type ?? this.type,
      durationMs: durationMs ?? this.durationMs,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'durationMs': durationMs,
      };

  factory ClipTransition.fromJson(Map<String, dynamic> json) => ClipTransition(
        type: TransitionType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => TransitionType.none,
        ),
        durationMs: (json['durationMs'] as int?) ?? 500,
      );
}
