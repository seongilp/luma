import 'package:flutter/services.dart';

/// macOS Vision(네이티브) 브리지. 이미지 1장의 특징벡터를 받아온다.
class VisionService {
  static const _channel = MethodChannel('photo_manager/vision');

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
