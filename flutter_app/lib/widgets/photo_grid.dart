import 'dart:io';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

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
    return _MarqueeGrid(
      state: state,
      items: items,
      onOpen: (i) => _openViewer(context, i),
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
const double _wSize = 90;
const double _wDate = 170;
// 행/헤더 공통 좌우 인셋 · 선행(썸네일+간격) 폭
const double _rowInset = 20; // margin 8 + padding 12
const double _lead = 46; // 썸네일 34 + 간격 12

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
    final hStyle = TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurfaceVariant);
    return Padding(
      padding: const EdgeInsets.only(left: _rowInset, right: _rowInset, top: 6, bottom: 8),
      child: Row(
        children: [
          const SizedBox(width: _lead),
          Expanded(child: _h(context, '이름', SortField.name)),
          SizedBox(width: _wType, child: Text('종류', style: hStyle)),
          SizedBox(width: _wSize, child: _h(context, '크기', SortField.size, right: true)),
          SizedBox(width: _wDate, child: _h(context, '수정한 날짜', SortField.modified, right: true)),
        ],
      ),
    );
  }

  Widget _h(BuildContext context, String label, SortField field, {bool right = false}) {
    final active = state.sortField == field;
    final cs = Theme.of(context).colorScheme;
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
                  color: active ? cs.primary : cs.onSurfaceVariant)),
          if (active)
            Icon(state.ascending ? CupertinoIcons.chevron_up : CupertinoIcons.chevron_down,
                size: 10, color: cs.primary),
        ],
      ),
    );
  }
}

class _ManageRow extends StatefulWidget {
  final AppState state;
  final PhotoItem item;
  final VoidCallback onOpen;
  const _ManageRow(
      {required this.state, required this.item, required this.onOpen});

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
    final cs = Theme.of(context).colorScheme;
    final selected = widget.state.isSelected(item.path);
    final colStyle = TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: _tap,
        onDoubleTap: widget.onOpen,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 46,
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: selected
                ? cs.primary.withValues(alpha: 0.16)
                : _hover
                    ? cs.onSurface.withValues(alpha: 0.06)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(width: 34, height: 34, child: _thumb(item)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: selected ? cs.primary : cs.onSurface)),
              ),
              SizedBox(
                  width: _wType,
                  child: Text(_typeLabel(item),
                      maxLines: 1, softWrap: false, style: colStyle)),
              SizedBox(
                width: _wSize,
                child: Text(_humanSize(item.sizeBytes),
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    softWrap: false,
                    style: colStyle),
              ),
              SizedBox(
                width: _wDate,
                child: Text(DateFormat('yyyy-MM-dd HH:mm').format(item.modified),
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.clip,
                    style: colStyle),
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
          child: const Icon(CupertinoIcons.play_fill, color: Colors.white70, size: 14));
    }
    if (item.isRaw) {
      return Container(
          color: const Color(0xFF2A2A30),
          child: const Center(
              child: Text('R', style: TextStyle(color: Colors.white54, fontSize: 11))));
    }
    return Image.file(File(item.path),
        width: 34, height: 34, fit: BoxFit.cover, cacheWidth: 68,
        errorBuilder: (_, _, _) => Container(color: const Color(0xFF3A3A40)));
  }
}

/// 드래그(마퀴)로 여러 사진을 한 번에 선택하는 썸네일 그리드.
/// 데스크톱에서 마우스 드래그는 스크롤에 쓰이지 않으므로 선택용으로 쓴다.
/// (스크롤은 트랙패드/휠) ⌘·⇧를 누른 채 드래그하면 기존 선택에 더한다.
class _MarqueeGrid extends StatefulWidget {
  final AppState state;
  final List<PhotoItem> items;
  final void Function(int index) onOpen;
  const _MarqueeGrid({
    required this.state,
    required this.items,
    required this.onOpen,
  });

  @override
  State<_MarqueeGrid> createState() => _MarqueeGridState();
}

class _MarqueeGridState extends State<_MarqueeGrid> {
  static const double _pad = 16;
  static const double _gap = 12;

  ScrollController? _controller;
  Offset? _start; // 콘텐츠 좌표(스크롤 반영)
  Offset? _current; // 콘텐츠 좌표
  Set<String> _base = const {}; // 드래그 시작 시점의 기존 선택(가산용)

  double get _scroll =>
      (_controller?.hasClients ?? false) ? _controller!.offset : 0;

  ({int count, double cell}) _geom(double width) {
    final cae = width - _pad * 2;
    final maxExt = widget.state.thumbSize * widget.state.uiScale;
    var count = (cae / (maxExt + _gap)).ceil();
    if (count < 1) count = 1;
    final cell = (cae - _gap * (count - 1)) / count;
    return (count: count, cell: cell);
  }

  Rect _cellRect(int i, int count, double cell) {
    final col = i % count;
    final row = i ~/ count;
    return Rect.fromLTWH(
      _pad + col * (cell + _gap),
      _pad + row * (cell + _gap),
      cell,
      cell,
    );
  }

  void _apply(int count, double cell) {
    final s = _start, c = _current;
    if (s == null || c == null) return;
    final drag = Rect.fromPoints(s, c);
    final sel = <String>{..._base};
    for (var i = 0; i < widget.items.length; i++) {
      if (_cellRect(i, count, cell).overlaps(drag)) {
        sel.add(widget.items[i].path);
      }
    }
    widget.state.setSelection(sel);
  }

  bool get _additive =>
      HardwareKeyboard.instance.isMetaPressed ||
      HardwareKeyboard.instance.isShiftPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ScrollArea(
      builder: (controller) {
        _controller = controller;
        return LayoutBuilder(
          builder: (context, constraints) {
            final g = _geom(constraints.maxWidth);
            widget.state.gridColumns = g.count; // 키보드 상하 이동용
            return GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: widget.state.clearSelection,
              onPanStart: (d) {
                final p = d.localPosition.translate(0, _scroll);
                setState(() {
                  _start = p;
                  _current = p;
                  _base = _additive ? {...widget.state.selection} : <String>{};
                });
              },
              onPanUpdate: (d) {
                setState(() =>
                    _current = d.localPosition.translate(0, _scroll));
                _apply(g.count, g.cell);
              },
              onPanEnd: (_) => setState(() {
                _start = null;
                _current = null;
              }),
              onPanCancel: () => setState(() {
                _start = null;
                _current = null;
              }),
              child: Stack(
                children: [
                  GridView.builder(
                    controller: controller,
                    padding: const EdgeInsets.all(_pad),
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent:
                          widget.state.thumbSize * widget.state.uiScale,
                      mainAxisSpacing: _gap,
                      crossAxisSpacing: _gap,
                    ),
                    itemCount: widget.items.length,
                    itemBuilder: (context, index) => PhotoTile(
                      state: widget.state,
                      item: widget.items[index],
                      decodeWidth:
                          widget.state.thumbSize * widget.state.uiScale * 2,
                      onOpen: () => widget.onOpen(index),
                    ),
                  ),
                  if (_start != null && _current != null)
                    Positioned.fromRect(
                      rect: Rect.fromPoints(
                        _start!.translate(0, -_scroll),
                        _current!.translate(0, -_scroll),
                      ),
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: cs.primary.withValues(alpha: 0.16),
                            border: Border.all(color: cs.primary, width: 1),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
