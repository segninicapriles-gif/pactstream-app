import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_haptics.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/shimmer_box.dart';
import '../../data/contract_pdf_builder.dart';
import '../../data/pact_providers.dart';

// Conditional import: web usa iframe nativo, mobile usa PdfPreview.
import '../widgets/pdf_iframe_stub.dart'
    if (dart.library.js_interop) '../widgets/pdf_iframe_web.dart';

/// Pantalla de lectura del contrato + firma con consentimiento explícito.
///
/// Flujo:
///   1. Renderiza el texto del contrato dinámico (ContractTextBuilder).
///   2. Usuario debe scrollear hasta el final para activar el checkbox.
///   3. Marca el checkbox de "He leído y acepto".
///   4. Pulsa "Firmar" → llama sf_sign_contract con hash del texto.
///   5. Si todos firmaron, pact → signed; mostramos pantalla de éxito.
class ContractSigningPage extends ConsumerStatefulWidget {
  const ContractSigningPage({super.key, required this.pactId});

  final String pactId;

  @override
  ConsumerState<ContractSigningPage> createState() =>
      _ContractSigningPageState();
}

class _ContractSigningPageState extends ConsumerState<ContractSigningPage> {
  // Consentimiento real (P1-10): en móvil el checkbox se habilita cuando
  // el usuario hace scroll hasta el final del contrato (escuchamos las
  // ScrollNotification que burbujean desde el ListView interno de
  // PdfPreview). Si el contenido cabe sin scroll, se habilita en cuanto
  // hay métricas. En web el PDF vive en un iframe nativo del navegador
  // (sin acceso a su scroll desde Flutter), así que ahí mantenemos un
  // mínimo de tiempo de lectura como aproximación.
  bool _hasReadContract = false;
  Timer? _webReadingTimer;

  bool _accepted = false;
  bool _submitting = false;
  String? _error;
  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _webReadingTimer = Timer(const Duration(seconds: 8), () {
        if (mounted) setState(() => _hasReadContract = true);
      });
    }
  }

  @override
  void dispose() {
    _webReadingTimer?.cancel();
    super.dispose();
  }

  /// Marca el contrato como leído si el usuario llegó al final del
  /// contenido (o si no hay scroll porque el contenido cabe entero).
  void _checkScrollMetrics(ScrollMetrics metrics) {
    if (_hasReadContract) return;
    if (metrics.axis != Axis.vertical) return;
    if (!metrics.hasContentDimensions) return;
    final reachedEnd =
        metrics.maxScrollExtent <= 0 || metrics.extentAfter <= 24;
    if (reachedEnd) {
      setState(() => _hasReadContract = true);
    }
  }

  Future<void> _sign(String contractText, String contractHash) async {
    setState(() {
      _submitting = true;
      _error = null;
    });

    AppHaptics.heavy();

    try {
      final repo = ref.read(pactsRepositoryProvider);
      final res = await repo.signContract(
        pactId: widget.pactId,
        consentTextHash: contractHash,
        userAgent: kIsWeb ? 'web' : defaultTargetPlatform.name,
      );

      // Invalidar caches para que la lista y detalle reflejen el cambio
      ref.invalidate(myPactsProvider);
      ref.invalidate(pactDetailProvider(widget.pactId));

      AppHaptics.success();

      if (!mounted) return;
      setState(() {
        _submitting = false;
        _result = res;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(pactDetailProvider(widget.pactId));

    if (_result != null) {
      return _SignSuccess(result: _result!);
    }

    return Scaffold(
      backgroundColor: context.colors.scaffold,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.psGradientDeep),
        ),
        title: Text('Firmar contrato',
            style: AppTypography.h3.copyWith(color: AppColors.white)),
      ),
      body: detailAsync.when(
        loading: () => const DetailSkeleton(),
        error: (e, _) => ErrorStateView(
          title: 'No se pudo cargar el contrato',
          message: e.toString(),
          onRetry: () => ref.invalidate(pactDetailProvider(widget.pactId)),
          scrollable: false,
        ),
        data: (detail) {
          final builder = ContractPdfBuilder(detail: detail);
          // Hash del texto consolidado (mismo que firma sf_sign_contract)
          final hash = builder.hash();
          // Texto plano para enviar al RPC como respaldo legal
          const text = ''; // ya no se usa; el hash es suficiente
          return Column(
            children: [
              // Banner contextual
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                color: context.colors.warningBg,
                child: Row(
                  children: [
                    const Icon(Icons.gavel,
                        color: AppColors.warning, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Lee el contrato completo. Tu firma electrónica '
                        'tiene la misma validez legal que una manuscrita.',
                        style: AppTypography.bodyS
                            .copyWith(color: AppColors.warning),
                      ),
                    ),
                  ],
                ),
              ),
              // En web PdfPreview no funciona (requiere pdf.js),
              // usamos el iframe nativo del navegador como en
              // ContractPdfPreviewPage.
              Expanded(
                child: kIsWeb
                    ? _WebSigningPdfView(builder: builder)
                    : NotificationListener<ScrollMetricsNotification>(
                        onNotification: (n) {
                          _checkScrollMetrics(n.metrics);
                          return false;
                        },
                        child: NotificationListener<ScrollNotification>(
                          onNotification: (n) {
                            _checkScrollMetrics(n.metrics);
                            return false;
                          },
                          child: PdfPreview(
                        build: (format) async {
                          try {
                            return await builder
                                .buildBytes()
                                .timeout(const Duration(seconds: 15));
                          } catch (e) {
                            final errorDoc = pw.Document();
                            errorDoc.addPage(pw.Page(
                              build: (_) => pw.Center(
                                child: pw.Text(
                                  'Error al generar el contrato.\n'
                                  'Intenta recargar la página.\n\n'
                                  '$e',
                                ),
                              ),
                            ));
                            return errorDoc.save();
                          }
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
                        ),
                            previewPageMargin:
                                const EdgeInsets.all(AppSpacing.sm),
                            loadingWidget: const Center(
                                child: CircularProgressIndicator()),
                          ),
                        ),
                      ),
              ),

              // Footer fijo: checkbox + firmar
              Container(
                decoration: BoxDecoration(
                  color: context.colors.card,
                  border: Border(
                    top: BorderSide(color: context.colors.border, width: 1),
                  ),
                ),
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!_hasReadContract)
                        Padding(
                          padding:
                              const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: Row(
                            children: [
                              Icon(
                                  kIsWeb
                                      ? Icons.timer_outlined
                                      : Icons.swipe_down_alt_outlined,
                                  color: context.colors.brandAccent,
                                  size: 16),
                              const SizedBox(width: AppSpacing.xs),
                              Expanded(
                                child: Text(
                                  kIsWeb
                                      ? 'Tómate unos segundos para revisar el contrato'
                                      : 'Desplázate hasta el final del contrato para poder aceptarlo',
                                  style: AppTypography.bodyS.copyWith(
                                      color: context.colors.brandAccent,
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                        ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: _accepted,
                        onChanged: !_hasReadContract || _submitting
                            ? null
                            : (v) =>
                                setState(() => _accepted = v ?? false),
                        title: Text(
                          'He leído, entendido y acepto el contrato. '
                          'Firmo electrónicamente con plena conciencia.',
                          style: AppTypography.bodyS,
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(_error!,
                            style: AppTypography.bodyS
                                .copyWith(color: AppColors.error)),
                      ],
                      const SizedBox(height: AppSpacing.sm),
                      ElevatedButton.icon(
                        icon: _submitting
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.white,
                                ),
                              )
                            : const Icon(Icons.draw),
                        onPressed: !_accepted || _submitting
                            ? null
                            : () => _sign(text, hash),
                        label: Text(
                            _submitting ? 'Firmando…' : 'Firmar contrato'),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Hash del contrato: ${hash.substring(0, 16)}…',
                        style: AppTypography.caption.copyWith(
                          color: context.colors.textHint,
                          letterSpacing: 0,
                          fontFamily: 'monospace',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SignSuccess extends StatelessWidget {
  const _SignSuccess({required this.result});

  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context) {
    final allSigned = result['all_signed'] == true;
    final signatureId = result['signature_id'] as String? ?? '';

    return Scaffold(
      backgroundColor: context.colors.card,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Center(
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: context.colors.successBg,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.verified,
                      color: AppColors.success, size: 56),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Firma registrada',
                  textAlign: TextAlign.center, style: AppTypography.h1.copyWith(color: context.colors.textPrimary)),
              const SizedBox(height: AppSpacing.sm),
              Text(
                allSigned
                    ? 'Todas las partes han firmado el contrato. El pacto pasa a estado “Firmado” y queda listo para el depósito en custodia.'
                    : 'Tu firma quedó registrada. Esperaremos a que las demás partes firmen para activar el pacto.',
                textAlign: TextAlign.center,
                style: AppTypography.body
                    .copyWith(color: context.colors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: context.colors.scaffold,
                  borderRadius: AppRadius.smAll,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Identificador de firma',
                        style: AppTypography.caption
                            .copyWith(color: context.colors.textTertiary)),
                    const SizedBox(height: 2),
                    SelectableText(
                      signatureId,
                      style: AppTypography.mono
                          .copyWith(fontSize: 11, color: context.colors.textPrimary),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () => context.pop(),
                child: const Text('Volver al pacto'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Visor de PDF para Flutter Web dentro de la pantalla de firma.
///
/// Genera los bytes del PDF asincrónicamente y los muestra en un iframe
/// nativo del navegador (Chrome PDF Viewer), evitando el bug de
/// PdfPreview en Flutter Web.
class _WebSigningPdfView extends StatefulWidget {
  const _WebSigningPdfView({required this.builder});

  final ContractPdfBuilder builder;

  @override
  State<_WebSigningPdfView> createState() => _WebSigningPdfViewState();
}

class _WebSigningPdfViewState extends State<_WebSigningPdfView> {
  Uint8List? _bytes;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _generatePdf();
  }

  Future<void> _generatePdf() async {
    try {
      final bytes = await widget.builder
          .buildBytes()
          .timeout(const Duration(seconds: 15));
      if (mounted) setState(() => _bytes = bytes);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 48),
            const SizedBox(height: AppSpacing.md),
            Text('No se pudo generar el PDF',
                style: AppTypography.body.copyWith(color: context.colors.textPrimary)),
            const SizedBox(height: AppSpacing.sm),
            Text(_error.toString(),
                style: AppTypography.bodyS.copyWith(color: context.colors.textTertiary),
                textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            TextButton.icon(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                setState(() {
                  _error = null;
                  _bytes = null;
                });
                _generatePdf();
              },
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }
    if (_bytes == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return buildPdfIframe(_bytes!);
  }
}
