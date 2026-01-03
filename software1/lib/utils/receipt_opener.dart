// Plataforma: expone `openReceiptWithAuth` con implementación condicional.
//
// - Web: descarga con `http` (Authorization) y abre el archivo vía Blob.
// - IO (Android/iOS/Desktop): descarga a temporal y abre con `open_file`.
export 'receipt_opener_stub.dart'
    if (dart.library.html) 'receipt_opener_web.dart'
    if (dart.library.io) 'receipt_opener_io.dart';
