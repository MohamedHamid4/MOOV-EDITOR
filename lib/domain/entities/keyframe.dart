enum EasingCurve { linear, easeIn, easeOut, easeInOut }

/// Stores transform values at a specific time within a clip.
class Keyframe {
  const Keyframe({
    required this.timeMs,
    this.x = 0.0,
    this.y = 0.0,
    this.scale = 1.0,
    this.rotation = 0.0,
    this.opacity = 1.0,
    this.easing = EasingCurve.linear,
  });

  final int timeMs;
  final double x;
  final double y;
  final double scale;
  final double rotation;
  final double opacity;
  final EasingCurve easing;

  Keyframe copyWith({
    int? timeMs,
    double? x,
    double? y,
    double? scale,
    double? rotation,
    double? opacity,
    EasingCurve? easing,
  }) {
    return Keyframe(
      timeMs: timeMs ?? this.timeMs,
      x: x ?? this.x,
      y: y ?? this.y,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
      opacity: opacity ?? this.opacity,
      easing: easing ?? this.easing,
    );
  }

  Map<String, dynamic> toJson() => {
        'timeMs': timeMs,
        'x': x,
        'y': y,
        'scale': scale,
        'rotation': rotation,
        'opacity': opacity,
        'easing': easing.name,
      };

  factory Keyframe.fromJson(Map<String, dynamic> json) => Keyframe(
        timeMs: json['timeMs'] as int,
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        scale: (json['scale'] as num).toDouble(),
        rotation: (json['rotation'] as num).toDouble(),
        opacity: (json['opacity'] as num).toDouble(),
        easing: EasingCurve.values.firstWhere(
          (e) => e.name == json['easing'],
          orElse: () => EasingCurve.linear,
        ),
      );
}

/// Interpolates between two keyframes at a given [t] in [0, 1].
class KeyframeInterpolator {
  KeyframeInterpolator._();

  static double _applyEasing(double t, EasingCurve curve) {
    switch (curve) {
      case EasingCurve.linear:
        return t;
      case EasingCurve.easeIn:
        return t * t;
      case EasingCurve.easeOut:
        return t * (2 - t);
      case EasingCurve.easeInOut:
        return t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t;
    }
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  /// Finds and interpolates the active transform at [localTimeMs] within a clip's keyframe list.
  static Keyframe interpolateAt({
    required List<Keyframe> keyframes,
    required int localTimeMs,
  }) {
    if (keyframes.isEmpty) return const Keyframe(timeMs: 0);

    final sorted = List<Keyframe>.from(keyframes)
      ..sort((a, b) => a.timeMs.compareTo(b.timeMs));

    if (localTimeMs <= sorted.first.timeMs) return sorted.first;
    if (localTimeMs >= sorted.last.timeMs) return sorted.last;

    Keyframe prev = sorted.first;
    Keyframe next = sorted.last;
    for (int i = 0; i < sorted.length - 1; i++) {
      if (sorted[i].timeMs <= localTimeMs && sorted[i + 1].timeMs >= localTimeMs) {
        prev = sorted[i];
        next = sorted[i + 1];
        break;
      }
    }

    final span = next.timeMs - prev.timeMs;
    if (span == 0) return prev;
    final rawT = (localTimeMs - prev.timeMs) / span;
    final t = _applyEasing(rawT, prev.easing);

    return Keyframe(
      timeMs: localTimeMs,
      x: _lerp(prev.x, next.x, t),
      y: _lerp(prev.y, next.y, t),
      scale: _lerp(prev.scale, next.scale, t),
      rotation: _lerp(prev.rotation, next.rotation, t),
      opacity: _lerp(prev.opacity, next.opacity, t),
    );
  }
}
