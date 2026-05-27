import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/pact_creation_data.dart';

/// Paso 1 del wizard: tipo de obra + información básica.
class NewPactStepBasics extends StatefulWidget {
  const NewPactStepBasics({
    super.key,
    required this.data,
    required this.onChange,
  });

  final PactCreationData data;
  final VoidCallback onChange;

  @override
  State<NewPactStepBasics> createState() => _NewPactStepBasicsState();
}

class _NewPactStepBasicsState extends State<NewPactStepBasics> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _cpCtrl;
  late final TextEditingController _provinceCtrl;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.data.title);
    _descCtrl = TextEditingController(text: widget.data.description);
    _addressCtrl = TextEditingController(text: widget.data.addressLine);
    _cpCtrl = TextEditingController(text: widget.data.postalCode);
    _provinceCtrl = TextEditingController(text: widget.data.province);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _addressCtrl.dispose();
    _cpCtrl.dispose();
    _provinceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text('¿Qué tipo de obra es?', style: AppTypography.h2),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Esto define qué partes participan y la documentación necesaria.',
          style: AppTypography.bodyS.copyWith(color: AppColors.ink500),
        ),
        const SizedBox(height: AppSpacing.lg),

        _PactTypeCard(
          selected: widget.data.pactType == 'obra_mayor',
          icon: Icons.apartment_outlined,
          title: 'Obra mayor',
          subtitle:
              'Reformas estructurales o ampliaciones. Requiere arquitecto técnico que valida hitos. Comisión 1% sobre custodia.',
          onTap: () {
            widget.data.pactType = 'obra_mayor';
            widget.data.minorWorkCategory = null;
            widget.data.minorWorkDeclaration = false;
            widget.onChange();
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        _PactTypeCard(
          selected: widget.data.pactType == 'obra_menor',
          icon: Icons.format_paint_outlined,
          title: 'Obra menor',
          subtitle:
              'Reformas no estructurales (pintura, baños, cocina). Solo promotor + constructor. Comisión 0,8% sobre custodia.',
          onTap: () {
            widget.data.pactType = 'obra_menor';
            widget.onChange();
          },
        ),

        // Si obra menor, exigimos categoría + declaración
        if (widget.data.pactType == 'obra_menor') ...[
          const SizedBox(height: AppSpacing.lg),
          Text('Categoría de obra menor', style: AppTypography.label),
          const SizedBox(height: AppSpacing.xs),
          DropdownButtonFormField<String>(
            value: widget.data.minorWorkCategory,
            items: const [
              DropdownMenuItem(value: 'pintura', child: Text('Pintura')),
              DropdownMenuItem(value: 'cocina', child: Text('Cocina')),
              DropdownMenuItem(value: 'bano', child: Text('Baño')),
              DropdownMenuItem(value: 'suelos', child: Text('Suelos')),
              DropdownMenuItem(value: 'carpinteria', child: Text('Carpintería')),
              DropdownMenuItem(value: 'otra', child: Text('Otra no estructural')),
            ],
            decoration: const InputDecoration(
              hintText: 'Selecciona el tipo',
            ),
            onChanged: (v) {
              widget.data.minorWorkCategory = v;
              widget.onChange();
            },
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.warningBg,
              borderRadius: AppRadius.smAll,
              border: Border.all(color: AppColors.warning, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        size: 18, color: AppColors.warning),
                    const SizedBox(width: AppSpacing.xs),
                    Text('Declaración del promotor',
                        style: AppTypography.bodyS
                            .copyWith(fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'En obra menor sin técnico, el promotor asume la responsabilidad de declarar que la obra no afecta a la estructura ni requiere licencia de obra mayor.',
                  style: AppTypography.bodyS,
                ),
                const SizedBox(height: AppSpacing.sm),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: widget.data.minorWorkDeclaration,
                  onChanged: (v) {
                    widget.data.minorWorkDeclaration = v ?? false;
                    widget.onChange();
                  },
                  title: Text(
                    'Declaro que esta obra no es estructural y conozco que la responsabilidad recae sobre mí.',
                    style: AppTypography.bodyS,
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: AppSpacing.xl),
        Text('Datos de la obra', style: AppTypography.h2),
        const SizedBox(height: AppSpacing.md),

        TextField(
          controller: _titleCtrl,
          decoration: const InputDecoration(
            labelText: 'Nombre / título de la obra',
            hintText: 'Ej: Reforma Integral Malasaña',
          ),
          textCapitalization: TextCapitalization.sentences,
          onChanged: (v) {
            widget.data.title = v;
            widget.onChange();
          },
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _descCtrl,
          decoration: const InputDecoration(
            labelText: 'Descripción breve (opcional)',
            hintText: 'Alcance principal del proyecto…',
          ),
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (v) {
            widget.data.description = v;
            widget.onChange();
          },
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _addressCtrl,
          decoration: const InputDecoration(
            labelText: 'Dirección',
            hintText: 'Calle, número, piso',
          ),
          textCapitalization: TextCapitalization.words,
          onChanged: (v) {
            widget.data.addressLine = v;
            widget.onChange();
          },
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: _provinceCtrl,
                decoration: const InputDecoration(labelText: 'Provincia'),
                textCapitalization: TextCapitalization.words,
                onChanged: (v) {
                  widget.data.province = v;
                  widget.onChange();
                },
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              flex: 1,
              child: TextField(
                controller: _cpCtrl,
                decoration: const InputDecoration(labelText: 'CP'),
                keyboardType: TextInputType.number,
                onChanged: (v) {
                  widget.data.postalCode = v;
                  widget.onChange();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

class _PactTypeCard extends StatelessWidget {
  const _PactTypeCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.mdAll,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: selected ? AppColors.infoBg : AppColors.white,
          borderRadius: AppRadius.mdAll,
          border: Border.all(
            color: selected ? AppColors.psBlue : AppColors.ink200,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: selected ? AppColors.psBlue : AppColors.ink100,
                borderRadius: AppRadius.smAll,
              ),
              child: Icon(
                icon,
                color: selected ? AppColors.white : AppColors.ink600,
                size: 24,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppTypography.body
                          .copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: AppTypography.bodyS
                          .copyWith(color: AppColors.ink500)),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: AppColors.psBlue),
          ],
        ),
      ),
    );
  }
}
