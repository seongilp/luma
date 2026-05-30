import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../models/folder_group.dart';
import '../models/photo_item.dart';
import '../models/photo_meta.dart';
import '../models/sort_filter.dart';
import '../services/file_ops.dart';
import '../services/geo.dart';
import '../services/similarity.dart';
import '../services/vision_service.dart';

/// 지도에 표시할 위치가 있는 사진 한 장.
typedef LocatedPhoto = ({String path, LatLng pos, bool estimated});

/// 사이드바에서 무엇을 보고 있는지.
enum LibraryView { all, favorites, similar, map, folder }

/// 유사 사진 분석 방식.
enum SimilarMode { ai, hash }

extension SimilarModeLabel on SimilarMode {
  String get label => this == SimilarMode.ai ? 'AI (정교)' : '해시 (빠름)';
}

/// 앱 전역 상태: 보기 선택(스마트/폴더), 보기 옵션(정렬·필터·검색·썸네일크기),
/// 다중 선택, 사용자 메타데이터, 파일 작업.
class AppState extends ChangeNotifier {
  final MetaStore meta = MetaStore();

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

  // 다중 선택 (절대 경로)
  final Set<String> _selection = {};
  String? _anchor;

  // 유사 사진 분석
  List<List<PhotoItem>> _similarGroups = [];
  bool _analyzing = false;
  double _analyzeProgress = 0;
  SimilarMode _similarMode = SimilarMode.ai;
  bool _usedFallback = false;

  // 위치/지도
  final Map<String, LatLng> _geo = {}; // EXIF GPS (실제)
  final Map<String, LatLng> _estimatedGeo = {}; // 유사 사진으로 추정
  bool _geoLoading = false;
  double _geoProgress = 0;

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
  double get analyzeProgress => _analyzeProgress;
  SimilarMode get similarMode => _similarMode;
  bool get usedFallback => _usedFallback;

  bool get geoLoading => _geoLoading;
  double get geoProgress => _geoProgress;
  int get realLocationCount => _geo.length;
  int get estimatedLocationCount => _estimatedGeo.length;

  /// 지도에 찍을 사진들(실제 GPS + 추정).
  List<LocatedPhoto> get locatedPhotos {
    final out = <LocatedPhoto>[];
    for (final it in _allItems) {
      final real = _geo[it.path];
      if (real != null) {
        out.add((path: it.path, pos: real, estimated: false));
        continue;
      }
      final est = _estimatedGeo[it.path];
      if (est != null) out.add((path: it.path, pos: est, estimated: true));
    }
    return out;
  }

  /// 현재 사이드바 선택의 표시 이름 (툴바 제목용).
  String get viewTitle => switch (_view) {
        LibraryView.all => '모든 사진',
        LibraryView.favorites => '즐겨찾기',
        LibraryView.similar => '유사 사진',
        LibraryView.map => '지도',
        LibraryView.folder => selectedFolder?.displayName ?? '',
      };

  /// 정렬/검색 전, 현재 보기의 원본 항목들.
  List<PhotoItem> get _baseItems => switch (_view) {
        LibraryView.all => _allItems,
        LibraryView.favorites =>
          _allItems.where((it) => meta.get(it.path).favorite).toList(),
        LibraryView.similar => _similarGroups.expand((g) => g).toList(),
        LibraryView.map => const [],
        LibraryView.folder => selectedFolder?.items ?? const [],
      };

  List<PhotoItem> get visibleItems => _visible;

  // ── 초기화 / 스캔 ──────────────────────────────────────────
  Future<void> init() async {
    await meta.load();
  }

  Future<void> openRoot(String path) async {
    _root = path;
    _loading = true;
    _error = null;
    _folders = [];
    _allItems = [];
    _similarGroups = [];
    _geo.clear();
    _estimatedGeo.clear();
    _view = LibraryView.all;
    _selectedFolder = 0;
    _selection.clear();
    notifyListeners();

    try {
      _folders = await scanFolders(path);
      _allItems = _folders.expand((f) => f.items).toList();
      _error = _folders.isEmpty ? '이 폴더에서 이미지를 찾지 못했습니다.' : null;
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
    _geo.clear();
    _estimatedGeo.clear();
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
      final pos = await readGps(_allItems[i].path);
      if (pos != null) _geo[_allItems[i].path] = pos;
      if (i % 8 == 0 || i == _allItems.length - 1) {
        _geoProgress = (i + 1) / _allItems.length;
        notifyListeners();
      }
    }
    _geoLoading = false;
    notifyListeners();
  }

  /// ④ 유사 사진 묶음을 이용해, GPS 없는 사진에 같은 묶음의 GPS를 전파(추정).
  Future<void> propagateLocations() async {
    if (_similarGroups.isEmpty) {
      await analyzeSimilar();
    }
    _estimatedGeo.clear();
    for (final group in _similarGroups) {
      // 묶음 안에서 실제 GPS가 있는 대표 위치를 찾는다.
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
    notifyListeners();
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

  /// 전체 사진을 분석해 유사 묶음을 만든다.
  /// AI(Vision) 모드는 네이티브 호출, 실패 시 해시로 폴백. 해시 모드는 진행률 알림.
  Future<void> analyzeSimilar() async {
    if (_analyzing || _allItems.isEmpty) return;
    _analyzing = true;
    _analyzeProgress = 0;
    _usedFallback = false;
    notifyListeners();

    List<List<PhotoItem>>? groups;
    if (_similarMode == SimilarMode.ai) {
      groups = await VisionService.similarGroups(_allItems);
      if (groups == null) _usedFallback = true; // Vision 실패 → 해시
    }
    groups ??= await findSimilarGroups(
      _allItems,
      onProgress: (p) {
        _analyzeProgress = p;
        notifyListeners();
      },
    );

    _similarGroups = groups;
    _analyzing = false;
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

  Future<void> deleteOne(String path) async {
    final failed = await FileOps.moveToTrash([path]);
    if (!failed.contains(path)) await meta.remove(path);
    await _rescanKeepingFolder();
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
