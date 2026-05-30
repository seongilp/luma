import 'package:flutter/services.dart';

import '../models/photo_item.dart';

/// macOS Vision(네이티브) 유사 사진 분석 브리지.
class VisionService {
  static const _channel = MethodChannel('photo_manager/vision');

  /// Vision 특징벡터로 의미적 유사 묶음을 계산한다.
  /// 미지원/실패 시 null을 반환(호출측에서 해시로 폴백).
  static Future<List<List<PhotoItem>>?> similarGroups(
    List<PhotoItem> items, {
    double threshold = 0.6,
  }) async {
    if (items.isEmpty) return [];
    try {
      final paths = items.map((e) => e.path).toList();
      final res = await _channel.invokeMethod('similarGroups', {
        'paths': paths,
        'threshold': threshold,
      });
      if (res is! List) return null;
      final groups = <List<PhotoItem>>[];
      for (final g in res) {
        final idxs = (g as List).map((e) => (e as num).toInt());
        groups.add([for (final i in idxs) items[i]]);
      }
      return groups;
    } catch (_) {
      return null;
    }
  }
}
