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
      children: cs.map((m) => m.freeze()).toList(),
    );
  }
}

/// 스캔된 폴더 목록으로 디렉토리 트리를 만든다 (중간 디렉토리 포함).
List<FolderNode> buildFolderTree(String root, List<FolderGroup> folders) {
  final rootM = _Mut(p.basename(root), root);
  for (var i = 0; i < folders.length; i++) {
    final fg = folders[i];
    if (fg.path == root) {
      rootM.folderIndex = i;
      rootM.direct = fg.count;
      continue;
    }
    final rel = p.relative(fg.path, from: root);
    var node = rootM;
    var cur = root;
    for (final seg in p.split(rel)) {
      cur = p.join(cur, seg);
      node = node.child(seg, cur);
    }
    node.folderIndex = i;
    node.direct = fg.count;
  }
  return [rootM.freeze()];
}
