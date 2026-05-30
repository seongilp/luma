import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../state/app_state.dart';

Future<void> showSettings(BuildContext context, AppState state) {
  return showDialog(
    context: context,
    builder: (_) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 640),
        child: _SettingsSheet(state: state),
      ),
    ),
  );
}

class _SettingsSheet extends StatefulWidget {
  final AppState state;
  const _SettingsSheet({required this.state});

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  late final TextEditingController _key;
  late final TextEditingController _baseUrl;
  late final TextEditingController _cf;
  late final TextEditingController _maxCalls;

  late String _themeMode;
  late bool _confirmDelete;
  late bool _autoOpenLast;
  late String _similarMode;
  late double _thumbSize;
  late int _rescanSeconds;

  @override
  void initState() {
    super.initState();
    final s = widget.state.settings;
    _key = TextEditingController(text: s.anthropicApiKey);
    _baseUrl = TextEditingController(text: s.anthropicBaseUrl);
    _cf = TextEditingController(text: s.cfToken);
    _maxCalls = TextEditingController(text: s.claudeMaxCalls.toString());
    _themeMode = s.themeMode;
    _confirmDelete = s.confirmDelete;
    _autoOpenLast = s.autoOpenLast;
    _similarMode = s.defaultSimilarMode;
    _thumbSize = s.thumbSize;
    _rescanSeconds = s.rescanSeconds;
  }

  @override
  void dispose() {
    _key.dispose();
    _baseUrl.dispose();
    _cf.dispose();
    _maxCalls.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    // copyWith로 기존 값(roots·uiScale·lastRoot)을 보존한다.
    final next = widget.state.settings.copyWith(
      anthropicApiKey: _key.text.trim(),
      anthropicBaseUrl: _baseUrl.text.trim(),
      cfToken: _cf.text.trim(),
      claudeMaxCalls: int.tryParse(_maxCalls.text.trim()) ?? 50,
      themeMode: _themeMode,
      confirmDelete: _confirmDelete,
      autoOpenLast: _autoOpenLast,
      defaultSimilarMode: _similarMode,
      thumbSize: _thumbSize,
      rescanSeconds: _rescanSeconds,
    );
    await widget.state.updateSettings(next);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
          child: Row(
            children: const [
              Icon(CupertinoIcons.gear, size: 22),
              SizedBox(width: 8),
              Text('설정',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _section('일반'),
                _rowControl(
                  '테마',
                  DropdownButton<String>(
                    value: _themeMode,
                    onChanged: (v) => setState(() => _themeMode = v ?? 'system'),
                    items: const [
                      DropdownMenuItem(value: 'system', child: Text('시스템')),
                      DropdownMenuItem(value: 'light', child: Text('라이트')),
                      DropdownMenuItem(value: 'dark', child: Text('다크')),
                    ],
                  ),
                ),
                _rowSwitch('삭제 시 확인 대화상자 표시', _confirmDelete,
                    (v) => setState(() => _confirmDelete = v)),
                _rowSwitch('실행 시 지난 폴더 자동 열기', _autoOpenLast,
                    (v) => setState(() => _autoOpenLast = v)),
                _rowControl(
                  '폴더 자동 재스캔 (새 사진 반영)',
                  DropdownButton<int>(
                    value: _rescanSeconds,
                    onChanged: (v) => setState(() => _rescanSeconds = v ?? 60),
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('끄기')),
                      DropdownMenuItem(value: 30, child: Text('30초')),
                      DropdownMenuItem(value: 60, child: Text('1분')),
                      DropdownMenuItem(value: 300, child: Text('5분')),
                      DropdownMenuItem(value: 600, child: Text('10분')),
                    ],
                  ),
                ),
                _rowControl(
                  '유사 사진 기본 분석',
                  DropdownButton<String>(
                    value: _similarMode,
                    onChanged: (v) =>
                        setState(() => _similarMode = v ?? 'ai'),
                    items: const [
                      DropdownMenuItem(value: 'ai', child: Text('AI (정교)')),
                      DropdownMenuItem(value: 'hash', child: Text('해시 (빠름)')),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text('그리드 썸네일 기본 크기  (${_thumbSize.round()}px)',
                    style: const TextStyle(fontSize: 13)),
                Slider(
                  value: _thumbSize,
                  min: 110,
                  max: 300,
                  onChanged: (v) => setState(() => _thumbSize = v),
                ),

                const SizedBox(height: 12),
                _section('Claude (클라우드 위치 추정 · 선택)'),
                Text('비워두면 환경변수에서 읽습니다. 비밀은 코드에 저장되지 않습니다.',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                const SizedBox(height: 12),
                _field('Anthropic API Key', _key, obscure: true, hint: 'sk-ant-…'),
                _field('Anthropic Base URL', _baseUrl,
                    hint: '비우면 api.anthropic.com / 게이트웨이 URL'),
                _field('Cloudflare AI Gateway Token', _cf,
                    obscure: true, hint: '게이트웨이(BYOK) 사용 시'),
                Text('Claude 호출 상한 (1회 실행당 최대 장소 수)',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                const SizedBox(height: 4),
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: _maxCalls,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: '50'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('취소'),
              ),
              const SizedBox(width: 10),
              FilledButton(onPressed: _save, child: const Text('저장')),
            ],
          ),
        ),
      ],
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      );

  Widget _rowControl(String label, Widget control) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
            control,
          ],
        ),
      );

  Widget _rowSwitch(String label, bool value, ValueChanged<bool> onChanged) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      );

  Widget _field(String label, TextEditingController c,
      {bool obscure = false, String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          TextField(
            controller: c,
            obscureText: obscure,
            maxLines: 1,
            decoration: InputDecoration(hintText: hint),
          ),
        ],
      ),
    );
  }
}
