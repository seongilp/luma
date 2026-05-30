import 'dart:io';
import 'package:path/path.dart' as p;

import 'photo_item.dart';

/// 한 폴더(디렉터리)에 직접 들어 있는 이미지 묶음. 사이드바 항목 1개에 대응.
class FolderGroup {
  /// 절대 디렉터리 경로.
  final String path;

  /// 사이드바에 표시할 이름 (root 기준 상대 경로, root 자신은 폴더명).
  final String displayName;

  /// 이 폴더 안 이미지들.
  final List<PhotoItem> items;

  const FolderGroup({
    required this.path,
    required this.displayName,
    required this.items,
  });

  int get count => items.length;
}

const _imageExts = {'.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'};
const _videoExts = {'.mp4', '.mov', '.m4v'};

bool isSupportedImage(String filePath) {
  return _imageExts.contains(p.extension(filePath).toLowerCase());
}

bool isVideoFile(String filePath) {
  return _videoExts.contains(p.extension(filePath).toLowerCase());
}

bool isSupportedMedia(String filePath) =>
    isSupportedImage(filePath) || isVideoFile(filePath);

/// `root`를 재귀 스캔해 이미지를 **직속 디렉터리별로 묶어** 반환한다.
/// 파일 통계(크기·수정일)도 함께 읽는다. 접근 불가 항목은 건너뛴다.
Future<List<FolderGroup>> scanFolders(String root) async {
  final dir = Directory(root);
  if (!await dir.exists()) return [];

  final Map<String, List<PhotoItem>> byDir = {};

  final stream = dir.list(recursive: true, followLinks: false);
  await for (final entity
      in stream.handleError((_) {}, test: (e) => e is FileSystemException)) {
    if (entity is! File) continue;
    if (!isSupportedMedia(entity.path)) continue;
    FileStat st;
    try {
      st = await entity.stat();
    } catch (_) {
      continue;
    }
    final d = p.dirname(entity.path);
    byDir.putIfAbsent(d, () => []).add(
          PhotoItem(
            path: entity.path,
            sizeBytes: st.size,
            modified: st.modified,
            isVideo: isVideoFile(entity.path),
          ),
        );
  }

  final groups = <FolderGroup>[];
  for (final entry in byDir.entries) {
    final items = entry.value..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final rel = p.relative(entry.key, from: root);
    groups.add(FolderGroup(
      path: entry.key,
      displayName: rel == '.' ? p.basename(root) : rel,
      items: items,
    ));
  }
  groups.sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
  return groups;
}
