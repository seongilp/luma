import 'dart:io';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';
import 'photo_viewer.dart';

/// 우측 메인 영역: 선택된 폴더의 썸네일 그리드.
/// GridView.builder가 보이는 셀만 렌더 + Image.file cacheWidth로 다운샘플 → 대량에도 가벼움.
class PhotoGrid extends StatelessWidget {
  final List<String> imagePaths;
  const PhotoGrid({super.key, required this.imagePaths});

  @override
  Widget build(BuildContext context) {
    if (imagePaths.isEmpty) {
      return const Center(
        child: Text('사진이 없습니다', style: TextStyle(color: Colors.grey)),
      );
    }

    return MacosScrollbar(
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 180,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
        ),
        itemCount: imagePaths.length,
        itemBuilder: (context, index) => _Thumb(
          path: imagePaths[index],
          onTap: () => _openViewer(context, index),
        ),
      ),
    );
  }

  void _openViewer(BuildContext context, int index) {
    Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black87,
      pageBuilder: (_, _, _) => PhotoViewer(imagePaths: imagePaths, initialIndex: index),
    ));
  }
}

class _Thumb extends StatefulWidget {
  final String path;
  final VoidCallback onTap;
  const _Thumb({required this.path, required this.onTap});

  @override
  State<_Thumb> createState() => _ThumbState();
}

class _ThumbState extends State<_Thumb> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _hover ? 1.03 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: _hover ? 0.35 : 0.2),
                  blurRadius: _hover ? 12 : 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(
                File(widget.path),
                fit: BoxFit.cover,
                cacheWidth: 360,
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
      ),
    );
  }
}
