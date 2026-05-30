import 'dart:io';
import 'package:exif/exif.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

/// 정보 패널에 표시할 사진 메타데이터.
class ExifInfo {
  final String fileName;
  final String sizeText;
  final String modifiedText;
  final String? dimensions;
  final String? dateTaken;
  final String? camera;
  final String? lens;
  final String? exposure;
  final String? gps;

  ExifInfo({
    required this.fileName,
    required this.sizeText,
    required this.modifiedText,
    this.dimensions,
    this.dateTaken,
    this.camera,
    this.lens,
    this.exposure,
    this.gps,
  });

  /// (라벨, 값) 쌍 목록 — 값이 있는 것만.
  List<MapEntry<String, String>> get rows => [
        MapEntry('파일', fileName),
        MapEntry('용량', sizeText),
        if (dimensions != null) MapEntry('해상도', dimensions!),
        if (dateTaken != null) MapEntry('촬영일', dateTaken!),
        MapEntry('수정일', modifiedText),
        if (camera != null) MapEntry('카메라', camera!),
        if (lens != null) MapEntry('렌즈', lens!),
        if (exposure != null) MapEntry('노출', exposure!),
        if (gps != null) MapEntry('위치', gps!),
      ];
}

String _humanSize(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB'];
  double s = bytes.toDouble();
  var u = 0;
  while (s >= 1024 && u < units.length - 1) {
    s /= 1024;
    u++;
  }
  return '${s.toStringAsFixed(u == 0 ? 0 : 1)} ${units[u]}';
}

Future<ExifInfo> readInfo(String path) async {
  final file = File(path);
  final stat = await file.stat();
  final df = DateFormat('yyyy-MM-dd HH:mm');

  String? dims, dateTaken, camera, lens, exposure, gps;

  try {
    final bytes = await file.readAsBytes();
    final tags = await readExifFromBytes(bytes);
    if (tags.isNotEmpty) {
      String? t(String k) => tags[k]?.printable.trim();

      final w = t('EXIF ExifImageWidth') ?? t('Image ImageWidth');
      final h = t('EXIF ExifImageLength') ?? t('Image ImageLength');
      if (w != null && h != null) dims = '$w × $h';

      dateTaken = t('EXIF DateTimeOriginal') ?? t('Image DateTime');

      final make = t('Image Make');
      final model = t('Image Model');
      if (model != null) {
        camera = (make != null && !model.startsWith(make)) ? '$make $model' : model;
      }
      lens = t('EXIF LensModel');

      final f = t('EXIF FNumber');
      final exp = t('EXIF ExposureTime');
      final iso = t('EXIF ISOSpeedRatings');
      final focal = t('EXIF FocalLength');
      final parts = <String>[
        if (f != null) 'ƒ/${_ratioToNum(f)}',
        if (exp != null) '${exp}s',
        if (iso != null) 'ISO $iso',
        if (focal != null) '${_ratioToNum(focal)}mm',
      ];
      if (parts.isNotEmpty) exposure = parts.join('  ');

      final latv = t('GPS GPSLatitude');
      final lonv = t('GPS GPSLongitude');
      if (latv != null && lonv != null) {
        final latRef = t('GPS GPSLatitudeRef') ?? '';
        final lonRef = t('GPS GPSLongitudeRef') ?? '';
        gps = '$latv $latRef, $lonv $lonRef';
      }
    }
  } catch (_) {/* EXIF 없거나 PNG 등 */}

  return ExifInfo(
    fileName: p.basename(path),
    sizeText: _humanSize(stat.size),
    modifiedText: df.format(stat.modified),
    dimensions: dims,
    dateTaken: dateTaken,
    camera: camera,
    lens: lens,
    exposure: exposure,
    gps: gps,
  );
}

/// "28/10" 같은 EXIF 분수 표기를 소수로.
String _ratioToNum(String s) {
  if (s.contains('/')) {
    final parts = s.split('/');
    final a = double.tryParse(parts[0]);
    final b = double.tryParse(parts[1]);
    if (a != null && b != null && b != 0) {
      final v = a / b;
      return v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
    }
  }
  return s;
}
