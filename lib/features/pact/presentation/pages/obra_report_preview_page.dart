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
import '../../data/obra_report_builder.dart';
import '../../data/pact_providers.dart';

// Conditional import: web uses iframe, mobile uses PdfPreview.
import '../widgets/pdf_iframe_stub.dart'
    if (dart.library.js_interop) '../widgets/pdf_iframe_web.dart';

/// Vista previa del "Libro de la Obra" — expediente completo en PDF.
///
/// Consolida contrato, hitos, anexos activos y firmas en un único
/// documento exportable para banco, aseguradora, notaría o archivo.
///
/// Comportamiento web/mobile idéntico al de ContractPdfPreviewPage.
class ObraReportPreviewPage extends ConsumerWidget {
  const ObraReportPreviewPage({super.key, required this.pactId});

  final String pactId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(pactDetailProvider(pactId));

    return Scaffold(
      backgroundColor: context.colors.scaffold,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.psGradientDeep),
        ),
        title: Text(
          'Libro de la Obra',
          style: AppTypography.h3.copyWith(color: AppColors.white),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: Tooltip(
              message: 'Expediente completo: contrato, hitos, anexos y firmas',
              child: const Icon(Icons.info_outline, size: 20),
            ),
          ),
        ],
      ),
      body: detailAsync.when(
        loading: () => const DetailSkeleton(),
        error: (e, _) => ErrorStateView(
          title: 'No se pudo cargar la obra',
          message: e.toString(),
          onRetry: () => ref.invalidate(pactDetailProvider(pactId)),
          scrollable: false,
        ),
        data: (detail) => kIsWeb
            ? _WebObraReportView(detail: detail, pactId: pactId)
            : PdfPreview(
                build: (format) async {
                  final builder = ObraReportBuilder(detail: detail);
                  return await builder.buildBytes();
                },
                canChangePageFormat: false,
                canChangeOrientation: false,
                canDebug: false,
                allowPrinting: true,
                allowSharing: true,
                pdfFileName:
                    'PactStream_${detail.pact.displayId}_libro_obra.pdf',
                actionBarTheme: const PdfActionBarTheme(
                  backgroundColor: AppColors.psNavy,
                  iconColor: AppColors.white,
                  textStyle: TextStyle(color: AppColors.white),
                ),
                previewPageMargin: const EdgeInsets.all(AppSpacing.md),
                loadingWidget:
                    const Center(child: CircularProgressIndicator()),
                onError: (context, error) => ErrorStateView(
                  title: 'No se pudo generar el expediente',
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

class _WebObraReportView extends StatefulWidget {
  const _WebObraReportView({required this.detail, required this.pactId});

  final dynamic detail;
  final String pactId;

  @override
  State<_WebObraReportView> createState() => _WebObraReportViewState();
}

class _WebObraReportViewState extends State<_WebObraReportView> {
  Uint8List? _bytes;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _generatePdf();
  }

  Future<void> _generatePdf() async {
    try {
      final builder = ObraReportBuilder(detail: widget.detail);
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
        title: 'No se pudo generar el expediente',
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
