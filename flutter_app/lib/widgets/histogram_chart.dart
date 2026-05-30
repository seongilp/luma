import 'package:flutter/material.dart' show Colors;
import 'package:flutter/widgets.dart';

import '../services/histogram.dart';

/// 히스토그램 그래프 (R/G/B 채널 곡선 채움).
class HistogramChart extends StatelessWidget {
  final String path;
  const HistogramChart({super.key, required this.path});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Histogram?>(
      future: computeHistogram(path),
      builder: (context, snap) {
        return Container(
          height: 90,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1E),
            borderRadius: BorderRadius.circular(6),
          ),
          child: snap.hasData && snap.data != null
              ? CustomPaint(painter: _HistPainter(snap.data!), size: Size.infinite)
              : const Center(
                  child: Text('—', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ),
        );
      },
    );
  }
}

class _HistPainter extends CustomPainter {
  final Histogram h;
  _HistPainter(this.h);

  @override
  void paint(Canvas canvas, Size size) {
    final maxV = [
      ...h.r,
      ...h.g,
      ...h.b,
    ].fold<int>(1, (m, v) => v > m ? v : m);

    void channel(List<int> bins, Color color) {
      final path = Path()..moveTo(0, size.height);
      for (var i = 0; i < 256; i++) {
        final x = size.width * i / 255;
        final y = size.height * (1 - bins[i] / maxV);
        path.lineTo(x, y);
      }
      path.lineTo(size.width, size.height);
      path.close();
      canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.45));
    }

    channel(h.r, Colors.red);
    channel(h.g, Colors.green);
    channel(h.b, Colors.blue);
  }

  @override
  bool shouldRepaint(_HistPainter old) => old.h != h;
}
