import 'dart:io';
import 'package:path/path.dart' as p;

import 'photo_item.dart';

/// 한 폴더(디렉터리)에 직접 들어 있는 미디어 묶음. 사이드바 항목 1개에 대응.
class FolderGroup {
  final String path;
  final String displayName;
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
const _rawExts = {'.cr2', '.cr3', '.nef', '.arw', '.dng', '.raf', '.orf', '.rw2'};

bool isSupportedImage(String filePath) => _imageExts.contains(p.extension(filePath).toLowerCase());
bool isVideoFile(String filePath) => _videoExts.contains(p.extension(filePath).toLowerCase());
bool isRawFile(String filePath) => _rawExts.contains(p.extension(filePath).toLowerCase());

bool isSupportedMedia(String filePath) =>
    isSupportedImage(filePath) || isVideoFile(filePath) || isRawFile(filePath);

class _FileRec {
  final String path;
  final int size;
  final DateTime modified;
  _FileRec(this.path, this.size, this.modified);
}

/// `root`를 재귀 스캔해 미디어를 직속 디렉터리별로 묶어 반환한다.
/// 같은 이름의 RAW+JPG는 한 항목으로 페어링한다.
Future<List<FolderGroup>> scanFolders(String root) async {
  final dir = Directory(root);
  if (!await dir.exists()) return [];

  // 디렉터리별 파일 수집
  final Map<String, List<_FileRec>> byDir = {};
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
    byDir.putIfAbsent(d, () => []).add(_FileRec(entity.path, st.size, st.modified));
  }

  final groups = <FolderGroup>[];
  for (final entry in byDir.entries) {
    final items = _pairItems(entry.value)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
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

/// 같은 폴더 파일들을 PhotoItem으로. RAW와 동명 이미지를 페어링.
List<PhotoItem> _pairItems(List<_FileRec> files) {
  // basename(확장자 제외, 소문자)별로 묶기
  final byStem = <String, List<_FileRec>>{};
  for (final f in files) {
    byStem.putIfAbsent(p.basenameWithoutExtension(f.path).toLowerCase(), () => []).add(f);
  }

  final items = <PhotoItem>[];
  for (final recs in byStem.values) {
    final image = recs.where((r) => isSupportedImage(r.path)).toList();
    final raw = recs.where((r) => isRawFile(r.path)).toList();
    final video = recs.where((r) => isVideoFile(r.path)).toList();

    // 이미지(있으면) — RAW가 있으면 페어링
    if (image.isNotEmpty) {
      final im = image.first;
      items.add(PhotoItem(
        path: im.path,
        sizeBytes: im.size,
        modified: im.modified,
        rawPath: raw.isNotEmpty ? raw.first.path : null,
      ));
      // 같은 stem의 추가 이미지들도 개별 항목으로
      for (final extra in image.skip(1)) {
        items.add(PhotoItem(path: extra.path, sizeBytes: extra.size, modified: extra.modified));
      }
    } else if (raw.isNotEmpty) {
      // RAW 단독 (미리보기 불가)
      final r = raw.first;
      items.add(PhotoItem(path: r.path, sizeBytes: r.size, modified: r.modified, isRaw: true));
    }
    // 동영상
    for (final v in video) {
      items.add(PhotoItem(path: v.path, sizeBytes: v.size, modified: v.modified, isVideo: true));
    }
  }
  return items;
}
