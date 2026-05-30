import 'package:flutter/foundation.dart';
import '../models/folder_group.dart';

/// 앱 전역 상태. root 폴더, 스캔된 폴더 그룹, 선택된 폴더를 보관한다.
class AppState extends ChangeNotifier {
  String? _root;
  List<FolderGroup> _folders = [];
  int _selected = 0;
  bool _loading = false;
  String? _error;

  String? get root => _root;
  List<FolderGroup> get folders => _folders;
  int get selectedIndex => _selected;
  bool get loading => _loading;
  String? get error => _error;

  FolderGroup? get selectedFolder =>
      _folders.isEmpty ? null : _folders[_selected.clamp(0, _folders.length - 1)];

  List<String> get currentImages => selectedFolder?.imagePaths ?? const [];

  Future<void> openRoot(String path) async {
    _root = path;
    _loading = true;
    _error = null;
    _folders = [];
    _selected = 0;
    notifyListeners();

    try {
      final groups = await scanFolders(path);
      _folders = groups;
      _error = groups.isEmpty ? '이 폴더에서 이미지를 찾지 못했습니다.' : null;
    } catch (e) {
      _error = '폴더를 읽을 수 없습니다: $e';
      _folders = [];
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void selectFolder(int index) {
    if (index < 0 || index >= _folders.length || index == _selected) return;
    _selected = index;
    notifyListeners();
  }
}
