import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';

import 'theme/app_theme.dart';
import 'services/zip_service.dart';
import 'state/app_state.dart';
import 'widgets/control_bar.dart';
import 'widgets/date_view.dart';
import 'widgets/dialogs.dart';
import 'widgets/folder_sidebar.dart';
import 'widgets/info_panel.dart';
import 'widgets/map_view.dart';
import 'widgets/people_view.dart';
import 'widgets/photo_grid.dart';
import 'widgets/stats_view.dart';
import 'widgets/settings_sheet.dart';
import 'widgets/similar_view.dart';

void main() {
  runApp(const PhotoApp());
}

class PhotoApp extends StatelessWidget {
  const PhotoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LUMA',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AppState _state = AppState();
  final GlobalKey _repaintKey = GlobalKey();
  final FocusNode _keyboardFocus = FocusNode();
  bool _showInfo = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    await _state.init();
    final dir = Platform.environment['PHOTO_DIR'];
    if (dir == null || dir.isEmpty) {
      // 환경변수 없으면 지난번에 추가한 폴더들 자동 복원
      final saved = _state.settings.roots;
      if (saved.isNotEmpty) {
        await _state.setRoots(saved);
      } else {
        final last = _state.settings.lastRoot; // 구버전 설정 마이그레이션
        if (last.isNotEmpty) await _state.openRoot(last);
      }
      return;
    }
    {
      {
        await _state.openRoot(dir);
        if (Platform.environment['PHOTO_DEMO'] != null) {
          final items = _state.visibleItems;
          if (items.length >= 4) {
            await _state.toggleFavorite(items[0].path);
            await _state.toggleFavorite(items[2].path);
            await _state.toggleFavorite(items[3].path);
            await _state.setRating(items[1].path, 4);
          }
        }
        if (Platform.environment['PHOTO_OVERLAY'] != null) {
          unawaited(_state.showSimilar()); // 분석 도중 화면을 잡기 위해 await 안 함
          await Future.delayed(const Duration(milliseconds: 1500));
          final shot = Platform.environment['PHOTO_SHOT'];
          if (shot != null && shot.isNotEmpty) await _captureAndExit(shot);
        }
        if (Platform.environment['PHOTO_SIMILAR'] != null) {
          await _state.showSimilar();
        }
        if (Platform.environment['PHOTO_PEOPLE'] != null) {
          await _state.showPeople();
        }
        if (Platform.environment['PHOTO_STATS'] != null) {
          _state.showStats();
        }
        if (Platform.environment['PHOTO_LIST'] != null) {
          _state.setGridMode(GridMode.list);
        }
        final z = Platform.environment['PHOTO_ZOOM'];
        if (z != null) _state.setUiScale(double.tryParse(z) ?? 1.6);
        if (Platform.environment['PHOTO_MAP'] != null) {
          await _state.showMap();
          await _state.estimateLocations();
          await Future.delayed(const Duration(seconds: 4)); // 지도 타일 로드 대기
        }
        if (Platform.environment['PHOTO_CLAUDE'] != null) {
          await _state.showMap();
          await _state.estimateLocationsWithClaude();
          await Future.delayed(const Duration(seconds: 4)); // 지도 타일 로드 대기
        }
        if (Platform.environment['PHOTO_CLAUDE_OVERLAY'] != null) {
          await _state.showMap();
          unawaited(_state.estimateLocationsWithClaude());
          await Future.delayed(const Duration(milliseconds: 3500));
          final shot = Platform.environment['PHOTO_SHOT'];
          if (shot != null && shot.isNotEmpty) await _captureAndExit(shot);
        }
        final shot = Platform.environment['PHOTO_SHOT'];
        if (shot != null && shot.isNotEmpty) {
          await Future.delayed(const Duration(milliseconds: 2200));
          await _captureAndExit(shot);
        }
      }
    }
  }

  @override
  void dispose() {
    _state.dispose();
    _keyboardFocus.dispose();
    super.dispose();
  }

  // 맥 폴더를 라이브러리에 추가(기존 위치 유지). 여러 폴더를 합쳐서 본다.
  Future<void> _openFolder() async {
    final dir = await getDirectoryPath(confirmButtonText: '추가');
    if (dir != null) await _state.addRoot(dir);
  }

  Future<void> _openZip() async {
    const group = XTypeGroup(label: 'ZIP', extensions: ['zip']);
    final file = await openFile(acceptedTypeGroups: [group]);
    if (file == null) return;
    final dir = await extractZipToTemp(file.path);
    if (dir != null) await _state.openRoot(dir);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (HardwareKeyboard.instance.isMetaPressed && key == LogicalKeyboardKey.keyA) {
      _state.selectAll();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      _state.clearSelection();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.delete || key == LogicalKeyboardKey.backspace) {
      if (_state.selectedCount > 0) _confirmDelete();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// 접근성 확대: ⌘+ (확대) / ⌘− (축소) / ⌘0 (원래대로). 앱 전역.
  KeyEventResult _onZoomKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (!HardwareKeyboard.instance.isMetaPressed) return KeyEventResult.ignored;
    final k = event.logicalKey;
    if (k == LogicalKeyboardKey.equal ||
        k == LogicalKeyboardKey.add ||
        k == LogicalKeyboardKey.numpadAdd) {
      _state.zoomInUi();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.minus || k == LogicalKeyboardKey.numpadSubtract) {
      _state.zoomOutUi();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.digit0 || k == LogicalKeyboardKey.numpad0) {
      _state.resetUiScale();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _confirmDelete() async {
    final n = _state.selectedCount;
    final ok = await confirm(context,
        title: '휴지통으로 이동', message: '$n개의 사진을 휴지통으로 보낼까요?');
    if (ok) await _state.deleteSelected();
  }

  Future<void> _captureAndExit(String path) async {
    try {
      final boundary =
          _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary != null) {
        final image = await boundary.toImage(pixelRatio: 2.0);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        if (data != null) await File(path).writeAsBytes(data.buffer.asUint8List());
      }
    } catch (_) {}
    exit(0);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _state,
      builder: (context, _) {
        return MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(_state.uiScale)),
          child: Focus(
            onKeyEvent: _onZoomKey,
            child: RepaintBoundary(
              key: _repaintKey,
              child: Scaffold(
                body: Row(
                  children: [
                    _Sidebar(state: _state, onAddFolder: _openFolder),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: Column(
                        children: [
                          _TopBar(
                            state: _state,
                            onToggleInfo: () =>
                                setState(() => _showInfo = !_showInfo),
                            onAddFolder: _openFolder,
                            onOpenZip: _openZip,
                            onSettings: () => showSettings(context, _state),
                          ),
                          Expanded(child: _buildBody()),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody() {
    if (_state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_state.root == null) {
      return _EmptyState(message: '시작하려면 폴더를 추가하세요.', onOpen: _openFolder);
    }
    if (_state.folders.isEmpty) {
      return _EmptyState(
          message: _state.error ?? '이 폴더에는 이미지가 없습니다.', onOpen: _openFolder);
    }

    final infoPath = _state.selectedCount == 1 ? _state.selection.first : null;
    final isGrid = _state.view == LibraryView.all ||
        _state.view == LibraryView.favorites ||
        _state.view == LibraryView.folder;
    return Focus(
      focusNode: _keyboardFocus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Column(
        children: [
          if (isGrid) ControlBar(state: _state),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _mainContent()),
                if (_showInfo) InfoPanel(path: infoPath, state: _state),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mainContent() {
    switch (_state.view) {
      case LibraryView.similar:
        return SimilarView(state: _state);
      case LibraryView.map:
        return MapView(state: _state);
      case LibraryView.dates:
        return DateView(state: _state);
      case LibraryView.people:
        return PeopleView(state: _state);
      case LibraryView.stats:
        return StatsView(state: _state);
      default:
        return PhotoGrid(state: _state);
    }
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  final VoidCallback onOpen;
  const _EmptyState({required this.message, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.photo_on_rectangle,
              size: 56, color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
          const SizedBox(height: 14),
          Text(message,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 15)),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onOpen,
            icon: const Icon(CupertinoIcons.add, size: 18),
            label: const Text('폴더 추가'),
          ),
        ],
      ),
    );
  }
}

/// 좌측 사이드바: 폴더 트리(스크롤) + 하단 '폴더 추가' 버튼.
class _Sidebar extends StatefulWidget {
  final AppState state;
  final VoidCallback onAddFolder;
  const _Sidebar({required this.state, required this.onAddFolder});

  @override
  State<_Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<_Sidebar> {
  final ScrollController _sc = ScrollController();

  @override
  void dispose() {
    _sc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 260,
      color: cs.surfaceContainerLow,
      child: Column(
        children: [
          Expanded(
            child: FolderSidebar(state: widget.state, scrollController: _sc),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: widget.onAddFolder,
                icon: const Icon(CupertinoIcons.add, size: 18),
                label: const Text('폴더 추가'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 상단 바: 제목 + 이름 검색 + 동작 아이콘들.
class _TopBar extends StatelessWidget {
  final AppState state;
  final VoidCallback onToggleInfo;
  final VoidCallback onAddFolder;
  final VoidCallback onOpenZip;
  final VoidCallback onSettings;
  const _TopBar({
    required this.state,
    required this.onToggleInfo,
    required this.onAddFolder,
    required this.onOpenZip,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 56,
      color: cs.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(
            state.root != null ? state.viewTitle : 'LUMA',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          SizedBox(
            width: 230,
            height: 36,
            child: TextField(
              onChanged: state.setQuery,
              textAlignVertical: TextAlignVertical.center,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: '이름 검색',
                hintStyle: TextStyle(
                    fontSize: 13, color: cs.onSurfaceVariant),
                isDense: true,
                filled: true,
                fillColor: cs.surfaceContainerHighest,
                prefixIcon: Icon(CupertinoIcons.search,
                    size: 16, color: cs.onSurfaceVariant),
                prefixIconConstraints:
                    const BoxConstraints(minWidth: 34, minHeight: 34),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(color: cs.primary, width: 1.4),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButtonTheme(
            data: IconButtonThemeData(
              style: IconButton.styleFrom(
                iconSize: 19,
                visualDensity: VisualDensity.compact,
                foregroundColor: cs.onSurfaceVariant,
              ),
            ),
            child: Row(children: [
              IconButton(
                tooltip: '정보 패널',
                onPressed: onToggleInfo,
                icon: const Icon(CupertinoIcons.info_circle),
              ),
              IconButton(
                tooltip: '폴더 추가 (기존 유지)',
                onPressed: onAddFolder,
                icon: const Icon(CupertinoIcons.folder_badge_plus),
              ),
              IconButton(
                tooltip: 'ZIP 열기',
                onPressed: onOpenZip,
                icon: const Icon(CupertinoIcons.archivebox),
              ),
              IconButton(
                tooltip: '설정',
                onPressed: onSettings,
                icon: const Icon(CupertinoIcons.gear),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
