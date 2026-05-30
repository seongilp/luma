/// Finder식 자연 정렬: 숫자 부분을 수치로 비교 ("img2" < "img10").
int naturalCompare(String a, String b) {
  final la = a.toLowerCase();
  final lb = b.toLowerCase();
  var i = 0, j = 0;
  while (i < la.length && j < lb.length) {
    final ca = la.codeUnitAt(i);
    final cb = lb.codeUnitAt(j);
    final aDigit = _isDigit(ca);
    final bDigit = _isDigit(cb);
    if (aDigit && bDigit) {
      // 숫자 덩어리 추출 후 수치 비교 (선행 0 무시)
      var si = i;
      while (i < la.length && _isDigit(la.codeUnitAt(i))) {
        i++;
      }
      var sj = j;
      while (j < lb.length && _isDigit(lb.codeUnitAt(j))) {
        j++;
      }
      var na = la.substring(si, i).replaceFirst(RegExp(r'^0+(?=\d)'), '');
      var nb = lb.substring(sj, j).replaceFirst(RegExp(r'^0+(?=\d)'), '');
      if (na.length != nb.length) return na.length - nb.length;
      final cmp = na.compareTo(nb);
      if (cmp != 0) return cmp;
    } else {
      if (ca != cb) return ca - cb;
      i++;
      j++;
    }
  }
  return (la.length - i) - (lb.length - j);
}

bool _isDigit(int c) => c >= 0x30 && c <= 0x39;
