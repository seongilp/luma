import 'package:flutter_test/flutter_test.dart';
import 'package:photo_manager/services/phash.dart';

void main() {
  test('hammingDistance: 동일/상이 비트', () {
    expect(hammingDistance(0, 0), 0);
    expect(hammingDistance(0xFF, 0xFF), 0);
    expect(hammingDistance(0x0, 0xF), 4);
    // 음수(최상위 비트) 차이도 무한루프 없이 계산
    expect(hammingDistance(0, -1), 64);
    expect(hammingDistance(-1, -1), 0);
  });
}
