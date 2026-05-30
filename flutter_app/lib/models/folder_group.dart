import 'dart:io';
import 'package:path/path.dart' as p;

/// 한 폴더(디렉터리)에 직접 들어 있는 이미지 묶음. 사이드바 항목 1개에 대응.
class FolderGroup {
  /// 절대 디렉터리 경로.
  final String path;

  /// 사이드바에 표시할 이름 (root 기준 상대 경로, root 자신은 폴더명).
  final String displayName;

  /// 이 폴더 안 이미지 파일들의 절대 경로 (이름 정렬됨).
  final List<String> imagePaths;

  const FolderGroup({
    required this.path,
    required this.displayName,
    required this.imagePaths,
  });

  int get count => imagePaths.length;
}

const _imageExts = {'.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'};

bool isSupportedImage(String filePath) {
  return _imageExts.contains(p.extension(filePath).toLowerCase());
}

/// `root`를 재귀 스캔해 이미지를 **직속 디렉터리별로 묶어** 반환한다.
/// 접근 불가한 항목은 건너뛰고 계속한다 (크래시 금지).
Future<List<FolderGroup>> scanFolders(String root) async {
  final dir = Directory(root);
  if (!await dir.exists()) return [];

  final Map<String, List<String>> byDir = {};

  final stream = dir.list(recursive: true, followLinks: false);
  await for (final entity in stream.handleError((_) {}, test: (e) => e is FileSystemException)) {
    if (entity is! File) continue;
    if (!isSupportedImage(entity.path)) continue;
    final d = p.dirname(entity.path);
    byDir.putIfAbsent(d, () => []).add(entity.path);
  }

  final groups = <FolderGroup>[];
  for (final entry in byDir.entries) {
    final paths = entry.value..sort();
    final rel = p.relative(entry.key, from: root);
    groups.add(FolderGroup(
      path: entry.key,
      displayName: rel == '.' ? p.basename(root) : rel,
      imagePaths: paths,
    ));
  }
  groups.sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
  return groups;
}
