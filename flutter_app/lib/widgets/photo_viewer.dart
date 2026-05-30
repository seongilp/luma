import 'dart:io';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/app_state.dart';

/// 전체 화면 큰 보기. 좌우 이동, Esc 닫기, 핀치 줌, 즐겨찾기·별점·삭제.
class PhotoViewer extends StatefulWidget {
  final AppState state;
  final List<String> paths;
  final int initialIndex;
  const PhotoViewer({
    super.key,
    required this.state,
    required this.paths,
    required this.initialIndex,
  });

  @override
  State<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<PhotoViewer> {
  late final PageController _controller;
  late int _index;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: _index);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _move(int delta) {
    final next = (_index + delta).clamp(0, widget.paths.length - 1);
    if (next != _index) {
      _controller.animateToPage(next,
          duration: const Duration(milliseconds: 180), curve: Curves.easeOut);
    }
  }

  bool _flash = false;

  /// 빠른 리뷰: 현재 사진을 즐겨찾기(이미 즐겨찾기면 유지)하고 다음으로.
  void _favoriteAndNext() {
    final path = widget.paths[_index];
    if (!widget.state.meta.get(path).favorite) {
      widget.state.toggleFavorite(path);
    }
    setState(() => _flash = true);
    Future.delayed(const Duration(milliseconds: 420), () {
      if (mounted) setState(() => _flash = false);
    });
    _move(1);
  }

  Future<void> _deleteCurrent() async {
    final path = widget.paths[_index];
    await widget.state.deleteOne(path);
    if (mounted) Navigator.of(context).maybePop();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowRight:
        _move(1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowLeft:
        _move(-1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
        Navigator.of(context).maybePop();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.keyF:
        widget.state.toggleFavorite(widget.paths[_index]);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.space:
        // 빠른 리뷰: 즐겨찾기 표시 후 다음 사진으로.
        _favoriteAndNext();
        return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focus,
      onKeyEvent: _onKey,
      child: Stack(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(color: Colors.transparent),
          ),
          PageView.builder(
            controller: _controller,
            itemCount: widget.paths.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) => InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: Center(
                child: Image.file(File(widget.paths[i]), fit: BoxFit.contain),
              ),
            ),
          ),
          Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${_index + 1} / ${widget.paths.length}   ·   Space: ♥ + 다음',
                    style: const TextStyle(color: Colors.white, fontSize: 13)),
              ),
            ),
          ),
          _NavButton(alignment: Alignment.centerLeft, icon: Icons.chevron_left, onTap: () => _move(-1)),
          _NavButton(alignment: Alignment.centerRight, icon: Icons.chevron_right, onTap: () => _move(1)),
          // 빠른 리뷰 하트 플래시
          IgnorePointer(
            child: AnimatedOpacity(
              opacity: _flash ? 1 : 0,
              duration: const Duration(milliseconds: 150),
              child: Center(
                child: Icon(CupertinoIcons.heart_fill,
                    color: Colors.redAccent.withValues(alpha: 0.9), size: 130),
              ),
            ),
          ),
          _bottomBar(),
        ],
      ),
    );
  }

  Widget _bottomBar() {
    return Positioned(
      bottom: 20,
      left: 0,
      right: 0,
      child: Center(
        child: ListenableBuilder(
          listenable: widget.state,
          builder: (context, _) {
            final path = widget.paths[_index];
            final meta = widget.state.meta.get(path);
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _BarIcon(
                    icon: meta.favorite ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                    color: meta.favorite ? Colors.redAccent : Colors.white,
                    onTap: () => widget.state.toggleFavorite(path),
                  ),
                  const SizedBox(width: 12),
                  ...List.generate(5, (i) {
                    final filled = i < meta.rating;
                    return GestureDetector(
                      onTap: () => widget.state.setRating(path, i + 1),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1),
                        child: Icon(
                          filled ? CupertinoIcons.star_fill : CupertinoIcons.star,
                          size: 18,
                          color: filled ? Colors.amber : Colors.white70,
                        ),
                      ),
                    );
                  }),
                  const SizedBox(width: 14),
                  _BarIcon(
                    icon: CupertinoIcons.delete,
                    color: Colors.white,
                    onTap: _deleteCurrent,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BarIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _BarIcon({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(icon, color: color, size: 22),
    );
  }
}

class _NavButton extends StatelessWidget {
  final Alignment alignment;
  final IconData icon;
  final VoidCallback onTap;
  const _NavButton({required this.alignment, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ),
      ),
    );
  }
}
