import 'package:flutter/services.dart';

/// 네이티브 EXIF 무손실 쓰기 + Finder 태그.
class MetadataService {
  static const _channel = MethodChannel('photo_manager/vision');

  /// 촬영일시("YYYY:MM:DD HH:MM:SS")·GPS를 무손실로 다시 쓴다.
  static Future<bool> writeMetadata(
    String path, {
    String? dateTime,
    double? lat,
    double? lng,
  }) async {
    try {
      final r = await _channel.invokeMethod('writeMetadata', {
        'path': path,
        'dateTime': dateTime,
        'lat': lat,
        'lng': lng,
      });
      return r == true;
    } catch (_) {
      return false;
    }
  }

  static Future<List<String>> getTags(String path) async {
    try {
      final r = await _channel.invokeMethod('getTags', {'path': path});
      return r is List ? [for (final s in r) s.toString()] : [];
    } catch (_) {
      return [];
    }
  }

  static Future<bool> setTags(String path, List<String> tags) async {
    try {
      final r = await _channel.invokeMethod('setTags', {'path': path, 'tags': tags});
      return r == true;
    } catch (_) {
      return false;
    }
  }
}
