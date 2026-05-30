import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show compute;
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

/// 디코드·축소·인코드 (무거운 CPU 작업 → isolate에서 실행).
Uint8List? _encodeInIsolate(Map<String, dynamic> a) {
  var image = img.decodeImage(a['bytes'] as Uint8List);
  if (image == null) return null;
  final maxDim = a['maxDim'] as int?;
  if (maxDim != null && (image.width > maxDim || image.height > maxDim)) {
    image = image.width >= image.height
        ? img.copyResize(image, width: maxDim)
        : img.copyResize(image, height: maxDim);
  }
  return a['format'] == 'png'
      ? img.encodePng(image)
      : img.encodeJpg(image, quality: 90);
}

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
        // 디코드/인코드는 isolate에서 → UI 멈춤·대용량 OOM 방지
        final out = await compute(_encodeInIsolate,
            {'bytes': bytes, 'format': format, 'maxDim': maxDim});
        if (out == null) continue;
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
      await Process.run('osascript', args);
    } catch (_) {
      // osascript 자체 실행 실패 — 아래 존재 검사로 판정
    }
    // 실제로 아직 남아있는 경로만 실패로 본다(부분 성공·Finder 미실행 모두 처리).
    final failed = <String>[];
    for (final path in paths) {
      if (await File(path).exists() || await Directory(path).exists()) {
        failed.add(path);
      }
    }
    return failed;
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

  /// 대상 폴더로 이동. 이름 충돌 시 " (n)" 접미사로 회피.
  /// moved=(원경로→새경로), failed=실제 실패 건수(같은 폴더 스킵은 제외).
  static Future<({Map<String, String> moved, int failed})> move(
          List<String> paths, String destDir) =>
      _transfer(paths, destDir, copy: false);

  /// 대상 폴더로 복사.
  static Future<({Map<String, String> moved, int failed})> copy(
          List<String> paths, String destDir) =>
      _transfer(paths, destDir, copy: true);

  static Future<({Map<String, String> moved, int failed})> _transfer(
    List<String> paths,
    String destDir, {
    required bool copy,
  }) async {
    final result = <String, String>{};
    var failed = 0;
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
      } catch (_) {
        failed++;
      }
    }
    return (moved: result, failed: failed);
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
