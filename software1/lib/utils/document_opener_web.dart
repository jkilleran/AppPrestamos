import 'dart:html' as html;

import 'package:http/http.dart' as http;

String _filenameFromContentDisposition(String? contentDisposition) {
  if (contentDisposition == null) return '';
  final cd = contentDisposition;
  final mStar = RegExp(
    r"filename\*=UTF-8''([^;]+)",
    caseSensitive: false,
  ).firstMatch(cd);
  if (mStar != null) {
    return Uri.decodeFull(mStar.group(1) ?? '');
  }
  final m = RegExp(
    r'filename="?([^";]+)"?',
    caseSensitive: false,
  ).firstMatch(cd);
  return m?.group(1) ?? '';
}

String _safeFilename({
  required String filenameFallback,
  required String? contentDisposition,
}) {
  final name = _filenameFromContentDisposition(contentDisposition);
  if (name.trim().isNotEmpty) return name;
  return filenameFallback;
}

Future<void> openDocumentWithAuth({
  required Uri uri,
  required String token,
  required String filenameFallback,
}) async {
  final resp = await http.get(uri, headers: {'Authorization': 'Bearer $token'});

  if (resp.statusCode != 200) {
    throw Exception('No se pudo descargar el documento (${resp.statusCode}).');
  }

  final filename = _safeFilename(
    filenameFallback: filenameFallback,
    contentDisposition: resp.headers['content-disposition'],
  );

  final blob = html.Blob([resp.bodyBytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);

  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..style.display = 'none';

  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}
