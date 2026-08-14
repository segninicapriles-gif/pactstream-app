import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/i18n/l10n_extension.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../data/datasources/supabase/supabase_client.dart';
import '../../../../l10n/gen/app_localizations.dart';

/// Captura KYC vía Veriff (sandbox).
///
/// Flujo:
///   1. Usuario pulsa "Iniciar verificación"
///   2. Llamamos a Edge Function `veriff-create-session` que crea
///      una sesión de Veriff y devuelve la URL.
///   3. Abrimos la URL (web: nueva pestaña; mobile: webview).
///   4. El usuario completa DNI + selfie + liveness en Veriff.
///   5. Veriff llama al webhook `veriff-webhook` que actualiza kyc_status.
///   6. Usuario vuelve a la app, polling detecta el cambio y redirige
///      a la pantalla de resultado.
///
/// Modo dev fallback: si las Edge Functions no están desplegadas o
/// VERIFF_API_KEY no está configurada, mantenemos los 3 botones mock
/// para no bloquear el desarrollo.
class KycCapturePage extends ConsumerStatefulWidget {
  const KycCapturePage({super.key});

  @override
  ConsumerState<KycCapturePage> createState() => _KycCapturePageState();
}

class _KycCapturePageState extends ConsumerState<KycCapturePage> {
  bool _processing = false;
  bool _waitingForCallback = false;
  /// P2-3 · El polling agotó los 5 minutos sin resultado de Veriff.
  bool _pollTimedOut = false;
  String? _errorMessage;
  String? _sessionUrl;

  /// P2-3 · Límite total del polling.
  static const Duration _pollTimeout = Duration(minutes: 5);

  /// Cadenas localizadas cacheadas como CAMPO, no leídas de `context` al vuelo.
  ///
  /// Este flujo es todo asíncrono (crear sesión, abrir navegador, polling de
  /// 5 minutos) y varios mensajes se construyen DESPUÉS de un `await`. Leer
  /// `context.l10n` ahí es exactamente lo que prohíbe
  /// `use_build_context_synchronously`, y con razón: el widget puede haberse
  /// desmontado. Cachearlo en `didChangeDependencies` lo hace seguro y además
  /// sigue reaccionando a un cambio de idioma, porque Flutter vuelve a llamar
  /// a ese método cuando cambia el `Localizations` de arriba.
  late AppLocalizations _l10n;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _l10n = context.l10n;
  }

  Future<void> _startVeriffSession() async {
    setState(() {
      _processing = true;
      _errorMessage = null;
    });

    try {
      // Llamar a Edge Function veriff-create-session
      final response =
          await SupabaseConfig.client.functions.invoke('veriff-create-session');

      if (response.status >= 400) {
        throw Exception(
          'Error ${response.status}: ${response.data?.toString() ?? 'desconocido'}',
        );
      }

      final data = response.data as Map<String, dynamic>;
      final url = data['url'] as String?;

      if (url == null || url.isEmpty) {
        throw Exception(_l10n.kycErrorNoSessionUrl);
      }

      _sessionUrl = url;

      // Abrir la URL de Veriff en el navegador
      final launched = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );

      if (!launched) {
        throw Exception(_l10n.kycErrorCannotOpenUrl);
      }

      if (!mounted) return;
      setState(() {
        _processing = false;
        _waitingForCallback = true;
        _pollTimedOut = false;
      });

      // Iniciar polling para detectar cuando se complete
      _pollKycStatus();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _pollKycStatus() async {
    // P2-3 · Polling con timeout (5 min) y backoff: cada 4s durante el
    // primer minuto, cada 8s después. Al agotarse mostramos un estado
    // "está tardando" con CTAs en vez de esperar para siempre.
    final startedAt = DateTime.now();

    while (mounted && _waitingForCallback) {
      final elapsed = DateTime.now().difference(startedAt);

      if (elapsed >= _pollTimeout) {
        if (!mounted) return;
        setState(() => _pollTimedOut = true);
        return;
      }

      final interval = elapsed > const Duration(minutes: 1)
          ? const Duration(seconds: 8)
          : const Duration(seconds: 4);
      await Future<void>.delayed(interval);
      if (!mounted) break;

      try {
        final rows = await SupabaseConfig.client.rpc('sf_get_my_profile');
        if (rows is List && rows.isNotEmpty) {
          final profile = rows.first as Map<String, dynamic>;
          final kyc = profile['kyc_status'] as String? ?? 'in_progress';

          if (kyc != 'in_progress' && kyc != 'not_started') {
            // Veriff resolvió → redirigir al resultado
            if (!mounted) return;
            context.go('${AppRoutes.kycResult}?status=$kyc');
            return;
          }
        }
      } catch (_) {
        // Errores de red transitorios — seguir polling
      }
    }
  }

  Future<void> _checkStatusManually() async {
    setState(() => _processing = true);
    try {
      final rows = await SupabaseConfig.client.rpc('sf_get_my_profile');
      if (rows is List && rows.isNotEmpty) {
        final profile = rows.first as Map<String, dynamic>;
        final kyc = profile['kyc_status'] as String? ?? 'in_progress';

        if (!mounted) return;

        if (kyc == 'in_progress' || kyc == 'not_started') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_l10n.kycStillProcessing),
            ),
          );
        } else {
          context.go('${AppRoutes.kycResult}?status=$kyc');
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  // MOCK fallback (si Edge Functions no están desplegadas todavía)
  Future<void> _simulateMock(String decision, {String? reason}) async {
    setState(() {
      _processing = true;
      _errorMessage = null;
    });
    try {
      await Future<void>.delayed(const Duration(seconds: 1));
      await SupabaseConfig.client.rpc(
        'sf_simulate_kyc_verification',
        params: {'p_decision': decision, 'p_reason': reason},
      );
      if (!mounted) return;
      context.go('${AppRoutes.kycResult}?status=$decision');
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.psGradientDeep),
        ),
        title: Text(_l10n.kycCaptureAppBarTitle,
            style: AppTypography.h3.copyWith(color: AppColors.white)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: _waitingForCallback ? _buildWaiting() : _buildMain(),
        ),
      ),
    );
  }

  Widget _buildWaiting() {
    // P2-3 · Estado de timeout: el webhook de Veriff no llegó en 5 min.
    if (_pollTimedOut) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.xxxl),
          Center(
            child: Icon(Icons.hourglass_bottom,
                size: 48, color: context.colors.warningText),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            _l10n.kycTimeoutTitle,
            textAlign: TextAlign.center,
            style: AppTypography.h3,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _l10n.kycTimeoutBody,
            textAlign: TextAlign.center,
            style: AppTypography.bodyS
                .copyWith(color: context.colors.textTertiary),
          ),
          const SizedBox(height: AppSpacing.xxl),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _pollTimedOut = false);
              _pollKycStatus();
            },
            label: Text(_l10n.commonRetry),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            icon: const Icon(Icons.home_outlined),
            onPressed: () => context.go(AppRoutes.home),
            label: Text(_l10n.kycContinueLater),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.xxxl),
        const Center(child: CircularProgressIndicator()),
        const SizedBox(height: AppSpacing.lg),
        Text(
          _l10n.kycWaitingTitle,
          textAlign: TextAlign.center,
          style: AppTypography.h3,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          _l10n.kycWaitingBody,
          textAlign: TextAlign.center,
          style: AppTypography.bodyS.copyWith(color: context.colors.textTertiary),
        ),
        const SizedBox(height: AppSpacing.xxl),
        if (_sessionUrl != null) ...[
          OutlinedButton.icon(
            icon: const Icon(Icons.open_in_new),
            onPressed: () => launchUrl(
              Uri.parse(_sessionUrl!),
              mode: LaunchMode.externalApplication,
            ),
            label: Text(_l10n.kycReopenVeriff),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        OutlinedButton.icon(
          icon: const Icon(Icons.refresh),
          onPressed: _processing ? null : _checkStatusManually,
          label: Text(_l10n.kycCheckStatusNow),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          onPressed: () {
            setState(() {
              _waitingForCallback = false;
              _pollTimedOut = false;
            });
          },
          child: Text(_l10n.kycCancelAndBack),
        ),
      ],
    );
  }

  Widget _buildMain() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Hero
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.colors.infoBg,
            ),
            child: Icon(
              Icons.shield_outlined,
              size: 44,
              color: context.colors.brandAccent,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(_l10n.kycCaptureTitle,
            textAlign: TextAlign.center, style: AppTypography.h1),
        const SizedBox(height: AppSpacing.sm),
        Text(
          // Antes: "tu DNI o pasaporte". El DNI es español y esta pantalla la
          // ven usuarios de EE. UU., Venezuela y El Salvador. Veriff acepta
          // documentos de decenas de países y decide él la validez.
          _l10n.kycCaptureBody,
          textAlign: TextAlign.center,
          style: AppTypography.body.copyWith(color: context.colors.textSecondary),
        ),

        const SizedBox(height: AppSpacing.xl),

        // Lo que va a pasar
        _Step(
          number: '1',
          title: _l10n.kycStep1Title,
          subtitle: _l10n.kycStep1Body,
        ),
        _Step(
          number: '2',
          title: _l10n.kycStep2Title,
          subtitle: _l10n.kycStep2Body,
        ),
        _Step(
          number: '3',
          title: _l10n.kycStep3Title,
          subtitle: _l10n.kycStep3Body,
        ),

        const SizedBox(height: AppSpacing.xl),

        if (_errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: context.colors.errorBg,
              borderRadius: AppRadius.smAll,
            ),
            child: Text(_errorMessage!,
                style: AppTypography.bodyS.copyWith(color: context.colors.errorText)),
          ),
          const SizedBox(height: AppSpacing.md),
        ],

        ElevatedButton.icon(
          icon: _processing
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.white,
                  ),
                )
              : const Icon(Icons.shield),
          onPressed: _processing ? null : _startVeriffSession,
          label: Text(_processing
              ? _l10n.kycCreatingSession
              : _l10n.kycStartSessionCta),
        ),

        const SizedBox(height: AppSpacing.md),

        // SECURITY: Mock KYC controls are hidden in release builds to
        // prevent users from bypassing identity verification.
        //
        // i18n: este bloque se queda SIN traducir a propósito. `kDebugMode` lo
        // recorta del build de release, así que ningún usuario lo ve nunca —
        // su único público somos nosotros. Meterlo en los ARB añadiría 6
        // claves a los tres idiomas para texto que no llega a producción.
        if (kDebugMode)
          ExpansionTile(
            title: Text('Modo desarrollo · Simular resultado',
                style: AppTypography.bodyS.copyWith(color: context.colors.textTertiary)),
            tilePadding: EdgeInsets.zero,
            children: [
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  OutlinedButton(
                    onPressed:
                        _processing ? null : () => _simulateMock('verified'),
                    child: const Text('✓ Simular Aprobado'),
                  ),
                  OutlinedButton(
                    onPressed: _processing
                        ? null
                        : () => _simulateMock('pending_review'),
                    child: const Text('⏳ Simular En revisión'),
                  ),
                  OutlinedButton(
                    onPressed:
                        _processing ? null : () => _simulateMock('rejected'),
                    child: const Text('✗ Simular Rechazado'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Solo visible mientras configuras Veriff. Eliminar este bloque antes de producción.',
                style: AppTypography.caption.copyWith(color: context.colors.textTertiary),
              ),
            ],
          ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.title,
    required this.subtitle,
  });

  final String number;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.psBlue,
            ),
            child: Center(
              child: Text(number,
                  style: AppTypography.body.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w700,
                  )),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTypography.body
                        .copyWith(fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
                Text(subtitle,
                    style: AppTypography.bodyS
                        .copyWith(color: context.colors.textTertiary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
