import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart' show Colors;
import 'package:flutter/widgets.dart';
import 'package:macos_ui/macos_ui.dart';

import '../state/app_state.dart';
import 'analysis_overlay.dart';
import 'photo_tile.dart';
import 'photo_viewer.dart';

const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

/// 날짜별 보기: 촬영일(없으면 파일 날짜) 기준 하루 단위 섹션.
class DateView extends StatelessWidget {
  final AppState state;
  const DateView({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.analyzing) return AnalysisOverlay(state: state);

    final sections = state.dateSections;
    if (sections.isEmpty) {
      return const Center(
        child: Text('표시할 사진이 없습니다', style: TextStyle(color: Colors.grey)),
      );
    }

    return MacosScrollbar(
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: sections.length,
        itemBuilder: (context, i) => _Section(state: state, section: sections[i]),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final AppState state;
  final DateSection section;
  const _Section({required this.state, required this.section});

  String get _title {
    final d = section.day;
    final wd = _weekdays[(d.weekday - 1) % 7];
    return '${d.year}년 ${d.month}월 ${d.day}일 ($wd)';
  }

  void _open(BuildContext context, int index) {
    Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black87,
      pageBuilder: (_, _, _) => PhotoViewer(
        state: state,
        paths: section.items.map((e) => e.path).toList(),
        initialIndex: index,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 2),
            child: Row(
              children: [
                const MacosIcon(CupertinoIcons.calendar, size: 15),
                const SizedBox(width: 6),
                Text(_title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                Text('${section.items.length}장',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var i = 0; i < section.items.length; i++)
                SizedBox(
                  width: 140,
                  height: 140,
                  child: PhotoTile(
                    state: state,
                    item: section.items[i],
                    decodeWidth: 280,
                    onOpen: () => _open(context, i),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
