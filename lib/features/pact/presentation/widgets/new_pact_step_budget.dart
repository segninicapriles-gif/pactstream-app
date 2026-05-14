import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/pact_creation_data.dart';

/// Paso 2 del wizard (modelo v2.0):
/// presupuesto total + IVA + slider del % de depósito + frecuencia de
/// certificación. NO se crean hitos aquí — los crea el constructor durante
/// la ejecución, por demanda.
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

  // Sugerencias rápidas para la frecuencia
  static const List<String> _freqSuggestions = [
    'Mensual',
    'Quincenal',
    'Por avance > 20 %',
    'Según hitos del proyecto',
  ];

  // Sugerencias rápidas para el % de depósito (anclas comunes)
  static const List<int> _depositSuggestions = [15, 30, 40];

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
    final depositCents = d.depositRequiredCents;
    final ivaCents = d.ivaIncluded
        ? 0
        : (d.totalAmountCents * d.ivaRatePct / 100).round();
    final totalWithIvaCents = d.totalAmountCents + ivaCents;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        // === Presupuesto ===
        Text('Presupuesto', style: AppTypography.h2),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Importe total acordado para la obra. Se podrá ajustar con anexos firmados por las partes.',
          style: AppTypography.bodyS.copyWith(color: AppColors.ink500),
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
                        .copyWith(fontWeight: FontWeight.w600)),
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
              color: AppColors.ink50,
              borderRadius: BorderRadius.circular(AppSpacing.xs),
            ),
            child: Row(
              children: [
                Text('IVA (${d.ivaRatePct.toStringAsFixed(0)} %)',
                    style: AppTypography.bodyS
                        .copyWith(color: AppColors.ink600)),
                const Spacer(),
                Text(AppFormatters.moneyShort(ivaCents),
                    style: AppTypography.bodyS
                        .copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text('Total con IVA',
                  style: AppTypography.bodyS
                      .copyWith(color: AppColors.ink900)),
              const Spacer(),
              Text(AppFormatters.moneyShort(totalWithIvaCents),
                  style: AppTypography.body
                      .copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
        ],

        const SizedBox(height: AppSpacing.xl),

        // === Depósito en custodia ===
        Text('Depósito en custodia', style: AppTypography.h2),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Importe que el promotor deposita al firmar. PactStream lo retiene y libera contra certificaciones validadas.',
          style: AppTypography.bodyS.copyWith(color: AppColors.ink500),
        ),
        const SizedBox(height: AppSpacing.md),

        // Card del depósito con preview en € en tiempo real
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.infoBg,
            borderRadius: BorderRadius.circular(AppSpacing.md),
            border: Border.all(color: AppColors.psBlue, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text('${d.depositPct.toStringAsFixed(0)} %',
                      style: AppTypography.h1
                          .copyWith(color: AppColors.psNavy)),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'del presupuesto',
                    style: AppTypography.bodyS
                        .copyWith(color: AppColors.ink600),
                  ),
                  const Spacer(),
                  Text(
                    AppFormatters.moneyShort(depositCents),
                    style: AppTypography.h2
                        .copyWith(color: AppColors.psNavy),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: AppColors.psBlue,
                  thumbColor: AppColors.psNavy,
                  inactiveTrackColor: AppColors.ink200,
                  valueIndicatorColor: AppColors.psNavy,
                  trackHeight: 4,
                ),
                child: Slider(
                  min: 15,
                  max: 40,
                  divisions: 25,
                  value: d.depositPct,
                  label: '${d.depositPct.toStringAsFixed(0)} %',
                  onChanged: (v) {
                    widget.data.depositPct = v.roundToDouble();
                    widget.onChange();
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('15 %',
                      style: AppTypography.caption
                          .copyWith(color: AppColors.ink500)),
                  Text('40 %',
                      style: AppTypography.caption
                          .copyWith(color: AppColors.ink500)),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              // Chips de anclas comunes
              Wrap(
                spacing: AppSpacing.xs,
                children: _depositSuggestions.map((pct) {
                  final selected = d.depositPct.round() == pct;
                  return ChoiceChip(
                    label: Text('$pct %'),
                    selected: selected,
                    onSelected: (_) {
                      widget.data.depositPct = pct.toDouble();
                      widget.onChange();
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.ink50,
            borderRadius: BorderRadius.circular(AppSpacing.xs),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.shield_outlined,
                  size: 16, color: AppColors.ink600),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'Sugerencia: el 30 % es lo más habitual en el sector. Tramos menores reducen el riesgo del promotor; mayores dan más colchón al constructor.',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.ink600),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.xl),

        // === Frecuencia de certificación ===
        Text('Frecuencia de certificación', style: AppTypography.h2),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Cada cuánto el constructor podrá emitir una certificación de avance para cobrar.',
          style: AppTypography.bodyS.copyWith(color: AppColors.ink500),
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
