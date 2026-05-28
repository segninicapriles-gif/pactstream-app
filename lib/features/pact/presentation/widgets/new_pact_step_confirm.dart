import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/pact_creation_data.dart';

/// Paso 4 del wizard (modelo v2.1): resumen final + creación del pacto en BD.
class NewPactStepConfirm extends StatefulWidget {
  const NewPactStepConfirm({
    super.key,
    required this.data,
    required this.submitting,
    required this.errorMessage,
    required this.onSubmit,
  });

  final PactCreationData data;
  final bool submitting;
  final String? errorMessage;
  final VoidCallback onSubmit;

  @override
  State<NewPactStepConfirm> createState() => _NewPactStepConfirmState();
}

class _NewPactStepConfirmState extends State<NewPactStepConfirm> {
  bool _accepted = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final canSubmit = _accepted && !widget.submitting && d.step4Valid;
    final feeRate = d.pactType == 'obra_menor' ? 0.008 : 0.01;
    final feeCents = (d.totalAmountCents * feeRate).round();
    final partiesCount = d.invites.length + 1;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      color: AppColors.infoBg,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.gavel,
                        color: AppColors.psBlue, size: 36),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Crear pacto',
                    textAlign: TextAlign.center, style: AppTypography.h1.copyWith(color: context.colors.textPrimary)),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Las partes invitadas recibirán un email para unirse y firmar. '
                  'El promotor comprometerá el ${d.advancePct.toStringAsFixed(0)} % del presupuesto como Adelanto: '
                  '${AppFormatters.moneyShort(d.advanceReleasedCents)} al constructor el día 1 y '
                  '${AppFormatters.moneyShort(d.advanceReserveCents)} en custodia hasta el finiquito.',
                  textAlign: TextAlign.center,
                  style: AppTypography.body.copyWith(color: context.colors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.xl),

                // === Resumen de la obra ===
                _SummaryCard(
                  title: 'La obra',
                  icon: Icons.business_center_outlined,
                  rows: [
                    _SummaryRow('Tipo',
                        d.pactType == 'obra_menor' ? 'Obra menor' : 'Obra mayor'),
                    _SummaryRow('Título', d.title),
                    _SummaryRow('Dirección',
                        '${d.addressLine}, ${d.postalCode} ${d.province}'),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // === Resumen económico v2.1 ===
                _SummaryCard(
                  title: 'Presupuesto y Adelanto',
                  icon: Icons.account_balance_outlined,
                  rows: [
                    _SummaryRow('Presupuesto total',
                        AppFormatters.moneyLong(d.totalAmountCents),
                        emphasis: true),
                    _SummaryRow(
                        'IVA',
                        d.ivaIncluded
                            ? 'Incluido (${d.ivaRatePct.toStringAsFixed(0)} %)'
                            : 'Más ${d.ivaRatePct.toStringAsFixed(0)} %'),
                    _SummaryRow(
                        'Adelanto total',
                        '${d.advancePct.toStringAsFixed(0)} % · ${AppFormatters.moneyLong(d.totalAdvanceCents)}',
                        emphasis: true),
                    _SummaryRow(
                        '  Reserva de finiquito (10 %)',
                        AppFormatters.moneyShort(d.advanceReserveCents),
                        muted: true),
                    _SummaryRow(
                        '  Anticipo al constructor',
                        AppFormatters.moneyShort(d.advanceReleasedCents),
                        muted: true),
                    _SummaryRow(
                        'Frecuencia certificación', d.certificationFrequency),
                    _SummaryRow(
                      'Comisión PactStream (${(feeRate * 100).toStringAsFixed(1)} %)',
                      AppFormatters.moneyLong(feeCents),
                      muted: true,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // === Equipo ===
                _SummaryCard(
                  title: 'Partes del pacto',
                  icon: Icons.group_outlined,
                  rows: [
                    _SummaryRow('Total de partes', '$partiesCount'),
                    for (final inv in d.invites)
                      _SummaryRow(_roleLabel(inv.role),
                          '${inv.fullName} · ${inv.email}'),
                  ],
                ),

                const SizedBox(height: AppSpacing.lg),

                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _accepted,
                  onChanged: widget.submitting
                      ? null
                      : (v) => setState(() => _accepted = v ?? false),
                  title: Text(
                    'Confirmo que los datos son correctos y autorizo a PactStream a notificar a las partes invitadas.',
                    style: AppTypography.bodyS.copyWith(color: context.colors.textPrimary),
                  ),
                ),

                if (widget.errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.errorBg,
                      borderRadius: AppRadius.smAll,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline,
                            color: AppColors.error, size: 18),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(widget.errorMessage!,
                              style: AppTypography.bodyS
                                  .copyWith(color: AppColors.error)),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          ElevatedButton.icon(
            icon: widget.submitting
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.white,
                    ),
                  )
                : const Icon(Icons.check),
            onPressed: canSubmit ? widget.onSubmit : null,
            label: Text(widget.submitting ? 'Creando…' : 'Crear pacto ahora'),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Aún no se cobra nada. El Adelanto se solicitará cuando todas las partes firmen.',
            textAlign: TextAlign.center,
            style: AppTypography.caption.copyWith(color: context.colors.textTertiary),
          ),
        ],
      ),
    );
  }

  static String _roleLabel(String role) {
    switch (role) {
      case 'promotor':
        return 'Promotor';
      case 'constructor':
        return 'Constructor';
      case 'tecnico':
        return 'Técnico';
      default:
        return role;
    }
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.icon,
    required this.rows,
  });

  final String title;
  final IconData icon;
  final List<_SummaryRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.colors.scaffold,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.psBlue),
              const SizedBox(width: AppSpacing.xs),
              Text(title,
                  style: AppTypography.bodyS
                      .copyWith(fontWeight: FontWeight.w800, color: context.colors.textPrimary)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ...rows,
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.label, this.value,
      {this.muted = false, this.emphasis = false});

  final String label;
  final String value;
  final bool muted;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(label,
                style: AppTypography.bodyS.copyWith(
                    color: muted ? context.colors.textTertiary : context.colors.textSecondary)),
          ),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppTypography.bodyS.copyWith(
                fontWeight: emphasis
                    ? FontWeight.w800
                    : (muted ? FontWeight.w500 : FontWeight.w700),
                color: muted ? context.colors.textSecondary : context.colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
