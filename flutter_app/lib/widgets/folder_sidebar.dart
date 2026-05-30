import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:macos_ui/macos_ui.dart';

import '../state/app_state.dart';

/// 좌측 사이드바: 상단 `보관함`(모든 사진·즐겨찾기) + 하단 `폴더` 목록.
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
    if (state.root == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('폴더를 열어 시작하세요',
            style: TextStyle(color: Colors.grey, fontSize: 13)),
      );
    }

    return ListView(
      controller: scrollController,
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
          count: state.allCount,
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
        if (state.folders.isEmpty)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('폴더 없음', style: TextStyle(color: Colors.grey, fontSize: 12)),
          )
        else
          for (var i = 0; i < state.folders.length; i++)
            _SidebarRow(
              icon: CupertinoIcons.folder_fill,
              label: state.folders[i].displayName,
              count: state.folders[i].count,
              selected: state.isFolderView && state.selectedIndex == i,
              onTap: () => state.selectFolder(i),
            ),
      ],
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
            MacosIcon(
              icon,
              size: 16,
              color: selected ? Colors.white : (iconColor ?? accent),
            ),
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
