import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:macos_ui/macos_ui.dart';

import '../models/folder_node.dart';
import '../state/app_state.dart';

/// 좌측 사이드바: 상단 `보관함`(스마트 보기) + 하단 `폴더` 디렉토리 트리.
class FolderSidebar extends StatefulWidget {
  final AppState state;
  final ScrollController scrollController;

  const FolderSidebar({
    super.key,
    required this.state,
    required this.scrollController,
  });

  @override
  State<FolderSidebar> createState() => _FolderSidebarState();
}

class _FolderSidebarState extends State<FolderSidebar> {
  final Set<String> _expanded = {};
  String? _treeRoot;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    if (state.root == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('폴더를 열어 시작하세요',
            style: TextStyle(color: Colors.grey, fontSize: 13)),
      );
    }

    final tree = state.folderTree;
    // 루트가 바뀌면 루트 노드를 기본 펼침
    if (tree.isNotEmpty && _treeRoot != tree.first.path) {
      _treeRoot = tree.first.path;
      _expanded
        ..clear()
        ..add(tree.first.path);
    }

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      children: [
        const _SectionHeader('보관함'),
        _SidebarRow(
          icon: CupertinoIcons.photo_on_rectangle,
          label: '모든 사진',
          count: state.allCount,
          selected: state.view == LibraryView.all,
          onTap: state.showAllPhotos,
        ),
        _SidebarRow(
          icon: CupertinoIcons.heart_fill,
          iconColor: Colors.redAccent,
          label: '즐겨찾기',
          count: state.favoriteCount,
          selected: state.view == LibraryView.favorites,
          onTap: state.showFavorites,
        ),
        _SidebarRow(
          icon: CupertinoIcons.square_stack_3d_down_right,
          label: '유사 사진',
          count: state.similarPhotoCount,
          showCount: state.similarGroups.isNotEmpty,
          selected: state.view == LibraryView.similar,
          onTap: state.showSimilar,
        ),
        _SidebarRow(
          icon: CupertinoIcons.map,
          iconColor: Colors.blue,
          label: '지도',
          count: state.realLocationCount + state.estimatedLocationCount,
          showCount: state.realLocationCount + state.estimatedLocationCount > 0,
          selected: state.view == LibraryView.map,
          onTap: state.showMap,
        ),
        _SidebarRow(
          icon: CupertinoIcons.calendar,
          label: '날짜별',
          count: 0,
          showCount: false,
          selected: state.view == LibraryView.dates,
          onTap: state.showDates,
        ),
        _SidebarRow(
          icon: CupertinoIcons.person_2_fill,
          label: '인물',
          count: state.personCount,
          showCount: state.personGroups.isNotEmpty,
          selected: state.view == LibraryView.people,
          onTap: state.showPeople,
        ),
        _SidebarRow(
          icon: CupertinoIcons.chart_bar_alt_fill,
          iconColor: Colors.indigo,
          label: '통계',
          count: 0,
          showCount: false,
          selected: state.view == LibraryView.stats,
          onTap: state.showStats,
        ),
        const SizedBox(height: 6),
        const _SectionHeader('폴더'),
        for (final node in tree) ..._treeRows(node, 0),
      ],
    );
  }

  List<Widget> _treeRows(FolderNode node, int depth) {
    final state = widget.state;
    final expanded = _expanded.contains(node.path);
    final selected = state.isFolderView &&
        node.folderIndex != null &&
        state.selectedIndex == node.folderIndex;

    final rows = <Widget>[
      _TreeRow(
        node: node,
        depth: depth,
        expanded: expanded,
        selected: selected,
        accent: MacosTheme.of(context).primaryColor,
        onToggle: node.hasChildren
            ? () => setState(() {
                  if (expanded) {
                    _expanded.remove(node.path);
                  } else {
                    _expanded.add(node.path);
                  }
                })
            : null,
        onTap: () {
          if (node.folderIndex != null) {
            state.selectFolder(node.folderIndex!);
          } else if (node.hasChildren) {
            setState(() {
              expanded ? _expanded.remove(node.path) : _expanded.add(node.path);
            });
          }
        },
      ),
    ];
    if (expanded) {
      for (final c in node.children) {
        rows.addAll(_treeRows(c, depth + 1));
      }
    }
    return rows;
  }
}

class _TreeRow extends StatelessWidget {
  final FolderNode node;
  final int depth;
  final bool expanded;
  final bool selected;
  final Color accent;
  final VoidCallback? onToggle;
  final VoidCallback onTap;

  const _TreeRow({
    required this.node,
    required this.depth,
    required this.expanded,
    required this.selected,
    required this.accent,
    required this.onToggle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 1),
        padding: EdgeInsets.only(left: 4.0 + depth * 14, right: 8, top: 5, bottom: 5),
        decoration: BoxDecoration(
          color: selected ? accent : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            // 펼침 삼각형
            GestureDetector(
              onTap: onToggle,
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                width: 14,
                child: node.hasChildren
                    ? Icon(
                        expanded ? CupertinoIcons.chevron_down : CupertinoIcons.chevron_right,
                        size: 10,
                        color: selected ? Colors.white70 : Colors.grey,
                      )
                    : const SizedBox(),
              ),
            ),
            MacosIcon(
              node.hasChildren && expanded
                  ? CupertinoIcons.folder_open
                  : CupertinoIcons.folder_fill,
              size: 15,
              color: selected ? Colors.white : accent,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                node.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: selected ? Colors.white : null),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${node.totalCount}',
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

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.grey,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _SidebarRow extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String label;
  final int count;
  final bool showCount;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarRow({
    required this.icon,
    this.iconColor,
    required this.label,
    required this.count,
    this.showCount = true,
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
            MacosIcon(icon, size: 16, color: selected ? Colors.white : (iconColor ?? accent)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: selected ? Colors.white : null),
              ),
            ),
            const SizedBox(width: 6),
            if (showCount)
              Text(
                '$count',
                style: TextStyle(fontSize: 12, color: selected ? Colors.white70 : Colors.grey),
              ),
          ],
        ),
      ),
    );
  }
}
