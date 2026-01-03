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

String _safePdfName(int installmentId, String? contentDisposition) {
  final name = _filenameFromContentDisposition(contentDisposition);
  if (name.toLowerCase().endsWith('.pdf')) return name;
  return 'recibo_$installmentId.pdf';
}

Future<void> openReceiptWithAuth({
  required Uri uri,
  required String token,
  required int installmentId,
}) async {
  final resp = await http.get(uri, headers: {'Authorization': 'Bearer $token'});

  if (resp.statusCode != 200) {
    String msg = 'No se pudo descargar el recibo.';
    try {
      final err = resp.body;
      if (err.contains('Token requerido')) {
        msg = 'Token requerido para descargar.';
      }
    } catch (_) {}
    throw Exception(msg);
  }

  final contentType = resp.headers['content-type'] ?? 'application/pdf';
  final filename = _safePdfName(
    installmentId,
    resp.headers['content-disposition'],
  );

  final blob = html.Blob([resp.bodyBytes], contentType);
  final objectUrl = html.Url.createObjectUrlFromBlob(blob);

  // Abrir/descargar usando un click real (mejor compatibilidad que window.open).
  final a = html.AnchorElement(href: objectUrl)
    ..target = '_self'
    ..style.display = 'none';

  // Forzar descarga (requerimiento: siempre descargar en PDF).
  a.download = filename;

  html.document.body?.children.add(a);
  a.click();
  a.remove();

  // Deja tiempo para que el navegador consuma el blob.
  await Future<void>.delayed(const Duration(seconds: 2));
  html.Url.revokeObjectUrl(objectUrl);
}
