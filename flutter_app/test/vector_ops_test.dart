import 'package:flutter_test/flutter_test.dart';
import 'package:photo_manager/services/vector_ops.dart';

void main() {
  test('l2Distance', () {
    expect(l2Distance([0, 0], [3, 4]), 5);
    expect(l2Distance([1, 2, 3], [1, 2, 3]), 0);
  });

  test('partitionByDistance: 같은 장소 묶음 → 대표만 호출', () {
    // 3곳(A,B,C). A 3장, B 2장, C 1장 = 6장 → 3 묶음.
    final a = [0.0, 0.0];
    final b = [10.0, 10.0];
    final c = [50.0, 50.0];
    final vectors = [a, [0.1, 0.0], [0.0, 0.1], b, [10.1, 10.0], c];
    final parts = partitionByDistance(vectors, 1.0);
    expect(parts.length, 3); // 6장이지만 Claude 호출은 3번이면 됨
    final sizes = parts.map((p) => p.length).toList()..sort();
    expect(sizes, [1, 2, 3]);
  });
}
