import 'dart:io';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 2~4장 비교. 동기화 줌/이동, 기준(Reference) 고정 비교 모드.
class CompareView extends StatefulWidget {
  final List<String> paths;
  const CompareView({super.key, required this.paths});

  @override
  State<CompareView> createState() => _CompareViewState();
}

class _CompareViewState extends State<CompareView> {
  final TransformationController _t = TransformationController();
  final FocusNode _focus = FocusNode();
  bool _synced = true;
  bool _reference = false;
  int _candIndex = 1; // 기준 모드에서 오른쪽에 보일 사진

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _t.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _cycleCand(int delta) {
    if (widget.paths.length < 2) return;
    var n = _candIndex + delta;
    // 0(기준)은 건너뛰고 1..length-1 순환
    final last = widget.paths.length - 1;
    if (n < 1) n = last;
    if (n > last) n = 1;
    setState(() => _candIndex = n);
  }

  KeyEventResult _onKey(FocusNode n, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    if (e.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).maybePop();
      return KeyEventResult.handled;
    }
    if (_reference) {
      if (e.logicalKey == LogicalKeyboardKey.arrowRight) {
        _cycleCand(1);
        return KeyEventResult.handled;
      }
      if (e.logicalKey == LogicalKeyboardKey.arrowLeft) {
        _cycleCand(-1);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final panels = _reference
        ? [_panel(widget.paths[0], '기준'), _panel(widget.paths[_candIndex], null)]
        : [for (final p in widget.paths) _panel(p, null)];

    return Focus(
      focusNode: _focus,
      onKeyEvent: _onKey,
      child: Container(
        color: Colors.black,
        child: Column(
          children: [
            _bar(),
            Expanded(
              child: Row(
                children: [
                  for (var i = 0; i < panels.length; i++) ...[
                    if (i > 0) const VerticalDivider(width: 1, color: Colors.white24),
                    Expanded(child: panels[i]),
                  ],
                ],
              ),
            ),
            if (_reference) _candStrip(),
          ],
        ),
      ),
    );
  }

  Widget _panel(String path, String? label) {
    return Stack(
      fit: StackFit.expand,
      children: [
        InteractiveViewer(
          transformationController: _synced ? _t : null,
          minScale: 1,
          maxScale: 8,
          child: Center(child: Image.file(File(path), fit: BoxFit.contain)),
        ),
        if (label != null)
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(label,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black)),
            ),
          ),
      ],
    );
  }

  Widget _bar() {
    return Container(
      height: 44,
      color: const Color(0xFF18181B),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Text('비교 (${_reference ? "기준 모드" : "${widget.paths.length}장"})',
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
          const Spacer(),
          _toggle('동기화 줌', _synced, () => setState(() => _synced = !_synced)),
          const SizedBox(width: 8),
          if (widget.paths.length >= 2)
            _toggle('기준 비교', _reference, () => setState(() => _reference = !_reference)),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: const Icon(CupertinoIcons.xmark, color: Colors.white70, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _toggle(String label, bool on, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: on ? Colors.blueAccent : Colors.white12,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ),
    );
  }

  Widget _candStrip() {
    return Container(
      height: 64,
      color: const Color(0xFF18181B),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          for (var i = 1; i < widget.paths.length; i++)
            GestureDetector(
              onTap: () => setState(() => _candIndex = i),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _candIndex == i ? Colors.blueAccent : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.file(File(widget.paths[i]),
                      width: 50, height: 50, fit: BoxFit.cover, cacheWidth: 100),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
