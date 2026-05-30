import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, ThemeMode;
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';
import 'package:macos_ui/macos_ui.dart';

import 'state/app_state.dart';
import 'widgets/control_bar.dart';
import 'widgets/dialogs.dart';
import 'widgets/folder_sidebar.dart';
import 'widgets/info_panel.dart';
import 'widgets/photo_grid.dart';
import 'widgets/similar_view.dart';

void main() {
  runApp(const PhotoApp());
}

class PhotoApp extends StatelessWidget {
  const PhotoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MacosApp(
      title: 'Photo Manager',
      theme: MacosThemeData.light(),
      darkTheme: MacosThemeData.dark(),
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
    _state.init();
    final dir = Platform.environment['PHOTO_DIR'];
    if (dir != null && dir.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
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
        if (Platform.environment['PHOTO_SIMILAR'] != null) {
          await _state.showSimilar();
        }
        final shot = Platform.environment['PHOTO_SHOT'];
        if (shot != null && shot.isNotEmpty) {
          await Future.delayed(const Duration(milliseconds: 2200));
          await _captureAndExit(shot);
        }
      });
    }
  }

  @override
  void dispose() {
    _state.dispose();
    _keyboardFocus.dispose();
    super.dispose();
  }

  Future<void> _openFolder() async {
    final dir = await getDirectoryPath(confirmButtonText: '선택');
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
        final root = _state.root;
        return RepaintBoundary(
          key: _repaintKey,
          child: MacosWindow(
            sidebar: Sidebar(
              minWidth: 240,
              builder: (context, scrollController) =>
                  FolderSidebar(state: _state, scrollController: scrollController),
              bottom: Padding(
                padding: const EdgeInsets.all(8),
                child: SizedBox(
                  width: double.infinity,
                  child: PushButton(
                    controlSize: ControlSize.large,
                    onPressed: _openFolder,
                    child: const Text('폴더 열기'),
                  ),
                ),
              ),
            ),
            child: MacosScaffold(
              toolBar: ToolBar(
                title: Text(root != null ? _state.viewTitle : 'Photo Manager'),
                titleWidth: 240,
                actions: [
                  CustomToolbarItem(
                    inToolbarBuilder: (context) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: SizedBox(
                        width: 200,
                        child: MacosSearchField(
                          placeholder: '이름 검색',
                          onChanged: _state.setQuery,
                          results: const [],
                        ),
                      ),
                    ),
                  ),
                  ToolBarIconButton(
                    label: '정보',
                    icon: const MacosIcon(CupertinoIcons.info_circle),
                    tooltipMessage: '정보 패널',
                    onPressed: () => setState(() => _showInfo = !_showInfo),
                    showLabel: false,
                  ),
                  ToolBarIconButton(
                    label: '폴더 열기',
                    icon: const MacosIcon(CupertinoIcons.folder_badge_plus),
                    tooltipMessage: '폴더 열기',
                    onPressed: _openFolder,
                    showLabel: false,
                  ),
                ],
              ),
              children: [
                ContentArea(
                  builder: (context, scrollController) => _buildBody(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody() {
    if (_state.loading) return const Center(child: ProgressCircle());
    if (_state.root == null) {
      return _EmptyState(message: '시작하려면 사진 폴더를 여세요.', onOpen: _openFolder);
    }
    if (_state.folders.isEmpty) {
      return _EmptyState(
          message: _state.error ?? '이 폴더에는 이미지가 없습니다.', onOpen: _openFolder);
    }

    final infoPath = _state.selectedCount == 1 ? _state.selection.first : null;
    return Focus(
      focusNode: _keyboardFocus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Column(
        children: [
          ControlBar(state: _state),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _state.view == LibraryView.similar
                      ? SimilarView(state: _state)
                      : PhotoGrid(state: _state),
                ),
                if (_showInfo) InfoPanel(path: infoPath),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  final VoidCallback onOpen;
  const _EmptyState({required this.message, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MacosIcon(CupertinoIcons.photo_on_rectangle, size: 56, color: Colors.grey),
          const SizedBox(height: 14),
          Text(message, style: const TextStyle(color: Colors.grey, fontSize: 15)),
          const SizedBox(height: 18),
          PushButton(
            controlSize: ControlSize.large,
            onPressed: onOpen,
            child: const Text('폴더 열기'),
          ),
        ],
      ),
    );
  }
}
