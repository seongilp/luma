import 'dart:io';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:macos_ui/macos_ui.dart' show MacosSheet, PushButton, ControlSize, showMacosSheet;
import 'package:video_player/video_player.dart';

import '../models/folder_group.dart';
import '../services/vision_service.dart';
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

  bool _ocrBusy = false;
  bool _filmstrip = false;

  Future<void> _runOcr() async {
    if (_ocrBusy) return;
    setState(() => _ocrBusy = true);
    final lines = await VisionService.ocr(widget.paths[_index]);
    if (!mounted) return;
    setState(() => _ocrBusy = false);
    final text = lines.join('\n');
    await showMacosSheet(
      context: context,
      builder: (ctx) => MacosSheet(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('인식된 텍스트',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460, maxHeight: 360),
                child: SingleChildScrollView(
                  child: SelectableText(
                    text.isEmpty ? '인식된 텍스트가 없습니다.' : text,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  PushButton(
                    controlSize: ControlSize.large,
                    secondary: true,
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('닫기'),
                  ),
                  const SizedBox(width: 10),
                  PushButton(
                    controlSize: ControlSize.large,
                    onPressed: text.isEmpty
                        ? null
                        : () {
                            Clipboard.setData(ClipboardData(text: text));
                            Navigator.of(ctx).pop();
                          },
                    child: const Text('복사'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
            itemBuilder: (context, i) {
              final path = widget.paths[i];
              if (isVideoFile(path)) return _VideoView(key: ValueKey(path), path: path);
              if (isRawFile(path)) {
                return const Center(
                  child: Text('RAW 파일은 미리보기를 지원하지 않습니다',
                      style: TextStyle(color: Colors.white70, fontSize: 16)),
                );
              }
              return InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: Center(
                  child: Image.file(File(path), fit: BoxFit.contain),
                ),
              );
            },
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
          if (!_filmstrip) ...[
            _NavButton(alignment: Alignment.centerLeft, icon: Icons.chevron_left, onTap: () => _move(-1)),
            _NavButton(alignment: Alignment.centerRight, icon: Icons.chevron_right, onTap: () => _move(1)),
          ],
          if (_filmstrip) _buildFilmstrip(),
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

  Widget _buildFilmstrip() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 70,
      child: Container(
        height: 72,
        color: Colors.black.withValues(alpha: 0.5),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          itemCount: widget.paths.length,
          itemBuilder: (context, i) {
            final sel = i == _index;
            final path = widget.paths[i];
            return GestureDetector(
              onTap: () => _controller.jumpToPage(i),
              child: Container(
                width: 60,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: sel ? Colors.white : Colors.transparent, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: isVideoFile(path)
                      ? Container(
                          color: const Color(0xFF26262B),
                          child: const Icon(CupertinoIcons.play_fill,
                              color: Colors.white70, size: 18))
                      : Image.file(File(path),
                          fit: BoxFit.cover, cacheWidth: 120,
                          errorBuilder: (_, _, _) =>
                              Container(color: const Color(0xFF3A3A40))),
                ),
              ),
            );
          },
        ),
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
                    icon: CupertinoIcons.rectangle_grid_1x2,
                    color: _filmstrip ? Colors.blueAccent : Colors.white,
                    onTap: () => setState(() => _filmstrip = !_filmstrip),
                  ),
                  if (!isVideoFile(path)) ...[
                    const SizedBox(width: 14),
                    _BarIcon(
                      icon: _ocrBusy ? CupertinoIcons.hourglass : CupertinoIcons.textformat,
                      color: Colors.white,
                      onTap: _runOcr,
                    ),
                  ],
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

/// 뷰어 내 동영상 재생 (탭으로 재생/일시정지, 진행바).
class _VideoView extends StatefulWidget {
  final String path;
  const _VideoView({super.key, required this.path});

  @override
  State<_VideoView> createState() => _VideoViewState();
}

class _VideoViewState extends State<_VideoView> {
  late final VideoPlayerController _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.path))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _ready = true);
        _controller
          ..setLooping(true)
          ..play();
      }).catchError((_) {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    return Center(
      child: GestureDetector(
        onTap: () => setState(() {
          _controller.value.isPlaying ? _controller.pause() : _controller.play();
        }),
        child: AspectRatio(
          aspectRatio: _controller.value.aspectRatio,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              VideoPlayer(_controller),
              VideoProgressIndicator(_controller, allowScrubbing: true),
              if (!_controller.value.isPlaying)
                const Icon(CupertinoIcons.play_circle_fill, color: Colors.white70, size: 64),
            ],
          ),
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
