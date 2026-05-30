import 'package:flutter/material.dart';

/// 텍스트 입력 다이얼로그 (이름 변경 등). 취소 시 null.
Future<String?> promptText(
  BuildContext context, {
  required String title,
  required String initial,
  String confirmLabel = '확인',
}) async {
  final controller = TextEditingController(text: initial);
  String? result;
  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(controller: controller, autofocus: true),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () {
            result = controller.text.trim();
            Navigator.of(ctx).pop();
          },
          child: Text(confirmLabel),
        ),
      ],
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
  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message, textAlign: TextAlign.center),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () {
            ok = true;
            Navigator.of(ctx).pop();
          },
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok;
}
