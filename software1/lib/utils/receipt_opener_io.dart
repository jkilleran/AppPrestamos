import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

String _filenameFromContentDisposition(String? contentDisposition) {
  if (contentDisposition == null) return '';
  final cd = contentDisposition;
  // filename*=UTF-8''...
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

  final filename = _safePdfName(
    installmentId,
    resp.headers['content-disposition'],
  );

  final dir = await getTemporaryDirectory();
  final filePath = '${dir.path}/$filename';
  final file = await File(filePath).writeAsBytes(resp.bodyBytes);

  final result = await OpenFile.open(file.path);
  if (result.type != ResultType.done) {
    throw Exception(result.message);
  }
}
