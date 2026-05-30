import 'package:flutter_test/flutter_test.dart';
import 'package:photo_manager/models/photo_item.dart';
import 'package:photo_manager/models/photo_meta.dart';
import 'package:photo_manager/models/sort_filter.dart';

PhotoItem item(String name, int size, int day) => PhotoItem(
      path: '/x/$name',
      sizeBytes: size,
      modified: DateTime(2026, 1, day),
    );

void main() {
  final items = [
    item('c.jpg', 300, 3),
    item('a.jpg', 100, 1),
    item('b.jpg', 200, 2),
  ];
  final meta = MetaStore();

  test('이름 오름차순 정렬', () {
    final r = applySortFilter(items,
        query: '', field: SortField.name, ascending: true, ratingFilter: RatingFilter.all, meta: meta);
    expect(r.map((e) => e.name).toList(), ['a.jpg', 'b.jpg', 'c.jpg']);
  });

  test('크기 내림차순 정렬', () {
    final r = applySortFilter(items,
        query: '', field: SortField.size, ascending: false, ratingFilter: RatingFilter.all, meta: meta);
    expect(r.first.name, 'c.jpg');
    expect(r.last.name, 'a.jpg');
  });

  test('검색어 필터', () {
    final r = applySortFilter(items,
        query: 'a', field: SortField.name, ascending: true, ratingFilter: RatingFilter.all, meta: meta);
    expect(r.length, 1);
    expect(r.first.name, 'a.jpg');
  });
}
