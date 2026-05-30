import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/exif_reader.dart';
import '../services/geo.dart';
import '../services/metadata_service.dart';
import '../services/xmp_service.dart';
import '../state/app_state.dart';

Future<void> showMetadataDialog(BuildContext context, AppState state, String path) {
  return showDialog(
    context: context,
    builder: (_) => _MetadataDialog(state: state, path: path),
  );
}

class _MetadataDialog extends StatefulWidget {
  final AppState state;
  final String path;
  const _MetadataDialog({required this.state, required this.path});

  @override
  State<_MetadataDialog> createState() => _MetadataDialogState();
}

class _MetadataDialogState extends State<_MetadataDialog> {
  final _date = TextEditingController();
  final _lat = TextEditingController();
  final _lng = TextEditingController();
  final _tags = TextEditingController();
  bool _busy = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  Future<void> _prefill() async {
    final taken = await readTakenDate(widget.path);
    if (taken != null) _date.text = DateFormat('yyyy-MM-dd HH:mm:ss').format(taken);
    final gps = await readGps(widget.path);
    if (gps != null) {
      _lat.text = gps.latitude.toStringAsFixed(6);
      _lng.text = gps.longitude.toStringAsFixed(6);
    }
    final tags = await MetadataService.getTags(widget.path);
    _tags.text = tags.join(', ');
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _date.dispose();
    _lat.dispose();
    _lng.dispose();
    _tags.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    var ok = true;
    // EXIF 날짜/GPS
    String? dt;
    if (_date.text.trim().isNotEmpty) {
      // "YYYY-MM-DD HH:MM:SS" → EXIF "YYYY:MM:DD HH:MM:SS"
      final t = _date.text.trim();
      dt = t.replaceRange(0, 10, t.substring(0, 10).replaceAll('-', ':'));
    }
    final lat = double.tryParse(_lat.text.trim());
    final lng = double.tryParse(_lng.text.trim());
    if (dt != null || (lat != null && lng != null)) {
      ok = await widget.state
          .correctMetadata(widget.path, dateTime: dt, lat: lat, lng: lng);
    }
    // Finder 태그
    final tagList = _tags.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final tagOk = await MetadataService.setTags(widget.path, tagList);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok && tagOk) {
      navigator.pop();
    } else {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
            content: Text('메타데이터를 저장하지 못했습니다 (권한·형식 확인)'),
            behavior: SnackBarBehavior.floating));
    }
  }

  Future<void> _exportXmp() async {
    final m = widget.state.meta.get(widget.path);
    final tagList = _tags.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final ok = await writeXmp(widget.path, rating: m.rating, keywords: tagList);
    setState(() => _status = ok ? 'XMP 사이드카로 별점·키워드 저장됨' : 'XMP 저장 실패');
  }

  Future<void> _importXmp() async {
    final x = await readXmp(widget.path);
    if (x == null) {
      setState(() => _status = '.xmp 사이드카가 없습니다');
      return;
    }
    if (x.rating != null) await widget.state.setRating(widget.path, x.rating!);
    if (x.keywords.isNotEmpty) _tags.text = x.keywords.join(', ');
    setState(() => _status = 'XMP에서 별점 ${x.rating ?? "-"}, 키워드 ${x.keywords.length}개 가져옴');
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(CupertinoIcons.slider_horizontal_3, size: 20),
                SizedBox(width: 8),
                Text('메타데이터 보정', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 16),
            _field('촬영일시 (YYYY-MM-DD HH:MM:SS)', _date),
            Row(
              children: [
                Expanded(child: _field('위도', _lat)),
                const SizedBox(width: 10),
                Expanded(child: _field('경도', _lng)),
              ],
            ),
            _field('Finder 태그 (쉼표로 구분)', _tags),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton(
                  onPressed: _exportXmp,
                  child: const Text('Lightroom XMP로 저장'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _importXmp,
                  child: const Text('XMP에서 가져오기'),
                ),
              ],
            ),
            if (_status != null) ...[
              const SizedBox(height: 8),
              Text(_status!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('취소'),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: _busy ? null : _save,
                  child: Text(_busy ? '저장 중…' : '저장'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          SizedBox(width: 420, child: TextField(controller: c, maxLines: 1)),
        ],
      ),
    );
  }
}
