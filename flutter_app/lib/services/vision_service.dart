import 'package:flutter/services.dart';

/// 검출된 얼굴: 특징벡터(근사 임베딩)와 위치(0~1, 좌상단 기준).
class DetectedFace {
  final List<double> vector;
  final double x, y, w, h;
  const DetectedFace({
    required this.vector,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });
}

/// macOS Vision(네이티브) 브리지. 이미지 1장의 특징벡터를 받아온다.
class VisionService {
  static const _channel = MethodChannel('photo_manager/vision');

  /// 사진에서 얼굴을 검출해 각 얼굴의 근사 임베딩을 받아온다.
  static Future<List<DetectedFace>> faces(String path) async {
    try {
      final res = await _channel.invokeMethod('faces', {'path': path});
      if (res is! List) return [];
      return [
        for (final f in res)
          DetectedFace(
            vector: [for (final v in (f['vector'] as List)) (v as num).toDouble()],
            x: (f['x'] as num).toDouble(),
            y: (f['y'] as num).toDouble(),
            w: (f['w'] as num).toDouble(),
            h: (f['h'] as num).toDouble(),
          ),
      ];
    } catch (_) {
      return [];
    }
  }

  /// 사진의 Vision 특징벡터. 미지원/실패 시 null.
  static Future<List<double>?> featurePrint(String path) async {
    try {
      final res = await _channel.invokeMethod('featurePrint', {'path': path});
      if (res is! List) return null;
      return [for (final e in res) (e as num).toDouble()];
    } catch (_) {
      return null;
    }
  }
}
