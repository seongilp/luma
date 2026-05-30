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

  /// 마지막으로 연 폴더 (구버전 설정 마이그레이션용). 현재는 [roots] 사용.
  String lastRoot;

  /// 사이드바에 추가된 맥 폴더(위치)들. 여러 폴더를 하나의 라이브러리로 합쳐 본다.
  List<String> roots;

  /// 전체 UI 배율 (접근성 확대). 1.0 = 기본.
  double uiScale;

  /// 테마 모드: 'system' | 'light' | 'dark'.
  String themeMode;

  /// 삭제 시 확인 대화상자를 띄울지.
  bool confirmDelete;

  /// 실행 시 지난번 추가한 폴더를 자동으로 다시 열지.
  bool autoOpenLast;

  /// 유사 사진 기본 분석 방식: 'ai' | 'hash'.
  String defaultSimilarMode;

  /// 그리드 썸네일 기본 크기(px).
  double thumbSize;

  AppSettings({
    this.anthropicApiKey = '',
    this.anthropicBaseUrl = '',
    this.cfToken = '',
    this.claudeMaxCalls = 50,
    this.lastRoot = '',
    List<String>? roots,
    this.uiScale = 1.0,
    this.themeMode = 'system',
    this.confirmDelete = true,
    this.autoOpenLast = true,
    this.defaultSimilarMode = 'ai',
    this.thumbSize = 160,
  }) : roots = roots ?? const [];

  AppSettings copyWith({
    String? anthropicApiKey,
    String? anthropicBaseUrl,
    String? cfToken,
    int? claudeMaxCalls,
    String? lastRoot,
    List<String>? roots,
    double? uiScale,
    String? themeMode,
    bool? confirmDelete,
    bool? autoOpenLast,
    String? defaultSimilarMode,
    double? thumbSize,
  }) =>
      AppSettings(
        anthropicApiKey: anthropicApiKey ?? this.anthropicApiKey,
        anthropicBaseUrl: anthropicBaseUrl ?? this.anthropicBaseUrl,
        cfToken: cfToken ?? this.cfToken,
        claudeMaxCalls: claudeMaxCalls ?? this.claudeMaxCalls,
        lastRoot: lastRoot ?? this.lastRoot,
        roots: roots ?? this.roots,
        uiScale: uiScale ?? this.uiScale,
        themeMode: themeMode ?? this.themeMode,
        confirmDelete: confirmDelete ?? this.confirmDelete,
        autoOpenLast: autoOpenLast ?? this.autoOpenLast,
        defaultSimilarMode: defaultSimilarMode ?? this.defaultSimilarMode,
        thumbSize: thumbSize ?? this.thumbSize,
      );

  Map<String, dynamic> toJson() => {
        'anthropicApiKey': anthropicApiKey,
        'anthropicBaseUrl': anthropicBaseUrl,
        'cfToken': cfToken,
        'claudeMaxCalls': claudeMaxCalls,
        'lastRoot': lastRoot,
        'roots': roots,
        'uiScale': uiScale,
        'themeMode': themeMode,
        'confirmDelete': confirmDelete,
        'autoOpenLast': autoOpenLast,
        'defaultSimilarMode': defaultSimilarMode,
        'thumbSize': thumbSize,
      };

  static AppSettings fromJson(Map<String, dynamic> j) => AppSettings(
        anthropicApiKey: j['anthropicApiKey'] as String? ?? '',
        anthropicBaseUrl: j['anthropicBaseUrl'] as String? ?? '',
        cfToken: j['cfToken'] as String? ?? '',
        claudeMaxCalls: (j['claudeMaxCalls'] as num?)?.toInt() ?? 50,
        lastRoot: j['lastRoot'] as String? ?? '',
        roots: (j['roots'] as List?)?.whereType<String>().toList() ?? const [],
        uiScale: (j['uiScale'] as num?)?.toDouble() ?? 1.0,
        themeMode: j['themeMode'] as String? ?? 'system',
        confirmDelete: j['confirmDelete'] as bool? ?? true,
        autoOpenLast: j['autoOpenLast'] as bool? ?? true,
        defaultSimilarMode: j['defaultSimilarMode'] as String? ?? 'ai',
        thumbSize: (j['thumbSize'] as num?)?.toDouble() ?? 160,
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
