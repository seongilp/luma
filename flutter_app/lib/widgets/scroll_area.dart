import 'package:flutter/widgets.dart';
import 'package:macos_ui/macos_ui.dart';

/// MacosScrollbar와 내부 스크롤뷰가 같은 ScrollController를 공유하도록 묶는다.
/// (컨트롤러 미연결로 인한 "no ScrollPosition attached" 예외 방지)
class ScrollArea extends StatefulWidget {
  final Widget Function(ScrollController controller) builder;
  const ScrollArea({super.key, required this.builder});

  @override
  State<ScrollArea> createState() => _ScrollAreaState();
}

class _ScrollAreaState extends State<ScrollArea> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MacosScrollbar(
      controller: _controller,
      child: widget.builder(_controller),
    );
  }
}
