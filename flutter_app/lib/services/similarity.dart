import '../models/photo_item.dart';
import 'phash.dart';

/// 해시 거리 임계값 (0~64). 이하이면 "비슷함". 연사/중복엔 10 안팎이 적당.
const int kSimilarThreshold = 10;

/// 모든 사진의 dHash를 구해, 서로 비슷한 것끼리 묶는다.
/// 2장 이상인 묶음만, 큰 묶음 순으로 반환한다.
/// `onProgress`(0~1)로 진행률을 알린다.
Future<List<List<PhotoItem>>> findSimilarGroups(
  List<PhotoItem> items, {
  int threshold = kSimilarThreshold,
  void Function(double progress)? onProgress,
}) async {
  final kept = <PhotoItem>[];
  final hashes = <int>[];

  for (var i = 0; i < items.length; i++) {
    final h = await computeDHash(items[i].path);
    if (h != null) {
      kept.add(items[i]);
      hashes.add(h);
    }
    if (onProgress != null && (i % 4 == 0 || i == items.length - 1)) {
      onProgress((i + 1) / items.length);
    }
  }

  // 유니온-파인드로 임계값 이하 쌍을 한 묶음으로.
  final parent = List<int>.generate(kept.length, (i) => i);
  int find(int x) {
    while (parent[x] != x) {
      parent[x] = parent[parent[x]];
      x = parent[x];
    }
    return x;
  }

  for (var i = 0; i < kept.length; i++) {
    for (var j = i + 1; j < kept.length; j++) {
      if (hammingDistance(hashes[i], hashes[j]) <= threshold) {
        parent[find(i)] = find(j);
      }
    }
  }

  final groups = <int, List<PhotoItem>>{};
  for (var i = 0; i < kept.length; i++) {
    groups.putIfAbsent(find(i), () => []).add(kept[i]);
  }

  final result = groups.values.where((g) => g.length > 1).toList();
  result.sort((a, b) => b.length.compareTo(a.length));
  return result;
}
