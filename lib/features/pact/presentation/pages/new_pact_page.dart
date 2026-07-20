import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_haptics.dart';
import '../../../../core/utils/error_humanizer.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../data/datasources/supabase/supabase_client.dart';
import '../../data/pact_creation_data.dart';
import '../../data/pact_providers.dart';
import '../widgets/new_pact_step_basics.dart';
import '../widgets/new_pact_step_team.dart';
import '../widgets/new_pact_step_budget.dart';
import '../widgets/new_pact_step_confirm.dart';

/// Wizard de creación de pacto (modelo v2.0) en 4 pasos:
///   1. Información de la obra (tipo, título, dirección, fechas)
///   2. Presupuesto y depósito (importe, IVA, % depósito 15-40, frecuencia)
///   3. Equipo (invitar a las partes que faltan)
///   4. Resumen y crear
///
/// Persistencia atómica al final con 3 RPCs encadenadas:
///   sf_create_pact_v2 → sf_invite_party (xN) → sf_finalize_pact_v2
///
/// A diferencia del wizard v1, NO se crean hitos al inicio — los irá creando
/// el constructor durante la ejecución, por demanda.
class NewPactPage extends ConsumerStatefulWidget {
  const NewPactPage({super.key});

  @override
  ConsumerState<NewPactPage> createState() => _NewPactPageState();
}

class _NewPactPageState extends ConsumerState<NewPactPage> {
  final PageController _pageController = PageController();
  final PactCreationData _data = PactCreationData();
  int _currentStep = 0;
  bool _submitting = false;
  bool _showErrors = false;
  String? _errorMessage;
  String? _createdPactId;
  String? _createdPactDisplayId;
  bool _createdAsDraft = false;

  // ── Estado de reanudación (P1-3) ─────────────────────────────────
  // Si la creación falla a mitad (invitaciones o finalize), guardamos lo
  // ya conseguido para que el reintento NO cree un pacto duplicado ni
  // repita invitaciones ya enviadas.
  String? _pendingPactId;
  String? _pendingDisplayId;
  final Set<String> _invitedEmails = <String>{};

  static const int _totalSteps = 4;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool get _canAdvance {
    switch (_currentStep) {
      case 0:
        return _data.step1Valid;
      case 1:
        return _data.step2Valid;
      case 2:
        return _data.step3Valid;
      case 3:
        return false; // último paso ya tiene su CTA propio
    }
    return false;
  }

  void _next() {
    if (_currentStep >= _totalSteps - 1) return;

    if (!_canAdvance) {
      // Show validation errors
      AppHaptics.warning();
      setState(() => _showErrors = true);
      return;
    }

    AppHaptics.selection();

    setState(() {
      _currentStep++;
      _showErrors = false;
      _errorMessage = null;
    });
    _pageController.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
    );
  }

  void _previous() {
    if (_currentStep == 0) {
      _confirmExit();
      return;
    }
    setState(() {
      _currentStep--;
      _errorMessage = null;
    });
    _pageController.previousPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _confirmExit() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Salir del wizard?'),
        content: const Text(
          'Si sales ahora perderás los datos del nuevo pacto. ¿Continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Seguir editando'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    if (shouldExit == true && mounted) {
      context.go(AppRoutes.home);
    }
  }

  /// Crea el pacto v2 en BD ejecutando 3 RPCs en cascada.
  ///
  /// Reanudable (P1-3): si un intento anterior dejó el pacto creado pero
  /// falló en las invitaciones o en el finalize, el reintento salta la
  /// creación, solo invita a los emails que faltan y finaliza. Así el
  /// botón "Crear" nunca duplica pactos ni invitaciones.
  Future<void> _createPact() async {
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    AppHaptics.heavy();

    try {
      final client = SupabaseConfig.client;

      // 1. Crear pact v2.1 (Adelanto con doble garantía) — SOLO si un
      // intento anterior no lo dejó ya creado.
      if (_pendingPactId == null) {
        // RPC devuelve TABLE(out_pact_id, out_display_id) → List<Map>.
        final pactRows = await client.rpc(
          'sf_create_pact_v21',
          params: {
            'p_title': _data.title.trim(),
            'p_obra_address_line': _data.addressLine.trim(),
            'p_total_amount_cents': _data.totalAmountCents,
            'p_description': _data.description.trim().isEmpty
                ? null
                : _data.description.trim(),
            'p_pact_type': _data.pactType,
            'p_obra_postal_code': _data.postalCode.trim(),
            'p_obra_province': _data.province.trim(),
            'p_obra_type': _data.pactType == 'obra_menor'
                ? 'obra_menor_${_data.minorWorkCategory ?? 'otra'}'
                : 'reforma_integral',
            'p_iva_rate_pct': _data.ivaRatePct,
            'p_iva_included': _data.ivaIncluded,
            'p_estimated_start_date':
                _data.estimatedStartDate?.toIso8601String().substring(0, 10),
            'p_estimated_end_date':
                _data.estimatedEndDate?.toIso8601String().substring(0, 10),
            'p_advance_pct': _data.advancePct,
            'p_advance_reserve_pct': PactCreationData.advanceReservePct,
            'p_certification_frequency':
                _data.certificationFrequency.trim().isEmpty
                    ? null
                    : _data.certificationFrequency.trim(),
            'p_obra_menor_declaration_accepted': _data.minorWorkDeclaration,
          },
        );

        final firstRow = (pactRows is List && pactRows.isNotEmpty)
            ? pactRows.first as Map<String, dynamic>
            : (pactRows as Map<String, dynamic>?);

        if (firstRow == null) {
          throw Exception(
            'sf_create_pact_v2 no devolvió ninguna fila. '
            'Respuesta cruda: $pactRows',
          );
        }

        final newPactId =
            (firstRow['out_pact_id'] ?? firstRow['id']) as String?;
        final newDisplayId =
            (firstRow['out_display_id'] ?? firstRow['display_id']) as String?;

        if (newPactId == null || newDisplayId == null) {
          throw Exception(
            'Respuesta inválida de sf_create_pact_v21. Recibido: $firstRow. '
            'Asegúrate de aplicar las migraciones del Sprint 5 y '
            'ejecutar NOTIFY pgrst, \'reload schema\'.',
          );
        }

        // Guardar ANTES de las invitaciones: si algo falla a partir de
        // aquí, el reintento reutiliza este pacto.
        _pendingPactId = newPactId;
        _pendingDisplayId = newDisplayId;
      }

      final pactId = _pendingPactId!;
      final displayId = _pendingDisplayId!;

      // 2. Invitar partes — solo si no es borrador, y solo los emails que
      // aún no fueron invitados con éxito en intentos anteriores.
      if (!_data.isDraft) {
        final pendingInvites = _data.invites.where(
          (i) => i.email.isNotEmpty && !_invitedEmails.contains(i.email),
        );
        for (final invite in pendingInvites) {
          await client.rpc(
            'sf_invite_party',
            params: invite.toRpcArgs(pactId),
          );
          _invitedEmails.add(invite.email);
        }

        // 3. Finalizar borrador v2.1 → estado 'inviting' (envía emails).
        await client.rpc(
          'sf_finalize_pact_v21',
          params: {'p_pact_id': pactId},
        );

        // Drenar la cola de emails (notificaciones de invitación a las partes)
        ref.read(pactsRepositoryProvider).kickEmailSender();
      }
      // En modo borrador: el pacto queda en estado 'draft', sin emails enviados.
      // El usuario puede invitar a las partes más tarde desde el detalle de obra.

      // Invalidar la lista para que el usuario vea el nuevo pacto al volver.
      ref.invalidate(myPactsProvider);

      AppHaptics.success();

      if (!mounted) return;
      setState(() {
        _submitting = false;
        _createdPactId = pactId;
        _createdPactDisplayId = displayId;
        _createdAsDraft = _data.isDraft;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorMessage = _resumeAwareError(e);
      });
    }
  }

  /// Mensaje de error que además informa del progreso ya conseguido para
  /// que el usuario entienda que reintentar es seguro (no duplica nada).
  String _resumeAwareError(Object e) {
    final base = humanizeError(e);
    if (_pendingPactId == null) return base;

    final totalInvites =
        _data.invites.where((i) => i.email.isNotEmpty).length;
    final buffer = StringBuffer(
      'La obra ${_pendingDisplayId ?? ''} ya quedó creada',
    );
    if (!_data.isDraft && totalInvites > 0) {
      buffer.write(
        ' y se enviaron ${_invitedEmails.length} de $totalInvites invitaciones',
      );
    }
    buffer
      ..write('. ')
      ..write(base)
      ..write(' Pulsa "Crear" de nuevo para continuar donde se quedó — '
          'no se duplicará nada.');
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    if (_createdPactDisplayId != null) {
      return _SuccessScreen(
        pactId: _createdPactId,
        displayId: _createdPactDisplayId!,
        isDraft: _createdAsDraft,
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_currentStep == 0) {
          await _confirmExit();
        } else {
          _previous();
        }
      },
      child: Scaffold(
        backgroundColor: context.colors.card,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: AppColors.white,
          elevation: 0,
          flexibleSpace: Container(
            decoration: const BoxDecoration(gradient: AppColors.psGradientDeep),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Volver',
            onPressed: _previous,
          ),
          title: Text(_titleForStep(_currentStep),
              style: AppTypography.h3.copyWith(color: AppColors.white)),
        ),
        body: SafeArea(
          child: Column(
            children: [
              _StepProgressBar(current: _currentStep, total: _totalSteps),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    NewPactStepBasics(
                      data: _data,
                      showErrors: _showErrors && _currentStep == 0,
                      onChange: () => setState(() {}),
                    ),
                    NewPactStepBudget(
                      data: _data,
                      showErrors: _showErrors && _currentStep == 1,
                      onChange: () => setState(() {}),
                    ),
                    NewPactStepTeam(
                      data: _data,
                      onChange: () => setState(() {}),
                    ),
                    NewPactStepConfirm(
                      data: _data,
                      submitting: _submitting,
                      errorMessage: _errorMessage,
                      onSubmit: _createPact,
                    ),
                  ],
                ),
              ),
              if (_currentStep < _totalSteps - 1) _buildBottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    // En el paso de equipo (paso 2), mostrar también "Guardar borrador"
    final isTeamStep = _currentStep == 2;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: context.colors.card,
          border: Border(top: BorderSide(color: context.colors.border, width: 1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isTeamStep) ...[
              OutlinedButton.icon(
                icon: const Icon(Icons.save_outlined, size: 18),
                label: const Text('Guardar borrador'),
                onPressed: () {
                  _data.isDraft = true;
                  _next();
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44),
                  foregroundColor: context.colors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            ElevatedButton(
              onPressed: () {
                _data.isDraft = false;
                _next();
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
              ),
              child: Text(_currentStep == _totalSteps - 2
                  ? 'Revisar y crear'
                  : 'Continuar'),
            ),
          ],
        ),
      ),
    );
  }

  String _titleForStep(int step) {
    switch (step) {
      case 0:
        return 'Información de la obra';
      case 1:
        return 'Presupuesto y depósito';
      case 2:
        return 'Quién participa';
      case 3:
        return 'Confirmar y crear';
    }
    return 'Nueva obra';
  }
}

class _StepProgressBar extends StatelessWidget {
  const _StepProgressBar({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: List.generate(total, (i) {
              final filled = i <= current;
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(
                      right: i == total - 1 ? 0 : AppSpacing.xs),
                  height: 4,
                  decoration: BoxDecoration(
                    color: filled ? AppColors.psBlue : context.colors.border,
                    borderRadius: AppRadius.xxsAll,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Paso ${current + 1} de $total',
            style: AppTypography.caption.copyWith(color: context.colors.textTertiary),
          ),
        ],
      ),
    );
  }
}

class _SuccessScreen extends StatelessWidget {
  const _SuccessScreen({
    required this.pactId,
    required this.displayId,
    required this.isDraft,
  });

  final String? pactId;
  final String displayId;
  final bool isDraft;

  void _goToDetail(BuildContext context) {
    // Vamos primero a Home para que el detalle quede apilado encima y
    // el botón "atrás" devuelva al usuario a sus obras.
    context.go(AppRoutes.home);
    if (pactId != null) {
      context.push('/pacts/$pactId');
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  child: const Icon(Icons.check_circle,
                      color: AppColors.success, size: 56),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Obra creada con éxito',
                  textAlign: TextAlign.center, style: AppTypography.h1.copyWith(color: context.colors.textPrimary)),
              const SizedBox(height: AppSpacing.sm),
              Text(
                isDraft
                    ? 'Tu pacto $displayId se ha guardado como borrador. '
                        'Podrás invitar a las partes cuando quieras desde el '
                        'detalle de la obra.'
                    : 'Tu pacto $displayId se ha creado y las partes '
                        'invitadas recibirán un email para unirse y firmar.',
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(color: context.colors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xl),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: context.colors.infoBg,
                  borderRadius: AppRadius.lgAll,
                  boxShadow: AppShadows.soft,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline,
                        color: context.colors.brandAccent, size: 18),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Próximos pasos: las partes firman el contrato y el promotor deposita el % acordado en custodia. Después, el constructor podrá emitir certificaciones.',
                        style: AppTypography.bodyS
                            .copyWith(color: context.colors.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: pactId != null
                    ? () => _goToDetail(context)
                    : () => context.go(AppRoutes.home),
                child: Text(
                  pactId != null
                      ? 'Ver detalle de la obra'
                      : 'Volver a mis obras',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: () => context.go(AppRoutes.home),
                child: const Text('Volver a mis obras'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
