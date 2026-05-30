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
import 'widgets/photo_viewer.dart';
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
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeMode,
      builder: (context, mode, _) => MaterialApp(
        title: 'LUMA',
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: mode,
        debugShowCheckedModeBanner: false,
        home: const HomePage(),
      ),
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
  double _sidebarWidth = 260;
  bool _sidebarCollapsed = false;

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
      if (saved.isNotEmpty && _state.autoOpenLast) {
        await _state.setRoots(saved);
      } else if (saved.isEmpty) {
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
    // 방향키는 누르고 있을 때 반복되도록 KeyRepeatEvent도 받는다.
    final isRepeat = event is KeyRepeatEvent;
    if (event is! KeyDownEvent && !isRepeat) return KeyEventResult.ignored;
    final key = event.logicalKey;

    // ── 그리드/리스트에서 방향키 이동 · Shift 범위 · Space 미리보기 ──
    final inGrid = _state.view == LibraryView.all ||
        _state.view == LibraryView.favorites ||
        _state.view == LibraryView.folder;
    if (inGrid) {
      final shift = HardwareKeyboard.instance.isShiftPressed;
      final cols =
          _state.gridMode == GridMode.grid ? _state.gridColumns : 1;
      if (key == LogicalKeyboardKey.arrowDown) {
        _state.moveCursor(cols, extend: shift);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowUp) {
        _state.moveCursor(-cols, extend: shift);
        return KeyEventResult.handled;
      }
      if (_state.gridMode == GridMode.grid &&
          key == LogicalKeyboardKey.arrowRight) {
        _state.moveCursor(1, extend: shift);
        return KeyEventResult.handled;
      }
      if (_state.gridMode == GridMode.grid &&
          key == LogicalKeyboardKey.arrowLeft) {
        _state.moveCursor(-1, extend: shift);
        return KeyEventResult.handled;
      }
      if (!isRepeat && key == LogicalKeyboardKey.space) {
        _openPreviewAtCursor();
        return KeyEventResult.handled;
      }
    }

    if (isRepeat) return KeyEventResult.ignored;
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
    // ⌘, : 설정 (맥 기본), ⌘K : 커맨드 팔레트
    if (k == LogicalKeyboardKey.comma) {
      showSettings(context, _state);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.keyK) {
      _openCommandPalette();
      return KeyEventResult.handled;
    }
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

  /// Space: 현재 커서 위치 사진을 바로 미리보기(뷰어)로 연다.
  void _openPreviewAtCursor() {
    final paths = _state.visibleItems.map((e) => e.path).toList();
    if (paths.isEmpty) return;
    final idx = _state.cursorIndex.clamp(0, paths.length - 1);
    Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black87,
      pageBuilder: (_, _, _) =>
          PhotoViewer(state: _state, paths: paths, initialIndex: idx),
    ));
  }

  void _openCommandPalette() {
    final s = _state;
    final cmds = <_Command>[
      _Command('모든 사진', CupertinoIcons.photo_on_rectangle, s.showAllPhotos),
      _Command('즐겨찾기', CupertinoIcons.heart, s.showFavorites),
      _Command('유사 사진', CupertinoIcons.square_stack_3d_down_right,
          () => s.showSimilar()),
      _Command('지도', CupertinoIcons.map, () => s.showMap()),
      _Command('날짜별', CupertinoIcons.calendar, s.showDates),
      _Command('인물', CupertinoIcons.person_2_fill, () => s.showPeople()),
      _Command('통계', CupertinoIcons.chart_bar_alt_fill, s.showStats),
      _Command('폴더 추가', CupertinoIcons.folder_badge_plus, _openFolder),
      _Command('ZIP 열기', CupertinoIcons.archivebox, _openZip),
      _Command('설정', CupertinoIcons.gear, () => showSettings(context, s)),
      _Command('정보 패널 토글', CupertinoIcons.info_circle,
          () => setState(() => _showInfo = !_showInfo)),
      _Command('사이드바 접기/펼치기', CupertinoIcons.sidebar_left,
          () => setState(() => _sidebarCollapsed = !_sidebarCollapsed)),
      _Command('그리드 보기', CupertinoIcons.square_grid_2x2,
          () => s.setGridMode(GridMode.grid)),
      _Command('리스트 보기', CupertinoIcons.list_bullet,
          () => s.setGridMode(GridMode.list)),
      _Command('선택 즐겨찾기 켜기/끄기', CupertinoIcons.heart_fill,
          () => s.favoriteSelected()),
      _Command('전체 선택', CupertinoIcons.checkmark_circle, s.selectAll),
      _Command('선택 해제', CupertinoIcons.clear, s.clearSelection),
      _Command('확대', CupertinoIcons.zoom_in, s.zoomInUi),
      _Command('축소', CupertinoIcons.zoom_out, s.zoomOutUi),
      _Command('배율 초기화', CupertinoIcons.fullscreen, s.resetUiScale),
    ];
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (_) => _CommandPalette(commands: cmds),
    );
  }

  Future<void> _confirmDelete() async {
    final n = _state.selectedCount;
    if (!_state.confirmDelete) {
      await _state.deleteSelected();
      return;
    }
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
                    if (!_sidebarCollapsed) ...[
                      _Sidebar(
                        state: _state,
                        width: _sidebarWidth,
                        onAddFolder: _openFolder,
                      ),
                      _SidebarResizer(
                        onDelta: (dx) => setState(() {
                          _sidebarWidth =
                              (_sidebarWidth + dx).clamp(180.0, 480.0);
                        }),
                      ),
                    ],
                    Expanded(
                      child: Column(
                        children: [
                          _TopBar(
                            state: _state,
                            collapsed: _sidebarCollapsed,
                            onToggleSidebar: () => setState(
                                () => _sidebarCollapsed = !_sidebarCollapsed),
                            onToggleInfo: () =>
                                setState(() => _showInfo = !_showInfo),
                            onAddFolder: _openFolder,
                            onOpenZip: _openZip,
                            onSettings: () => showSettings(context, _state),
                          ),
                          // 본문(그리드/리스트)을 클릭하면 키보드 포커스를 본문으로
                          // 가져와 방향키가 검색창으로 새지 않게 한다.
                          Expanded(
                            child: Listener(
                              behavior: HitTestBehavior.translucent,
                              onPointerDown: (_) {
                                if (!_keyboardFocus.hasFocus) {
                                  _keyboardFocus.requestFocus();
                                }
                              },
                              child: _buildBody(),
                            ),
                          ),
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
  final double width;
  final VoidCallback onAddFolder;
  const _Sidebar({
    required this.state,
    required this.width,
    required this.onAddFolder,
  });

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
      width: widget.width,
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

/// 사이드바와 본문 사이의 드래그 핸들(좌우 크기 조절).
class _SidebarResizer extends StatefulWidget {
  final void Function(double dx) onDelta;
  const _SidebarResizer({required this.onDelta});

  @override
  State<_SidebarResizer> createState() => _SidebarResizerState();
}

class _SidebarResizerState extends State<_SidebarResizer> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: (d) => widget.onDelta(d.delta.dx),
        child: SizedBox(
          width: 8,
          child: Center(
            child: Container(
              width: _hover ? 2 : 1,
              color: _hover ? cs.primary : cs.outlineVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// 상단 바: 사이드바 접기 + 제목 + 이름 검색 + 동작 아이콘들.
class _TopBar extends StatelessWidget {
  final AppState state;
  final bool collapsed;
  final VoidCallback onToggleSidebar;
  final VoidCallback onToggleInfo;
  final VoidCallback onAddFolder;
  final VoidCallback onOpenZip;
  final VoidCallback onSettings;
  const _TopBar({
    required this.state,
    required this.collapsed,
    required this.onToggleSidebar,
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
      padding: const EdgeInsets.only(left: 12, right: 16),
      child: Row(
        children: [
          IconButton(
            tooltip: collapsed ? '사이드바 펼치기' : '사이드바 접기',
            onPressed: onToggleSidebar,
            visualDensity: VisualDensity.compact,
            icon: Icon(CupertinoIcons.sidebar_left, color: cs.onSurfaceVariant),
          ),
          const SizedBox(width: 4),
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

/// 커맨드 팔레트 항목.
class _Command {
  final String label;
  final IconData icon;
  final VoidCallback run;
  const _Command(this.label, this.icon, this.run);
}

/// ⌘K 커맨드 팔레트: 입력으로 명령을 검색하고 ↑↓·Enter로 실행.
class _CommandPalette extends StatefulWidget {
  final List<_Command> commands;
  const _CommandPalette({required this.commands});

  @override
  State<_CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<_CommandPalette> {
  final _focus = FocusNode();
  final _scroll = ScrollController();
  String _query = '';
  int _index = 0;

  List<_Command> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.commands;
    return widget.commands
        .where((c) => c.label.toLowerCase().contains(q))
        .toList();
  }

  @override
  void dispose() {
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _move(int delta) {
    final list = _filtered;
    if (list.isEmpty) return;
    setState(() => _index = (_index + delta).clamp(0, list.length - 1));
    // 하이라이트가 보이도록 즉시 스크롤(애니메이션 없이 → 키 반복 시 끊김 없음)
    if (_scroll.hasClients) {
      const rowH = 46.0;
      final top = _index * rowH;
      final viewTop = _scroll.offset;
      final viewBottom = viewTop + _scroll.position.viewportDimension;
      double? target;
      if (top < viewTop) target = top;
      if (top + rowH > viewBottom) target = top + rowH - _scroll.position.viewportDimension;
      if (target != null) {
        _scroll.jumpTo(target.clamp(0.0, _scroll.position.maxScrollExtent));
      }
    }
  }

  void _runAt(int i) {
    final list = _filtered;
    if (i < 0 || i >= list.length) return;
    Navigator.of(context).pop();
    list[i].run();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    // 누르고 있을 때 자동 반복되도록 KeyRepeatEvent도 받는다.
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    switch (e.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        _move(1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        _move(-1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.numpadEnter:
        _runAt(_index);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
        Navigator.of(context).pop();
        return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final list = _filtered;
    if (_index >= list.length) _index = list.isEmpty ? 0 : list.length - 1;
    return Align(
      alignment: const Alignment(0, -0.45),
      child: Focus(
        onKeyEvent: _onKey,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 560,
            constraints: const BoxConstraints(maxHeight: 420),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                  child: TextField(
                    autofocus: true,
                    style: const TextStyle(fontSize: 15),
                    onChanged: (v) => setState(() {
                      _query = v;
                      _index = 0;
                    }),
                    onSubmitted: (_) => _runAt(_index),
                    decoration: InputDecoration(
                      hintText: '명령 검색…  (↑↓ 이동, Enter 실행, Esc 닫기)',
                      prefixIcon: const Icon(CupertinoIcons.search, size: 18),
                      filled: true,
                      fillColor: cs.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                Flexible(
                  child: list.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text('일치하는 명령 없음',
                              style: TextStyle(color: cs.onSurfaceVariant)),
                        )
                      : ListView.builder(
                          controller: _scroll,
                          shrinkWrap: true,
                          padding: const EdgeInsets.only(bottom: 8),
                          itemCount: list.length,
                          itemBuilder: (context, i) {
                            final c = list[i];
                            final active = i == _index;
                            return InkWell(
                              onTap: () => _runAt(i),
                              child: Container(
                                height: 44,
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 1),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: active
                                      ? cs.primary.withValues(alpha: 0.16)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(c.icon,
                                        size: 18,
                                        color: active
                                            ? cs.primary
                                            : cs.onSurfaceVariant),
                                    const SizedBox(width: 12),
                                    Text(c.label,
                                        style: TextStyle(
                                            fontSize: 14,
                                            color: active
                                                ? cs.primary
                                                : cs.onSurface)),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
