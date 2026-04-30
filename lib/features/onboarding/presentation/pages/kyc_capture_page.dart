import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../data/datasources/supabase/supabase_client.dart';

/// Captura KYC. En desarrollo es un MOCK que simula el SDK de Onfido.
///
/// TODO(v2): reemplazar por integración real con Onfido SDK.
///   - iOS/Android: usar package onfido_sdk con Workflow ID configurado
///     en el dashboard de Onfido (https://dashboard.onfido.com).
///   - Web: redirect a Onfido Studio Web Workflow + callback URL.
///   - Backend: webhook handler en Edge Function que escucha
///     `check.completed` y actualiza kyc_status vía RPC equivalente.
///
/// El mock permite testear los 3 estados de salida (verified, pending,
/// rejected) que tendrá Onfido en producción.
class KycCapturePage extends ConsumerStatefulWidget {
  const KycCapturePage({super.key});

  @override
  ConsumerState<KycCapturePage> createState() => _KycCapturePageState();
}

class _KycCapturePageState extends ConsumerState<KycCapturePage> {
  bool _processing = false;
  String? _errorMessage;

  Future<void> _simulate(String decision, {String? reason}) async {
    setState(() {
      _processing = true;
      _errorMessage = null;
    });
    try {
      // Simulación de tiempo de captura/procesamiento (Onfido tarda 5-30s real)
      await Future<void>.delayed(const Duration(seconds: 2));

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
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.ink900,
        elevation: 0,
        title: Text('Captura · MOCK', style: AppTypography.h3),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.warningBg,
                  borderRadius: BorderRadius.circular(AppSpacing.md),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.science_outlined,
                        color: AppColors.warning),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Modo desarrollo. En producción aquí se ejecutaría el SDK de Onfido (DNI + selfie + liveness).',
                        style: AppTypography.bodyS
                            .copyWith(color: AppColors.warning),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Text('Simular resultado de KYC',
                  style: AppTypography.h2, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Selecciona qué respuesta quieres simular. En la app real, Onfido devuelve uno de estos 3 estados.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyS.copyWith(color: AppColors.ink500),
              ),
              const SizedBox(height: AppSpacing.xl),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.errorBg,
                    borderRadius: BorderRadius.circular(AppSpacing.sm),
                  ),
                  child: Text(_errorMessage!,
                      style: AppTypography.bodyS
                          .copyWith(color: AppColors.error)),
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              if (_processing) ...[
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Procesando verificación...',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyS.copyWith(color: AppColors.ink500),
                ),
              ] else ...[
                _SimulateButton(
                  icon: Icons.check_circle_outline,
                  label: 'Aprobado',
                  subtitle: 'Verificación exitosa. Acceso completo a la app.',
                  color: AppColors.success,
                  onTap: () => _simulate('verified'),
                ),
                const SizedBox(height: AppSpacing.md),
                _SimulateButton(
                  icon: Icons.access_time,
                  label: 'En revisión manual',
                  subtitle: 'Documento ambiguo. 24h de revisión por agente.',
                  color: AppColors.warning,
                  onTap: () => _simulate('pending_review'),
                ),
                const SizedBox(height: AppSpacing.md),
                _SimulateButton(
                  icon: Icons.block,
                  label: 'Rechazado',
                  subtitle: 'Documento ilegible o caducado. Volver a intentar.',
                  color: AppColors.error,
                  onTap: () => _simulate('rejected',
                      reason: 'Documento ilegible (simulado)'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SimulateButton extends StatelessWidget {
  const _SimulateButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppSpacing.lg),
          border: Border.all(color: AppColors.ink200, width: 1.5),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: AppTypography.body
                          .copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: AppTypography.bodyS
                          .copyWith(color: AppColors.ink500)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.ink400),
          ],
        ),
      ),
    );
  }
}
