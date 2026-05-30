import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:macos_ui/macos_ui.dart';

import '../state/app_state.dart';

/// 좌측 사이드바: 스캔된 폴더 목록. 선택하면 우측 그리드가 해당 폴더로 바뀐다.
class FolderSidebar extends StatelessWidget {
  final AppState state;
  final ScrollController scrollController;

  const FolderSidebar({
    super.key,
    required this.state,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    if (state.folders.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          '열린 폴더가 없습니다',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      itemCount: state.folders.length,
      itemBuilder: (context, index) {
        final folder = state.folders[index];
        final selected = index == state.selectedIndex;
        return _FolderRow(
          name: folder.displayName,
          count: folder.count,
          selected: selected,
          onTap: () => state.selectFolder(index),
        );
      },
    );
  }
}

class _FolderRow extends StatelessWidget {
  final String name;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _FolderRow({
    required this.name,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = MacosTheme.of(context).primaryColor;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? accent : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            MacosIcon(
              CupertinoIcons.folder_fill,
              size: 16,
              color: selected ? Colors.white : accent,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: selected ? Colors.white : null,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                color: selected ? Colors.white70 : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
