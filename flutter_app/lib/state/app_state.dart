import 'package:flutter/foundation.dart';

import '../models/folder_group.dart';
import '../models/photo_item.dart';
import '../models/photo_meta.dart';
import '../models/sort_filter.dart';
import '../services/file_ops.dart';

/// 앱 전역 상태: 폴더/선택폴더, 보기 옵션(정렬·필터·검색·썸네일크기),
/// 다중 선택, 사용자 메타데이터, 파일 작업.
class AppState extends ChangeNotifier {
  final MetaStore meta = MetaStore();

  String? _root;
  List<FolderGroup> _folders = [];
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
    _selectedFolder = 0;
    _selection.clear();
    notifyListeners();

    try {
      _folders = await scanFolders(path);
      _error = _folders.isEmpty ? '이 폴더에서 이미지를 찾지 못했습니다.' : null;
    } catch (e) {
      _error = '폴더를 읽을 수 없습니다: $e';
      _folders = [];
    } finally {
      _loading = false;
      _recompute();
    }
  }

  Future<void> _rescanKeepingFolder() async {
    final keepPath = selectedFolder?.path;
    _folders = await scanFolders(_root!);
    if (keepPath != null) {
      final idx = _folders.indexWhere((f) => f.path == keepPath);
      _selectedFolder = idx >= 0 ? idx : 0;
    }
    _selection.clear();
    _recompute();
  }

  void selectFolder(int index) {
    if (index < 0 || index >= _folders.length || index == _selectedFolder) return;
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
      selectedFolder?.items ?? const [],
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
