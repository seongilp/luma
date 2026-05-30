import 'dart:io';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:macos_ui/macos_ui.dart';

import '../models/photo_item.dart';
import '../state/app_state.dart';

/// 그리드/유사보기 공용 썸네일 타일.
/// 단일 클릭=선택(⌘/⇧ 다중·범위), 더블 클릭=뷰어. 즐겨찾기·별점·선택 오버레이.
class PhotoTile extends StatefulWidget {
  final AppState state;
  final PhotoItem item;
  final VoidCallback onOpen;
  final double decodeWidth;
  const PhotoTile({
    super.key,
    required this.state,
    required this.item,
    required this.onOpen,
    this.decodeWidth = 360,
  });

  @override
  State<PhotoTile> createState() => _PhotoTileState();
}

class _PhotoTileState extends State<PhotoTile> {
  bool _hover = false;

  void _handleTap() {
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
    final state = widget.state;
    final path = widget.item.path;
    final selected = state.isSelected(path);
    final meta = state.meta.get(path);
    final accent = MacosTheme.of(context).primaryColor;
    final showOverlay = _hover || selected || meta.favorite || meta.rating > 0;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _handleTap,
        onDoubleTap: widget.onOpen,
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedScale(
              scale: _hover && !selected ? 1.02 : 1.0,
              duration: const Duration(milliseconds: 120),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected ? accent : Colors.transparent,
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: _hover ? 0.35 : 0.2),
                      blurRadius: _hover ? 12 : 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(path),
                    fit: BoxFit.cover,
                    cacheWidth: widget.decodeWidth.round(),
                    filterQuality: FilterQuality.medium,
                    errorBuilder: (_, _, _) => Container(
                      color: const Color(0xFF3A3A40),
                      child: const Icon(CupertinoIcons.exclamationmark_triangle,
                          color: Colors.grey, size: 20),
                    ),
                  ),
                ),
              ),
            ),
            if (selected)
              Positioned(
                top: 6,
                right: 6,
                child: Icon(CupertinoIcons.checkmark_circle_fill, color: accent, size: 22),
              ),
            if (showOverlay)
              Positioned(
                top: 6,
                left: 6,
                child: _IconButton(
                  icon: meta.favorite ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                  color: meta.favorite ? Colors.redAccent : Colors.white,
                  onTap: () => state.toggleFavorite(path),
                ),
              ),
            if (showOverlay)
              Positioned(
                left: 0,
                right: 0,
                bottom: 6,
                child: _StarRow(
                  rating: meta.rating,
                  onRate: (r) => state.setRating(path, r),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _IconButton({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }
}

class _StarRow extends StatelessWidget {
  final int rating;
  final ValueChanged<int> onRate;
  const _StarRow({required this.rating, required this.onRate});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(5, (i) {
          final filled = i < rating;
          return GestureDetector(
            onTap: () => onRate(i + 1),
            child: Icon(
              filled ? CupertinoIcons.star_fill : CupertinoIcons.star,
              size: 13,
              color: filled ? Colors.amber : Colors.white70,
            ),
          );
        }),
      ),
    );
  }
}
