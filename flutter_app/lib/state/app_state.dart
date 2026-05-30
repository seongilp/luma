import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../models/app_settings.dart';
import '../models/folder_group.dart';
import '../services/analysis_cache.dart';
import '../models/photo_item.dart';
import '../models/photo_meta.dart';
import '../models/sort_filter.dart';
import '../services/claude_service.dart';
import '../services/exif_reader.dart';
import '../services/file_ops.dart';
import '../services/geo.dart';
import '../services/metadata_service.dart';
import '../services/similarity.dart';
import '../services/vector_ops.dart';
import '../services/vision_service.dart';

/// 유사도로 같은 묶음으로 볼 Vision 벡터 거리 임계값.
const double _kSimilarThreshold = 0.6;

/// 내용 기반 위치추정: 이 거리 안에 GPS 사진이 있으면 같은 장소로 본다.
const double _kLocationThreshold = 0.9;

/// 얼굴 근사 임베딩 거리 임계값 (같은 사람 판단). 근사라 다소 보수적.
const double _kFaceThreshold = 0.7;

/// 위치 출처: 실제 GPS / 사진내용(Vision 매칭) / Claude(클라우드).
enum LocationKind { gps, content, claude }

/// 지도에 표시할 위치가 있는 사진 한 장.
typedef LocatedPhoto = ({String path, LatLng pos, LocationKind kind});

/// 사이드바에서 무엇을 보고 있는지.
enum LibraryView { all, favorites, similar, map, dates, people, stats, folder }

/// 날짜 섹션(하루)과 그날 사진들.
typedef DateSection = ({DateTime day, List<PhotoItem> items});

/// 요일별 통계 한 줄(기간). values[0]=일 ~ values[6]=토, 요일당 평균 사진 수.
typedef WeekdayStat = ({String label, List<double> values});

/// 사진 영역 표시 방식: 그리드 / 리스트(Manage).
enum GridMode { grid, list }

/// 유사 사진 분석 방식.
enum SimilarMode { ai, hash }

extension SimilarModeLabel on SimilarMode {
  String get label => this == SimilarMode.ai ? 'AI (정교)' : '해시 (빠름)';
}

/// 앱 전역 상태: 보기 선택(스마트/폴더), 보기 옵션(정렬·필터·검색·썸네일크기),
/// 다중 선택, 사용자 메타데이터, 파일 작업.
class AppState extends ChangeNotifier {
  final MetaStore meta = MetaStore();
  final AnalysisCache _cache = AnalysisCache();

  String? _root;
  List<FolderGroup> _folders = [];
  List<PhotoItem> _allItems = [];
  LibraryView _view = LibraryView.all;
  int _selectedFolder = 0;
  bool _loading = false;
  String? _error;

  // 보기 옵션
  String _query = '';
  SortField _sortField = SortField.name;
  bool _ascending = true;
  RatingFilter _ratingFilter = RatingFilter.all;
  double _thumbSize = 160;
  GridMode _gridMode = GridMode.grid;

  // 다중 선택 (절대 경로)
  final Set<String> _selection = {};
  String? _anchor;

  // 유사 사진 분석
  List<List<PhotoItem>> _similarGroups = [];
  bool _analyzing = false;
  SimilarMode _similarMode = SimilarMode.ai;
  bool _usedFallback = false;

  // Vision 특징벡터 캐시 (유사도 + 내용기반 위치추정 공용)
  final Map<String, List<double>> _vectors = {};

  // 날짜별 앨범 (촬영일, 없으면 파일 수정일)
  final Map<String, DateTime> _dates = {};
  bool _datesLoaded = false;

  // 인물(얼굴) 분류
  List<List<PhotoItem>> _personGroups = [];
  bool _peopleLoaded = false;

  // 진행 상태(분석 화면용): 무엇을·몇 번째·어떤 파일
  String _progressPhase = '';
  int _progressIndex = 0;
  int _progressTotal = 0;
  String? _progressPath;

  // 위치/지도
  final Map<String, LatLng> _geo = {}; // EXIF GPS (실제)
  final Map<String, LatLng> _estimatedGeo = {}; // 사진내용(Vision)으로 추정
  final Map<String, LatLng> _claudeGeo = {}; // Claude(클라우드)로 추정
  final Map<String, String> _claudePlace = {}; // Claude가 본 장소명
  bool _geoLoading = false;
  double _geoProgress = 0;

  // 설정 (Claude 자격증명·호출 상한). 저장소에서 로드, env로 폴백.
  final SettingsStore _settingsStore = SettingsStore();
  AppSettings _settings = AppSettings();

  ClaudeConfig _claudeConfig() {
    final env = Platform.environment;
    String pick(String s, String e) => s.isNotEmpty ? s : (env[e] ?? '');
    final base = pick(_settings.anthropicBaseUrl, 'ANTHROPIC_BASE_URL');
    return ClaudeConfig(
      baseUrl: (base.isEmpty ? 'https://api.anthropic.com' : base).replaceAll(RegExp(r'/$'), ''),
      apiKey: pick(_settings.anthropicApiKey, 'ANTHROPIC_API_KEY'),
      cfToken: pick(_settings.cfToken, 'CF_AIG_TOKEN'),
    );
  }

  ClaudeService get _claude => ClaudeService(_claudeConfig());

  List<PhotoItem> _visible = [];

  // ── getters ────────────────────────────────────────────────
  String? get root => _root;
  List<FolderGroup> get folders => _folders;
  int get selectedIndex => _selectedFolder;
  bool get loading => _loading;
  String? get error => _error;

  String get query => _query;
  SortField get sortField => _sortField;
  bool get ascending => _ascending;
  RatingFilter get ratingFilter => _ratingFilter;
  double get thumbSize => _thumbSize;
  GridMode get gridMode => _gridMode;

  void setGridMode(GridMode m) {
    if (m == _gridMode) return;
    _gridMode = m;
    notifyListeners();
  }

  Set<String> get selection => _selection;
  int get selectedCount => _selection.length;
  bool isSelected(String path) => _selection.contains(path);

  FolderGroup? get selectedFolder =>
      _folders.isEmpty ? null : _folders[_selectedFolder.clamp(0, _folders.length - 1)];

  LibraryView get view => _view;
  bool get isFolderView => _view == LibraryView.folder;

  int get allCount => _allItems.length;
  int get favoriteCount =>
      _allItems.where((it) => meta.get(it.path).favorite).length;

  List<List<PhotoItem>> get similarGroups => _similarGroups;
  int get similarPhotoCount =>
      _similarGroups.fold(0, (s, g) => s + g.length);
  bool get analyzing => _analyzing;
  SimilarMode get similarMode => _similarMode;
  bool get usedFallback => _usedFallback;

  // 진행 상태 getter (분석 오버레이용)
  String get progressPhase => _progressPhase;
  int get progressIndex => _progressIndex;
  int get progressTotal => _progressTotal;
  String? get progressPath => _progressPath;
  double get progressFraction =>
      _progressTotal == 0 ? 0 : _progressIndex / _progressTotal;

  bool get geoLoading => _geoLoading;
  double get geoProgress => _geoProgress;
  int get realLocationCount => _geo.length;
  int get estimatedLocationCount => _estimatedGeo.length;
  int get claudeLocationCount => _claudeGeo.length;
  bool get claudeConfigured => _claude.config.isConfigured;

  String? claudePlaceFor(String path) => _claudePlace[path];

  bool _claudeTried(PhotoItem it) =>
      _cache.peek(it.path, it.modified.millisecondsSinceEpoch, it.sizeBytes)?.claudeChecked ?? false;

  /// 아직 위치가 없고 Claude도 안 시도한(=Claude 후보) 사진 수.
  int get unlocatedCount => _allItems
      .where((it) =>
          !_geo.containsKey(it.path) &&
          !_estimatedGeo.containsKey(it.path) &&
          !_claudeGeo.containsKey(it.path) &&
          !_claudeTried(it))
      .length;

  /// 지도에 찍을 사진들. 우선순위: 실제 GPS > 사진내용 추정 > Claude 추정.
  List<LocatedPhoto> get locatedPhotos {
    final out = <LocatedPhoto>[];
    for (final it in _allItems) {
      final real = _geo[it.path];
      if (real != null) {
        out.add((path: it.path, pos: real, kind: LocationKind.gps));
        continue;
      }
      final est = _estimatedGeo[it.path];
      if (est != null) {
        out.add((path: it.path, pos: est, kind: LocationKind.content));
        continue;
      }
      final cl = _claudeGeo[it.path];
      if (cl != null) out.add((path: it.path, pos: cl, kind: LocationKind.claude));
    }
    return out;
  }

  List<List<PhotoItem>> get personGroups => _personGroups;
  int get personCount => _personGroups.length;

  DateTime _dateOf(PhotoItem it) => _dates[it.path] ?? it.modified;

  /// 요일별 통계: 기간별 '요일당 평균 사진 수'(길이 다른 기간을 비교 가능하게 정규화).
  /// 비교: 이번 주 · 지난주 · 지난달 · 작년(같은 시기).
  List<WeekdayStat> get weekdayStats {
    final now = DateTime.now();
    DateTime atDay(int daysAgo) => DateTime(now.year, now.month, now.day - daysAgo);

    WeekdayStat window(String label, int startDaysAgo, int endDaysAgo) {
      final start = atDay(startDaysAgo);
      final endExclusive = atDay(endDaysAgo).add(const Duration(days: 1));
      final sums = List<int>.filled(7, 0);
      final dayCounts = List<int>.filled(7, 0);
      for (var d = start; d.isBefore(endExclusive); d = d.add(const Duration(days: 1))) {
        dayCounts[d.weekday % 7] += 1;
      }
      for (final it in _allItems) {
        final dt = _dateOf(it);
        if (dt.isBefore(start) || !dt.isBefore(endExclusive)) continue;
        sums[dt.weekday % 7] += 1;
      }
      return (
        label: label,
        values: [for (var w = 0; w < 7; w++) dayCounts[w] == 0 ? 0.0 : sums[w] / dayCounts[w]],
      );
    }

    return [
      window('이번 주', 6, 0),
      window('지난주', 13, 7),
      window('지난달', 37, 8),
      window('작년', 380, 350),
    ];
  }

  /// 날짜 내림차순 섹션(하루 단위).
  List<DateSection> get dateSections {
    final byDay = <DateTime, List<PhotoItem>>{};
    for (final it in _allItems) {
      final d = _dates[it.path] ?? it.modified;
      final day = DateTime(d.year, d.month, d.day);
      byDay.putIfAbsent(day, () => []).add(it);
    }
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
    return [for (final day in days) (day: day, items: byDay[day]!)];
  }

  /// 현재 사이드바 선택의 표시 이름 (툴바 제목용).
  String get viewTitle => switch (_view) {
        LibraryView.all => '모든 사진',
        LibraryView.favorites => '즐겨찾기',
        LibraryView.similar => '유사 사진',
        LibraryView.map => '지도',
        LibraryView.dates => '날짜별',
        LibraryView.people => '인물',
        LibraryView.stats => '통계',
        LibraryView.folder => selectedFolder?.displayName ?? '',
      };

  /// 정렬/검색 전, 현재 보기의 원본 항목들.
  List<PhotoItem> get _baseItems => switch (_view) {
        LibraryView.all => _allItems,
        LibraryView.favorites =>
          _allItems.where((it) => meta.get(it.path).favorite).toList(),
        LibraryView.similar => _similarGroups.expand((g) => g).toList(),
        LibraryView.map => const [],
        LibraryView.dates => _allItems,
        LibraryView.people => _personGroups.expand((g) => g).toList(),
        LibraryView.stats => const [],
        LibraryView.folder => selectedFolder?.items ?? const [],
      };

  List<PhotoItem> get visibleItems => _visible;

  AppSettings get settings => _settings;

  // ── 접근성: 전체 UI 배율 ──────────────────────────────────
  double get uiScale => _settings.uiScale;

  void setUiScale(double s) {
    final c = s.clamp(1.0, 2.0);
    if (c == _settings.uiScale) return;
    _settings = _settings.copyWith(uiScale: c);
    _settingsStore.save(_settings);
    notifyListeners();
  }

  void zoomInUi() => setUiScale(uiScale + 0.15);
  void zoomOutUi() => setUiScale(uiScale - 0.15);
  void resetUiScale() => setUiScale(1.0);

  Future<void> updateSettings(AppSettings s) async {
    _settings = s;
    await _settingsStore.save(s);
    notifyListeners();
  }

  // ── 초기화 / 스캔 ──────────────────────────────────────────
  Future<void> init() async {
    _settings = await _settingsStore.load();
    await meta.load();
    await _cache.load();
    notifyListeners();
  }

  /// 캐시에서 분석 결과를 미리 채운다 (재계산·재과금 방지).
  void _hydrateFromCache() {
    for (final it in _allItems) {
      final e = _cache.peek(it.path, it.modified.millisecondsSinceEpoch, it.sizeBytes);
      if (e == null) continue;
      if (e.vector != null) _vectors[it.path] = e.vector!;
      if (e.gpsChecked && e.lat != null && e.lng != null) {
        _geo[it.path] = LatLng(e.lat!, e.lng!);
      }
      if (e.takenChecked && e.taken != null) {
        final d = DateTime.tryParse(e.taken!);
        if (d != null) _dates[it.path] = d;
      }
      if (e.claudeChecked && e.claudeLat != null && e.claudeLng != null) {
        _claudeGeo[it.path] = LatLng(e.claudeLat!, e.claudeLng!);
        if (e.claudePlace != null) _claudePlace[it.path] = e.claudePlace!;
      }
    }
  }

  CacheEntry _entry(PhotoItem it) =>
      _cache.entryFor(it.path, it.modified.millisecondsSinceEpoch, it.sizeBytes);

  Future<void> openRoot(String path) async {
    _root = path;
    _loading = true;
    _error = null;
    _folders = [];
    _allItems = [];
    _similarGroups = [];
    _vectors.clear();
    _dates.clear();
    _datesLoaded = false;
    _personGroups = [];
    _peopleLoaded = false;
    _geo.clear();
    _estimatedGeo.clear();
    _claudeGeo.clear();
    _claudePlace.clear();
    _view = LibraryView.all;
    _selectedFolder = 0;
    _selection.clear();
    notifyListeners();

    try {
      _folders = await scanFolders(path);
      _allItems = _folders.expand((f) => f.items).toList();
      _hydrateFromCache(); // 이전 분석 결과 복원
      _error = _folders.isEmpty ? '이 폴더에서 이미지를 찾지 못했습니다.' : null;
      if (_folders.isNotEmpty) {
        _settings = _settings.copyWith(lastRoot: path);
        _settingsStore.save(_settings); // 마지막 폴더 기억
      }
    } catch (e) {
      _error = '폴더를 읽을 수 없습니다: $e';
      _folders = [];
      _allItems = [];
    } finally {
      _loading = false;
      _recompute();
    }
  }

  Future<void> _rescanKeepingFolder() async {
    final keepPath = selectedFolder?.path;
    _folders = await scanFolders(_root!);
    _allItems = _folders.expand((f) => f.items).toList();
    _similarGroups = []; // 파일이 바뀌었으니 무효화
    _vectors.clear();
    _dates.clear();
    _datesLoaded = false;
    _personGroups = [];
    _peopleLoaded = false;
    _geo.clear();
    _estimatedGeo.clear();
    _claudeGeo.clear();
    _claudePlace.clear();
    if (keepPath != null) {
      final idx = _folders.indexWhere((f) => f.path == keepPath);
      _selectedFolder = idx >= 0 ? idx : 0;
    }
    _selection.clear();
    if (_view == LibraryView.similar) {
      await analyzeSimilar();
    } else {
      _recompute();
    }
  }

  void showAllPhotos() {
    _view = LibraryView.all;
    _selection.clear();
    _anchor = null;
    _recompute();
  }

  void showFavorites() {
    _view = LibraryView.favorites;
    _selection.clear();
    _anchor = null;
    _recompute();
  }

  Future<void> showSimilar() async {
    _view = LibraryView.similar;
    _selection.clear();
    _anchor = null;
    notifyListeners();
    if (_similarGroups.isEmpty && !_analyzing) {
      await analyzeSimilar();
    } else {
      _recompute();
    }
  }

  Future<void> showDates() async {
    _view = LibraryView.dates;
    _selection.clear();
    _anchor = null;
    notifyListeners();
    if (!_datesLoaded && !_analyzing) await loadDates();
  }

  /// 모든 사진의 촬영일(EXIF, 없으면 수정일)을 읽는다.
  Future<void> loadDates() async {
    if (_analyzing || _allItems.isEmpty) return;
    _analyzing = true;
    notifyListeners();
    for (var i = 0; i < _allItems.length; i++) {
      _setProgress('날짜 읽는 중', i + 1, _allItems.length, _allItems[i].path);
      final it = _allItems[i];
      final e = _entry(it);
      if (e.takenChecked) {
        if (e.taken != null) {
          _dates[it.path] = DateTime.tryParse(e.taken!) ?? it.modified;
        }
      } else {
        final d = await readTakenDate(it.path);
        e.takenChecked = true;
        e.taken = d?.toIso8601String();
        if (d != null) _dates[it.path] = d;
        _cache.markDirty();
      }
    }
    await _cache.save();
    _datesLoaded = true;
    _analyzing = false;
    _clearProgress();
    notifyListeners();
  }

  void showStats() {
    _view = LibraryView.stats;
    _selection.clear();
    _anchor = null;
    notifyListeners();
  }

  Future<void> showPeople() async {
    _view = LibraryView.people;
    _selection.clear();
    _anchor = null;
    notifyListeners();
    if (!_peopleLoaded && !_analyzing) await analyzeFaces();
  }

  /// 모든 사진에서 얼굴을 검출·임베딩해 같은 사람끼리 묶는다 (근사).
  Future<void> analyzeFaces() async {
    if (_analyzing || _allItems.isEmpty) return;
    _analyzing = true;
    notifyListeners();

    // 모든 얼굴 벡터 수집 (어떤 사진의 얼굴인지 함께)
    final faceVecs = <List<double>>[];
    final facePhoto = <PhotoItem>[];
    for (var i = 0; i < _allItems.length; i++) {
      _setProgress('인물(얼굴) 인식', i + 1, _allItems.length, _allItems[i].path);
      final it = _allItems[i];
      final e = _entry(it);
      List<List<double>> faces;
      if (e.faces != null) {
        faces = e.faces!; // 캐시
      } else {
        final detected = await VisionService.faces(it.path);
        faces = [for (final f in detected) f.vector];
        e.faces = faces;
        _cache.markDirty();
      }
      for (final v in faces) {
        faceVecs.add(v);
        facePhoto.add(it);
      }
    }
    await _cache.save();

    // 얼굴 벡터 클러스터링 → 사람별 사진 묶음(사진 중복 제거)
    final parts = partitionByDistance(faceVecs, _kFaceThreshold);
    final groups = <List<PhotoItem>>[];
    for (final part in parts) {
      final seen = <String>{};
      final photos = <PhotoItem>[];
      for (final idx in part) {
        final it = facePhoto[idx];
        if (seen.add(it.path)) photos.add(it);
      }
      groups.add(photos);
    }
    groups.sort((a, b) => b.length.compareTo(a.length));

    _personGroups = groups;
    _peopleLoaded = true;
    _analyzing = false;
    _clearProgress();
    _recompute();
  }

  Future<void> showMap() async {
    _view = LibraryView.map;
    _selection.clear();
    _anchor = null;
    notifyListeners();
    if (_geo.isEmpty && _estimatedGeo.isEmpty && !_geoLoading) {
      await loadGeo();
    }
  }

  /// 모든 사진의 EXIF GPS를 읽어 위치를 모은다 (진행률 알림).
  Future<void> loadGeo() async {
    if (_geoLoading || _allItems.isEmpty) return;
    _geoLoading = true;
    _geoProgress = 0;
    _geo.clear();
    notifyListeners();
    for (var i = 0; i < _allItems.length; i++) {
      _setProgress('위치(GPS) 읽는 중', i + 1, _allItems.length, _allItems[i].path);
      final it = _allItems[i];
      final e = _entry(it);
      if (e.gpsChecked) {
        if (e.lat != null && e.lng != null) _geo[it.path] = LatLng(e.lat!, e.lng!);
      } else {
        final pos = await readGps(it.path);
        e.gpsChecked = true;
        if (pos != null) {
          e.lat = pos.latitude;
          e.lng = pos.longitude;
          _geo[it.path] = pos;
        }
        _cache.markDirty();
      }
      _geoProgress = (i + 1) / _allItems.length;
    }
    await _cache.save();
    _geoLoading = false;
    _clearProgress();
    notifyListeners();
  }

  /// ④ 사진 내용(Vision 특징벡터)으로 위치 추정.
  /// GPS 없는 사진을, 라이브러리의 GPS 사진들과 시각적으로 비교해
  /// 가장 비슷한(같은 장소로 판단되는) 사진의 위치를 부여한다.
  /// Vision 불가 시 유사 묶음 기반 전파로 폴백.
  Future<void> estimateLocations() async {
    if (_allItems.isEmpty || _analyzing) return;
    _analyzing = true;
    notifyListeners();

    final ok = await _ensureVectors('위치 분석 (사진 내용)');
    _estimatedGeo.clear();
    _claudeGeo.clear();
    _claudePlace.clear();

    if (ok) {
      final refs = [
        for (final it in _allItems)
          if (_geo.containsKey(it.path) && _vectors.containsKey(it.path)) it.path
      ];
      for (final it in _allItems) {
        if (_geo.containsKey(it.path)) continue;
        final v = _vectors[it.path];
        if (v == null) continue;
        var best = double.infinity;
        String? bestRef;
        for (final r in refs) {
          final d = l2Distance(v, _vectors[r]!);
          if (d < best) {
            best = d;
            bestRef = r;
          }
        }
        if (bestRef != null && best <= _kLocationThreshold) {
          _estimatedGeo[it.path] = _geo[bestRef]!;
        }
      }
    } else {
      // Vision 불가 → 기존 유사 묶음으로 위치 전파
      for (final group in _similarGroups) {
        LatLng? anchor;
        for (final it in group) {
          final g = _geo[it.path];
          if (g != null) {
            anchor = g;
            break;
          }
        }
        if (anchor == null) continue;
        for (final it in group) {
          if (!_geo.containsKey(it.path)) _estimatedGeo[it.path] = anchor;
        }
      }
    }

    _analyzing = false;
    _clearProgress();
    notifyListeners();
  }

  /// 위치 없는 사진을 Claude(클라우드)에 보낼 때, 비슷한 사진끼리 묶어
  /// **대표 1장만** 보내고 결과를 묶음 전체에 전파할 클러스터를 만든다.
  /// 반환: 대표를 보낼 묶음 목록(각 묶음의 첫 항목이 대표). Vision 불가 시 1장씩.
  Future<List<List<PhotoItem>>> _claudeClusters() async {
    final targets = [
      for (final it in _allItems)
        if (!_geo.containsKey(it.path) &&
            !_estimatedGeo.containsKey(it.path) &&
            !_claudeGeo.containsKey(it.path) &&
            !_claudeTried(it))
          it
    ];
    if (targets.isEmpty) return [];
    final ok = await _ensureVectors('사진 묶는 중 (Claude 준비)');
    if (!ok) return [for (final t in targets) [t]];
    final vecs = [for (final t in targets) _vectors[t.path]];
    final parts = partitionByDistance(vecs, _kLocationThreshold);
    return [for (final p in parts) [for (final i in p) targets[i]]];
  }

  /// Claude로 위치 추정. 비슷한 사진은 묶어 대표만 전송(토큰 절감) 후 전파.
  /// 호출 전 사용자 동의 필요(사진이 외부로 전송됨).
  Future<void> estimateLocationsWithClaude() async {
    if (_analyzing || !claudeConfigured) return;
    _analyzing = true;
    notifyListeners();

    var groups = await _claudeClusters();
    // 호출 상한: 큰 묶음(같은 장소 많이 찍은 곳) 우선으로 N개까지만.
    final cap = _settings.claudeMaxCalls;
    if (cap > 0 && groups.length > cap) {
      groups = ([...groups]..sort((a, b) => b.length.compareTo(a.length))).take(cap).toList();
    }
    for (var i = 0; i < groups.length; i++) {
      final rep = groups[i].first;
      _setProgress('위치 분석 (Claude)', i + 1, groups.length, rep.path);
      final loc = await _claude.identifyLocation(rep.path);
      final ok = loc != null && loc.hasCoords && loc.confidence >= 0.3;
      final pos = ok ? LatLng(loc.lat!, loc.lng!) : null;
      // 결과를 묶음 전체에 전파 + 캐시(시도 표시 → 재호출/재과금 방지)
      for (final member in groups[i]) {
        final e = _entry(member);
        e.claudeChecked = true;
        if (pos != null) {
          _claudeGeo[member.path] = pos;
          e.claudeLat = pos.latitude;
          e.claudeLng = pos.longitude;
          if (loc!.place != null) {
            _claudePlace[member.path] = loc.place!;
            e.claudePlace = loc.place;
          }
        }
        _cache.markDirty();
      }
    }
    await _cache.save();

    _analyzing = false;
    _clearProgress();
    notifyListeners();
  }

  /// AI 빠른 점검 (Claude). 자격증명 없으면 null.
  Future<String?> quickCheck(String path) async {
    if (!claudeConfigured) return null;
    return _claude.quickCheck(path);
  }

  void setSimilarMode(SimilarMode mode) {
    if (mode == _similarMode) return;
    _similarMode = mode;
    _similarGroups = [];
    if (_view == LibraryView.similar) {
      analyzeSimilar();
    } else {
      notifyListeners();
    }
  }

  void _setProgress(String phase, int index, int total, String? path) {
    _progressPhase = phase;
    _progressIndex = index;
    _progressTotal = total;
    _progressPath = path;
    // 매 항목마다 전체 리빌드하면 느려지므로 몇 개마다 + 마지막에만 알림.
    if (index % 4 == 0 || index >= total) notifyListeners();
  }

  void _clearProgress() {
    _progressPhase = '';
    _progressPath = null;
    _progressIndex = 0;
    _progressTotal = 0;
  }

  /// 모든 사진의 Vision 특징벡터를 확보해 캐시한다. Vision 자체가 안 되면 false.
  Future<bool> _ensureVectors(String phase) async {
    // 캐시(hydrate)로 이미 채워진 사진은 _vectors에 있으므로 자동 제외.
    final todo = [for (final it in _allItems) if (!_vectors.containsKey(it.path)) it];
    if (todo.isEmpty) return _vectors.isNotEmpty;
    for (var i = 0; i < todo.length; i++) {
      _setProgress(phase, i + 1, todo.length, todo[i].path);
      final v = await VisionService.featurePrint(todo[i].path);
      if (v == null) {
        if (i == 0 && _vectors.isEmpty) return false; // Vision 미지원
        continue;
      }
      _vectors[todo[i].path] = v;
      _entry(todo[i]).vector = v; // 캐시에 저장
      _cache.markDirty();
    }
    await _cache.save();
    return true;
  }

  /// 전체 사진을 분석해 유사 묶음을 만든다.
  /// AI 모드는 Vision 특징벡터로 클러스터링, 실패 시 해시로 폴백.
  Future<void> analyzeSimilar() async {
    if (_analyzing || _allItems.isEmpty) return;
    _analyzing = true;
    _usedFallback = false;
    notifyListeners();

    List<List<PhotoItem>>? groups;
    if (_similarMode == SimilarMode.ai) {
      final ok = await _ensureVectors('유사도 분석 (AI)');
      if (ok) {
        final vecs = [for (final it in _allItems) _vectors[it.path]];
        final idxGroups = clusterByDistance(vecs, _kSimilarThreshold);
        groups = [for (final g in idxGroups) [for (final i in g) _allItems[i]]];
      } else {
        _usedFallback = true;
      }
    }
    groups ??= await findSimilarGroups(
      _allItems,
      onProgress: (i, total, path) => _setProgress('유사도 분석 (해시)', i, total, path),
    );

    _similarGroups = groups;
    _analyzing = false;
    _clearProgress();
    _recompute();
  }

  void selectFolder(int index) {
    if (index < 0 || index >= _folders.length) return;
    _view = LibraryView.folder;
    _selectedFolder = index;
    _selection.clear();
    _anchor = null;
    _recompute();
  }

  // ── 보기 옵션 ─────────────────────────────────────────────
  void setQuery(String q) {
    _query = q;
    _recompute();
  }

  void setSort(SortField f) {
    _sortField = f;
    _recompute();
  }

  void toggleOrder() {
    _ascending = !_ascending;
    _recompute();
  }

  void setRatingFilter(RatingFilter f) {
    _ratingFilter = f;
    _selection.clear();
    _recompute();
  }

  void setThumbSize(double v) {
    _thumbSize = v;
    notifyListeners();
  }

  void _recompute() {
    _visible = applySortFilter(
      _baseItems,
      query: _query,
      field: _sortField,
      ascending: _ascending,
      ratingFilter: _ratingFilter,
      meta: meta,
    );
    // 더 이상 보이지 않는 선택 항목 정리
    _selection.removeWhere((p) => !_visible.any((it) => it.path == p));
    notifyListeners();
  }

  // ── 선택 ──────────────────────────────────────────────────
  void selectOnly(String path) {
    _selection
      ..clear()
      ..add(path);
    _anchor = path;
    notifyListeners();
  }

  void toggleSelect(String path) {
    if (!_selection.add(path)) _selection.remove(path);
    _anchor = path;
    notifyListeners();
  }

  void selectRange(String path) {
    final anchor = _anchor;
    if (anchor == null) {
      selectOnly(path);
      return;
    }
    final paths = _visible.map((e) => e.path).toList();
    final a = paths.indexOf(anchor);
    final b = paths.indexOf(path);
    if (a < 0 || b < 0) {
      selectOnly(path);
      return;
    }
    final lo = a < b ? a : b;
    final hi = a < b ? b : a;
    for (var i = lo; i <= hi; i++) {
      _selection.add(paths[i]);
    }
    notifyListeners();
  }

  void selectAll() {
    _selection
      ..clear()
      ..addAll(_visible.map((e) => e.path));
    notifyListeners();
  }

  void clearSelection() {
    if (_selection.isEmpty) return;
    _selection.clear();
    notifyListeners();
  }

  // ── 메타데이터 ────────────────────────────────────────────
  Future<void> toggleFavorite(String path) async {
    await meta.toggleFavorite(path);
    _recompute();
  }

  Future<void> setRating(String path, int rating) async {
    await meta.setRating(path, rating);
    _recompute();
  }

  /// 선택된 모든 항목 즐겨찾기 on/off (현재 전부 즐겨찾기면 해제).
  Future<void> favoriteSelected() async {
    if (_selection.isEmpty) return;
    final allFav = _selection.every((p) => meta.get(p).favorite);
    for (final p in _selection) {
      if (meta.get(p).favorite == allFav) await meta.toggleFavorite(p);
    }
    _recompute();
  }

  // ── 파일 작업 ─────────────────────────────────────────────
  Future<String?> deleteSelected() async {
    if (_selection.isEmpty) return null;
    final paths = _selection.toList();
    final failed = await FileOps.moveToTrash(paths);
    for (final p in paths) {
      if (!failed.contains(p)) await meta.remove(p);
    }
    await _rescanKeepingFolder();
    return failed.isEmpty ? null : '${failed.length}개를 삭제하지 못했습니다.';
  }

  Future<void> deleteOne(String path) async => deletePaths([path]);

  Future<void> deletePaths(List<String> paths) async {
    if (paths.isEmpty) return;
    final failed = await FileOps.moveToTrash(paths);
    for (final p in paths) {
      if (!failed.contains(p)) await meta.remove(p);
    }
    await _rescanKeepingFolder();
  }

  /// 묶음에서 가장 큰(고해상도일 가능성) 1장만 남기고 나머지를 휴지통으로.
  Future<void> keepBestInGroup(List<PhotoItem> group) async {
    if (group.length < 2) return;
    final sorted = [...group]..sort((a, b) => b.sizeBytes.compareTo(a.sizeBytes));
    await deletePaths([for (final it in sorted.skip(1)) it.path]);
  }

  /// 촬영일시·GPS를 무손실로 보정한다(EXIF 쓰기). 성공 시 재스캔으로 반영.
  Future<bool> correctMetadata(String path, {String? dateTime, double? lat, double? lng}) async {
    final ok = await MetadataService.writeMetadata(
      path,
      dateTime: dateTime,
      lat: lat,
      lng: lng,
    );
    if (ok) await _rescanKeepingFolder();
    return ok;
  }

  Future<String?> renameOne(String path, String newName) async {
    try {
      final np = await FileOps.rename(path, newName);
      await meta.rename(path, np);
      await _rescanKeepingFolder();
      return null;
    } catch (e) {
      return '이름을 바꾸지 못했습니다: $e';
    }
  }

  Future<void> moveSelected(String destDir) async {
    final moved = await FileOps.move(_selection.toList(), destDir);
    for (final e in moved.entries) {
      await meta.rename(e.key, e.value);
    }
    await _rescanKeepingFolder();
  }

  Future<void> copySelected(String destDir) async {
    await FileOps.copy(_selection.toList(), destDir);
    await _rescanKeepingFolder();
  }
}
