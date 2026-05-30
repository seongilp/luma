import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../state/app_state.dart';

Future<void> showSettings(BuildContext context, AppState state) {
  return showDialog(
    context: context,
    builder: (_) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
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

  @override
  void initState() {
    super.initState();
    final s = widget.state.settings;
    _key = TextEditingController(text: s.anthropicApiKey);
    _baseUrl = TextEditingController(text: s.anthropicBaseUrl);
    _cf = TextEditingController(text: s.cfToken);
    _maxCalls = TextEditingController(text: s.claudeMaxCalls.toString());
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
    final next = AppSettings(
      anthropicApiKey: _key.text.trim(),
      anthropicBaseUrl: _baseUrl.text.trim(),
      cfToken: _cf.text.trim(),
      claudeMaxCalls: int.tryParse(_maxCalls.text.trim()) ?? 50,
    );
    await widget.state.updateSettings(next);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Row(
            children: [
              Icon(CupertinoIcons.gear, size: 22),
              SizedBox(width: 8),
              Text('설정', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Claude(클라우드 위치 추정) 자격증명. 비워두면 환경변수에서 읽습니다.',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 20),

          _field('Anthropic API Key', _key, obscure: true, hint: 'sk-ant-…'),
          _field('Anthropic Base URL', _baseUrl,
              hint: '비우면 api.anthropic.com / 게이트웨이 URL'),
          _field('Cloudflare AI Gateway Token', _cf,
              obscure: true, hint: '게이트웨이(BYOK) 사용 시'),

          const SizedBox(height: 8),
          const Text('Claude 호출 상한 (1회 실행당 최대 장소 수)',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          SizedBox(
            width: 120,
            child: TextField(
              controller: _maxCalls,
              decoration: const InputDecoration(hintText: '50'),
            ),
          ),

          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('취소'),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: _save,
                child: const Text('저장'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController c, {bool obscure = false, String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          SizedBox(
            width: 460,
            child: TextField(
              controller: c,
              obscureText: obscure,
              maxLines: 1,
              decoration: InputDecoration(hintText: hint),
            ),
          ),
        ],
      ),
    );
  }
}
