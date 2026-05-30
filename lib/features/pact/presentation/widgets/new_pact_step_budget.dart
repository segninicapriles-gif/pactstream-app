import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/pact_creation_data.dart';

/// Paso 2 del wizard (modelo v2.1):
/// presupuesto total + IVA + slider del % de Adelanto + frecuencia.
///
/// El Adelanto (10-40 %) se desglosa internamente:
///   · 10 % fijo → reserva de finiquito custodiada
///   · 0-30 % variable → entregado al constructor el día 1
class NewPactStepBudget extends StatefulWidget {
  const NewPactStepBudget({
    super.key,
    required this.data,
    required this.onChange,
  });

  final PactCreationData data;
  final VoidCallback onChange;

  @override
  State<NewPactStepBudget> createState() => _NewPactStepBudgetState();
}

class _NewPactStepBudgetState extends State<NewPactStepBudget> {
  late final TextEditingController _totalCtrl;
  late final TextEditingController _freqCtrl;

  static const List<String> _freqSuggestions = [
    'Mensual',
    'Quincenal',
    'Por avance > 20 %',
    'Según hitos del proyecto',
  ];

  static const List<int> _advanceSuggestions = [10, 20, 30, 40];

  @override
  void initState() {
    super.initState();
    _totalCtrl = TextEditingController(
      text: widget.data.totalAmountCents > 0
          ? (widget.data.totalAmountCents / 100).toStringAsFixed(0)
          : '',
    );
    _freqCtrl = TextEditingController(text: widget.data.certificationFrequency);
  }

  @override
  void dispose() {
    _totalCtrl.dispose();
    _freqCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final ivaCents = d.ivaIncluded
        ? 0
        : (d.totalAmountCents * d.ivaRatePct / 100).round();
    final totalWithIvaCents = d.totalAmountCents + ivaCents;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        // === Presupuesto ===
        Text('Presupuesto', style: AppTypography.h2.copyWith(color: context.colors.textPrimary)),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Importe total acordado para la obra. Podrá ajustarse con anexos firmados por las partes.',
          style: AppTypography.bodyS.copyWith(color: context.colors.textTertiary),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _totalCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Importe total',
            suffixText: '€',
          ),
          onChanged: (v) {
            final euros = int.tryParse(v) ?? 0;
            widget.data.totalAmountCents = euros * 100;
            widget.onChange();
          },
        ),
        const SizedBox(height: AppSpacing.md),

        // IVA
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<double>(
                initialValue: d.ivaRatePct,
                decoration: const InputDecoration(labelText: 'IVA'),
                items: const [
                  DropdownMenuItem(value: 10, child: Text('10 % (vivienda)')),
                  DropdownMenuItem(value: 21, child: Text('21 % (general)')),
                  DropdownMenuItem(value: 0, child: Text('Exento')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  widget.data.ivaRatePct = v;
                  widget.onChange();
                },
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('IVA incluido',
                    style: AppTypography.bodyS
                        .copyWith(fontWeight: FontWeight.w600, color: context.colors.textPrimary)),
                value: d.ivaIncluded,
                onChanged: (v) {
                  widget.data.ivaIncluded = v;
                  widget.onChange();
                },
              ),
            ),
          ],
        ),

        if (!d.ivaIncluded && d.totalAmountCents > 0) ...[
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: context.colors.scaffold,
              borderRadius: AppRadius.microAll,
            ),
            child: Row(
              children: [
                Text('IVA (${d.ivaRatePct.toStringAsFixed(0)} %)',
                    style: AppTypography.bodyS
                        .copyWith(color: context.colors.textSecondary)),
                const Spacer(),
                Text(AppFormatters.moneyShort(ivaCents),
                    style: AppTypography.bodyS
                        .copyWith(fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text('Total con IVA',
                  style: AppTypography.bodyS
                      .copyWith(color: context.colors.textPrimary)),
              const Spacer(),
              Text(AppFormatters.moneyShort(totalWithIvaCents),
                  style: AppTypography.body
                      .copyWith(fontWeight: FontWeight.w800, color: context.colors.textPrimary)),
            ],
          ),
        ],

        const SizedBox(height: AppSpacing.xl),

        // === Adelanto con doble garantía ===
        Text('Adelanto', style: AppTypography.h2.copyWith(color: context.colors.textPrimary)),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Importe que el promotor compromete al firmar. PactStream entrega la parte variable al constructor el día 1 y custodia el 10 % como reserva de finiquito.',
          style: AppTypography.bodyS.copyWith(color: context.colors.textTertiary),
        ),
        const SizedBox(height: AppSpacing.md),

        // Card del Adelanto con desglose en tiempo real
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: context.colors.infoBg,
            borderRadius: AppRadius.mdAll,
            border: Border.all(color: AppColors.psBlue, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // % grande + total en € arriba a la derecha
              Row(
                children: [
                  Text('${d.advancePct.toStringAsFixed(0)} %',
                      style: AppTypography.h1
                          .copyWith(color: context.colors.textPrimary)),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'del presupuesto',
                    style: AppTypography.bodyS
                        .copyWith(color: context.colors.textSecondary),
                  ),
                  const Spacer(),
                  Text(
                    AppFormatters.moneyShort(d.totalAdvanceCents),
                    style: AppTypography.h2
                        .copyWith(color: context.colors.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: context.colors.brandAccent,
                  thumbColor: context.colors.brandAccent,
                  inactiveTrackColor: context.colors.border,
                  valueIndicatorColor: context.colors.brandAccent,
                  trackHeight: 4,
                ),
                child: Slider(
                  min: 10,
                  max: 40,
                  divisions: 30,
                  value: d.advancePct,
                  label: '${d.advancePct.toStringAsFixed(0)} %',
                  onChanged: (v) {
                    widget.data.advancePct = v.roundToDouble();
                    widget.onChange();
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('10 %',
                      style: AppTypography.caption
                          .copyWith(color: context.colors.textTertiary)),
                  Text('40 %',
                      style: AppTypography.caption
                          .copyWith(color: context.colors.textTertiary)),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              // Chips de anclas
              Wrap(
                spacing: AppSpacing.xs,
                children: _advanceSuggestions.map((pct) {
                  final selected = d.advancePct.round() == pct;
                  return ChoiceChip(
                    label: Text('$pct %'),
                    selected: selected,
                    onSelected: (_) {
                      widget.data.advancePct = pct.toDouble();
                      widget.onChange();
                    },
                  );
                }).toList(),
              ),

              // Desglose interno (las dos partes del Adelanto)
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: context.colors.card,
                  borderRadius: AppRadius.microAll,
                ),
                child: Column(
                  children: [
                    _BreakdownRow(
                      icon: Icons.shield_outlined,
                      iconColor: AppColors.success,
                      label: 'Reserva de finiquito (10 %)',
                      sublabel: 'Custodiada hasta la última certificación',
                      value: AppFormatters.moneyShort(d.advanceReserveCents),
                    ),
                    const SizedBox(height: 6),
                    Divider(height: 1, color: context.colors.divider),
                    const SizedBox(height: 6),
                    _BreakdownRow(
                      icon: Icons.payments_outlined,
                      iconColor: context.colors.brandAccent,
                      label:
                          'Anticipo al constructor (${d.advanceVariablePct.toStringAsFixed(0)} %)',
                      sublabel: d.advancePct == 10
                          ? 'No hay anticipo · solo reserva'
                          : 'Entregado el día 1, asegurado con caución',
                      value: AppFormatters.moneyShort(d.advanceReleasedCents),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: context.colors.scaffold,
            borderRadius: AppRadius.microAll,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline,
                  size: 16, color: context.colors.textSecondary),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'Mínimo del 10 % obligatorio (la reserva). El resto se negocia con el constructor: lo habitual son 20-30 % adicionales para que pueda comprar materiales.',
                  style: AppTypography.caption
                      .copyWith(color: context.colors.textSecondary),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.xl),

        // === Frecuencia de certificación ===
        Text('Frecuencia de certificación', style: AppTypography.h2.copyWith(color: context.colors.textPrimary)),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Cada cuánto el constructor podrá emitir certificaciones de avance para cobrar.',
          style: AppTypography.bodyS.copyWith(color: context.colors.textTertiary),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _freqCtrl,
          decoration: const InputDecoration(
            labelText: 'Frecuencia acordada *',
            hintText: 'Ej: Mensual, por avance > 20 %, según hitos…',
          ),
          textCapitalization: TextCapitalization.sentences,
          onChanged: (v) {
            widget.data.certificationFrequency = v;
            widget.onChange();
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: _freqSuggestions.map((s) {
            final selected =
                widget.data.certificationFrequency.trim() == s;
            return ChoiceChip(
              label: Text(s),
              selected: selected,
              onSelected: (_) {
                _freqCtrl.text = s;
                widget.data.certificationFrequency = s;
                widget.onChange();
              },
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

/// Fila de desglose del Adelanto (reserva / anticipo al constructor).
class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.sublabel,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String sublabel;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: AppTypography.bodyS
                      .copyWith(fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
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
