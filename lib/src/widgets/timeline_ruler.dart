import 'package:flutter/material.dart';

class TimelineRuler extends StatelessWidget {
  const TimelineRuler({
    super.key,
    required this.width,
    required this.durationMs,
    required this.positionMs,
    required this.pixelsPerSecond,
    required this.onSeek,
  });

  final double width;
  final int durationMs;
  final int positionMs;
  final double pixelsPerSecond;
  final ValueChanged<double> onSeek;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (TapDownDetails details) => _seek(details.localPosition.dx),
      child: SizedBox(
        width: width,
        height: 30,
        child: CustomPaint(
          painter: _TimelineRulerPainter(
            durationMs: durationMs,
            positionMs: positionMs,
            pixelsPerSecond: pixelsPerSecond,
          ),
        ),
      ),
    );
  }

  void _seek(double dx) {
    if (width <= 0) {
      return;
    }
    onSeek((dx / width).clamp(0, 1));
  }
}

class _TimelineRulerPainter extends CustomPainter {
  const _TimelineRulerPainter({
    required this.durationMs,
    required this.positionMs,
    required this.pixelsPerSecond,
  });

  final int durationMs;
  final int positionMs;
  final double pixelsPerSecond;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect bounds = Offset.zero & size;
    canvas.drawRect(bounds, Paint()..color = const Color(0xFF050608));

    final double totalSeconds = durationMs / 1000;
    final _RulerStep step = _stepForPixelsPerSecond(pixelsPerSecond);
    final double majorStep = step.major;
    final double minorStep = step.minor;
    final Paint majorPaint = Paint()
      ..color = const Color(0xFFDDE7F2)
      ..strokeWidth = 1.2;
    final Paint minorPaint = Paint()
      ..color = const Color(0xFF5C6570)
      ..strokeWidth = 0.9;
    final TextPainter textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    for (
      double second = 0;
      second <= totalSeconds + minorStep;
      second += minorStep
    ) {
      final double x = second * pixelsPerSecond;
      final bool isMajor =
          ((second / majorStep) - (second / majorStep).round()).abs() < 0.0001;
      final double tickHeight = isMajor ? 15 : 8;
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x, size.height - tickHeight),
        isMajor ? majorPaint : minorPaint,
      );

      if (isMajor) {
        textPainter.text = TextSpan(
          text: _formatLabel(Duration(milliseconds: (second * 1000).round())),
          style: const TextStyle(
            color: Color(0xFFE7EEF6),
            fontSize: 8.5,
            fontWeight: FontWeight.w800,
          ),
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(x + 2, 2));
      }
    }

    final double playheadX = (positionMs / 1000) * pixelsPerSecond;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, playheadX.clamp(0, size.width), size.height),
      Paint()..color = const Color(0x1111C9FF),
    );
    canvas.drawLine(
      Offset(0, size.height - 0.5),
      Offset(size.width, size.height - 0.5),
      Paint()
        ..color = const Color(0xFF242831)
        ..strokeWidth = 0.8,
    );
  }

  @override
  bool shouldRepaint(covariant _TimelineRulerPainter oldDelegate) {
    return oldDelegate.durationMs != durationMs ||
        oldDelegate.positionMs != positionMs ||
        oldDelegate.pixelsPerSecond != pixelsPerSecond;
  }

  String _formatLabel(Duration duration) {
    final String minutes = duration.inMinutes
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    final String seconds = duration.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    if (pixelsPerSecond >= 260) {
      final String milliseconds = duration.inMilliseconds
          .remainder(1000)
          .toString()
          .padLeft(3, '0');
      return '$minutes:$seconds.$milliseconds';
    }
    if (pixelsPerSecond >= 120) {
      final String tenths = (duration.inMilliseconds.remainder(1000) ~/ 100)
          .toString();
      return '$minutes:$seconds.$tenths';
    }
    if (duration.inHours > 0) {
      return '${duration.inHours}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }
}

class _RulerStep {
  const _RulerStep({required this.major, required this.minor});

  final double major;
  final double minor;
}

_RulerStep _stepForPixelsPerSecond(double pixelsPerSecond) {
  if (pixelsPerSecond >= 1200) {
    return const _RulerStep(major: 0.1, minor: 0.01);
  }
  if (pixelsPerSecond >= 600) {
    return const _RulerStep(major: 0.25, minor: 0.05);
  }
  if (pixelsPerSecond >= 260) {
    return const _RulerStep(major: 0.5, minor: 0.1);
  }
  if (pixelsPerSecond >= 120) {
    return const _RulerStep(major: 1, minor: 0.5);
  }
  if (pixelsPerSecond >= 72) {
    return const _RulerStep(major: 2, minor: 1);
  }
  if (pixelsPerSecond >= 36) {
    return const _RulerStep(major: 5, minor: 1);
  }
  if (pixelsPerSecond >= 18) {
    return const _RulerStep(major: 10, minor: 2);
  }
  if (pixelsPerSecond >= 9) {
    return const _RulerStep(major: 15, minor: 5);
  }
  return const _RulerStep(major: 30, minor: 10);
}
