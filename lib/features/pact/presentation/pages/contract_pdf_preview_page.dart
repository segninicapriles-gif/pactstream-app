import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/shimmer_box.dart';
import '../../data/contract_pdf_builder.dart';
import '../../data/pact_detail.dart';
import '../../data/pact_providers.dart';

// Conditional import: web uses iframe, mobile uses PdfPreview.
import '../widgets/pdf_iframe_stub.dart'
    if (dart.library.js_interop) '../widgets/pdf_iframe_web.dart';

/// Vista previa del PDF del contrato.
///
/// - En **web**: genera los bytes y los muestra en un iframe nativo del
///   navegador (Chrome PDF Viewer), evitando el bug de PdfPreview en
///   Flutter Web (Unexpected null value en printing_web.dart).
/// - En **mobile/desktop**: usa PdfPreview que gestiona zoom, scroll,
///   descarga, imprimir y compartir.
/// - El PDF se genera in-memory desde PactDetail; no se persiste todavia
///   en Storage (en un chunk futuro guardaremos un snapshot inmutable
///   cuando todas las partes firmen).
class ContractPdfPreviewPage extends ConsumerWidget {
  const ContractPdfPreviewPage({super.key, required this.pactId});

  final String pactId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(pactDetailProvider(pactId));

    return Scaffold(
      backgroundColor: AppColors.ink50,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.psGradientDeep),
        ),
        title: Text(
          'Contrato del pacto',
          style: AppTypography.h3.copyWith(color: AppColors.white),
        ),
      ),
      body: detailAsync.when(
        loading: () => const DetailSkeleton(),
        error: (e, _) => ErrorStateView(
          title: 'No se pudo cargar el contrato',
          message: e.toString(),
          onRetry: () => ref.invalidate(pactDetailProvider(pactId)),
          scrollable: false,
        ),
        data: (detail) => kIsWeb
            ? _WebPdfView(detail: detail, pactId: pactId)
            : PdfPreview(
                build: (format) async {
                  final builder = ContractPdfBuilder(detail: detail);
                  return await builder.buildBytes();
                },
                canChangePageFormat: false,
                canChangeOrientation: false,
                canDebug: false,
                allowPrinting: true,
                allowSharing: true,
                pdfFileName:
                    'PactStream_${detail.pact.displayId}_contrato.pdf',
                actionBarTheme: const PdfActionBarTheme(
                  backgroundColor: AppColors.psNavy,
                  iconColor: AppColors.white,
                  textStyle: TextStyle(color: AppColors.white),
                ),
                previewPageMargin: const EdgeInsets.all(AppSpacing.md),
                loadingWidget:
                    const Center(child: CircularProgressIndicator()),
                onError: (context, error) => ErrorStateView(
                  title: 'No se pudo generar el PDF',
                  message: error.toString(),
                  onRetry: () =>
                      ref.invalidate(pactDetailProvider(pactId)),
                  scrollable: false,
                ),
              ),
      ),
    );
  }
}

/// Visor de PDF para Flutter Web.
///
/// Genera los bytes del PDF de forma asincrona y los muestra en un
/// iframe nativo del navegador con su visor integrado (zoom, scroll,
/// descarga, imprimir).
class _WebPdfView extends StatefulWidget {
  const _WebPdfView({required this.detail, required this.pactId});

  final PactDetail detail;
  final String pactId;

  @override
  State<_WebPdfView> createState() => _WebPdfViewState();
}

class _WebPdfViewState extends State<_WebPdfView> {
  Uint8List? _bytes;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _generatePdf();
  }

  Future<void> _generatePdf() async {
    try {
      final builder = ContractPdfBuilder(detail: widget.detail);
      final bytes = await builder.buildBytes();
      if (mounted) setState(() => _bytes = bytes);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return ErrorStateView(
        title: 'No se pudo generar el PDF',
        message: _error.toString(),
        onRetry: () {
          setState(() {
            _error = null;
            _bytes = null;
          });
          _generatePdf();
        },
        scrollable: false,
      );
    }
    if (_bytes == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return buildPdfIframe(_bytes!);
  }
}
