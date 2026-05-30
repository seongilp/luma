import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/widgets.dart';
import 'package:macos_ui/macos_ui.dart';

/// 텍스트 입력 다이얼로그 (이름 변경 등). 취소 시 null.
Future<String?> promptText(
  BuildContext context, {
  required String title,
  required String initial,
  String confirmLabel = '확인',
}) async {
  final controller = TextEditingController(text: initial);
  String? result;
  await showMacosAlertDialog(
    context: context,
    builder: (ctx) => MacosAlertDialog(
      appIcon: const MacosIcon(CupertinoIcons.pencil, size: 48),
      title: Text(title),
      message: MacosTextField(controller: controller, autofocus: true),
      primaryButton: PushButton(
        controlSize: ControlSize.large,
        onPressed: () {
          result = controller.text.trim();
          Navigator.of(ctx).pop();
        },
        child: Text(confirmLabel),
      ),
      secondaryButton: PushButton(
        controlSize: ControlSize.large,
        secondary: true,
        onPressed: () => Navigator.of(ctx).pop(),
        child: const Text('취소'),
      ),
    ),
  );
  final r = result;
  return (r == null || r.isEmpty) ? null : r;
}

/// 확인/취소 다이얼로그. 확인 시 true.
Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = '삭제',
}) async {
  bool ok = false;
  await showMacosAlertDialog(
    context: context,
    builder: (ctx) => MacosAlertDialog(
      appIcon: const MacosIcon(CupertinoIcons.exclamationmark_triangle, size: 48),
      title: Text(title),
      message: Text(message, textAlign: TextAlign.center),
      primaryButton: PushButton(
        controlSize: ControlSize.large,
        onPressed: () {
          ok = true;
          Navigator.of(ctx).pop();
        },
        child: Text(confirmLabel),
      ),
      secondaryButton: PushButton(
        controlSize: ControlSize.large,
        secondary: true,
        onPressed: () => Navigator.of(ctx).pop(),
        child: const Text('취소'),
      ),
    ),
  );
  return ok;
}
