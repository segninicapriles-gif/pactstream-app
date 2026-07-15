import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/monthly_series_providers.dart';
import 'mini_bar_chart.dart';

/// Qué serie mensual pinta el chart.
enum MonthlySeriesKind { billing, fundFlow, validations }

/// Chart de barras conectado a `sf_get_monthly_series` (datos reales).
///
/// Mientras carga, o si la RPC aún no está desplegada, muestra 6 barras a
/// cero → MiniBarChart renderiza su empty state honesto ("Aún no hay
/// datos"). Nunca cifras inventadas.
class MonthlySeriesChart extends ConsumerWidget {
  const MonthlySeriesChart({
    super.key,
    required this.kind,
    required this.title,
    this.barColor,
  });

  final MonthlySeriesKind kind;
  final String title;
  final Color? barColor;

  static const _monthNames = [
    'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
    'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
  ];

  /// 6 meses a cero terminando en el actual (placeholder de carga/fallback).
  static List<BarChartItem> _zeros() {
    final now = DateTime.now();
    return List.generate(6, (i) {
      final month = DateTime(now.year, now.month - 5 + i);
      return BarChartItem(label: _monthNames[month.month - 1], value: 0);
    });
  }

  List<BarChartItem> _select(MonthlySeries s) => switch (kind) {
        MonthlySeriesKind.billing => s.billing,
        MonthlySeriesKind.fundFlow => s.fundFlow,
        MonthlySeriesKind.validations => s.validations,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(monthlySeriesProvider);
    final data = async.maybeWhen(
      data: (s) {
        final serie = _select(s);
        return serie.isEmpty ? _zeros() : serie;
      },
      orElse: _zeros,
    );

    return MiniBarChart(title: title, barColor: barColor, data: data);
  }
}
