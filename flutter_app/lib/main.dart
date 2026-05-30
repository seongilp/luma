import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, ThemeMode;
import 'package:file_selector/file_selector.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:path/path.dart' as p;

import 'state/app_state.dart';
import 'widgets/folder_sidebar.dart';
import 'widgets/photo_grid.dart';

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

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  Future<void> _openFolder() async {
    final dir = await getDirectoryPath(confirmButtonText: '선택');
    if (dir != null) {
      await _state.openRoot(dir);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _state,
      builder: (context, _) {
        final root = _state.root;
        return MacosWindow(
          sidebar: Sidebar(
            minWidth: 240,
            top: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('폴더', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            builder: (context, scrollController) => FolderSidebar(
              state: _state,
              scrollController: scrollController,
            ),
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
              title: Text(root != null ? p.basename(root) : 'Photo Manager'),
              titleWidth: 240,
              actions: [
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
                builder: (context, scrollController) => _buildContent(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent() {
    if (_state.loading) {
      return const Center(child: ProgressCircle());
    }
    if (_state.root == null) {
      return _EmptyState(
        message: '시작하려면 사진 폴더를 여세요.',
        onOpen: _openFolder,
      );
    }
    if (_state.currentImages.isEmpty) {
      return _EmptyState(
        message: _state.error ?? '이 폴더에는 이미지가 없습니다.',
        onOpen: _openFolder,
      );
    }
    return PhotoGrid(imagePaths: _state.currentImages);
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
