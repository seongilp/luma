import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';

import '../state/app_state.dart';
import 'photo_tile.dart';
import 'photo_viewer.dart';

/// 우측 메인: 선택 폴더/보기의 썸네일 그리드.
class PhotoGrid extends StatelessWidget {
  final AppState state;
  const PhotoGrid({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final items = state.visibleItems;
    if (items.isEmpty) {
      return const Center(
        child: Text('표시할 사진이 없습니다', style: TextStyle(color: Colors.grey)),
      );
    }

    return MacosScrollbar(
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: state.clearSelection,
        child: GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: state.thumbSize,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) => PhotoTile(
            state: state,
            item: items[index],
            decodeWidth: state.thumbSize * 2,
            onOpen: () => _openViewer(context, index),
          ),
        ),
      ),
    );
  }

  void _openViewer(BuildContext context, int index) {
    Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black87,
      pageBuilder: (_, _, _) => PhotoViewer(
        state: state,
        paths: state.visibleItems.map((e) => e.path).toList(),
        initialIndex: index,
      ),
    ));
  }
}
