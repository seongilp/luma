import 'package:file_selector/file_selector.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

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
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('폴더를 추가해 시작하세요',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13)),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: _addLocation,
              icon: const Icon(CupertinoIcons.add, size: 18),
              label: const Text('폴더 추가'),
            ),
          ],
        ),
      );
    }

    final tree = state.folderTree;
    // 루트 구성이 바뀌면 트리를 접은 상태로 초기화(깊은 하위폴더로 어수선해지지 않게).
    // 추가된 위치가 하나뿐일 때만 그 한 단계는 펼쳐 바로 내용이 보이게 한다.
    final topKey = tree.map((n) => n.path).join('|');
    if (_treeRoot != topKey) {
      _treeRoot = topKey;
      _expanded.clear();
      if (tree.length == 1) _expanded.add(tree.first.path);
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
        _SectionHeader('폴더', trailing: _AddFolderButton(onTap: _addLocation)),
        for (final node in tree) ..._treeRows(node, 0),
      ],
    );
  }

  /// 맥의 기존 폴더를 골라 라이브러리에 위치로 추가한다.
  Future<void> _addLocation() async {
    final dir = await getDirectoryPath(confirmButtonText: '추가');
    if (dir == null) return;
    await widget.state.addRoot(dir);
  }

  List<Widget> _treeRows(FolderNode node, int depth) {
    final state = widget.state;
    final expanded = _expanded.contains(node.path);
    final selected =
        state.isFolderView && state.selectedFolderPath == node.path;

    final rows = <Widget>[
      _TreeRow(
        node: node,
        depth: depth,
        expanded: expanded,
        selected: selected,
        accent: Theme.of(context).colorScheme.primary,
        // 최상위 노드(=추가된 맥 폴더)는 목록에서 제거 가능.
        onRemove: depth == 0 ? () => state.removeRoot(node.path) : null,
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
          // 폴더를 고르면 그 폴더(하위 포함)의 사진만 보여준다.
          state.selectFolderPath(node.path);
          // 하위가 있으면 펼쳐서 트리 탐색도 함께.
          if (node.hasChildren && !expanded) {
            setState(() => _expanded.add(node.path));
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
  final VoidCallback? onRemove;

  const _TreeRow({
    required this.node,
    required this.depth,
    required this.expanded,
    required this.selected,
    required this.accent,
    required this.onToggle,
    required this.onTap,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final labelColor = Theme.of(context).colorScheme.onSurface;
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    final tertiary = Theme.of(context).colorScheme.outline;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 1.5),
        padding: EdgeInsets.only(left: 6.0 + depth * 16, right: 8, top: 6, bottom: 6),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            // 펼침 삼각형
            GestureDetector(
              onTap: onToggle,
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                width: 18,
                child: node.hasChildren
                    ? Icon(
                        expanded ? CupertinoIcons.chevron_down : CupertinoIcons.chevron_right,
                        size: 11,
                        color: tertiary,
                      )
                    : const SizedBox(),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              node.hasChildren && expanded
                  ? CupertinoIcons.folder_open
                  : CupertinoIcons.folder_fill,
              size: 15,
              color: accent,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                node.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  color: selected ? accent : labelColor,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${node.totalCount}',
              style: TextStyle(
                  fontSize: 12.5, color: selected ? accent : secondary),
            ),
            if (onRemove != null) ...[
              const SizedBox(width: 4),
              Tooltip(
                message: '목록에서 제거',
                child: GestureDetector(
                  onTap: onRemove,
                  behavior: HitTestBehavior.opaque,
                  child: Icon(
                    CupertinoIcons.xmark_circle_fill,
                    size: 13,
                    color: tertiary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const _SectionHeader(this.title, {this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 4, 5),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              letterSpacing: 0.2,
            ),
          ),
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

class _AddFolderButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddFolderButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '폴더 추가',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Icon(CupertinoIcons.add,
              size: 15, color: Theme.of(context).colorScheme.primary),
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
    final accent = Theme.of(context).colorScheme.primary;
    final labelColor = Theme.of(context).colorScheme.onSurface;
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 17, color: selected ? accent : (iconColor ?? accent)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  color: selected ? accent : labelColor,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            const SizedBox(width: 6),
            if (showCount)
              Text(
                '$count',
                style: TextStyle(
                    fontSize: 12.5, color: selected ? accent : secondary),
              ),
          ],
        ),
      ),
    );
  }
}
