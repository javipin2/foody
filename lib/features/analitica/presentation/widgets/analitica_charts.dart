import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_tokens.dart';

/// Charts minimalistas — líneas/barras limpias, sin arcoíris.
class AnaliticaCharts {
  AnaliticaCharts._();

  static final _moneda = NumberFormat.compactCurrency(
    locale: 'es_CO',
    symbol: r'$',
    decimalDigits: 0,
  );

  /// Escala neutra para series categóricas (pie).
  static const colores = [
    Color(0xFF374151),
    Color(0xFF6B7280),
    Color(0xFF9CA3AF),
    Color(0xFFD1D5DB),
    Color(0xFF4B5563),
    Color(0xFF2563EB),
  ];

  static double numOf(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

  static BarChartData barrasHora(List<dynamic> porHora) {
    final spots = <BarChartGroupData>[];
    for (final raw in porHora) {
      final m = raw as Map<String, dynamic>;
      final h = numOf(m['hora']).toInt();
      spots.add(
        BarChartGroupData(
          x: h,
          barRods: [
            BarChartRodData(
              toY: numOf(m['ventas']),
              width: 7,
              color: AnaliticaTokens.chart,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
            ),
          ],
        ),
      );
    }
    return BarChartData(
      alignment: BarChartAlignment.spaceAround,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (_) => FlLine(
          color: AnaliticaTokens.borderSoft,
          strokeWidth: 1,
        ),
      ),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 20,
            getTitlesWidget: (v, _) {
              if (v % 3 != 0) return const SizedBox.shrink();
              return Text(
                '${v.toInt()}h',
                style: const TextStyle(
                  fontSize: 10,
                  color: AnaliticaTokens.inkSoft,
                ),
              );
            },
          ),
        ),
      ),
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipColor: (_) => AnaliticaTokens.ink,
          getTooltipItem: (group, _, rod, __) => BarTooltipItem(
            '${group.x}h · ${_moneda.format(rod.toY)}',
            const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
              fontSize: 11,
            ),
          ),
        ),
      ),
      barGroups: spots,
    );
  }

  static LineChartData lineaDia(List<dynamic> porDia) {
    final spots = <FlSpot>[];
    final labels = <int, String>{};
    for (var i = 0; i < porDia.length; i++) {
      final m = porDia[i] as Map<String, dynamic>;
      spots.add(FlSpot(i.toDouble(), numOf(m['ventas'])));
      final dia = '${m['dia'] ?? ''}';
      labels[i] = dia.length >= 10 ? dia.substring(5, 10) : dia;
    }
    final accent = AnaliticaTokens.ventas;
    // Si hay muchos días, mostrar puntos solo cada N; si pocos, todos.
    final mostrarTodos = spots.length <= 14;
    final stepPunto = spots.length <= 30 ? 1 : (spots.length / 10).ceil();

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: null,
        getDrawingHorizontalLine: (_) => FlLine(
          color: AnaliticaTokens.borderSoft,
          strokeWidth: 1,
        ),
      ),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            getTitlesWidget: (v, meta) {
              if (v == meta.max || v == meta.min) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  _moneda.format(v),
                  style: const TextStyle(
                    fontSize: 9,
                    color: AnaliticaTokens.inkSoft,
                  ),
                  textAlign: TextAlign.right,
                ),
              );
            },
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 22,
            interval: (porDia.length / 5).clamp(1, 10).toDouble(),
            getTitlesWidget: (v, _) {
              final i = v.toInt();
              final t = labels[i];
              if (t == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  t,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AnaliticaTokens.inkSoft,
                  ),
                ),
              );
            },
          ),
        ),
      ),
      lineTouchData: LineTouchData(
        handleBuiltInTouches: true,
        getTouchLineStart: (_, __) => 0,
        getTouchLineEnd: (_, __) => double.infinity,
        getTouchedSpotIndicator: (barData, spotIndexes) {
          return spotIndexes.map((i) {
            return TouchedSpotIndicatorData(
              FlLine(
                color: AnaliticaTokens.inkSoft.withValues(alpha: 0.45),
                strokeWidth: 1,
                dashArray: [4, 3],
              ),
              FlDotData(
                show: true,
                getDotPainter: (spot, percent, bar, index) =>
                    FlDotCirclePainter(
                  radius: 5,
                  color: accent,
                  strokeWidth: 2.5,
                  strokeColor: Colors.white,
                ),
              ),
            );
          }).toList();
        },
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => Colors.white,
          tooltipRoundedRadius: 8,
          tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          tooltipBorder: const BorderSide(color: AnaliticaTokens.border),
          getTooltipItems: (touched) => touched.map((s) {
            final i = s.x.toInt();
            final fecha = labels[i] ?? '';
            return LineTooltipItem(
              '${_moneda.format(s.y)}\n$fecha',
              const TextStyle(
                color: AnaliticaTokens.ink,
                fontWeight: FontWeight.w600,
                fontSize: 12,
                height: 1.35,
              ),
            );
          }).toList(),
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          curveSmoothness: 0.28,
          color: accent,
          barWidth: 2.2,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            checkToShowDot: (spot, _) {
              if (mostrarTodos) return true;
              return spot.x.toInt() % stepPunto == 0 ||
                  spot.x.toInt() == spots.length - 1;
            },
            getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
              radius: 3.5,
              color: accent,
              strokeWidth: 2,
              strokeColor: Colors.white,
            ),
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                accent.withValues(alpha: 0.75),
                accent.withValues(alpha: 0.45),
                accent.withValues(alpha: 0.28),
                accent.withValues(alpha: 0.08),
                accent.withValues(alpha: 0.0),
              ],
              stops: const [0.0, 0.25,0.5, 0.75, 1.0],
            ),
          ),
        ),
      ],
    );
  }

  static PieChartData pieMetodo(List<dynamic> porMetodo) {
    final sections = <PieChartSectionData>[];
    for (var i = 0; i < porMetodo.length; i++) {
      final m = porMetodo[i] as Map<String, dynamic>;
      sections.add(
        PieChartSectionData(
          value: numOf(m['total']),
          color: colores[i % colores.length],
          radius: 46,
          title: '',
          showTitle: false,
          borderSide: const BorderSide(color: Colors.white, width: 2),
        ),
      );
    }
    return PieChartData(
      sectionsSpace: 2,
      centerSpaceRadius: 38,
      sections: sections,
    );
  }

  static PieChartData donutNiveles(List<dynamic> niveles) {
    final sections = <PieChartSectionData>[];
    for (var i = 0; i < niveles.length; i++) {
      final m = niveles[i] as Map<String, dynamic>;
      final n = '${m['nivel']}'.toLowerCase();
      final color = switch (n) {
        'critico' || 'alto' => AnaliticaTokens.alertas,
        'medio' => AnaliticaTokens.chartMuted,
        _ => AnaliticaTokens.chart,
      };
      sections.add(
        PieChartSectionData(
          value: numOf(m['total']),
          color: color,
          radius: 44,
          title: '',
          showTitle: false,
          borderSide: const BorderSide(color: Colors.white, width: 2),
        ),
      );
    }
    return PieChartData(
      sectionsSpace: 2,
      centerSpaceRadius: 40,
      sections: sections.isEmpty
          ? [
              PieChartSectionData(
                value: 1,
                color: Colors.grey.shade200,
                radius: 44,
                showTitle: false,
              ),
            ]
          : sections,
    );
  }

  static BarChartData barrasHorizontales(
    List<dynamic> items, {
    required String valorKey,
    required String nombreKey,
    int maxItems = 6,
    Color? color,
  }) {
    final slice = items.take(maxItems).toList();
    final c = color ?? AnaliticaTokens.chart;
    final groups = <BarChartGroupData>[];
    for (var i = 0; i < slice.length; i++) {
      final m = slice[i] as Map<String, dynamic>;
      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: numOf(m[valorKey]),
              width: 12,
              color: c,
              borderRadius: BorderRadius.circular(3),
            ),
          ],
        ),
      );
    }
    return BarChartData(
      alignment: BarChartAlignment.spaceAround,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (_) => FlLine(
          color: AnaliticaTokens.borderSoft,
          strokeWidth: 1,
        ),
      ),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 44,
            getTitlesWidget: (v, _) {
              final i = v.toInt();
              if (i < 0 || i >= slice.length) return const SizedBox.shrink();
              final nombre =
                  '${(slice[i] as Map)[nombreKey] ?? ''}'.split(' ').first;
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  nombre,
                  style: const TextStyle(
                    fontSize: 9,
                    color: AnaliticaTokens.inkSoft,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            },
          ),
        ),
      ),
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipColor: (_) => AnaliticaTokens.ink,
          getTooltipItem: (group, _, rod, __) {
            final i = group.x.toInt();
            final nombre = i >= 0 && i < slice.length
                ? '${(slice[i] as Map)[nombreKey] ?? ''}'
                : '';
            return BarTooltipItem(
              '$nombre\n${_moneda.format(rod.toY)}',
              const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                fontSize: 11,
              ),
            );
          },
        ),
      ),
      barGroups: groups,
    );
  }

  static Widget leyendaPie(List<dynamic> items, String labelKey, String valueKey) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: colores[i % colores.length],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${(items[i] as Map)[labelKey] ?? '—'}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AnaliticaTokens.inkMuted,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  _moneda.format(numOf((items[i] as Map)[valueKey])),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AnaliticaTokens.ink,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Serie actual + referencia del periodo anterior (promedio diario del total ant.).
  static LineChartData lineaDiaVsAnterior(
    List<dynamic> porDia, {
    double? ventasAnteriorTotal,
  }) {
    final base = lineaDia(porDia);
    if (ventasAnteriorTotal == null || porDia.isEmpty) return base;

    final n = porDia.length;
    final avg = ventasAnteriorTotal / n;
    final refSpots = <FlSpot>[
      for (var i = 0; i < n; i++) FlSpot(i.toDouble(), avg),
    ];

    return LineChartData(
      gridData: base.gridData,
      borderData: base.borderData,
      titlesData: base.titlesData,
      lineTouchData: base.lineTouchData,
      minX: base.minX,
      maxX: base.maxX,
      minY: base.minY,
      maxY: base.maxY,
      lineBarsData: [
        ...base.lineBarsData,
        LineChartBarData(
          spots: refSpots,
          isCurved: false,
          color: AnaliticaTokens.chartMuted,
          barWidth: 1.5,
          dashArray: const [6, 4],
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
        ),
      ],
    );
  }
}
