import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_charts.dart';

/// Mini serie para KPI cards.
class AnaliticaSparkline extends StatelessWidget {
  const AnaliticaSparkline({
    super.key,
    required this.valores,
    required this.color,
    this.height = 36,
  });

  final List<double> valores;
  final Color color;
  final double height;

  factory AnaliticaSparkline.fromSeries(
    List<dynamic> serie, {
    required Color color,
    String valorKey = 'ventas',
    double height = 36,
  }) {
    final vals = serie
        .map((e) => AnaliticaCharts.numOf((e as Map)[valorKey]))
        .toList();
    return AnaliticaSparkline(valores: vals, color: color, height: height);
  }

  @override
  Widget build(BuildContext context) {
    if (valores.length < 2) {
      return SizedBox(height: height);
    }
    final spots = <FlSpot>[
      for (var i = 0; i < valores.length; i++) FlSpot(i.toDouble(), valores[i]),
    ];
    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (valores.length - 1).toDouble(),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: const FlTitlesData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: color,
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    color.withValues(alpha: 0.12),
                    color.withValues(alpha: 0.01),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
