import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

/// 긴 변 768px JPEG로 축소 후 base64 (무거운 디코드 → isolate).
String? _downscaleToBase64(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  final resized = decoded.width > decoded.height
      ? img.copyResize(decoded, width: 768)
      : img.copyResize(decoded, height: 768);
  return base64Encode(img.encodeJpg(resized, quality: 80));
}

/// Claude(멀티모달) 설정. 직접 키 또는 Cloudflare AI Gateway(BYOK)를 지원.
/// 비밀은 코드에 두지 않고 환경변수에서 읽는다.
class ClaudeConfig {
  final String baseUrl;
  final String? apiKey;
  final String? cfToken;

  const ClaudeConfig({required this.baseUrl, this.apiKey, this.cfToken});

  bool get isConfigured =>
      (apiKey != null && apiKey!.isNotEmpty) || (cfToken != null && cfToken!.isNotEmpty);

  factory ClaudeConfig.fromEnv() {
    final e = Platform.environment;
    return ClaudeConfig(
      baseUrl: (e['ANTHROPIC_BASE_URL'] ?? 'https://api.anthropic.com').replaceAll(RegExp(r'/$'), ''),
      apiKey: e['ANTHROPIC_API_KEY'],
      cfToken: e['CF_AIG_TOKEN'],
    );
  }
}

/// Claude가 추정한 위치.
class ClaudeLocation {
  final String? place;
  final double? lat;
  final double? lng;
  final double confidence;

  const ClaudeLocation({this.place, this.lat, this.lng, required this.confidence});

  bool get hasCoords => lat != null && lng != null;
}

class ClaudeService {
  final ClaudeConfig config;
  ClaudeService(this.config);

  static const _model = 'claude-sonnet-4-5';

  /// 사진을 보고 촬영 장소를 추정한다. 식별 못하면 null 또는 place=null.
  Future<ClaudeLocation?> identifyLocation(String imagePath) async {
    final b64 = await _downscaledJpegBase64(imagePath);
    if (b64 == null) return null;

    final headers = <String, String>{
      'content-type': 'application/json',
      'anthropic-version': '2023-06-01',
    };
    if (config.apiKey != null && config.apiKey!.isNotEmpty) {
      headers['x-api-key'] = config.apiKey!;
    }
    if (config.cfToken != null && config.cfToken!.isNotEmpty) {
      headers['cf-aig-authorization'] = 'Bearer ${config.cfToken}';
    }

    final body = jsonEncode({
      'model': _model,
      'max_tokens': 200,
      'messages': [
        {
          'role': 'user',
          'content': [
            {
              'type': 'image',
              'source': {'type': 'base64', 'media_type': 'image/jpeg', 'data': b64},
            },
            {
              'type': 'text',
              'text': '이 사진이 어디서 찍혔는지 추정해. 인식 가능한 랜드마크·도시·지형이면 추정하고, '
                  '아니면 place를 null로. JSON만 출력: '
                  '{"place":"장소명 또는 null","lat":위도숫자,"lng":경도숫자,"confidence":0~1}',
            },
          ],
        },
      ],
    });

    try {
      final resp = await http
          .post(
            Uri.parse('${config.baseUrl}/v1/messages'),
            headers: headers,
            body: body,
          )
          .timeout(const Duration(seconds: 30));
      if (resp.statusCode != 200) return null;
      final data = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      final content = (data['content'] as List?)?.firstWhere(
        (c) => c['type'] == 'text',
        orElse: () => null,
      );
      final text = content?['text'] as String?;
      if (text == null) return null;
      return _parse(text);
    } catch (_) {
      return null;
    }
  }

  /// AI 빠른 점검: 사진을 보고 내용·노출/초점/구도·개선 팁을 간단히.
  Future<String?> quickCheck(String imagePath) async {
    final b64 = await _downscaledJpegBase64(imagePath);
    if (b64 == null) return null;
    final headers = <String, String>{
      'content-type': 'application/json',
      'anthropic-version': '2023-06-01',
    };
    if (config.apiKey != null && config.apiKey!.isNotEmpty) {
      headers['x-api-key'] = config.apiKey!;
    }
    if (config.cfToken != null && config.cfToken!.isNotEmpty) {
      headers['cf-aig-authorization'] = 'Bearer ${config.cfToken}';
    }
    final body = jsonEncode({
      'model': _model,
      'max_tokens': 300,
      'messages': [
        {
          'role': 'user',
          'content': [
            {
              'type': 'image',
              'source': {'type': 'base64', 'media_type': 'image/jpeg', 'data': b64},
            },
            {
              'type': 'text',
              'text': '이 사진을 빠르게 점검해줘. 한국어로 간결하게: '
                  '① 무엇이 담겼는지 ② 노출·초점·구도 등 눈에 띄는 점 ③ 개선 팁. '
                  '각 항목 1~2줄.',
            },
          ],
        },
      ],
    });
    try {
      final resp = await http
          .post(Uri.parse('${config.baseUrl}/v1/messages'),
              headers: headers, body: body)
          .timeout(const Duration(seconds: 30));
      if (resp.statusCode != 200) return null;
      final data = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      final content = (data['content'] as List?)?.firstWhere(
        (c) => c['type'] == 'text',
        orElse: () => null,
      );
      return content?['text'] as String?;
    } catch (_) {
      return null;
    }
  }

  ClaudeLocation? _parse(String text) {
    // ```json ... ``` 펜스 제거 후 JSON 파싱
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    try {
      final j = jsonDecode(text.substring(start, end + 1)) as Map<String, dynamic>;
      final place = j['place'];
      return ClaudeLocation(
        place: (place == null || place == 'null') ? null : place.toString(),
        lat: (j['lat'] as num?)?.toDouble(),
        lng: (j['lng'] as num?)?.toDouble(),
        confidence: (j['confidence'] as num?)?.toDouble() ?? 0,
      );
    } catch (_) {
      return null;
    }
  }

  /// 토큰/비용 절감을 위해 긴 변 768px로 줄여 JPEG base64로 인코딩.
  Future<String?> _downscaledJpegBase64(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      return await compute(_downscaleToBase64, bytes);
    } catch (_) {
      return null;
    }
  }
}
