import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/duration_formatter.dart';

class TimelineRuler extends StatelessWidget {
  const TimelineRuler({
    super.key,
    required this.totalDuration,
    required this.zoom,
    required this.scrollOffset,
  });

  final Duration totalDuration;
  final double zoom;
  final double scrollOffset;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppConstants.rulerHeight,
      child: CustomPaint(
        painter: _RulerPainter(
          totalDuration: totalDuration,
          zoom: zoom,
          scrollOffset: scrollOffset,
        ),
      ),
    );
  }
}

class _RulerPainter extends CustomPainter {
  _RulerPainter({
    required this.totalDuration,
    required this.zoom,
    required this.scrollOffset,
  });

  final Duration totalDuration;
  final double zoom;
  final double scrollOffset;

  @override
  void paint(Canvas canvas, Size size) {
    final tickPaint = Paint()
      ..color = AppColors.darkTextSecondary
      ..strokeWidth = 1;
    const textStyle = TextStyle(
      color: AppColors.darkTextSecondary,
      fontSize: 10,
    );

    final visibleSeconds = size.width / zoom;
    final startSec = scrollOffset / zoom;
    final endSec = startSec + visibleSeconds;

    // Major ticks every second; minor ticks every 0.5s
    for (double s = (startSec).floorToDouble(); s <= endSec + 1; s += 0.5) {
      final x = s * zoom - scrollOffset;
      if (x < 0 || x > size.width) continue;

      final isMajor = s == s.roundToDouble();
      final tickH = isMajor ? size.height * 0.6 : size.height * 0.35;
      canvas.drawLine(Offset(x, size.height - tickH), Offset(x, size.height), tickPaint);

      if (isMajor) {
        final label = DurationFormatter.formatCompact(
          Duration(milliseconds: (s * 1000).round()),
        );
        final tp = TextPainter(
          text: TextSpan(text: label, style: textStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x + 2, 2));
      }
    }
  }

  @override
  bool shouldRepaint(_RulerPainter old) =>
      old.zoom != zoom || old.scrollOffset != scrollOffset || old.totalDuration != totalDuration;
}
