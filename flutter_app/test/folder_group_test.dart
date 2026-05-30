import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_manager/models/folder_group.dart';

void main() {
  test('isSupportedImage: 확장자 판별', () {
    expect(isSupportedImage('a.jpg'), isTrue);
    expect(isSupportedImage('A.PNG'), isTrue);
    expect(isSupportedImage('b.jpeg'), isTrue);
    expect(isSupportedImage('doc.txt'), isFalse);
    expect(isSupportedImage('noext'), isFalse);
  });

  test('scanFolders: 재귀 스캔 + 폴더별 그룹화', () async {
    final tmp = await Directory.systemTemp.createTemp('photo_test');
    addTearDown(() => tmp.delete(recursive: true));

    await File('${tmp.path}/a.jpg').writeAsBytes([0]);
    await File('${tmp.path}/b.txt').writeAsString('x');
    await Directory('${tmp.path}/sub').create();
    await File('${tmp.path}/sub/c.png').writeAsBytes([0]);
    await File('${tmp.path}/sub/d.jpeg').writeAsBytes([0]);

    final result = await scanFolders(tmp.path);
    final groups = result.folders;

    // 루트(이미지 1) + sub(이미지 2) = 폴더 2개
    expect(groups.length, 2);
    final total = groups.fold<int>(0, (s, g) => s + g.count);
    expect(total, 3);
    // 디렉토리 목록에 sub 포함
    expect(result.dirs.any((d) => d.endsWith('sub')), isTrue);
  });
}
