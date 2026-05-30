import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../models/photo_item.dart';
import '../state/app_state.dart';
import 'analysis_overlay.dart';
import 'dialogs.dart';
import 'photo_tile.dart';
import 'photo_viewer.dart';
import 'scroll_area.dart';

/// 유사 사진 보기: 비슷한 사진을 묶음별로 보여준다. (연사·중복 정리용)
class SimilarView extends StatelessWidget {
  final AppState state;
  const SimilarView({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _modeBar(context),
        Expanded(child: _content()),
      ],
    );
  }

  /// 상단: AI/해시 모드 토글 + 다시 분석.
  Widget _modeBar(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          const Text('분석 방식', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(width: 8),
          DropdownButton<SimilarMode>(
            value: state.similarMode,
            items: SimilarMode.values
                .map((m) => DropdownMenuItem(value: m, child: Text(m.label)))
                .toList(),
            onChanged: state.analyzing
                ? null
                : (m) => m == null ? null : state.setSimilarMode(m),
          ),
          if (state.usedFallback && !state.analyzing) ...[
            const SizedBox(width: 10),
            const Text('· Vision 불가 → 해시 사용',
                style: TextStyle(fontSize: 11, color: Colors.orange)),
          ],
          const Spacer(),
          TextButton(
            onPressed: state.analyzing ? null : state.analyzeSimilar,
            child: const Text('다시 분석'),
          ),
        ],
      ),
    );
  }

  Widget _content() {
    if (state.analyzing) {
      return AnalysisOverlay(state: state);
    }

    final groups = state.similarGroups;
    if (groups.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(CupertinoIcons.square_stack_3d_down_right,
                size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('비슷한 사진을 찾지 못했습니다',
                style: TextStyle(color: Colors.grey, fontSize: 15)),
          ],
        ),
      );
    }

    return ScrollArea(
      builder: (controller) => ListView.builder(
        controller: controller,
        padding: const EdgeInsets.all(16),
        itemCount: groups.length,
        itemBuilder: (context, gi) => _Group(state: state, items: groups[gi]),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  final AppState state;
  final List<PhotoItem> items;
  const _Group({required this.state, required this.items});

  void _open(BuildContext context, int index) {
    Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black87,
      pageBuilder: (_, _, _) => PhotoViewer(
        state: state,
        paths: items.map((e) => e.path).toList(),
        initialIndex: index,
      ),
    ));
  }

  Future<void> _cleanup(BuildContext context) async {
    final ok = await confirm(context,
        title: '중복 정리',
        message: '이 묶음에서 가장 큰 1장만 남기고 ${items.length - 1}장을 휴지통으로 보낼까요?');
    if (ok) await state.keepBestInGroup(items);
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
                const Icon(CupertinoIcons.square_stack_3d_down_right, size: 16),
                const SizedBox(width: 6),
                Text('유사 사진 ${items.length}장',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(width: 10),
                TextButton(
                  onPressed: () => _cleanup(context),
                  child: const Text('1장만 남기고 정리'),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var i = 0; i < items.length; i++)
                SizedBox(
                  width: 150,
                  height: 150,
                  child: PhotoTile(
                    state: state,
                    item: items[i],
                    decodeWidth: 300,
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
