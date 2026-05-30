import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

/// ZIP을 임시 폴더에 풀고 그 경로를 반환한다 (실패 시 null).
/// 푼 폴더를 그대로 라이브러리로 열어 탐색할 수 있다.
Future<String?> extractZipToTemp(String zipPath) async {
  try {
    final bytes = await File(zipPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final base = p.basenameWithoutExtension(zipPath);
    final dir = await Directory.systemTemp.createTemp('photo_zip_${base}_');
    for (final entry in archive) {
      if (!entry.isFile) continue;
      // 경로 탈출(zip slip) 방지
      final outPath = p.normalize(p.join(dir.path, entry.name));
      if (!p.isWithin(dir.path, outPath)) continue;
      final f = File(outPath);
      await f.parent.create(recursive: true);
      await f.writeAsBytes(entry.content as List<int>);
    }
    return dir.path;
  } catch (_) {
    return null;
  }
}
