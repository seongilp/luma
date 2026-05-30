import 'dart:math';

/// 두 특징벡터의 L2(유클리드) 거리. Vision computeDistance와 같은 척도.
double l2Distance(List<double> a, List<double> b) {
  final n = a.length < b.length ? a.length : b.length;
  var sum = 0.0;
  for (var i = 0; i < n; i++) {
    final d = a[i] - b[i];
    sum += d * d;
  }
  return sqrt(sum);
}

/// 인덱스별 벡터 목록을 거리 임계값 이하끼리 유니온-파인드로 묶는다.
/// 2개 이상 묶음만, 큰 순으로 인덱스 배열 반환.
List<List<int>> clusterByDistance(List<List<double>?> vectors, double threshold) {
  final n = vectors.length;
  final parent = List<int>.generate(n, (i) => i);
  int find(int x) {
    while (parent[x] != x) {
      parent[x] = parent[parent[x]];
      x = parent[x];
    }
    return x;
  }

  for (var i = 0; i < n; i++) {
    final a = vectors[i];
    if (a == null) continue;
    for (var j = i + 1; j < n; j++) {
      final b = vectors[j];
      if (b == null) continue;
      if (l2Distance(a, b) <= threshold) parent[find(i)] = find(j);
    }
  }

  final groups = <int, List<int>>{};
  for (var i = 0; i < n; i++) {
    if (vectors[i] == null) continue;
    groups.putIfAbsent(find(i), () => []).add(i);
  }
  final result = groups.values.where((g) => g.length > 1).toList();
  result.sort((a, b) => b.length.compareTo(a.length));
  return result;
}
