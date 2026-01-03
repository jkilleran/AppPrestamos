// Fallback (por si una plataforma no está soportada por web/io).
// Esto evita errores de compilación si se llegara a compilar en un target inesperado.

Future<void> openReceiptWithAuth({
  required Uri uri,
  required String token,
  required int installmentId,
}) {
  throw UnsupportedError('Plataforma no soportada para abrir recibos.');
}
