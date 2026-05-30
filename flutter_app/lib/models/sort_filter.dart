import 'package:path/path.dart' as p;

import '../services/natural_sort.dart';
import 'photo_item.dart';
import 'photo_meta.dart';

enum SortField { name, modified, size }

extension SortFieldLabel on SortField {
  String get label => switch (this) {
        SortField.name => '이름',
        SortField.modified => '수정일',
        SortField.size => '크기',
      };
}

/// 별점/즐겨찾기 필터.
enum RatingFilter { all, favorites, rated3, rated4, rated5 }

extension RatingFilterLabel on RatingFilter {
  String get label => switch (this) {
        RatingFilter.all => '전체',
        RatingFilter.favorites => '즐겨찾기',
        RatingFilter.rated3 => '★3 이상',
        RatingFilter.rated4 => '★4 이상',
        RatingFilter.rated5 => '★5',
      };
}

/// 검색어 + 필터를 적용한 뒤 정렬한 목록을 만든다. (순수 함수)
///
/// [groupByFolder]가 true면 같은 폴더 사진끼리 항상 붙여 보여준다(폴더가 1차 키).
/// 여러 폴더를 합쳐 보는 '모든 사진'에서 사진이 마구 섞이는 걸 막는다.
List<PhotoItem> applySortFilter(
  List<PhotoItem> items, {
  required String query,
  required SortField field,
  required bool ascending,
  required RatingFilter ratingFilter,
  required MetaStore meta,
  bool groupByFolder = false,
}) {
  final q = query.trim().toLowerCase();
  var list = items.where((it) {
    if (q.isNotEmpty && !it.name.toLowerCase().contains(q)) return false;
    final m = meta.get(it.path);
    return switch (ratingFilter) {
      RatingFilter.all => true,
      RatingFilter.favorites => m.favorite,
      RatingFilter.rated3 => m.rating >= 3,
      RatingFilter.rated4 => m.rating >= 4,
      RatingFilter.rated5 => m.rating >= 5,
    };
  }).toList();

  int cmp(PhotoItem a, PhotoItem b) => switch (field) {
        SortField.name => naturalCompare(a.name, b.name),
        SortField.modified => a.modified.compareTo(b.modified),
        SortField.size => a.sizeBytes.compareTo(b.sizeBytes),
      };

  list.sort((a, b) {
    // 폴더 그룹은 항상 같은 순서로 묶고, 그 안에서만 선택한 기준으로 정렬한다.
    if (groupByFolder) {
      final byDir = naturalCompare(p.dirname(a.path), p.dirname(b.path));
      if (byDir != 0) return byDir;
    }
    final c = cmp(a, b);
    return ascending ? c : -c;
  });
  return list;
}
