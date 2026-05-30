import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

/// 앱 설정. Claude 자격증명과 호출 상한 등을 보관·저장한다.
/// (코드에 비밀을 두지 않기 위해 사용자별 저장소에 보관)
class AppSettings {
  String anthropicApiKey;
  String anthropicBaseUrl;
  String cfToken;

  /// Claude 위치 추정 1회 실행에서 최대 호출(=장소 묶음) 수.
  int claudeMaxCalls;

  AppSettings({
    this.anthropicApiKey = '',
    this.anthropicBaseUrl = '',
    this.cfToken = '',
    this.claudeMaxCalls = 50,
  });

  AppSettings copyWith({
    String? anthropicApiKey,
    String? anthropicBaseUrl,
    String? cfToken,
    int? claudeMaxCalls,
  }) =>
      AppSettings(
        anthropicApiKey: anthropicApiKey ?? this.anthropicApiKey,
        anthropicBaseUrl: anthropicBaseUrl ?? this.anthropicBaseUrl,
        cfToken: cfToken ?? this.cfToken,
        claudeMaxCalls: claudeMaxCalls ?? this.claudeMaxCalls,
      );

  Map<String, dynamic> toJson() => {
        'anthropicApiKey': anthropicApiKey,
        'anthropicBaseUrl': anthropicBaseUrl,
        'cfToken': cfToken,
        'claudeMaxCalls': claudeMaxCalls,
      };

  static AppSettings fromJson(Map<String, dynamic> j) => AppSettings(
        anthropicApiKey: j['anthropicApiKey'] as String? ?? '',
        anthropicBaseUrl: j['anthropicBaseUrl'] as String? ?? '',
        cfToken: j['cfToken'] as String? ?? '',
        claudeMaxCalls: (j['claudeMaxCalls'] as num?)?.toInt() ?? 50,
      );
}

class SettingsStore {
  File? _file;

  Future<File?> _resolve() async {
    if (_file != null) return _file;
    final home = Platform.environment['HOME'];
    if (home == null) return null;
    final dir = Directory(p.join(home, 'Library', 'Application Support', 'photo_manager'));
    await dir.create(recursive: true);
    _file = File(p.join(dir.path, 'settings.json'));
    return _file;
  }

  Future<AppSettings> load() async {
    final f = await _resolve();
    if (f == null || !await f.exists()) return AppSettings();
    try {
      return AppSettings.fromJson(jsonDecode(await f.readAsString()) as Map<String, dynamic>);
    } catch (_) {
      return AppSettings();
    }
  }

  Future<void> save(AppSettings s) async {
    final f = await _resolve();
    if (f == null) return;
    try {
      await f.writeAsString(jsonEncode(s.toJson()));
    } catch (_) {}
  }
}
