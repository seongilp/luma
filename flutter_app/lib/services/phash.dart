import 'dart:io';
import 'dart:ui' as ui;

/// 퍼셉추얼 해시(dHash). 이미지를 9×8 회색조로 줄여, 가로 인접 픽셀
/// 밝기 비교로 64비트 지문을 만든다. 밝기/크기 변화에 강하다.
Future<int?> computeDHash(String path) async {
  try {
    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: 9, targetHeight: 8);
    final frame = await codec.getNextFrame();
    final data = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
    frame.image.dispose();
    if (data == null) return null;
    final px = data.buffer.asUint8List();

    final gray = List<int>.filled(72, 0);
    for (var i = 0; i < 72; i++) {
      final o = i * 4;
      gray[i] = (px[o] * 0.299 + px[o + 1] * 0.587 + px[o + 2] * 0.114).round();
    }

    var hash = 0;
    var bit = 0;
    for (var r = 0; r < 8; r++) {
      for (var c = 0; c < 8; c++) {
        if (gray[r * 9 + c] > gray[r * 9 + c + 1]) hash |= (1 << bit);
        bit++;
      }
    }
    return hash;
  } catch (_) {
    return null;
  }
}

/// 두 해시의 해밍 거리(다른 비트 수, 0~64). 작을수록 비슷함.
int hammingDistance(int a, int b) {
  var x = a ^ b;
  var count = 0;
  while (x != 0) {
    count += x & 1;
    x >>>= 1; // 부호 없는 시프트 (음수 무한루프 방지)
  }
  return count;
}
