// LUMA 앱 아이콘 생성기.
// 바이올렛→블루 그라디언트 라운드 스퀘어 위에 흰 "사진"(해+산) 글리프.
// 실행: dart run tool/gen_icon.dart
import 'dart:io';
import 'dart:math' as math;
import 'package:image/image.dart' as img;

const _dir = 'macos/Runner/Assets.xcassets/AppIcon.appiconset';
const _sizes = [16, 32, 64, 128, 256, 512, 1024];

int _lerp(int a, int b, double t) => (a + (b - a) * t).round();

void main() {
  const n = 1024;
  final im = img.Image(width: n, height: n, numChannels: 4);

  // 라운드 스퀘어 그라디언트 배경 (macOS 스타일: 약간의 여백)
  const pad = 0.0; // 꽉 채움 (macOS가 자체 마스크 안 함 → 라운드 직접)
  final r = n * 0.225; // 코너 반경
  // 그라디언트 두 색
  const topR = 0x7C, topG = 0x6C, topB = 0xF0; // 바이올렛
  const botR = 0x42, botG = 0x7B, botB = 0xF7; // 블루
  for (var y = 0; y < n; y++) {
    final t = y / (n - 1);
    final cr = _lerp(topR, botR, t);
    final cg = _lerp(topG, botG, t);
    final cb = _lerp(topB, botB, t);
    for (var x = 0; x < n; x++) {
      if (_insideRounded(x.toDouble(), y.toDouble(), pad, pad, n - pad, n - pad, r)) {
        im.setPixelRgba(x, y, cr, cg, cb, 255);
      }
    }
  }

  // 흰 "사진" 카드
  final cardL = n * 0.27, cardT = n * 0.30, cardR = n * 0.73, cardB = n * 0.70;
  final cardRad = n * 0.05;
  _fillRounded(im, cardL, cardT, cardR, cardB, cardRad, 255, 255, 255, 255);

  // 카드 안쪽을 살짝 그라디언트 톤으로 (해/산을 그릴 캔버스)
  // 해 (원) — 카드 좌상단
  final sunCx = cardL + (cardR - cardL) * 0.30;
  final sunCy = cardT + (cardB - cardT) * 0.32;
  final sunR = (cardR - cardL) * 0.11;
  img.fillCircle(im,
      x: sunCx.round(), y: sunCy.round(), radius: sunR.round(),
      color: img.ColorRgba8(0xF6, 0xB7, 0x3C, 255)); // 따뜻한 노랑

  // 산 (삼각형 2개) — 카드 하단, 배경색으로 잘라낸 듯한 실루엣
  final base = cardB - (cardB - cardT) * 0.06;
  _triangle(im,
      cardL + (cardR - cardL) * 0.10, base,
      cardL + (cardR - cardL) * 0.46, cardT + (cardB - cardT) * 0.40,
      cardL + (cardR - cardL) * 0.66, base,
      0x49, 0x71, 0xF4);
  _triangle(im,
      cardL + (cardR - cardL) * 0.42, base,
      cardL + (cardR - cardL) * 0.72, cardT + (cardB - cardT) * 0.52,
      cardL + (cardR - cardL) * 0.94, base,
      0x6A, 0x66, 0xF2);

  // 출력
  for (final s in _sizes) {
    final out = s == n ? im : img.copyResize(im, width: s, height: s, interpolation: img.Interpolation.cubic);
    File('$_dir/app_icon_$s.png').writeAsBytesSync(img.encodePng(out));
    stdout.writeln('wrote app_icon_$s.png');
  }
}

bool _insideRounded(double x, double y, double l, double t, double rr, double b, double rad) {
  if (x < l || x > rr || y < t || y > b) return false;
  // 코너 원 검사
  final corners = [
    [l + rad, t + rad],
    [rr - rad, t + rad],
    [l + rad, b - rad],
    [rr - rad, b - rad],
  ];
  // 코너 영역 밖이면 내부
  final inX = x > l + rad && x < rr - rad;
  final inY = y > t + rad && y < b - rad;
  if (inX || inY) return true;
  for (final c in corners) {
    final dx = x - c[0], dy = y - c[1];
    if ((x < l + rad || x > rr - rad) && (y < t + rad || y > b - rad)) {
      if (dx * dx + dy * dy <= rad * rad) return true;
    }
  }
  return false;
}

void _fillRounded(img.Image im, double l, double t, double rr, double b, double rad,
    int cr, int cg, int cb, int ca) {
  for (var y = t.floor(); y <= b.ceil(); y++) {
    for (var x = l.floor(); x <= rr.ceil(); x++) {
      if (_insideRounded(x.toDouble(), y.toDouble(), l, t, rr, b, rad)) {
        im.setPixelRgba(x, y, cr, cg, cb, ca);
      }
    }
  }
}

void _triangle(img.Image im, double x1, double y1, double x2, double y2,
    double x3, double y3, int cr, int cg, int cb) {
  final minX = [x1, x2, x3].reduce(math.min).floor();
  final maxX = [x1, x2, x3].reduce(math.max).ceil();
  final minY = [y1, y2, y3].reduce(math.min).floor();
  final maxY = [y1, y2, y3].reduce(math.max).ceil();
  double area(double ax, double ay, double bx, double by, double cx, double cy) =>
      (bx - ax) * (cy - ay) - (cx - ax) * (by - ay);
  final a0 = area(x1, y1, x2, y2, x3, y3);
  for (var y = minY; y <= maxY; y++) {
    for (var x = minX; x <= maxX; x++) {
      final w1 = area(x2, y2, x3, y3, x.toDouble(), y.toDouble()) / a0;
      final w2 = area(x3, y3, x1, y1, x.toDouble(), y.toDouble()) / a0;
      final w3 = area(x1, y1, x2, y2, x.toDouble(), y.toDouble()) / a0;
      if (w1 >= 0 && w2 >= 0 && w3 >= 0) {
        im.setPixelRgba(x, y, cr, cg, cb, 255);
      }
    }
  }
}
