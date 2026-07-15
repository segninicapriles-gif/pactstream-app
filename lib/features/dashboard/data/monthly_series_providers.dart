import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/datasources/supabase/supabase_client.dart';
import '../presentation/widgets/mini_bar_chart.dart';

/// Series mensuales (últimos 6 meses) para los charts de la home,
/// cargadas de `sf_get_monthly_series()` (migración 20260715000002):
///   billing     · céntimos cobrados/mes  (rol constructor)
///   fundFlow    · céntimos pagados/mes   (rol promotor)
///   validations · nº de validaciones/mes (técnico)
class MonthlySeries {
  const MonthlySeries({
    required this.billing,
    required this.fundFlow,
    required this.validations,
  });

  final List<BarChartItem> billing;
  final List<BarChartItem> fundFlow;
  final List<BarChartItem> validations;

  static const _monthNames = [
    'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
    'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
  ];

  /// `[{month: '2026-02', value: 1234500}, ...]` → barras del chart.
  /// [cents] true divide entre 100 (los importes llegan en céntimos).
  static List<BarChartItem> _parse(dynamic list, {required bool cents}) {
    if (list is! List) return const [];
    return list.map((e) {
      final m = e as Map<String, dynamic>;
      final month = (m['month'] as String?) ?? '';
      final parts = month.split('-');
      final label = parts.length == 2
          ? _monthNames[(int.tryParse(parts[1]) ?? 1) - 1]
          : month;
      final raw = (m['value'] as num?)?.toDouble() ?? 0;
      return BarChartItem(label: label, value: cents ? raw / 100 : raw);
    }).toList();
  }

  factory MonthlySeries.fromJson(Map<String, dynamic> json) => MonthlySeries(
        billing: _parse(json['billing'], cents: true),
        fundFlow: _parse(json['fund_flow'], cents: true),
        validations: _parse(json['validations'], cents: false),
      );
}

/// Si la RPC aún no está desplegada (o falla), devolvemos series vacías:
/// MiniBarChart muestra su empty state honesto en vez de romper la home.
final monthlySeriesProvider =
    FutureProvider.autoDispose<MonthlySeries>((ref) async {
  try {
    final json = await SupabaseConfig.client.rpc('sf_get_monthly_series')
        as Map<String, dynamic>?;
    if (json == null) {
      return const MonthlySeries(billing: [], fundFlow: [], validations: []);
    }
    return MonthlySeries.fromJson(json);
  } on Exception {
    return const MonthlySeries(billing: [], fundFlow: [], validations: []);
  }
});
