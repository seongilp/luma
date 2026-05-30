import 'dart:io';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:macos_ui/macos_ui.dart';

import 'package:path/path.dart' as p;

import '../models/photo_item.dart';
import '../models/sort_filter.dart';
import '../state/app_state.dart';
import 'photo_tile.dart';
import 'photo_viewer.dart';
import 'scroll_area.dart';

/// 우측 메인: 선택 폴더/보기의 썸네일 그리드 또는 리스트(Manage).
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
    return state.gridMode == GridMode.list ? _buildList(context, items) : _buildGrid(context, items);
  }

  Widget _buildGrid(BuildContext context, List<PhotoItem> items) {
    return ScrollArea(
      builder: (controller) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: state.clearSelection,
        child: GridView.builder(
          controller: controller,
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: state.thumbSize * state.uiScale,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) => PhotoTile(
            state: state,
            item: items[index],
            decodeWidth: state.thumbSize * state.uiScale * 2,
            onOpen: () => _openViewer(context, index),
          ),
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, List<PhotoItem> items) {
    return Column(
      children: [
        _ListHeader(state: state),
        Expanded(
          child: ScrollArea(
            builder: (controller) => ListView.builder(
              controller: controller,
              padding: EdgeInsets.zero,
              itemCount: items.length,
              itemBuilder: (context, index) => _ManageRow(
                state: state,
                item: items[index],
                even: index.isEven,
                onOpen: () => _openViewer(context, index),
              ),
            ),
          ),
        ),
      ],
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

String _humanSize(int b) {
  const u = ['B', 'KB', 'MB', 'GB'];
  var s = b.toDouble();
  var i = 0;
  while (s >= 1024 && i < u.length - 1) {
    s /= 1024;
    i++;
  }
  return '${s.toStringAsFixed(i == 0 ? 0 : 1)} ${u[i]}';
}

// 컬럼 너비 (헤더/행 공유)
const double _wType = 72;
const double _wSize = 84;
const double _wDate = 140;

String _typeLabel(PhotoItem item) {
  if (item.isRaw) return 'RAW';
  final ext = p.extension(item.path).replaceFirst('.', '').toUpperCase();
  return ext.isEmpty ? '파일' : ext;
}

/// 탐색기식 상세 보기 헤더 (클릭 정렬).
class _ListHeader extends StatelessWidget {
  final AppState state;
  const _ListHeader({required this.state});

  void _sort(SortField f) {
    if (state.sortField == f) {
      state.toggleOrder();
    } else {
      state.setSort(f);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.only(left: 16, right: 24),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: MacosTheme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 36),
          Expanded(child: _h(context, '이름', SortField.name)),
          SizedBox(width: _wType, child: const Text('종류', style: _hStyle)),
          SizedBox(width: _wSize, child: _h(context, '크기', SortField.size, right: true)),
          SizedBox(width: _wDate, child: _h(context, '수정한 날짜', SortField.modified, right: true)),
        ],
      ),
    );
  }

  Widget _h(BuildContext context, String label, SortField field, {bool right = false}) {
    final active = state.sortField == field;
    return GestureDetector(
      onTap: () => _sort(field),
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisAlignment: right ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: active ? MacosTheme.of(context).primaryColor : null)),
          if (active)
            Icon(state.ascending ? CupertinoIcons.chevron_up : CupertinoIcons.chevron_down,
                size: 10, color: MacosTheme.of(context).primaryColor),
        ],
      ),
    );
  }

  static const _hStyle = TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey);
}

class _ManageRow extends StatefulWidget {
  final AppState state;
  final PhotoItem item;
  final bool even;
  final VoidCallback onOpen;
  const _ManageRow(
      {required this.state, required this.item, required this.even, required this.onOpen});

  @override
  State<_ManageRow> createState() => _ManageRowState();
}

class _ManageRowState extends State<_ManageRow> {
  bool _hover = false;

  void _tap() {
    final path = widget.item.path;
    if (HardwareKeyboard.instance.isShiftPressed) {
      widget.state.selectRange(path);
    } else if (HardwareKeyboard.instance.isMetaPressed) {
      widget.state.toggleSelect(path);
    } else {
      widget.state.selectOnly(path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final selected = widget.state.isSelected(item.path);
    final accent = MacosTheme.of(context).primaryColor;
    final bg = selected
        ? accent.withValues(alpha: 0.22)
        : _hover
            ? Colors.white.withValues(alpha: 0.04)
            : (widget.even ? Colors.transparent : Colors.white.withValues(alpha: 0.02));

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: _tap,
        onDoubleTap: widget.onOpen,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 30,
          color: bg,
          padding: const EdgeInsets.only(left: 16, right: 24),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: SizedBox(width: 24, height: 24, child: _thumb(item)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13)),
              ),
              SizedBox(
                  width: _wType,
                  child: Text(_typeLabel(item),
                      style: const TextStyle(fontSize: 12, color: Colors.grey))),
              SizedBox(
                width: _wSize,
                child: Text(_humanSize(item.sizeBytes),
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ),
              SizedBox(
                width: _wDate,
                child: Text(DateFormat('yyyy-MM-dd HH:mm').format(item.modified),
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thumb(PhotoItem item) {
    if (item.isVideo) {
      return Container(
          color: const Color(0xFF26262B),
          child: const Icon(CupertinoIcons.play_fill, color: Colors.white70, size: 11));
    }
    if (item.isRaw) {
      return Container(
          color: const Color(0xFF2A2A30),
          child: const Center(
              child: Text('R', style: TextStyle(color: Colors.white54, fontSize: 9))));
    }
    return Image.file(File(item.path),
        width: 24, height: 24, fit: BoxFit.cover, cacheWidth: 48,
        errorBuilder: (_, _, _) => Container(color: const Color(0xFF3A3A40)));
  }
}
