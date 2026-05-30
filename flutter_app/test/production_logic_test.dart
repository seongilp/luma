import 'package:flutter_test/flutter_test.dart';
import 'package:photo_manager/models/app_settings.dart';
import 'package:photo_manager/models/folder_group.dart';
import 'package:photo_manager/models/folder_node.dart';
import 'package:photo_manager/models/photo_item.dart';
import 'package:photo_manager/models/photo_meta.dart';
import 'package:photo_manager/models/sort_filter.dart';

PhotoItem item(String path) =>
    PhotoItem(path: path, sizeBytes: 1, modified: DateTime(2026, 1, 1));

void main() {
  group('applySortFilter groupByFolder', () {
    final items = [
      item('/A/2.jpg'),
      item('/B/1.jpg'),
      item('/A/1.jpg'),
      item('/B/2.jpg'),
    ];
    final meta = MetaStore();

    test('폴더별로 묶어 같은 폴더 사진이 붙어 나온다', () {
      final r = applySortFilter(items,
          query: '',
          field: SortField.name,
          ascending: true,
          ratingFilter: RatingFilter.all,
          meta: meta,
          groupByFolder: true);
      expect(r.map((e) => e.path).toList(),
          ['/A/1.jpg', '/A/2.jpg', '/B/1.jpg', '/B/2.jpg']);
    });

    test('groupByFolder=false면 전역 이름순으로 섞인다', () {
      final r = applySortFilter(items,
          query: '',
          field: SortField.name,
          ascending: true,
          ratingFilter: RatingFilter.all,
          meta: meta,
          groupByFolder: false);
      expect(r.map((e) => e.name).toList(), ['1.jpg', '1.jpg', '2.jpg', '2.jpg']);
    });
  });

  group('buildFolderTree 멀티루트', () {
    FolderGroup fg(String path, int count) => FolderGroup(
        path: path,
        displayName: path,
        items: [for (var i = 0; i < count; i++) item('$path/p$i.jpg')]);

    test('해당 루트에 속한 폴더만 트리에 포함한다', () {
      final folders = [fg('/A', 2), fg('/B/sub', 3)];
      final dirs = ['/A', '/B', '/B/sub'];

      final treeA = buildFolderTree('/A', folders, dirs);
      expect(treeA.length, 1);
      expect(treeA.first.path, '/A');
      expect(treeA.first.folderIndex, 0); // /A는 0번 폴더
      // /B 계열은 /A 트리에 없어야 한다
      expect(treeA.first.children.any((c) => c.path.startsWith('/B')), isFalse);

      final treeB = buildFolderTree('/B', folders, dirs);
      expect(treeB.first.path, '/B');
      expect(treeB.first.children.map((c) => c.path), contains('/B/sub'));
      // 합산 카운트: /B 자체 0 + sub 3
      expect(treeB.first.totalCount, 3);
    });
  });

  group('AppSettings 직렬화 라운드트립', () {
    test('새 필드(테마/삭제확인/자동열기/유사분석/썸네일/roots) 보존', () {
      final s = AppSettings(
        anthropicApiKey: 'k',
        claudeMaxCalls: 7,
        roots: ['/a', '/b'],
        uiScale: 1.5,
        themeMode: 'dark',
        confirmDelete: false,
        autoOpenLast: false,
        defaultSimilarMode: 'hash',
        thumbSize: 220,
      );
      final r = AppSettings.fromJson(s.toJson());
      expect(r.anthropicApiKey, 'k');
      expect(r.claudeMaxCalls, 7);
      expect(r.roots, ['/a', '/b']);
      expect(r.uiScale, 1.5);
      expect(r.themeMode, 'dark');
      expect(r.confirmDelete, false);
      expect(r.autoOpenLast, false);
      expect(r.defaultSimilarMode, 'hash');
      expect(r.thumbSize, 220);
    });

    test('구버전 JSON(신규 필드 없음)도 기본값으로 로드', () {
      final r = AppSettings.fromJson({'lastRoot': '/old'});
      expect(r.themeMode, 'system');
      expect(r.confirmDelete, true);
      expect(r.autoOpenLast, true);
      expect(r.defaultSimilarMode, 'ai');
      expect(r.thumbSize, 160);
      expect(r.lastRoot, '/old');
      expect(r.roots, isEmpty);
    });
  });
}
