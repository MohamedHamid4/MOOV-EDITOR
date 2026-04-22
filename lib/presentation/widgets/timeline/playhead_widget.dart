import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';

class PlayheadWidget extends StatelessWidget {
  const PlayheadWidget({
    super.key,
    required this.position,
    required this.zoom,
    required this.totalHeight,
    required this.onDrag,
  });

  final Duration position;
  final double zoom;
  final double totalHeight;
  final ValueChanged<Duration> onDrag;

  @override
  Widget build(BuildContext context) {
    final x = position.inMilliseconds / 1000.0 * zoom;
    return Positioned(
      left: x - AppConstants.playheadWidth / 2,
      top: 0,
      child: GestureDetector(
        onHorizontalDragUpdate: (d) {
          final newX = x + d.delta.dx;
          final newSec = newX / zoom;
          if (newSec >= 0) onDrag(Duration(milliseconds: (newSec * 1000).round()));
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle triangle at top
            CustomPaint(
              size: const Size(12, 8),
              painter: _PlayheadHandlePainter(),
            ),
            Container(
              width: AppConstants.playheadWidth,
              height: totalHeight - 8,
              color: AppColors.playhead,
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayheadHandlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.playhead;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}
