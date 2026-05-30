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
List<PhotoItem> applySortFilter(
  List<PhotoItem> items, {
  required String query,
  required SortField field,
  required bool ascending,
  required RatingFilter ratingFilter,
  required MetaStore meta,
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

  list.sort((a, b) => ascending ? cmp(a, b) : cmp(b, a));
  return list;
}
