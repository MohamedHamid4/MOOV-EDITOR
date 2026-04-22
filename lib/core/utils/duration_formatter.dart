/// Formats durations as timecodes for display in the editor.
class DurationFormatter {
  DurationFormatter._();

  /// Returns `HH:MM:SS.ff` e.g. `00:01:23.45`
  static String formatTimecode(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final f = (d.inMilliseconds.remainder(1000) ~/ 10).toString().padLeft(2, '0');
    return '$h:$m:$s.$f';
  }

  /// Returns `M:SS` for compact timeline ruler labels.
  static String formatCompact(Duration d) {
    final m = d.inMinutes.toString().padLeft(1, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// Returns human-readable `Xm Ys` for display in project cards.
  static String formatHuman(Duration d) {
    if (d.inSeconds < 60) return '${d.inSeconds}s';
    return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
  }

  /// Parses seconds (double) to Duration.
  static Duration fromSeconds(double s) =>
      Duration(microseconds: (s * 1e6).round());
}
