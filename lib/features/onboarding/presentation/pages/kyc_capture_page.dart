import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../data/datasources/supabase/supabase_client.dart';

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
  String? _errorMessage;
  String? _sessionUrl;

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
        throw Exception('Veriff no devolvió URL de sesión');
      }

      _sessionUrl = url;

      // Abrir la URL de Veriff en el navegador
      final launched = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );

      if (!launched) {
        throw Exception('No se pudo abrir la URL de Veriff');
      }

      if (!mounted) return;
      setState(() {
        _processing = false;
        _waitingForCallback = true;
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
    while (mounted && _waitingForCallback) {
      await Future<void>.delayed(const Duration(seconds: 4));
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
            const SnackBar(
              content: Text('Verificación aún en proceso. Espera unos segundos.'),
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
        title: Text('Verificación de identidad',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.xxxl),
        const Center(child: CircularProgressIndicator()),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Esperando confirmación de Veriff...',
          textAlign: TextAlign.center,
          style: AppTypography.h3,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Completa la verificación en la pestaña que se abrió. Cuando termines, vuelve aquí — detectaremos el resultado automáticamente.',
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
            label: const Text('Reabrir verificación de Veriff'),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        OutlinedButton.icon(
          icon: const Icon(Icons.refresh),
          onPressed: _processing ? null : _checkStatusManually,
          label: const Text('Comprobar estado ahora'),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          onPressed: () {
            setState(() => _waitingForCallback = false);
          },
          child: const Text('Cancelar y volver'),
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
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.infoBg,
            ),
            child: const Icon(
              Icons.shield_outlined,
              size: 44,
              color: AppColors.psBlue,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Verifica tu identidad con Veriff',
            textAlign: TextAlign.center, style: AppTypography.h1),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Necesitas tu DNI o pasaporte y la cámara del dispositivo. Tarda 2-3 minutos.',
          textAlign: TextAlign.center,
          style: AppTypography.body.copyWith(color: context.colors.textSecondary),
        ),

        const SizedBox(height: AppSpacing.xl),

        // Lo que va a pasar
        const _Step(
          number: '1',
          title: 'Foto del documento',
          subtitle: 'DNI, NIE o pasaporte. Veriff valida la autenticidad.',
        ),
        const _Step(
          number: '2',
          title: 'Selfie con prueba de vida',
          subtitle: 'Mira a la cámara y sigue las instrucciones.',
        ),
        const _Step(
          number: '3',
          title: 'Resultado en 30-60 segundos',
          subtitle: 'Si todo bien, accedes a la app inmediatamente.',
        ),

        const SizedBox(height: AppSpacing.xl),

        if (_errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.errorBg,
              borderRadius: AppRadius.smAll,
            ),
            child: Text(_errorMessage!,
                style: AppTypography.bodyS.copyWith(color: AppColors.error)),
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
          label: Text(_processing ? 'Creando sesión...' : 'Iniciar verificación'),
        ),

        const SizedBox(height: AppSpacing.md),

        // Modo dev fallback
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
