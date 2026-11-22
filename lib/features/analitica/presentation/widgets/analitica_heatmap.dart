import 'package:flutter/material.dart';
import 'package:reserva_canchas/core/saas_ui/saas_tokens.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_charts.dart';

/// Heatmap de intensidad por hora (datos reales de `por_hora`).
class AnaliticaHeatmapHoras extends StatelessWidget {
  const AnaliticaHeatmapHoras({super.key, required this.porHora});

  final List<dynamic> porHora;

  @override
  Widget build(BuildContext context) {
    if (porHora.isEmpty) {
      return Center(
        child: Text(
          'Sin datos horarios',
          style: TextStyle(color: SaaSTokens.inkSoft(context), fontSize: 13),
        ),
      );
    }

    final byHour = <int, double>{};
    var maxV = 0.0;
    for (final raw in porHora) {
      final m = raw as Map;
      final h = AnaliticaCharts.numOf(m['hora']).toInt();
      final v = AnaliticaCharts.numOf(m['ventas']);
      byHour[h] = v;
      if (v > maxV) maxV = v;
    }

    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var h = 0; h < 24; h++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Tooltip(
                      message:
                          '$h:00 · \$${AnaliticaCharts.numOf(byHour[h] ?? 0).toStringAsFixed(0)}',
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          color: SaaSTokens.ventas.withValues(
                            alpha: maxV <= 0
                                ? 0.04
                                : (0.08 + 0.72 * ((byHour[h] ?? 0) / maxV))
                                    .clamp(0.08, 0.85),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('0h', style: _cap(context)),
            Text('6h', style: _cap(context)),
            Text('12h', style: _cap(context)),
            Text('18h', style: _cap(context)),
            Text('23h', style: _cap(context)),
          ],
        ),
      ],
    );
  }

  TextStyle _cap(BuildContext context) => TextStyle(
        fontSize: 10,
        color: SaaSTokens.inkSoft(context),
      );
}
