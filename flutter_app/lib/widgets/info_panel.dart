import 'package:flutter/material.dart';

import '../models/folder_group.dart';
import '../services/exif_reader.dart';
import '../services/metadata_service.dart';
import '../state/app_state.dart';
import 'histogram_chart.dart';
import 'metadata_dialog.dart';

/// 우측 정보 패널: 선택한 사진 1장의 EXIF/파일 정보.
class InfoPanel extends StatelessWidget {
  final String? path;
  final AppState state;
  const InfoPanel({super.key, required this.path, required this.state});

  @override
  Widget build(BuildContext context) {
    final p = path;
    return Container(
      width: 260,
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: Theme.of(context).dividerColor)),
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
                  return const Center(child: CircularProgressIndicator());
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
                    if (!isVideoFile(p)) ...[
                      const Text('히스토그램',
                          style: TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 6),
                      HistogramChart(path: p),
                      const SizedBox(height: 14),
                    ],
                    for (final row in info.rows) _InfoRow(label: row.key, value: row.value),
                    const SizedBox(height: 8),
                    _TagsRow(path: p),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => showMetadataDialog(context, state, p),
                        child: const Text('메타데이터 보정'),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _TagsRow extends StatelessWidget {
  final String path;
  const _TagsRow({required this.path});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: MetadataService.getTags(path),
      builder: (context, snap) {
        final tags = snap.data ?? const [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Finder 태그', style: TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 4),
            if (tags.isEmpty)
              const Text('—', style: TextStyle(fontSize: 13, color: Colors.grey))
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final t in tags)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0x33007AFF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(t, style: const TextStyle(fontSize: 12)),
                    ),
                ],
              ),
          ],
        );
      },
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
