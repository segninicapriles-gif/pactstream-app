import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/app_haptics.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/success_overlay.dart';
import '../../data/pact_actions_v2.dart';
import '../../data/pact_detail.dart';

/// Conjunto de bottom-sheets para las acciones del modelo v2.0.
///
/// Cada función devuelve `true` si la acción se ejecutó con éxito (la UI
/// llamará a `ref.invalidate` para refrescar el detalle).

// =====================================================================
// 1 · Promotor confirma el depósito inicial
// =====================================================================

Future<bool> showFundInitialDepositSheet(
  BuildContext context, {
  required PactDetail detail,
}) async {
  final required = detail.pact.depositRequiredCents;

  return await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.sheetTop,
        ),
        builder: (ctx) => _FundDepositSheet(
          requiredCents: required,
          pactId: detail.pact.id,
          depositPct: detail.pact.depositRequiredPct?.toDouble() ?? 30,
        ),
      ) ??
      false;
}

class _FundDepositSheet extends StatefulWidget {
  const _FundDepositSheet({
    required this.requiredCents,
    required this.pactId,
    required this.depositPct,
  });

  final int requiredCents;
  final String pactId;
  final double depositPct;

  @override
  State<_FundDepositSheet> createState() => _FundDepositSheetState();
}

class _FundDepositSheetState extends State<_FundDepositSheet> {
  bool _accepted = false;
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await PactActionsV2.fundInitialDeposit(widget.pactId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
      await showSuccessOverlay(context, message: 'Depósito confirmado');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetScaffold(
      title: 'Depositar en custodia',
      icon: Icons.shield_outlined,
      iconColor: AppColors.psBlue,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.infoBg,
            borderRadius: AppRadius.mdAll,
            border: Border.all(color: AppColors.psBlue, width: 1),
          ),
          child: Column(
            children: [
              Text('${widget.depositPct.toStringAsFixed(0)} % del presupuesto',
                  style: AppTypography.caption
                      .copyWith(color: context.colors.textSecondary)),
              const SizedBox(height: 4),
              Text(AppFormatters.moneyLong(widget.requiredCents),
                  style: AppTypography.h1.copyWith(color: AppColors.psNavy)),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Al confirmar, el pacto pasará a "En ejecución" y el constructor podrá empezar a emitir certificaciones. '
          'En esta versión MVP el ingreso se simula — en producción Mangopay confirmará la transferencia.',
          style: AppTypography.bodyS.copyWith(color: context.colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.md),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: _accepted,
          onChanged: _loading ? null : (v) => setState(() => _accepted = v ?? false),
          title: Text(
            'Confirmo que he transferido el importe a la cuenta de custodia.',
            style: AppTypography.bodyS.copyWith(color: context.colors.textPrimary),
          ),
        ),
        if (_error != null) _ErrorBanner(message: _error!),
        const SizedBox(height: AppSpacing.sm),
        _PrimaryButton(
          enabled: _accepted && !_loading,
          loading: _loading,
          label:
              'Confirmar depósito · ${AppFormatters.moneyShort(widget.requiredCents)}',
          onPressed: _submit,
        ),
      ],
    );
  }
}

// =====================================================================
// 2 · Promotor repone el depósito
// =====================================================================

Future<bool> showReplenishDepositSheet(
  BuildContext context, {
  required PactDetail detail,
}) async {
  // Sugerencia: la diferencia entre requerido y actual
  final suggested = (detail.pact.depositRequiredCents -
          detail.pact.depositCurrentCents)
      .clamp(0, detail.pact.totalAmountCents);

  return await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.sheetTop,
        ),
        builder: (ctx) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: _ReplenishDepositSheet(
            pactId: detail.pact.id,
            suggestedCents: suggested,
            currentCents: detail.pact.depositCurrentCents,
          ),
        ),
      ) ??
      false;
}

class _ReplenishDepositSheet extends StatefulWidget {
  const _ReplenishDepositSheet({
    required this.pactId,
    required this.suggestedCents,
    required this.currentCents,
  });

  final String pactId;
  final int suggestedCents;
  final int currentCents;

  @override
  State<_ReplenishDepositSheet> createState() => _ReplenishDepositSheetState();
}

class _ReplenishDepositSheetState extends State<_ReplenishDepositSheet> {
  late final TextEditingController _ctrl = TextEditingController(
    text: widget.suggestedCents > 0
        ? (widget.suggestedCents ~/ 100).toString()
        : '',
  );
  bool _loading = false;
  String? _error;

  int get _amountCents {
    final euros = int.tryParse(_ctrl.text) ?? 0;
    return euros * 100;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_amountCents <= 0) {
      setState(() => _error = 'El importe debe ser positivo');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await PactActionsV2.replenishDeposit(
        pactId: widget.pactId,
        amountCents: _amountCents,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      await showSuccessOverlay(context, message: 'Depósito repuesto');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final newBalance = widget.currentCents + _amountCents;

    return _SheetScaffold(
      title: 'Reponer depósito',
      icon: Icons.add_circle_outline,
      iconColor: AppColors.warning,
      children: [
        Text(
          'El depósito se utiliza para liberar dinero al constructor cuando se aprueba una certificación. '
          'Reponlo para que la obra siga avanzando sin pausas.',
          style: AppTypography.bodyS.copyWith(color: context.colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Importe a reponer',
            suffixText: '€',
          ),
          onChanged: (_) => setState(() => _error = null),
        ),
        if (widget.suggestedCents > 0) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Sugerido para volver al 100 %: ${AppFormatters.moneyShort(widget.suggestedCents)}',
            style: AppTypography.caption.copyWith(color: context.colors.textTertiary),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        if (_amountCents > 0)
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: context.colors.scaffold,
              borderRadius: AppRadius.microAll,
            ),
            child: Row(
              children: [
                Text('Nuevo balance', style: AppTypography.bodyS.copyWith(color: context.colors.textPrimary)),
                const Spacer(),
                Text(AppFormatters.moneyLong(newBalance),
                    style: AppTypography.body
                        .copyWith(fontWeight: FontWeight.w800, color: context.colors.textPrimary)),
              ],
            ),
          ),
        if (_error != null) _ErrorBanner(message: _error!),
        const SizedBox(height: AppSpacing.sm),
        _PrimaryButton(
          enabled: _amountCents > 0 && !_loading,
          loading: _loading,
          label: 'Confirmar reposición',
          onPressed: _submit,
        ),
      ],
    );
  }
}

// =====================================================================
// 3 · Constructor crea certificación
// =====================================================================

Future<bool> showCreateCertSheet(
  BuildContext context, {
  required PactDetail detail,
}) async {
  return await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.sheetTop,
        ),
        builder: (ctx) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: _CreateCertSheet(detail: detail),
        ),
      ) ??
      false;
}

class _CreateCertSheet extends StatefulWidget {
  const _CreateCertSheet({required this.detail});

  final PactDetail detail;

  @override
  State<_CreateCertSheet> createState() => _CreateCertSheetState();
}

class _CreateCertSheetState extends State<_CreateCertSheet> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  int get _amountCents {
    final euros = int.tryParse(_amountCtrl.text) ?? 0;
    return euros * 100;
  }

  bool get _isValid =>
      _nameCtrl.text.trim().isNotEmpty && _amountCents >= 50000;

  /// Presupuesto disponible: total + anexos − ya consumido − en curso.
  int get _availableCents {
    final pact = widget.detail.pact;
    final inProgress = widget.detail.milestones
        .where((m) => m.state != 'paid')
        .fold<int>(0, (acc, m) => acc + m.amountCents);
    return widget.detail.effectiveBudgetCents -
        pact.budgetConsumedCents -
        inProgress;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_amountCents > _availableCents) {
      setState(() => _error =
          'Excede el presupuesto disponible (${AppFormatters.moneyShort(_availableCents)})');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await PactActionsV2.createCertification(
        pactId: widget.detail.pact.id,
        name: _nameCtrl.text,
        amountCents: _amountCents,
        description: _descCtrl.text,
        modelVersion: widget.detail.pact.modelVersion,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      await showSuccessOverlay(context, message: 'Certificación creada');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetScaffold(
      title: 'Nueva certificación',
      icon: Icons.add_chart,
      iconColor: AppColors.psBlue,
      children: [
        Text(
          'Describe el avance certificado y su importe. Recuerda adjuntar la factura desde el detalle de la certificación antes de enviarla a revisión.',
          style: AppTypography.bodyS.copyWith(color: context.colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nombre de la certificación *',
            hintText: 'Ej: Certificación #3 · Tabiquería',
          ),
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _descCtrl,
          decoration: const InputDecoration(
            labelText: 'Descripción del avance',
            hintText: 'Qué obra se ha ejecutado y qué evidencias se aportan',
          ),
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _amountCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Importe a certificar *',
            suffixText: '€',
          ),
          onChanged: (_) => setState(() => _error = null),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Disponible: ${AppFormatters.moneyShort(_availableCents)}',
          style: AppTypography.caption.copyWith(color: context.colors.textTertiary),
        ),
        if (_error != null) _ErrorBanner(message: _error!),
        const SizedBox(height: AppSpacing.sm),
        _PrimaryButton(
          enabled: _isValid && !_loading,
          loading: _loading,
          label: 'Crear certificación',
          onPressed: _submit,
        ),
      ],
    );
  }
}

// =====================================================================
// 4 · Cualquier parte propone anexo
// =====================================================================

Future<bool> showProposeAddendumSheet(
  BuildContext context, {
  required PactDetail detail,
}) async {
  return await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.sheetTop,
        ),
        builder: (ctx) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: _ProposeAddendumSheet(pactId: detail.pact.id),
        ),
      ) ??
      false;
}

class _ProposeAddendumSheet extends StatefulWidget {
  const _ProposeAddendumSheet({required this.pactId});

  final String pactId;

  @override
  State<_ProposeAddendumSheet> createState() => _ProposeAddendumSheetState();
}

class _ProposeAddendumSheetState extends State<_ProposeAddendumSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _daysCtrl = TextEditingController();
  final _justCtrl = TextEditingController();
  bool _isNegative = false;
  bool _loading = false;
  String? _error;

  int get _amountCents {
    final euros = int.tryParse(_amountCtrl.text) ?? 0;
    return _isNegative ? -euros * 100 : euros * 100;
  }

  int get _extraDays => int.tryParse(_daysCtrl.text) ?? 0;

  bool get _needsDoc => _amountCents.abs() > 1000000; // > 10K€

  bool get _isValid =>
      _titleCtrl.text.trim().isNotEmpty &&
      _amountCents != 0 &&
      _justCtrl.text.trim().isNotEmpty;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _amountCtrl.dispose();
    _daysCtrl.dispose();
    _justCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_needsDoc) {
      setState(() => _error =
          'Anexos > 10 000 € requieren documento detallado. Esta versión MVP aún no permite adjuntarlo — propón un anexo menor o espera al próximo sprint.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await PactActionsV2.createAddendum(
        pactId: widget.pactId,
        title: _titleCtrl.text,
        extraAmountCents: _amountCents,
        description: _descCtrl.text,
        extraDays: _extraDays,
        justification: _justCtrl.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      await showSuccessOverlay(context, message: 'Anexo propuesto');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetScaffold(
      title: 'Proponer anexo',
      icon: Icons.assignment_outlined,
      iconColor: AppColors.psBlue,
      children: [
        Text(
          'Los anexos modifican el pacto cuando hay imprevistos o cambios de alcance. '
          'Para activarse, todas las partes deben firmarlo.',
          style: AppTypography.bodyS.copyWith(color: context.colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _titleCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Título del anexo *',
            hintText: 'Ej: Ampliación zona cocina',
          ),
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText:
                      _isNegative ? 'Reducir importe' : 'Aumentar importe',
                  suffixText: '€',
                ),
                onChanged: (_) => setState(() => _error = null),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Column(
              children: [
                Text('Reduce',
                    style: AppTypography.caption
                        .copyWith(color: context.colors.textTertiary)),
                Switch(
                  value: _isNegative,
                  onChanged: (v) => setState(() => _isNegative = v),
                ),
              ],
            ),
          ],
        ),
        if (_needsDoc) ...[
          const SizedBox(height: AppSpacing.xs),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.warningBg,
              borderRadius: AppRadius.microAll,
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 16, color: AppColors.warning),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    'Anexos > 10 000 € requieren documento detallado adjunto.',
                    style: AppTypography.caption
                        .copyWith(color: context.colors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _daysCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Días extra al calendario (opcional)',
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _descCtrl,
          decoration: const InputDecoration(
            labelText: 'Descripción del cambio',
          ),
          maxLines: 2,
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _justCtrl,
          decoration: const InputDecoration(
            labelText: 'Justificación *',
            hintText: 'Por qué es necesario este anexo',
          ),
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => setState(() {}),
        ),
        if (_error != null) _ErrorBanner(message: _error!),
        const SizedBox(height: AppSpacing.sm),
        _PrimaryButton(
          enabled: _isValid && !_loading,
          loading: _loading,
          label: 'Proponer anexo',
          onPressed: _submit,
        ),
      ],
    );
  }
}

// =====================================================================
// 5 · Firmar anexo
// =====================================================================

Future<bool> showSignAddendumSheet(
  BuildContext context, {
  required PactAddendum addendum,
  required String myRole,
}) async {
  return await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.sheetTop,
        ),
        builder: (ctx) => _SignAddendumSheet(
          addendum: addendum,
          myRole: myRole,
        ),
      ) ??
      false;
}

class _SignAddendumSheet extends StatefulWidget {
  const _SignAddendumSheet({
    required this.addendum,
    required this.myRole,
  });

  final PactAddendum addendum;
  final String myRole;

  @override
  State<_SignAddendumSheet> createState() => _SignAddendumSheetState();
}

class _SignAddendumSheetState extends State<_SignAddendumSheet> {
  bool _accepted = false;
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final activated = await PactActionsV2.signAddendum(widget.addendum.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
      await showSuccessOverlay(
        context,
        message: activated
            ? 'Anexo activo · Presupuesto actualizado'
            : 'Anexo firmado',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.addendum;

    return _SheetScaffold(
      title: 'Firmar anexo #${a.ordinal}',
      icon: Icons.edit_note,
      iconColor: AppColors.psBlue,
      children: [
        Text(a.title,
            style: AppTypography.body.copyWith(fontWeight: FontWeight.w800)),
        if (a.description != null) ...[
          const SizedBox(height: 4),
          Text(a.description!,
              style: AppTypography.bodyS.copyWith(color: context.colors.textSecondary)),
        ],
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: context.colors.scaffold,
            borderRadius: AppRadius.smAll,
            border: Border.all(color: context.colors.border),
          ),
          child: Column(
            children: [
              _kv('Variación importe',
                  '${a.extraAmountCents >= 0 ? '+' : ''}${AppFormatters.moneyLong(a.extraAmountCents)}',
                  emphasis: true),
              if (a.extraDays != 0)
                _kv('Días extra',
                    '${a.extraDays > 0 ? '+' : ''}${a.extraDays} días'),
              if (a.justification != null)
                _kv('Justificación', a.justification!),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: _accepted,
          onChanged: _loading ? null : (v) => setState(() => _accepted = v ?? false),
          title: Text(
            'He leído el anexo y estoy conforme con su contenido. Confirmo mi firma electrónica como ${_roleLabel(widget.myRole)}.',
            style: AppTypography.bodyS,
          ),
        ),
        if (_error != null) _ErrorBanner(message: _error!),
        const SizedBox(height: AppSpacing.sm),
        _PrimaryButton(
          enabled: _accepted && !_loading,
          loading: _loading,
          label: 'Firmar anexo',
          onPressed: _submit,
        ),
      ],
    );
  }

  Widget _kv(String k, String v, {bool emphasis = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: Text(k,
                  style:
                      AppTypography.bodyS.copyWith(color: context.colors.textTertiary)),
            ),
            Expanded(
              flex: 6,
              child: Text(
                v,
                textAlign: TextAlign.right,
                style: AppTypography.bodyS.copyWith(
                  fontWeight: emphasis ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );

  static String _roleLabel(String r) => r == 'promotor'
      ? 'promotor'
      : (r == 'constructor' ? 'constructor' : 'técnico');
}

// =====================================================================
// Helpers compartidos
// =====================================================================

class _SheetScaffold extends StatelessWidget {
  const _SheetScaffold({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.children,
  });

  final String title;
  final IconData icon;
  final Color iconColor;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.colors.borderSubtle,
                    borderRadius: AppRadius.xxsAll,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: iconColor, size: 18),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child:
                        Text(title, style: AppTypography.h3),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.enabled,
    required this.loading,
    required this.label,
    required this.onPressed,
  });

  final bool enabled;
  final bool loading;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: loading
          ? const SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.white),
            )
          : const Icon(Icons.check, size: 18),
      onPressed: enabled
          ? () {
              AppHaptics.medium();
              onPressed();
            }
          : null,
      label: Text(loading ? 'Procesando…' : label),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.errorBg,
          borderRadius: AppRadius.microAll,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline,
                size: 16, color: AppColors.error),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(message,
                  style: AppTypography.bodyS
                      .copyWith(color: AppColors.error)),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// 6 · v2.1 · Promotor configura el Adelanto (sustituye fund_initial)
// =====================================================================

Future<bool> showSetupAdvanceSheet(
  BuildContext context, {
  required PactDetail detail,
}) async {
  return await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.sheetTop,
        ),
        builder: (ctx) => _SetupAdvanceSheet(detail: detail),
      ) ??
      false;
}

class _SetupAdvanceSheet extends StatefulWidget {
  const _SetupAdvanceSheet({required this.detail});
  final PactDetail detail;

  @override
  State<_SetupAdvanceSheet> createState() => _SetupAdvanceSheetState();
}

class _SetupAdvanceSheetState extends State<_SetupAdvanceSheet> {
  bool _accepted = false;
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await PactActionsV2.setupAdvance(widget.detail.pact.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
      await showSuccessOverlay(context, message: 'Adelanto configurado');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.detail.pact;
    final total = p.totalAdvanceCents;

    return _SheetScaffold(
      title: 'Configurar Adelanto',
      icon: Icons.shield_outlined,
      iconColor: AppColors.psBlue,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.infoBg,
            borderRadius: AppRadius.mdAll,
            border: Border.all(color: AppColors.psBlue, width: 1),
          ),
          child: Column(
            children: [
              Text(
                '${(p.depositRequiredPct ?? 30).toStringAsFixed(0)} % del presupuesto',
                style: AppTypography.caption
                    .copyWith(color: context.colors.textSecondary),
              ),
              const SizedBox(height: 4),
              Text(AppFormatters.moneyLong(total),
                  style: AppTypography.h1.copyWith(color: AppColors.psNavy)),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // Desglose interno
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: context.colors.scaffold,
            borderRadius: AppRadius.smAll,
            border: Border.all(color: context.colors.border),
          ),
          child: Column(
            children: [
              _kvRow(
                icon: Icons.account_balance_wallet_outlined,
                iconColor: AppColors.success,
                label: 'Reserva de finiquito',
                sublabel:
                    'Custodiada en PactStream hasta la última certificación',
                value: AppFormatters.moneyLong(p.advanceReserveCents),
              ),
              const SizedBox(height: AppSpacing.sm),
              Divider(height: 1, color: context.colors.divider),
              const SizedBox(height: AppSpacing.sm),
              _kvRow(
                icon: Icons.payments_outlined,
                iconColor: AppColors.psBlue,
                label: 'Anticipo al constructor',
                sublabel:
                    'Se entrega hoy. Cobertura inicial de la póliza de caución.',
                value: AppFormatters.moneyLong(p.advanceVariableCents),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Tras confirmar, el pacto pasará a "En ejecución" y el constructor podrá emitir certificaciones. '
          'En esta versión MVP el ingreso se simula — en producción Mangopay confirmará la transferencia.',
          style: AppTypography.bodyS.copyWith(color: context.colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.md),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: _accepted,
          onChanged: _loading ? null : (v) => setState(() => _accepted = v ?? false),
          title: Text(
            'Confirmo que he transferido ${AppFormatters.moneyShort(total)} a PactStream para configurar el Adelanto.',
            style: AppTypography.bodyS.copyWith(color: context.colors.textPrimary),
          ),
        ),
        if (_error != null) _ErrorBanner(message: _error!),
        const SizedBox(height: AppSpacing.sm),
        _PrimaryButton(
          enabled: _accepted && !_loading,
          loading: _loading,
          label:
              'Configurar Adelanto · ${AppFormatters.moneyShort(total)}',
          onPressed: _submit,
        ),
      ],
    );
  }

  Widget _kvRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String sublabel,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: AppTypography.bodyS
                      .copyWith(fontWeight: FontWeight.w700)),
              Text(sublabel,
                  style: AppTypography.caption
                      .copyWith(color: context.colors.textTertiary)),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(value,
            style: AppTypography.body
                .copyWith(fontWeight: FontWeight.w800, color: iconColor)),
      ],
    );
  }
}

// =====================================================================
// 7 · v2.1 · Promotor pre-deposita el neto de una certificación
// =====================================================================

Future<bool> showPredepositMilestoneSheet(
  BuildContext context, {
  required PactMilestone milestone,
}) async {
  return await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.sheetTop,
        ),
        builder: (ctx) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: _PredepositMilestoneSheet(milestone: milestone),
        ),
      ) ??
      false;
}

class _PredepositMilestoneSheet extends StatefulWidget {
  const _PredepositMilestoneSheet({required this.milestone});
  final PactMilestone milestone;

  @override
  State<_PredepositMilestoneSheet> createState() =>
      _PredepositMilestoneSheetState();
}

class _PredepositMilestoneSheetState
    extends State<_PredepositMilestoneSheet> {
  late final TextEditingController _ctrl = TextEditingController(
    text: widget.milestone.predepositRemainingCents > 0
        ? (widget.milestone.predepositRemainingCents ~/ 100).toString()
        : '',
  );
  bool _loading = false;
  String? _error;

  int get _amountCents {
    final euros = int.tryParse(_ctrl.text) ?? 0;
    return euros * 100;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_amountCents <= 0) {
      setState(() => _error = 'El importe debe ser positivo');
      return;
    }
    if (_amountCents > widget.milestone.predepositRemainingCents) {
      setState(() => _error =
          'El importe excede lo pendiente (${AppFormatters.moneyShort(widget.milestone.predepositRemainingCents)})');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await PactActionsV2.predepositMilestone(
        milestoneId: widget.milestone.id,
        amountCents: _amountCents,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      await showSuccessOverlay(context, message: 'Pre-depósito confirmado');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.milestone;

    return _SheetScaffold(
      title: 'Pre-depositar Cert #${m.ordinal}',
      icon: Icons.savings_outlined,
      iconColor: AppColors.warning,
      children: [
        Text(
          'Pre-deposita el neto para que el constructor pueda emitir la certificación oficialmente. El dinero queda custodiado en PactStream hasta la validación técnica.',
          style: AppTypography.bodyS.copyWith(color: context.colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.md),
        // Desglose de la cert
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: context.colors.scaffold,
            borderRadius: AppRadius.smAll,
            border: Border.all(color: context.colors.border),
          ),
          child: Column(
            children: [
              _kvLine('Bruto certificado',
                  AppFormatters.moneyLong(m.amountCents)),
              _kvLine('Amortización del Adelanto',
                  '− ${AppFormatters.moneyShort(m.advanceAmortizationCents)}',
                  muted: true),
              Divider(height: AppSpacing.sm, color: context.colors.divider),
              _kvLine('Neto a pre-depositar',
                  AppFormatters.moneyLong(m.netAmountCents),
                  emphasis: true),
              if (m.predepositReceivedCents > 0)
                _kvLine('Ya pre-depositado',
                    '− ${AppFormatters.moneyShort(m.predepositReceivedCents)}',
                    muted: true),
              if (m.predepositReceivedCents > 0) ...[
                Divider(height: AppSpacing.sm, color: context.colors.divider),
                _kvLine('Falta por pre-depositar',
                    AppFormatters.moneyLong(m.predepositRemainingCents),
                    emphasis: true,
                    color: AppColors.warning),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Importe a pre-depositar',
            suffixText: '€',
          ),
          onChanged: (_) => setState(() => _error = null),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Sugerido: ${AppFormatters.moneyShort(m.predepositRemainingCents)} (completar el neto)',
          style: AppTypography.caption.copyWith(color: context.colors.textTertiary),
        ),
        if (_error != null) _ErrorBanner(message: _error!),
        const SizedBox(height: AppSpacing.sm),
        _PrimaryButton(
          enabled: _amountCents > 0 && !_loading,
          loading: _loading,
          label: 'Pre-depositar ${AppFormatters.moneyShort(_amountCents)}',
          onPressed: _submit,
        ),
      ],
    );
  }

  Widget _kvLine(String k, String v,
      {bool muted = false, bool emphasis = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(k,
                style: AppTypography.bodyS.copyWith(
                  color: muted ? context.colors.textTertiary : context.colors.textSecondary,
                  fontWeight:
                      emphasis ? FontWeight.w700 : FontWeight.w400,
                )),
          ),
          Text(v,
              style: AppTypography.body.copyWith(
                fontWeight: emphasis ? FontWeight.w800 : FontWeight.w700,
                color: color ?? context.colors.textPrimary,
              )),
        ],
      ),
    );
  }
}

// =====================================================================
// 8 · v2.1 · Constructor avanza bajo su responsabilidad
// =====================================================================

Future<bool> showForceAdvanceSheet(
  BuildContext context, {
  required PactMilestone milestone,
}) async {
  return await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.sheetTop,
        ),
        builder: (ctx) => _ForceAdvanceSheet(milestone: milestone),
      ) ??
      false;
}

class _ForceAdvanceSheet extends StatefulWidget {
  const _ForceAdvanceSheet({required this.milestone});
  final PactMilestone milestone;

  @override
  State<_ForceAdvanceSheet> createState() => _ForceAdvanceSheetState();
}

class _ForceAdvanceSheetState extends State<_ForceAdvanceSheet> {
  bool _accepted = false;
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await PactActionsV2.forceAdvanceMilestone(
        milestoneId: widget.milestone.id,
        disclaimerAccepted: true,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      await showSuccessOverlay(context, message: 'Certificación reactivada');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.milestone;
    final gap = m.predepositRemainingCents;

    return _SheetScaffold(
      title: 'Avanzar bajo responsabilidad',
      icon: Icons.warning_amber_rounded,
      iconColor: AppColors.warning,
      children: [
        Text(
          'Vas a reactivar la Certificación #${m.ordinal} sin esperar a que el promotor complete el pre-depósito. '
          'Esto te permite seguir trabajando, pero el riesgo del importe pendiente recae sobre ti.',
          style: AppTypography.bodyS.copyWith(color: context.colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.md),

        // Card con el resumen del riesgo
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.warningBg,
            borderRadius: AppRadius.smAll,
            border: Border.all(color: AppColors.warning, width: 1),
          ),
          child: Column(
            children: [
              _miniRow('Cert #${m.ordinal}', m.name),
              const SizedBox(height: 4),
              _miniRow('Bruto certificado',
                  AppFormatters.moneyShort(m.amountCents)),
              _miniRow('Pre-depositado por el promotor',
                  AppFormatters.moneyShort(m.predepositReceivedCents)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: 6),
                decoration: BoxDecoration(
                  color: context.colors.card,
                  borderRadius: AppRadius.microAll,
                ),
                child: Row(
                  children: [
                    Text('Importe en riesgo',
                        style: AppTypography.bodyS
                            .copyWith(fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Text(AppFormatters.moneyLong(gap),
                        style: AppTypography.body.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.warning)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Disclaimer con peso jurídico
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.errorBg,
            borderRadius: AppRadius.smAll,
            border: Border.all(color: AppColors.error, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.gavel,
                      size: 16, color: AppColors.error),
                  const SizedBox(width: AppSpacing.xs),
                  Text('Implicaciones legales',
                      style: AppTypography.bodyS
                          .copyWith(fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '• PactStream queda liberada de responsabilidad sobre el dinero ejecutado mientras el pre-depósito no esté completo.\n\n'
                '• La aseguradora no cubrirá un eventual impago del importe en riesgo.\n\n'
                '• Esta acción se registra de forma inmutable en el audit log con marca temporal.\n\n'
                '• El promotor sigue obligado contractualmente a pagar, pero deberás reclamarlo directamente si no lo hace.',
                style: AppTypography.bodyS
                    .copyWith(color: context.colors.textPrimary, height: 1.45),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: _accepted,
          onChanged: _loading
              ? null
              : (v) => setState(() => _accepted = v ?? false),
          title: Text(
            'He leído las implicaciones y asumo el riesgo de ${AppFormatters.moneyShort(gap)} bajo mi propia responsabilidad.',
            style: AppTypography.bodyS,
          ),
        ),
        if (_error != null) _ErrorBanner(message: _error!),
        const SizedBox(height: AppSpacing.sm),
        ElevatedButton.icon(
          icon: _loading
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.white),
                )
              : const Icon(Icons.warning_amber_rounded, size: 18),
          onPressed: (_accepted && !_loading) ? _submit : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.warning,
            foregroundColor: AppColors.white,
          ),
          label:
              Text(_loading ? 'Procesando…' : 'Reactivar bajo mi responsabilidad'),
        ),
      ],
    );
  }

  Widget _miniRow(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(k,
                style: AppTypography.caption
                    .copyWith(color: context.colors.textSecondary)),
          ),
          Text(v,
              style: AppTypography.bodyS
                  .copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
