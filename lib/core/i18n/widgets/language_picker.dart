import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../theme/app_colors.dart';
import '../app_language.dart';
import '../l10n_extension.dart';
import '../locale_provider.dart';

/// Selector de idioma en línea, para el wizard de alta.
///
/// Cada opción se etiqueta en SU PROPIO idioma ("English (US)", no "Inglés").
/// Quien abre la app en el idioma equivocado no entiende la etiqueta traducida;
/// solo reconoce el nombre nativo. Es la regla básica de todo selector de
/// idioma y la que más se incumple.
///
/// El cambio es inmediato y visible: al tocar "English (US)" toda la pantalla
/// pasa a inglés al instante, así que el usuario confirma su elección viéndola
/// aplicada en vez de fiándose de una etiqueta.
class LanguagePicker extends ConsumerWidget {
  const LanguagePicker({super.key, this.showHeader = true});

  /// El sheet de ajustes ya tiene su propio título; ahí se oculta.
  final bool showHeader;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(appLanguageProvider);
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeader) ...[
          Text(l10n.languageSelectorTitle,
              style: AppTypography.h3.copyWith(fontSize: 16)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.languageSelectorSubtitle,
            style: AppTypography.bodyS
                .copyWith(color: context.colors.textTertiary),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        ...AppLanguage.values.map(
          (language) => _LanguageOption(
            language: language,
            selected: language == current,
            onTap: () => ref
                .read(appLanguageProvider.notifier)
                .setLanguage(language),
          ),
        ),
      ],
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.language,
    required this.selected,
    required this.onTap,
  });

  final AppLanguage language;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Semantics(
        // `selected` da a los lectores de pantalla el estado real del control;
        // sin esto se anuncia como un botón cualquiera y no se sabe cuál está
        // activo.
        selected: selected,
        button: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.lgAll,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: context.colors.card,
              borderRadius: AppRadius.lgAll,
              border: Border.all(
                color: selected
                    ? context.colors.brandAccent
                    : context.colors.border,
                width: selected ? 2 : 1.5,
              ),
            ),
            child: Row(
              children: [
                Text(language.flagEmoji,
                    style: const TextStyle(fontSize: 22)),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    language.nativeName,
                    style: AppTypography.body.copyWith(
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: context.colors.textPrimary,
                    ),
                  ),
                ),
                if (selected)
                  Icon(Icons.check_circle,
                      color: context.colors.brandAccent, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Fila de ajustes que abre el selector en un bottom sheet.
///
/// Es el punto de cambio POSTERIOR al alta: el usuario elige idioma al crear el
/// perfil, pero tiene que poder rectificar sin borrar la cuenta.
class LanguageSettingsTile extends ConsumerWidget {
  const LanguageSettingsTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(appLanguageProvider);

    return ListTile(
      leading: Icon(Icons.language_outlined,
          color: context.colors.brandAccent),
      title: Text(context.l10n.languageLabel, style: AppTypography.body),
      subtitle: Text(
        '${language.flagEmoji}  ${language.nativeName}',
        style: AppTypography.bodyS
            .copyWith(color: context.colors.textTertiary),
      ),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: () => showLanguageSheet(context),
    );
  }
}

/// Abre el selector de idioma como bottom sheet.
Future<void> showLanguageSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.colors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(sheetContext.l10n.languageSelectorTitle,
                style: AppTypography.h2),
            const SizedBox(height: AppSpacing.xs),
            Text(
              sheetContext.l10n.languageSelectorSubtitle,
              style: AppTypography.bodyS
                  .copyWith(color: sheetContext.colors.textTertiary),
            ),
            const SizedBox(height: AppSpacing.lg),
            const LanguagePicker(showHeader: false),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: () => Navigator.of(sheetContext).pop(),
              child: Text(sheetContext.l10n.commonClose),
            ),
          ],
        ),
      ),
    ),
  );
}
