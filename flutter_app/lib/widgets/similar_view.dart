import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart' show Colors;
import 'package:flutter/widgets.dart';
import 'package:macos_ui/macos_ui.dart';

import '../models/photo_item.dart';
import '../state/app_state.dart';
import 'photo_tile.dart';
import 'photo_viewer.dart';

/// 유사 사진 보기: 비슷한 사진을 묶음별로 보여준다. (연사·중복 정리용)
class SimilarView extends StatelessWidget {
  final AppState state;
  const SimilarView({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.analyzing) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('유사한 사진을 분석하는 중…',
                style: TextStyle(fontSize: 15)),
            const SizedBox(height: 14),
            SizedBox(
              width: 240,
              child: ProgressBar(value: state.analyzeProgress * 100),
            ),
            const SizedBox(height: 8),
            Text('${(state.analyzeProgress * 100).round()}%',
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      );
    }

    final groups = state.similarGroups;
    if (groups.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MacosIcon(CupertinoIcons.square_stack_3d_down_right,
                size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('비슷한 사진을 찾지 못했습니다',
                style: TextStyle(color: Colors.grey, fontSize: 15)),
            const SizedBox(height: 16),
            PushButton(
              controlSize: ControlSize.large,
              onPressed: state.analyzeSimilar,
              child: const Text('다시 분석'),
            ),
          ],
        ),
      );
    }

    return MacosScrollbar(
      child: ListView.builder(
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
                const MacosIcon(CupertinoIcons.square_stack_3d_down_right, size: 16),
                const SizedBox(width: 6),
                Text('유사 사진 ${items.length}장',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                const Text('· 베스트만 남기고 정리하세요',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
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
