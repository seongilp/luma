import 'package:path/path.dart' as p;

/// 그리드/정렬/선택의 기본 단위. 사진 또는 동영상.
class PhotoItem {
  final String path;
  final int sizeBytes;
  final DateTime modified;
  final bool isVideo;

  PhotoItem({
    required this.path,
    required this.sizeBytes,
    required this.modified,
    this.isVideo = false,
  });

  String get name => p.basename(path);

  /// 경로만 바뀐 복사본 (이름변경/이동 후 상태 갱신용).
  PhotoItem withPath(String newPath) =>
      PhotoItem(path: newPath, sizeBytes: sizeBytes, modified: modified, isVideo: isVideo);
}
