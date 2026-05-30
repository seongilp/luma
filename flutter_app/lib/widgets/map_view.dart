import 'dart:io';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart' show Colors;
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:macos_ui/macos_ui.dart';

import '../state/app_state.dart';
import 'analysis_overlay.dart';
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
          const SizedBox(width: 14),
          _legend(Colors.orange, '추정 ${state.estimatedLocationCount}'),
          const Spacer(),
          PushButton(
            controlSize: ControlSize.regular,
            onPressed: state.estimateLocations,
            child: const Text('사진 내용으로 위치 추정'),
          ),
        ],
      ),
    );
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
                  estimated: lp.estimated,
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
  final bool estimated;
  final VoidCallback onTap;
  const _PinThumb({required this.path, required this.estimated, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = estimated ? Colors.orange : Colors.blue;
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
