import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../state/app_state.dart';
import 'scroll_area.dart';

const _weekdayLabels = ['일', '월', '화', '수', '목', '금', '토'];

class _Series {
  final String label;
  final Color color;
  final List<double> values;
  const _Series(this.label, this.color, this.values);
}

/// 통계: 요일별 '요일당 평균 사진 수'를 라인 차트로, 기간(이번 주·지난주·지난달·작년) 비교.
class StatsView extends StatefulWidget {
  final AppState state;
  const StatsView({super.key, required this.state});

  @override
  State<StatsView> createState() => _StatsViewState();
}

class _StatsViewState extends State<StatsView> {
  final Set<String> _hidden = {};

  static const _colors = [
    Color(0xFF6366F1), // 이번 주 - indigo
    Color(0xFFF59E0B), // 지난주 - amber
    Color(0xFF14B8A6), // 지난달 - teal
    Color(0xFF94A3B8), // 작년 - slate
  ];

  @override
  Widget build(BuildContext context) {
    final stats = widget.state.weekdayStats;
    final series = [
      for (var i = 0; i < stats.length; i++)
        _Series(stats[i].label, _colors[i % _colors.length], stats[i].values),
    ];
    final visible = series.where((s) => !_hidden.contains(s.label)).toList();

    return ScrollArea(
      builder: (controller) => SingleChildScrollView(
        controller: controller,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _card(
              context,
              icon: CupertinoIcons.calendar,
              title: '언제 (요일별)',
              hint: '· 요일당 평균 사진 수',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 14,
                    runSpacing: 8,
                    children: [for (final s in series) _legendChip(s)],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 260,
                    child: visible.isEmpty
                        ? const Center(
                            child: Text('표시할 기간을 선택하세요',
                                style: TextStyle(color: Colors.grey)))
                        : CustomPaint(
                            painter: _LineChartPainter(visible),
                            size: Size.infinite,
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _summary(series),
          ],
        ),
      ),
    );
  }

  Widget _legendChip(_Series s) {
    final off = _hidden.contains(s.label);
    return GestureDetector(
      onTap: () => setState(() {
        if (off) {
          _hidden.remove(s.label);
        } else {
          _hidden.add(s.label);
        }
      }),
      child: Opacity(
        opacity: off ? 0.4 : 1,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 14, height: 3, color: s.color),
            const SizedBox(width: 6),
            Text(s.label, style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }

  /// 기간별 총 평균 + 가장 활발한 요일 요약.
  Widget _summary(List<_Series> series) {
    return _card(
      context,
      icon: CupertinoIcons.chart_bar,
      title: '요약',
      child: Column(
        children: [
          for (final s in series)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Container(width: 10, height: 10,
                      decoration: BoxDecoration(color: s.color, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  SizedBox(width: 60, child: Text(s.label, style: const TextStyle(fontSize: 13))),
                  Expanded(
                    child: Text(
                      _peakText(s),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _peakText(_Series s) {
    var peak = 0;
    for (var i = 1; i < 7; i++) {
      if (s.values[i] > s.values[peak]) peak = i;
    }
    final total = s.values.fold<double>(0, (a, b) => a + b);
    if (total == 0) return '데이터 없음';
    return '가장 활발: ${_weekdayLabels[peak]}요일 (요일평균 ${s.values[peak].toStringAsFixed(1)}장)';
  }

  Widget _card(BuildContext context,
      {required IconData icon, required String title, String? hint, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).canvasColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Icon(icon, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                if (hint != null) ...[
                  const SizedBox(width: 8),
                  Text(hint, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ],
            ),
          ),
          Container(height: 1, color: Theme.of(context).dividerColor),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<_Series> series;
  _LineChartPainter(this.series);

  @override
  void paint(Canvas canvas, Size size) {
    const left = 40.0, right = 14.0, top = 10.0, bottom = 26.0;
    final pw = size.width - left - right;
    final ph = size.height - top - bottom;

    var maxY = 0.0;
    for (final s in series) {
      for (final v in s.values) {
        if (v > maxY) maxY = v;
      }
    }
    if (maxY <= 0) maxY = 1;
    maxY = _niceCeil(maxY);

    final axis = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1;
    final grid = Paint()
      ..color = const Color(0x22808080)
      ..strokeWidth = 1;

    double xAt(int i) => left + pw * (i / 6);
    double yAt(double v) => top + ph * (1 - v / maxY);

    // y 그리드 + 라벨 (0, 1/2, max)
    const steps = 4;
    for (var s = 0; s <= steps; s++) {
      final v = maxY * s / steps;
      final y = yAt(v);
      canvas.drawLine(Offset(left, y), Offset(size.width - right, y), grid);
      _text(canvas, v.toStringAsFixed(v >= 10 ? 0 : 1), Offset(left - 6, y),
          align: TextAlign.right, color: const Color(0xFF94A3B8), size: 10);
    }

    // x 라벨 (요일)
    for (var i = 0; i < 7; i++) {
      final weekend = i == 0 || i == 6;
      _text(canvas, _weekdayLabels[i], Offset(xAt(i), size.height - bottom + 6),
          align: TextAlign.center,
          color: weekend ? const Color(0xFFEF4444) : const Color(0xFF64748B),
          size: 12);
    }

    canvas.drawLine(Offset(left, top), Offset(left, top + ph), axis);

    // 각 시리즈 라인 + 점
    for (final ser in series) {
      final paint = Paint()
        ..color = ser.color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final path = Path();
      for (var i = 0; i < 7; i++) {
        final p = Offset(xAt(i), yAt(ser.values[i]));
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      canvas.drawPath(path, paint);
      final dot = Paint()..color = ser.color;
      final dotInner = Paint()..color = const Color(0xFFFFFFFF);
      for (var i = 0; i < 7; i++) {
        final p = Offset(xAt(i), yAt(ser.values[i]));
        canvas.drawCircle(p, 3.5, dot);
        canvas.drawCircle(p, 1.6, dotInner);
      }
    }
  }

  double _niceCeil(double v) {
    if (v <= 1) return 1;
    final mag = _pow10((v).floor().toString().length - 1);
    final n = (v / mag).ceil() * mag;
    return n.toDouble();
  }

  double _pow10(int e) {
    var r = 1.0;
    for (var i = 0; i < e; i++) {
      r *= 10;
    }
    return r;
  }

  void _text(Canvas canvas, String s, Offset at,
      {required TextAlign align, required Color color, required double size}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(color: color, fontSize: size)),
      textAlign: align,
      textDirection: TextDirection.ltr,
    )..layout();
    var dx = at.dx;
    if (align == TextAlign.center) dx -= tp.width / 2;
    if (align == TextAlign.right) dx -= tp.width;
    tp.paint(canvas, Offset(dx, at.dy));
  }

  @override
  bool shouldRepaint(_LineChartPainter old) => old.series != series;
}
