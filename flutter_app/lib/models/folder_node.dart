import 'package:path/path.dart' as p;

import 'folder_group.dart';

/// 사이드바 디렉토리 트리 노드.
class FolderNode {
  final String name; // 폴더명(세그먼트)
  final String path; // 절대 경로
  final int? folderIndex; // 직접 사진이 있는 폴더면 _folders의 인덱스
  final int directCount; // 이 폴더에 직접 든 사진 수
  final List<FolderNode> children;

  const FolderNode({
    required this.name,
    required this.path,
    required this.folderIndex,
    required this.directCount,
    required this.children,
  });

  int get totalCount =>
      directCount + children.fold(0, (s, c) => s + c.totalCount);
  bool get hasChildren => children.isNotEmpty;
}

class _Mut {
  String name;
  String path;
  int? folderIndex;
  int direct = 0;
  final Map<String, _Mut> kids = {};
  _Mut(this.name, this.path);

  _Mut child(String n, String pth) => kids.putIfAbsent(n, () => _Mut(n, pth));

  FolderNode freeze() {
    final cs = kids.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return FolderNode(
      name: name,
      path: path,
      folderIndex: folderIndex,
      directCount: direct,
      // 미디어가 하나도 없는 하위 폴더(빈 서브트리)는 트리에서 숨긴다.
      children: cs.map((m) => m.freeze()).where((n) => n.totalCount > 0).toList(),
    );
  }
}

/// 모든 디렉토리(빈 폴더 포함) + 이미지 폴더 정보로 디렉토리 트리를 만든다.
List<FolderNode> buildFolderTree(String root, List<FolderGroup> folders, List<String> allDirs) {
  final rootM = _Mut(p.basename(root), root);
  final byPath = <String, _Mut>{root: rootM};

  _Mut nodeFor(String dirPath) {
    final existing = byPath[dirPath];
    if (existing != null) return existing;
    final parent = nodeFor(p.dirname(dirPath));
    final m = parent.child(p.basename(dirPath), dirPath);
    byPath[dirPath] = m;
    return m;
  }

  for (final d in allDirs) {
    if (p.isWithin(root, d)) nodeFor(d);
  }
  for (var i = 0; i < folders.length; i++) {
    final fg = folders[i];
    // 멀티루트: 이 루트에 속한 폴더만 (다른 루트의 폴더는 건너뜀)
    if (fg.path != root && !p.isWithin(root, fg.path)) continue;
    final m = nodeFor(fg.path);
    m.folderIndex = i;
    m.direct = fg.count;
  }
  return [rootM.freeze()];
}
