import 'dart:io';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart' show Colors;
import 'package:flutter/widgets.dart';
import 'package:macos_ui/macos_ui.dart';

import '../state/app_state.dart';

/// 분석 중 화면: 현재 분석 중인 사진 + 스캔 애니메이션 + 진행률.
/// "전체 N장 중 i번째 · 무엇을(위치/유사도) 분석 중" 을 보여줘 기다리는 재미를 준다.
class AnalysisOverlay extends StatefulWidget {
  final AppState state;
  const AnalysisOverlay({super.key, required this.state});

  @override
  State<AnalysisOverlay> createState() => _AnalysisOverlayState();
}

class _AnalysisOverlayState extends State<AnalysisOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scan;

  static const _locationMsgs = [
    '장소를 맞춰보는 중…',
    '사진 배경을 살펴보는 중…',
    '지도에 점을 찍는 중…',
  ];
  static const _similarMsgs = [
    '닮은 순간을 찾는 중…',
    '같은 장면을 모으는 중…',
    '비슷한 컷을 추려내는 중…',
  ];

  @override
  void initState() {
    super.initState();
    _scan = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat();
  }

  @override
  void dispose() {
    _scan.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final isLocation = s.progressPhase.contains('위치');
    final accent = isLocation ? Colors.blue : Colors.purpleAccent;
    final msgs = isLocation ? _locationMsgs : _similarMsgs;
    final msg = s.progressTotal == 0
        ? '준비 중…'
        : msgs[(s.progressIndex ~/ 3) % msgs.length];

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 분석 단계
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              MacosIcon(
                isLocation
                    ? CupertinoIcons.map_pin_ellipse
                    : CupertinoIcons.sparkles,
                size: 18,
                color: accent,
              ),
              const SizedBox(width: 6),
              Text(s.progressPhase.isEmpty ? '분석 중' : s.progressPhase,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 18),

          // 현재 분석 중인 사진 + 스캔 라인
          _scanThumb(s.progressPath, accent),
          const SizedBox(height: 16),

          // 전체 N장 중 i번째
          Text(
            s.progressTotal == 0
                ? ''
                : '전체 ${s.progressTotal}장 중 ${s.progressIndex}번째',
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 4),
          if (s.progressPath != null)
            Text(
              _basename(s.progressPath!),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          const SizedBox(height: 14),

          // 진행 바 + %
          SizedBox(
            width: 260,
            child: ProgressBar(value: s.progressFraction * 100),
          ),
          const SizedBox(height: 6),
          Text('${(s.progressFraction * 100).round()}%   ·   $msg',
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _scanThumb(String? path, Color accent) {
    const size = 180.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (path != null)
              Image.file(
                File(path),
                fit: BoxFit.cover,
                cacheWidth: 360,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => Container(color: const Color(0xFF2A2A30)),
              )
            else
              Container(color: const Color(0xFF2A2A30)),
            // 스캔 라인
            AnimatedBuilder(
              animation: _scan,
              builder: (context, _) {
                return Align(
                  alignment: Alignment(0, _scan.value * 2 - 1),
                  child: Container(
                    height: 2.5,
                    decoration: BoxDecoration(
                      color: accent,
                      boxShadow: [BoxShadow(color: accent, blurRadius: 10, spreadRadius: 1)],
                    ),
                  ),
                );
              },
            ),
            // 테두리 글로우
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: accent.withValues(alpha: 0.6), width: 2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _basename(String path) {
    final i = path.lastIndexOf('/');
    return i < 0 ? path : path.substring(i + 1);
  }
}
