import 'dart:typed_data';

import 'package:flutter/widgets.dart';

/// Stub para plataformas no-web.
/// En mobile/desktop se usa PdfPreview del paquete `printing`,
/// por lo que esta funcion nunca se invoca.
Widget buildPdfIframe(Uint8List bytes) {
  throw UnsupportedError('buildPdfIframe solo es soportado en Flutter Web');
}
