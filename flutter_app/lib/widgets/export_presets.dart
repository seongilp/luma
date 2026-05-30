import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

/// 내보내기 포맷/프리셋.
class ExportPreset {
  final String label;
  final String sub;
  final String format; // 'jpg' | 'png'
  final int? maxDim;
  const ExportPreset(this.label, this.sub, this.format, this.maxDim);
}

const exportPresets = [
  ExportPreset('원본 크기 · JPEG', '품질 90, 원본 해상도', 'jpg', null),
  ExportPreset('원본 크기 · PNG', '무손실, 원본 해상도', 'png', null),
  ExportPreset('Instagram', '긴 변 1080px · JPEG', 'jpg', 1080),
  ExportPreset('Threads / X', '긴 변 1080px · JPEG', 'jpg', 1080),
  ExportPreset('블로그', '긴 변 1600px · JPEG', 'jpg', 1600),
];

/// 내보내기 프리셋을 고르는 시트. 취소 시 null.
Future<ExportPreset?> pickExportFormat(BuildContext context) async {
  ExportPreset? chosen;
  await showDialog(
    context: context,
    builder: (ctx) => Dialog(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(CupertinoIcons.square_arrow_up, size: 20),
                SizedBox(width: 8),
                Text('내보내기', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 16),
            for (final preset in exportPresets)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  onTap: () {
                    chosen = preset;
                    Navigator.of(ctx).pop();
                  },
                  child: Container(
                    width: 360,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Theme.of(ctx).dividerColor),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(preset.label,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                              Text(preset.sub,
                                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ),
                        const Icon(CupertinoIcons.chevron_right, size: 14, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('취소'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  return chosen;
}
