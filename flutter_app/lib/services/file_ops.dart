import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

/// 로컬 파일 작업. 삭제는 영구 삭제 대신 **macOS 휴지통으로 이동**(복구 가능).
class FileOps {
  /// Finder에서 해당 파일을 선택해 보여준다.
  static Future<void> showInFinder(String path) async {
    try {
      await Process.run('open', ['-R', path]);
    } catch (_) {}
  }

  /// 선택 이미지를 JPEG/PNG로 내보낸다(선택적 긴 변 축소). 내보낸 개수 반환.
  static Future<int> exportImages(
    List<String> paths,
    String destDir, {
    required String format, // 'jpg' | 'png'
    int? maxDim,
  }) async {
    var n = 0;
    for (final src in paths) {
      try {
        final bytes = await File(src).readAsBytes();
        var image = img.decodeImage(bytes);
        if (image == null) continue;
        if (maxDim != null && (image.width > maxDim || image.height > maxDim)) {
          image = image.width >= image.height
              ? img.copyResize(image, width: maxDim)
              : img.copyResize(image, height: maxDim);
        }
        final out = format == 'png' ? img.encodePng(image) : img.encodeJpg(image, quality: 90);
        final base = p.basenameWithoutExtension(src);
        final target = await _uniqueTarget(destDir, '$base.$format');
        await File(target).writeAsBytes(out);
        n++;
      } catch (_) {}
    }
    return n;
  }

  /// 선택 항목들을 휴지통으로 보낸다. Finder를 통해 처리해 복구 가능.
  /// 실패한 경로 목록을 반환한다 (빈 리스트 = 전부 성공).
  static Future<List<String>> moveToTrash(List<String> paths) async {
    if (paths.isEmpty) return [];
    // argv로 경로를 넘겨 따옴표/특수문자 이스케이프 문제를 피한다.
    const script = [
      'on run argv',
      'set toDelete to {}',
      'repeat with f in argv',
      'set end of toDelete to (POSIX file (f as text) as alias)',
      'end repeat',
      'tell application "Finder" to delete toDelete',
      'end run',
    ];
    final args = <String>[];
    for (final line in script) {
      args..add('-e')..add(line);
    }
    args.addAll(paths);
    try {
      final r = await Process.run('osascript', args);
      if (r.exitCode != 0) return paths; // 통째 실패로 간주
      return [];
    } catch (_) {
      return paths;
    }
  }

  /// 같은 폴더 안에서 이름변경. 새 절대경로 반환. 충돌 시 예외.
  static Future<String> rename(String path, String newName) async {
    final dir = p.dirname(path);
    final target = p.join(dir, newName);
    if (target == path) return path;
    if (await File(target).exists() || await Directory(target).exists()) {
      throw FileSystemException('이미 같은 이름이 있습니다', target);
    }
    final f = await File(path).rename(target);
    return f.path;
  }

  /// 대상 폴더로 이동. 이름 충돌 시 " (n)" 접미사로 회피. (원경로 → 새경로) 맵 반환.
  static Future<Map<String, String>> move(List<String> paths, String destDir) =>
      _transfer(paths, destDir, copy: false);

  /// 대상 폴더로 복사. (원경로 → 새경로) 맵 반환.
  static Future<Map<String, String>> copy(List<String> paths, String destDir) =>
      _transfer(paths, destDir, copy: true);

  static Future<Map<String, String>> _transfer(
    List<String> paths,
    String destDir, {
    required bool copy,
  }) async {
    final result = <String, String>{};
    for (final src in paths) {
      if (p.dirname(src) == destDir && !copy) continue; // 같은 곳으로 이동은 무시
      final target = await _uniqueTarget(destDir, p.basename(src));
      try {
        if (copy) {
          await File(src).copy(target);
        } else {
          await File(src).rename(target);
        }
        result[src] = target;
      } catch (_) {/* 개별 실패는 건너뜀 */}
    }
    return result;
  }

  static Future<String> _uniqueTarget(String dir, String name) async {
    var target = p.join(dir, name);
    if (!await File(target).exists()) return target;
    final stem = p.basenameWithoutExtension(name);
    final ext = p.extension(name);
    var n = 1;
    while (await File(target).exists()) {
      target = p.join(dir, '$stem ($n)$ext');
      n++;
    }
    return target;
  }
}
