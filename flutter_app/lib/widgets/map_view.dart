import 'dart:io';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart' show Colors;
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:macos_ui/macos_ui.dart';

import '../state/app_state.dart';
import 'analysis_overlay.dart';
import 'dialogs.dart';
import 'photo_viewer.dart';

/// 지도 보기: EXIF GPS가 있는 사진은 실제 위치에, 유사 사진으로 추정한 위치는
/// 점선 테두리로 표시한다. (③ + ④)
class MapView extends StatelessWidget {
  final AppState state;
  const MapView({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.geoLoading || state.analyzing) {
      return AnalysisOverlay(state: state);
    }

    final located = state.locatedPhotos;
    return Column(
      children: [
        _toolbar(context),
        Expanded(
          child: located.isEmpty
              ? _empty()
              : _map(context, located),
        ),
      ],
    );
  }

  Widget _toolbar(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: MacosTheme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          _legend(Colors.blue, 'GPS ${state.realLocationCount}'),
          const SizedBox(width: 12),
          _legend(Colors.orange, '내용추정 ${state.estimatedLocationCount}'),
          if (state.claudeLocationCount > 0) ...[
            const SizedBox(width: 12),
            _legend(Colors.purpleAccent, 'Claude ${state.claudeLocationCount}'),
          ],
          const Spacer(),
          PushButton(
            controlSize: ControlSize.regular,
            secondary: true,
            onPressed: state.estimateLocations,
            child: const Text('사진 내용으로 추정'),
          ),
          if (state.claudeConfigured) ...[
            const SizedBox(width: 8),
            PushButton(
              controlSize: ControlSize.regular,
              onPressed:
                  state.unlocatedCount > 0 ? () => _runClaude(context) : null,
              child: Text('Claude로 위치 찾기 (${state.unlocatedCount})'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _runClaude(BuildContext context) async {
    final n = state.unlocatedCount;
    final ok = await confirm(
      context,
      title: 'Claude로 위치 찾기',
      message: '위치 없는 사진 $n장을 Claude(클라우드)로 보내 촬영 장소를 추정합니다.\n'
          '사진이 외부(Anthropic 게이트웨이)로 전송됩니다.',
      confirmLabel: '추정 시작',
    );
    if (ok) await state.estimateLocationsWithClaude();
  }

  Widget _legend(Color color, String label) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _empty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MacosIcon(CupertinoIcons.map, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          const Text('GPS 정보가 있는 사진이 없습니다',
              style: TextStyle(color: Colors.grey, fontSize: 15)),
          const SizedBox(height: 6),
          const Text('“사진 내용으로 위치 추정”으로 일부를 채울 수 있어요',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _map(BuildContext context, List<LocatedPhoto> located) {
    final center = located.first.pos;
    return FlutterMap(
      options: MapOptions(initialCenter: center, initialZoom: 4),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.zihado.photo_manager',
        ),
        MarkerLayer(
          markers: [
            for (final lp in located)
              Marker(
                point: lp.pos,
                width: 54,
                height: 54,
                child: _PinThumb(
                  path: lp.path,
                  kind: lp.kind,
                  onTap: () => _open(context, located, lp.path),
                ),
              ),
          ],
        ),
      ],
    );
  }

  void _open(BuildContext context, List<LocatedPhoto> located, String path) {
    final paths = located.map((e) => e.path).toList();
    final idx = paths.indexOf(path);
    Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black87,
      pageBuilder: (_, _, _) => PhotoViewer(
        state: state,
        paths: paths,
        initialIndex: idx < 0 ? 0 : idx,
      ),
    ));
  }
}

class _PinThumb extends StatelessWidget {
  final String path;
  final LocationKind kind;
  final VoidCallback onTap;
  const _PinThumb({required this.path, required this.kind, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = switch (kind) {
      LocationKind.gps => Colors.blue,
      LocationKind.content => Colors.orange,
      LocationKind.claude => Colors.purpleAccent,
    };
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 3),
          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 4)],
        ),
        child: ClipOval(
          child: Image.file(
            File(path),
            width: 48,
            height: 48,
            fit: BoxFit.cover,
            cacheWidth: 96,
            errorBuilder: (_, _, _) => Container(color: const Color(0xFF3A3A40)),
          ),
        ),
      ),
    );
  }
}
