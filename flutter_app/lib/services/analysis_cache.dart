import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

/// 사진 1장의 분석 결과 캐시. 파일이 바뀌면(mtime/size) 무효화된다.
class CacheEntry {
  int mtimeMs;
  int size;

  List<double>? vector; // Vision 이미지 특징벡터 (null=미계산)
  List<List<double>>? faces; // 얼굴 벡터들 (null=미계산, []=얼굴없음)

  bool gpsChecked = false;
  double? lat, lng; // EXIF GPS

  bool takenChecked = false;
  String? taken; // ISO 촬영일

  bool claudeChecked = false;
  double? claudeLat, claudeLng;
  String? claudePlace;

  CacheEntry(this.mtimeMs, this.size);

  bool validFor(int mtimeMs, int size) => this.mtimeMs == mtimeMs && this.size == size;

  Map<String, dynamic> toJson() => {
        'm': mtimeMs,
        's': size,
        if (vector != null) 'v': vector,
        if (faces != null) 'f': faces,
        if (gpsChecked) 'gc': true,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        if (takenChecked) 'tc': true,
        if (taken != null) 't': taken,
        if (claudeChecked) 'cc': true,
        if (claudeLat != null) 'cla': claudeLat,
        if (claudeLng != null) 'clo': claudeLng,
        if (claudePlace != null) 'cp': claudePlace,
      };

  static CacheEntry fromJson(Map<String, dynamic> j) {
    final e = CacheEntry((j['m'] as num).toInt(), (j['s'] as num).toInt());
    if (j['v'] != null) e.vector = [for (final x in j['v'] as List) (x as num).toDouble()];
    if (j['f'] != null) {
      e.faces = [
        for (final fv in j['f'] as List) [for (final x in fv as List) (x as num).toDouble()]
      ];
    }
    e.gpsChecked = j['gc'] == true;
    e.lat = (j['lat'] as num?)?.toDouble();
    e.lng = (j['lng'] as num?)?.toDouble();
    e.takenChecked = j['tc'] == true;
    e.taken = j['t'] as String?;
    e.claudeChecked = j['cc'] == true;
    e.claudeLat = (j['cla'] as num?)?.toDouble();
    e.claudeLng = (j['clo'] as num?)?.toDouble();
    e.claudePlace = j['cp'] as String?;
    return e;
  }
}

/// 절대경로 → CacheEntry. `~/Library/Application Support/photo_manager/analysis_cache.json`.
class AnalysisCache {
  final Map<String, CacheEntry> _map = {};
  File? _file;
  bool _dirty = false;

  Future<File?> _resolve() async {
    if (_file != null) return _file;
    final home = Platform.environment['HOME'];
    if (home == null) return null;
    final dir = Directory(p.join(home, 'Library', 'Application Support', 'photo_manager'));
    await dir.create(recursive: true);
    _file = File(p.join(dir.path, 'analysis_cache.json'));
    return _file;
  }

  Future<void> load() async {
    final f = await _resolve();
    if (f == null || !await f.exists()) return;
    try {
      final raw = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      raw.forEach((k, v) => _map[k] = CacheEntry.fromJson(v as Map<String, dynamic>));
    } catch (_) {}
  }

  /// 파일이 일치하는 유효한 엔트리. 없거나 변경됐으면 새 엔트리를 만들어 등록.
  CacheEntry entryFor(String path, int mtimeMs, int size) {
    final e = _map[path];
    if (e != null && e.validFor(mtimeMs, size)) return e;
    final fresh = CacheEntry(mtimeMs, size);
    _map[path] = fresh;
    _dirty = true;
    return fresh;
  }

  CacheEntry? peek(String path, int mtimeMs, int size) {
    final e = _map[path];
    return (e != null && e.validFor(mtimeMs, size)) ? e : null;
  }

  void markDirty() => _dirty = true;

  Future<void> save() async {
    if (!_dirty) return;
    final f = await _resolve();
    if (f == null) return;
    try {
      await f.writeAsString(jsonEncode({for (final e in _map.entries) e.key: e.value.toJson()}));
      _dirty = false;
    } catch (_) {}
  }
}
