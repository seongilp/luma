import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

/// 사진 한 장에 대한 사용자 메타데이터. 원본 파일을 건드리지 않고
/// 별도 JSON에 저장한다 (즐겨찾기/별점/태그).
class PhotoMeta {
  final bool favorite;
  final int rating; // 0~5
  final List<String> tags;

  const PhotoMeta({this.favorite = false, this.rating = 0, this.tags = const []});

  PhotoMeta copyWith({bool? favorite, int? rating, List<String>? tags}) => PhotoMeta(
        favorite: favorite ?? this.favorite,
        rating: rating ?? this.rating,
        tags: tags ?? this.tags,
      );

  bool get isEmpty => !favorite && rating == 0 && tags.isEmpty;

  Map<String, dynamic> toJson() => {
        if (favorite) 'fav': true,
        if (rating > 0) 'rating': rating,
        if (tags.isNotEmpty) 'tags': tags,
      };

  static PhotoMeta fromJson(Map<String, dynamic> j) => PhotoMeta(
        favorite: j['fav'] == true,
        rating: (j['rating'] as num?)?.toInt() ?? 0,
        tags: (j['tags'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      );
}

/// 절대 경로 → PhotoMeta 저장소. `~/Library/Application Support/photo_manager/meta.json`.
class MetaStore {
  final Map<String, PhotoMeta> _map = {};
  File? _file;

  PhotoMeta get(String path) => _map[path] ?? const PhotoMeta();

  Future<void> load() async {
    final home = Platform.environment['HOME'];
    if (home == null) return;
    final dir = Directory(p.join(home, 'Library', 'Application Support', 'photo_manager'));
    await dir.create(recursive: true);
    _file = File(p.join(dir.path, 'meta.json'));
    if (await _file!.exists()) {
      try {
        final raw = jsonDecode(await _file!.readAsString()) as Map<String, dynamic>;
        raw.forEach((k, v) => _map[k] = PhotoMeta.fromJson(v as Map<String, dynamic>));
      } catch (_) {/* 손상 시 무시 */}
    }
  }

  Future<void> _persist() async {
    if (_file == null) return;
    final out = <String, dynamic>{};
    _map.forEach((k, v) {
      if (!v.isEmpty) out[k] = v.toJson();
    });
    try {
      await _file!.writeAsString(jsonEncode(out));
    } catch (_) {}
  }

  Future<void> _set(String path, PhotoMeta meta) async {
    if (meta.isEmpty) {
      _map.remove(path);
    } else {
      _map[path] = meta;
    }
    await _persist();
  }

  Future<void> toggleFavorite(String path) =>
      _set(path, get(path).copyWith(favorite: !get(path).favorite));

  /// 같은 별점을 다시 누르면 해제(0).
  Future<void> setRating(String path, int rating) {
    final cur = get(path).rating;
    return _set(path, get(path).copyWith(rating: cur == rating ? 0 : rating));
  }

  /// 경로 이동/이름변경 시 메타 키를 옮긴다.
  Future<void> rename(String oldPath, String newPath) async {
    final m = _map.remove(oldPath);
    if (m != null) _map[newPath] = m;
    await _persist();
  }

  Future<void> remove(String path) async {
    _map.remove(path);
    await _persist();
  }
}
