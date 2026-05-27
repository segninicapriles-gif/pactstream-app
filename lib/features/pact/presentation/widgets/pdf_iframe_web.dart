import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

int _viewCounter = 0;

/// Construye un widget que muestra el PDF dentro de un iframe nativo
/// del navegador. Evita el bug de PdfPreview en Flutter Web
/// (Unexpected null value en printing_web.dart).
///
/// El navegador usa su visor PDF integrado (Chrome PDF Viewer) que
/// incluye zoom, scroll, descarga e imprimir de forma nativa.
Widget buildPdfIframe(Uint8List bytes) {
  final viewType = 'contract-pdf-${_viewCounter++}';

  ui_web.platformViewRegistry.registerViewFactory(
      viewType, (int viewId, {Object? params}) {
    final blob = web.Blob(
      [bytes.toJS].toJS,
      web.BlobPropertyBag(type: 'application/pdf'),
    );
    final url = web.URL.createObjectURL(blob);

    final iframe = web.document.createElement('iframe') as web.HTMLIFrameElement;
    iframe.src = url;
    iframe.style.border = 'none';
    iframe.style.width = '100%';
    iframe.style.height = '100%';
    return iframe;
  });

  return HtmlElementView(viewType: viewType);
}
