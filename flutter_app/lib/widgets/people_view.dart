import 'dart:io';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../models/photo_item.dart';
import '../state/app_state.dart';
import 'analysis_overlay.dart';
import 'photo_tile.dart';
import 'photo_viewer.dart';
import 'scroll_area.dart';

/// 인물 보기: 얼굴 인식으로 같은 사람끼리 묶은 묶음(근사).
class PeopleView extends StatelessWidget {
  final AppState state;
  const PeopleView({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.analyzing) return AnalysisOverlay(state: state);

    final groups = state.personGroups;
    return Column(
      children: [
        _bar(context),
        Expanded(
          child: groups.isEmpty
              ? const Center(
                  child: Text('인식된 인물이 없습니다',
                      style: TextStyle(color: Colors.grey, fontSize: 15)))
              : ScrollArea(
                  builder: (controller) => ListView.builder(
                    controller: controller,
                    padding: const EdgeInsets.all(16),
                    itemCount: groups.length,
                    itemBuilder: (context, i) =>
                        _Person(state: state, index: i, items: groups[i]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _bar(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Text('${state.personCount}명 (근사 분류)',
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const Spacer(),
          TextButton(
            onPressed: state.analyzeFaces,
            child: const Text('다시 분석'),
          ),
        ],
      ),
    );
  }
}

class _Person extends StatelessWidget {
  final AppState state;
  final int index;
  final List<PhotoItem> items;
  const _Person({required this.state, required this.index, required this.items});

  void _open(BuildContext context, int i) {
    Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black87,
      pageBuilder: (_, _, _) => PhotoViewer(
        state: state,
        paths: items.map((e) => e.path).toList(),
        initialIndex: i,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 2),
            child: Row(
              children: [
                ClipOval(
                  child: Image.file(
                    File(items.first.path),
                    width: 32,
                    height: 32,
                    fit: BoxFit.cover,
                    cacheWidth: 64,
                    errorBuilder: (_, _, _) => Container(
                      width: 32,
                      height: 32,
                      color: const Color(0xFF3A3A40),
                      child: const Icon(CupertinoIcons.person_fill,
                          size: 16, color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('인물 ${index + 1}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                Text('${items.length}장',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var i = 0; i < items.length; i++)
                SizedBox(
                  width: 130,
                  height: 130,
                  child: PhotoTile(
                    state: state,
                    item: items[i],
                    decodeWidth: 260,
                    onOpen: () => _open(context, i),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
