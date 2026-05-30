import 'dart:io';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:macos_ui/macos_ui.dart';

import '../models/photo_item.dart';
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

  Widget _buildList(BuildContext context, List<PhotoItem> items) {
    return ScrollArea(
      builder: (controller) => ListView.builder(
        controller: controller,
        padding: const EdgeInsets.symmetric(vertical: 6),
        itemCount: items.length,
        itemBuilder: (context, index) => _ManageRow(
          state: state,
          item: items[index],
          onOpen: () => _openViewer(context, index),
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

class _ManageRow extends StatelessWidget {
  final AppState state;
  final PhotoItem item;
  final VoidCallback onOpen;
  const _ManageRow({required this.state, required this.item, required this.onOpen});

  void _tap() {
    final path = item.path;
    if (HardwareKeyboard.instance.isShiftPressed) {
      state.selectRange(path);
    } else if (HardwareKeyboard.instance.isMetaPressed) {
      state.toggleSelect(path);
    } else {
      state.selectOnly(path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = state.isSelected(item.path);
    final accent = MacosTheme.of(context).primaryColor;
    return GestureDetector(
      onTap: _tap,
      onDoubleTap: onOpen,
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: selected ? accent.withValues(alpha: 0.18) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                width: 40,
                height: 40,
                child: item.isVideo
                    ? Container(
                        color: const Color(0xFF26262B),
                        child: const Icon(CupertinoIcons.play_fill, color: Colors.white70, size: 16))
                    : item.isRaw
                        ? Container(
                            color: const Color(0xFF2A2A30),
                            child: const Center(
                                child: Text('RAW',
                                    style: TextStyle(color: Colors.white54, fontSize: 9))))
                        : Image.file(File(item.path),
                            width: 40, height: 40, fit: BoxFit.cover, cacheWidth: 80,
                            errorBuilder: (_, _, _) => Container(color: const Color(0xFF3A3A40))),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Text(item.name,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
            ),
            if (item.rawPath != null)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Text('RAW',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
              ),
            SizedBox(
              width: 80,
              child: Text(_humanSize(item.sizeBytes),
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 120,
              child: Text(DateFormat('yyyy-MM-dd HH:mm').format(item.modified),
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }
}
