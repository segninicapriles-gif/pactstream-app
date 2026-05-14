import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/contract_pdf_builder.dart';
import '../../data/pact_providers.dart';

/// Vista previa del PDF del contrato.
///
/// - PdfPreview gestiona zoom, scroll, descarga, imprimir y compartir.
/// - El PDF se genera in-memory desde PactDetail; no se persiste todavía
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
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.ink900,
        elevation: 0,
        title: Text('Contrato del pacto', style: AppTypography.h3),
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Text(
              'No se pudo cargar el contrato: $e',
              textAlign: TextAlign.center,
              style: AppTypography.body,
            ),
          ),
        ),
        data: (detail) => PdfPreview(
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
          loadingWidget: const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}
