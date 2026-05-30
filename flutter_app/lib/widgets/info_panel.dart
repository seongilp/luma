import 'package:flutter/material.dart' show Colors;
import 'package:flutter/widgets.dart';
import 'package:macos_ui/macos_ui.dart';

import '../services/exif_reader.dart';

/// 우측 정보 패널: 선택한 사진 1장의 EXIF/파일 정보.
class InfoPanel extends StatelessWidget {
  final String? path;
  const InfoPanel({super.key, required this.path});

  @override
  Widget build(BuildContext context) {
    final p = path;
    return Container(
      width: 260,
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: MacosTheme.of(context).dividerColor)),
      ),
      child: p == null
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('사진을 선택하면\n정보가 표시됩니다',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 13)),
              ),
            )
          : FutureBuilder<ExifInfo>(
              future: readInfo(p),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: ProgressCircle());
                }
                final info = snap.data!;
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text('정보',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                    for (final row in info.rows) _InfoRow(label: row.key, value: row.value),
                  ],
                );
              },
            ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}
