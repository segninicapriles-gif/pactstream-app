import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import '../utils/currency.dart';
import '../utils/formatters.dart';

/// Cifra Viva — Sistema ARCO §1/§8 (ver
/// `design-ecosistema-2026-07/DESIGN-ECOSISTEMA.md`).
///
/// Renderiza un importe en Nunito (cifras tabulares) con la firma del
/// ecosistema: la parte entera en w700 (el dato que se reconoce "a un
/// metro de distancia"), los decimales y el símbolo de moneda en w400
/// al 55% de opacidad (el detalle, en segundo plano).
///
/// NOTA (decisión Andrés, 20-jul): la Cifra Viva pasó de JetBrains Mono a
/// Nunito para armonizar con los titulares — las formas monoespaciadas
/// chocaban con la estética redondeada del sistema. Cambio en todo el
/// ecosistema (web + apps). No revertir a mono creyendo que es un bug.
///
/// Dos formas de uso:
///
/// 1. A partir de céntimos (recomendado — usa [AppFormatters] internamente,
///    currency-aware por sesión, sin duplicar lógica de formato):
/// ```dart
/// CifraViva(amountCents: pact.totalAmountCents)
/// CifraViva(amountCents: milestone.amountCents, showDecimals: true, size: CifraViva.xl)
/// ```
///
/// 2. A partir de un string ya formateado por [AppFormatters] (para no
///    tocar call sites que ya construyen el texto, p. ej. `HeroKpiCard`):
/// ```dart
/// CifraViva(formatted: AppFormatters.moneyShort(cents))
/// ```
///
/// El split entre "parte entera" y "decimales + símbolo" se hace sobre el
/// TEXTO ya formateado (no se reimplementa el formateo de moneda): se busca
/// el símbolo activo al inicio o al final del string y, si corresponde, los
/// últimos 1-2 dígitos decimales tras un separador. Funciona con símbolos
/// prefijo ($, S/) o sufijo (€), que es como ya se comporta multi-moneda en
/// [CurrencyInfo].
class CifraViva extends StatelessWidget {
  const CifraViva({
    super.key,
    this.amountCents,
    this.formatted,
    this.currency,
    this.showDecimals = false,
    this.symbolOverride,
    this.size = base,
    this.color,
    this.fontWeight = FontWeight.w700,
    this.dimOpacity = 0.55,
    this.semanticLabel,
  })  : assert(
          amountCents != null || formatted != null,
          'CifraViva requiere amountCents o formatted.',
        ),
        assert(
          !(amountCents != null && formatted != null),
          'CifraViva: pasa amountCents o formatted, no ambos.',
        );

  /// Tamaño por defecto (~24px), para KPIs de dashboard y cards de lista.
  static const double base = 24;

  /// Variante XL (~34px), para importes protagonistas (detalle de hito).
  static const double xl = 34;

  /// Importe en la subunidad (céntimos). Si se pasa, el formateo se hace
  /// internamente vía [AppFormatters.moneyShort]/[AppFormatters.moneyLong].
  final int? amountCents;

  /// Importe ya formateado (p. ej. salida de [AppFormatters.moneyShort]).
  /// Alternativa a [amountCents] para no tocar call sites existentes.
  final String? formatted;

  /// Moneda a usar al formatear desde [amountCents]. Por defecto, la moneda
  /// activa de sesión ([AppFormatters.activeCurrency]).
  final CurrencyInfo? currency;

  /// Si se formatea desde [amountCents]: `true` → [AppFormatters.moneyLong]
  /// (con decimales), `false` → [AppFormatters.moneyShort] (sin decimales).
  final bool showDecimals;

  /// Símbolo a usar para detectar el split cuando se pasa [formatted] con
  /// una moneda distinta a la activa de sesión. Por defecto, el símbolo de
  /// [currency] o de la moneda activa.
  final String? symbolOverride;

  /// Tamaño de fuente de la parte entera (los decimales son ~0.6x de este).
  final double size;

  /// Color de la parte entera. Por defecto, `context.colors.textPrimary`.
  final Color? color;

  /// Peso de la parte entera (los decimales siempre van en w400).
  final FontWeight fontWeight;

  /// Opacidad de la parte "decimales + símbolo" respecto a [color].
  final double dimOpacity;

  /// Label de accesibilidad opcional. Si se omite, se usa el texto completo
  /// (la cifra formateada tal cual se leería).
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final resolvedCurrency = currency ?? AppFormatters.activeCurrency;
    final text = formatted ??
        (showDecimals
            ? AppFormatters.moneyLong(amountCents!, currency: currency)
            : AppFormatters.moneyShort(amountCents!, currency: currency));
    final symbol = symbolOverride ?? resolvedCurrency.symbol;
    final baseColor = color ?? context.colors.textPrimary;
    final dimColor = baseColor.withValues(alpha: dimOpacity);

    final parts = _splitAmount(text, symbol);

    final boldStyle = GoogleFonts.nunito(
      fontSize: size,
      fontWeight: fontWeight,
      color: baseColor,
      height: 1.0,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final dimStyle = boldStyle.copyWith(
      fontSize: size * 0.6,
      fontWeight: FontWeight.w400,
      color: dimColor,
    );

    return Semantics(
      label: semanticLabel ?? text,
      excludeSemantics: true,
      child: RichText(
        text: TextSpan(
          children: [
            if (parts.prefixDim.isNotEmpty)
              TextSpan(text: parts.prefixDim, style: dimStyle),
            TextSpan(text: parts.intPart, style: boldStyle),
            if (parts.dimTail.isNotEmpty)
              TextSpan(text: parts.dimTail, style: dimStyle),
          ],
        ),
      ),
    );
  }

  /// Separa un importe ya formateado en (prefijo tenue, parte entera fuerte,
  /// cola tenue = decimales + símbolo). Tolerante a símbolo prefijo o sufijo
  /// y a ausencia de decimales (listas usan `moneyShort`, sin decimales: en
  /// ese caso solo el símbolo queda tenue).
  static _AmountParts _splitAmount(String formatted, String symbol) {
    final trimmed = formatted.trim();

    if (symbol.isNotEmpty && trimmed.startsWith(symbol)) {
      final afterSymbol = trimmed.substring(symbol.length);
      final leadWs = RegExp(r'^\s*').stringMatch(afterSymbol) ?? '';
      final rest = afterSymbol.substring(leadWs.length);
      final split = _splitDecimals(rest);
      return _AmountParts(
        prefixDim: symbol + leadWs,
        intPart: split.$1,
        dimTail: split.$2,
      );
    }

    if (symbol.isNotEmpty && trimmed.endsWith(symbol)) {
      final beforeSymbol = trimmed.substring(0, trimmed.length - symbol.length);
      final trailWs = RegExp(r'\s*$').stringMatch(beforeSymbol) ?? '';
      final rest = beforeSymbol.substring(0, beforeSymbol.length - trailWs.length);
      final split = _splitDecimals(rest);
      return _AmountParts(
        prefixDim: '',
        intPart: split.$1,
        dimTail: split.$2 + trailWs + symbol,
      );
    }

    // Símbolo no localizado en el texto (moneda/formato inesperado): no se
    // fuerza ningún split del símbolo, pero se intentan igualmente separar
    // los decimales para no perder la firma tipográfica de Cifra Viva.
    final split = _splitDecimals(trimmed);
    return _AmountParts(prefixDim: '', intPart: split.$1, dimTail: split.$2);
  }

  /// Devuelve (parte entera, separador+decimales o '').
  static (String, String) _splitDecimals(String numeric) {
    final match = RegExp(r'([.,]\d{1,2})$').firstMatch(numeric);
    if (match == null) return (numeric, '');
    return (numeric.substring(0, match.start), match.group(0)!);
  }
}

class _AmountParts {
  const _AmountParts({
    required this.prefixDim,
    required this.intPart,
    required this.dimTail,
  });

  final String prefixDim;
  final String intPart;
  final String dimTail;
}
