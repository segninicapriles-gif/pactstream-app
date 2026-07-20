import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// Datos para una barra del gráfico.
class BarChartItem {
  const BarChartItem({required this.label, required this.value});

  /// Etiqueta del eje X (ej. "Ene", "Feb").
  final String label;

  /// Valor en euros (entero — se formatea como "12.4k€" cuando >999).
  final double value;
}

/// Mini gráfico de barras reutilizable para los dashboards.
///
/// Usado en:
///   - Constructor → "Facturación mensual"
///   - Promotor  → "Flujo de fondos"
class MiniBarChart extends StatelessWidget {
  const MiniBarChart({
    super.key,
    required this.title,
    required this.data,
    this.barColor,
    this.maxY,
    this.height = 180,
  });

  final String title;
  final List<BarChartItem> data;
  final Color? barColor;
  final double? maxY;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();

    final color = barColor ?? AppColors.psBlue;
    final allZero = data.every((e) => e.value == 0);

    // Si todos los valores son 0, mostrar empty state en vez de chart vacío
    if (allZero) {
      final c = context.colors;
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: AppRadius.lgAll,
          boxShadow: AppShadows.soft,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTypography.body.copyWith(fontWeight: FontWeight.w700, color: c.textPrimary),
            ),
            SizedBox(height: height * 0.3),
            Center(
              child: Column(
                children: [
                  Icon(Icons.bar_chart_rounded,
                      color: c.textHint, size: 40),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Aún no hay datos',
                    style: AppTypography.bodyS.copyWith(
                      color: c.textHint,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'El gráfico se llenará con la actividad de tus obras',
                    style: AppTypography.caption.copyWith(
                      color: c.textHint,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: height * 0.3),
          ],
        ),
      );
    }

    final computedMaxY =
        maxY ?? (data.map((e) => e.value).reduce((a, b) => a > b ? a : b) * 1.3);

    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: AppRadius.lgAll,
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.body.copyWith(fontWeight: FontWeight.w700, color: c.textPrimary),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: height,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: computedMaxY,
                minY: 0,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) =>
                        AppColors.psNavy.withValues(alpha: 0.9),
                    tooltipRoundedRadius: 6,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final item = data[group.x.toInt()];
                      return BarTooltipItem(
                        _formatValue(item.value),
                        AppTypography.bodyS.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const SizedBox.shrink();
                        return Text(
                          _formatValueShort(value),
                          style: AppTypography.caption.copyWith(
                            color: c.textTertiary,
                            fontSize: 9,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= data.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            data[idx].label,
                            style: AppTypography.caption.copyWith(
                              color: c.textTertiary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: computedMaxY / 4,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: c.border,
                    strokeWidth: 0.5,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: data.asMap().entries.map((entry) {
                  final i = entry.key;
                  final item = entry.value;
                  final isLast = i == data.length - 1;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: item.value,
                        color: isLast ? color : color.withValues(alpha: 0.5),
                        width: 20,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
            ),
          ),
        ],
      ),
    );
  }

  static String _formatValue(double value) {
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}k €';
    }
    return '${value.toStringAsFixed(0)} €';
  }

  static String _formatValueShort(double value) {
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}k';
    }
    return value.toStringAsFixed(0);
  }
}
