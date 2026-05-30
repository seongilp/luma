import 'dart:io';
import 'package:image/image.dart' as img;

/// RGB 히스토그램 (각 256 빈).
class Histogram {
  final List<int> r;
  final List<int> g;
  final List<int> b;
  const Histogram(this.r, this.g, this.b);
}

/// 사진의 RGB 히스토그램을 계산한다 (속도 위해 다운샘플). 실패 시 null.
Future<Histogram?> computeHistogram(String path) async {
  try {
    final bytes = await File(path).readAsBytes();
    var image = img.decodeImage(bytes);
    if (image == null) return null;
    if (image.width > 360) {
      image = img.copyResize(image, width: 360);
    }
    final r = List<int>.filled(256, 0);
    final g = List<int>.filled(256, 0);
    final b = List<int>.filled(256, 0);
    for (final px in image) {
      r[px.r.toInt() & 0xFF]++;
      g[px.g.toInt() & 0xFF]++;
      b[px.b.toInt() & 0xFF]++;
    }
    return Histogram(r, g, b);
  } catch (_) {
    return null;
  }
}
