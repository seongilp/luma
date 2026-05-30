import 'dart:io';
import 'package:exif/exif.dart';
import 'package:latlong2/latlong.dart';

/// 사진의 EXIF에서 GPS 좌표를 읽는다. 없으면 null.
Future<LatLng?> readGps(String path) async {
  try {
    final bytes = await File(path).readAsBytes();
    final tags = await readExifFromBytes(bytes);
    if (tags.isEmpty) return null;
    final lat = _toDecimal(tags['GPS GPSLatitude'], tags['GPS GPSLatitudeRef']);
    final lon = _toDecimal(tags['GPS GPSLongitude'], tags['GPS GPSLongitudeRef']);
    if (lat == null || lon == null) return null;
    if (lat == 0 && lon == 0) return null;
    return LatLng(lat, lon);
  } catch (_) {
    return null;
  }
}

/// 도/분/초 비율 3쌍 + 방향(N/S/E/W) → 십진수 좌표.
double? _toDecimal(IfdTag? value, IfdTag? ref) {
  if (value == null) return null;
  final parts = value.values.toList();
  if (parts.length < 3) return null;
  try {
    double r(int i) {
      final v = parts[i] as Ratio;
      return v.denominator == 0 ? 0 : v.numerator / v.denominator;
    }

    var deg = r(0) + r(1) / 60.0 + r(2) / 3600.0;
    final dir = (ref?.printable ?? '').trim().toUpperCase();
    if (dir == 'S' || dir == 'W') deg = -deg;
    return deg;
  } catch (_) {
    return null;
  }
}
