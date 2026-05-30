import 'dart:io';
import 'package:path/path.dart' as p;

/// Lightroom XMP 사이드카(별점·키워드).
class XmpData {
  final int? rating; // 0~5
  final List<String> keywords;
  const XmpData({this.rating, this.keywords = const []});
}

String _sidecarPath(String photoPath) => p.setExtension(photoPath, '.xmp');

/// 사진 옆 .xmp 사이드카를 읽는다 (없으면 null).
Future<XmpData?> readXmp(String photoPath) async {
  final f = File(_sidecarPath(photoPath));
  if (!await f.exists()) return null;
  try {
    final s = await f.readAsString();
    final rating = RegExp(r'xmp:Rating="(\d)"').firstMatch(s)?.group(1) ??
        RegExp(r'<xmp:Rating>(\d)</xmp:Rating>').firstMatch(s)?.group(1);
    final keywords = RegExp(r'<rdf:li[^>]*>([^<]+)</rdf:li>')
        .allMatches(s)
        .map((m) => m.group(1)!.trim())
        .where((k) => k.isNotEmpty)
        .toList();
    return XmpData(rating: rating != null ? int.tryParse(rating) : null, keywords: keywords);
  } catch (_) {
    return null;
  }
}

/// 별점·키워드를 XMP 사이드카로 저장한다 (Lightroom 호환).
Future<bool> writeXmp(String photoPath, {int? rating, List<String> keywords = const []}) async {
  final subjects = keywords.isEmpty
      ? ''
      : '''
   <dc:subject>
    <rdf:Bag>
${keywords.map((k) => '     <rdf:li>${_esc(k)}</rdf:li>').join('\n')}
    </rdf:Bag>
   </dc:subject>''';
  final xmp = '''<?xpacket begin="﻿" id="W5M0MpCehiHzreSzNTczkc9d"?>
<x:xmpmeta xmlns:x="adobe:ns:meta/">
 <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
  <rdf:Description rdf:about=""
    xmlns:xmp="http://ns.adobe.com/xap/1.0/"
    xmlns:dc="http://purl.org/dc/elements/1.1/"
    xmp:Rating="${rating ?? 0}">
$subjects
  </rdf:Description>
 </rdf:RDF>
</x:xmpmeta>
<?xpacket end="w"?>''';
  try {
    await File(_sidecarPath(photoPath)).writeAsString(xmp);
    return true;
  } catch (_) {
    return false;
  }
}

String _esc(String s) =>
    s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
