import 'package:path/path.dart' as p;

/// 그리드/정렬/선택의 기본 단위. 사진/동영상/RAW.
class PhotoItem {
  final String path;
  final int sizeBytes;
  final DateTime modified;
  final bool isVideo;

  /// 같은 이름의 RAW 원본 경로 (JPG와 페어링된 경우). 없으면 null.
  final String? rawPath;

  /// 이 항목 자체가 RAW(미리보기 불가)인지.
  final bool isRaw;

  PhotoItem({
    required this.path,
    required this.sizeBytes,
    required this.modified,
    this.isVideo = false,
    this.rawPath,
    this.isRaw = false,
  });

  String get name => p.basename(path);
  bool get hasRaw => rawPath != null || isRaw;

  PhotoItem withPath(String newPath) => PhotoItem(
        path: newPath,
        sizeBytes: sizeBytes,
        modified: modified,
        isVideo: isVideo,
        rawPath: rawPath,
        isRaw: isRaw,
      );
}
