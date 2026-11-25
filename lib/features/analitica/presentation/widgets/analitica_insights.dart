import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_charts.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_surface.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_tokens.dart';

/// Insight generado solo a partir de datos ya calculados por el API.
class AnaliticaInsight {
  const AnaliticaInsight({
    required this.texto,
    required this.icono,
    required this.color,
    this.tono = AnaliticaInsightTono.neutro,
  });

  final String texto;
  final IconData icono;
  final Color color;
  final AnaliticaInsightTono tono;
}

enum AnaliticaInsightTono { positivo, negativo, neutro, alerta }

/// Deriva tarjetas de insight desde mapas del backend (sin nuevas métricas).
class AnaliticaInsightsBuilder {
  AnaliticaInsightsBuilder._();

  static List<AnaliticaInsight> from({
    Map<String, dynamic>? resumen,
    Map<String, dynamic>? ventas,
    List<dynamic> topProductos = const [],
  }) {
    final out = <AnaliticaInsight>[];
    final kpis = resumen?['kpis'] as Map<String, dynamic>? ?? {};
    final comp = resumen?['comparativa'] as Map<String, dynamic>?;
    final delta = comp?['delta'] as Map<String, dynamic>?;
    final ventasPct = AnaliticaCharts.numOf(delta?['ventas_netas_pct']);
    final pedidosPct = AnaliticaCharts.numOf(delta?['pedidos_pct']);
    final tendencia = '${delta?['tendencia'] ?? ''}';

    if (delta != null) {
      if (ventasPct > 0) {
        out.add(
          AnaliticaInsight(
            texto:
                'Las ventas aumentaron un ${ventasPct.toStringAsFixed(1)}% respecto al periodo anterior.',
            icono: Icons.trending_up_rounded,
            color: AnaliticaTokens.margen,
            tono: AnaliticaInsightTono.positivo,
          ),
        );
      } else if (ventasPct < 0) {
        out.add(
          AnaliticaInsight(
            texto:
                'Las ventas están ${ventasPct.abs().toStringAsFixed(1)}% por debajo del periodo anterior.',
            icono: Icons.trending_down_rounded,
            color: AnaliticaTokens.cancelacion,
            tono: AnaliticaInsightTono.negativo,
          ),
        );
      }
      if (pedidosPct != 0) {
        out.add(
          AnaliticaInsight(
            texto: pedidosPct > 0
                ? 'Los pedidos crecieron ${pedidosPct.toStringAsFixed(1)}% ($tendencia).'
                : 'Los pedidos bajaron ${pedidosPct.abs().toStringAsFixed(1)}%.',
            icono: Icons.receipt_long_rounded,
            color: AnaliticaTokens.pedidos,
            tono: pedidosPct > 0
                ? AnaliticaInsightTono.positivo
                : AnaliticaInsightTono.negativo,
          ),
        );
      }
    }

    final cancel = AnaliticaCharts.numOf(kpis['pct_cancelacion']);
    if (cancel > 0) {
      out.add(
        AnaliticaInsight(
          texto: cancel >= 8
              ? 'La cancelación está en ${cancel.toStringAsFixed(1)}% — revisa el tab Riesgo.'
              : 'Cancelación del periodo: ${cancel.toStringAsFixed(1)}%.',
          icono: Icons.cancel_outlined,
          color: AnaliticaTokens.cancelacion,
          tono: cancel >= 8
              ? AnaliticaInsightTono.alerta
              : AnaliticaInsightTono.neutro,
        ),
      );
    }

    final alertas = AnaliticaCharts.numOf(kpis['alertas_abiertas']).toInt();
    if (alertas > 0) {
      out.add(
        AnaliticaInsight(
          texto: alertas == 1
              ? 'Hay 1 alerta abierta que requiere atención.'
              : 'Hay $alertas alertas abiertas en la operación.',
          icono: Icons.auto_awesome_rounded,
          color: AnaliticaTokens.alertas,
          tono: AnaliticaInsightTono.alerta,
        ),
      );
    }

    final ticket = AnaliticaCharts.numOf(kpis['ticket_promedio']);
    if (ticket > 0) {
      out.add(
        AnaliticaInsight(
          texto:
              'El ticket promedio del periodo es \$${ticket.toStringAsFixed(0)}.',
          icono: Icons.shopping_bag_outlined,
          color: AnaliticaTokens.ticket,
        ),
      );
    }

    final porTipo = ventas?['por_tipo'] as List<dynamic>? ?? [];
    if (porTipo.isNotEmpty) {
      var totalPedidos = 0.0;
      Map<String, dynamic>? top;
      for (final raw in porTipo) {
        final m = raw as Map<String, dynamic>;
        final p = AnaliticaCharts.numOf(m['pedidos']);
        totalPedidos += p;
        if (top == null || p > AnaliticaCharts.numOf(top['pedidos'])) top = m;
      }
      if (top != null && totalPedidos > 0) {
        final pct =
            (AnaliticaCharts.numOf(top['pedidos']) / totalPedidos * 100);
        final tipo = '${top['tipo']}'.replaceAll('_', ' ');
        out.add(
          AnaliticaInsight(
            texto:
                'Hoy el canal «$tipo» concentra el ${pct.toStringAsFixed(0)}% de los pedidos.',
            icono: Icons.hub_outlined,
            color: AnaliticaTokens.domicilio,
          ),
        );
      }
    }

    final porMetodo = ventas?['por_metodo'] as List<dynamic>? ?? [];
    if (porMetodo.isNotEmpty) {
      var total = 0.0;
      Map<String, dynamic>? top;
      for (final raw in porMetodo) {
        final m = raw as Map<String, dynamic>;
        final t = AnaliticaCharts.numOf(m['total']);
        total += t;
        if (top == null || t > AnaliticaCharts.numOf(top['total'])) top = m;
      }
      if (top != null && total > 0) {
        final pct = AnaliticaCharts.numOf(top['total']) / total * 100;
        out.add(
          AnaliticaInsight(
            texto:
                'El método de pago dominante es «${top['metodo_pago']}» (${pct.toStringAsFixed(0)}%).',
            icono: Icons.payments_outlined,
            color: AnaliticaTokens.pago,
          ),
        );
      }
    }

    final porCat = ventas?['por_categoria'] as List<dynamic>? ?? [];
    if (porCat.isNotEmpty) {
      var total = 0.0;
      Map<String, dynamic>? top;
      for (final raw in porCat) {
        final m = raw as Map<String, dynamic>;
        final v = AnaliticaCharts.numOf(m['ventas']);
        total += v;
        if (top == null || v > AnaliticaCharts.numOf(top['ventas'])) top = m;
      }
      if (top != null && total > 0) {
        final pct = AnaliticaCharts.numOf(top['ventas']) / total * 100;
        out.add(
          AnaliticaInsight(
            texto:
                '«${top['nombre']}» lidera categorías con el ${pct.toStringAsFixed(0)}% de ventas.',
            icono: Icons.category_outlined,
            color: AnaliticaTokens.inventario,
          ),
        );
      }
    }

    if (topProductos.isNotEmpty) {
      final p = topProductos.first as Map<String, dynamic>;
      final nombre = p['nombre'] as String? ?? 'Producto';
      final cant = AnaliticaCharts.numOf(p['cantidad']).toInt();
      out.add(
        AnaliticaInsight(
          texto: 'Producto estrella: $nombre ($cant u. en el periodo).',
          icono: Icons.star_rounded,
          color: AnaliticaTokens.alertas,
          tono: AnaliticaInsightTono.positivo,
        ),
      );
    }

    final porHora = ventas?['por_hora'] as List<dynamic>? ?? [];
    if (porHora.isNotEmpty) {
      Map<String, dynamic>? pico;
      for (final raw in porHora) {
        final m = raw as Map<String, dynamic>;
        if (pico == null ||
            AnaliticaCharts.numOf(m['ventas']) >
                AnaliticaCharts.numOf(pico['ventas'])) {
          pico = m;
        }
      }
      if (pico != null) {
        final h = AnaliticaCharts.numOf(pico['hora']).toInt();
        out.add(
          AnaliticaInsight(
            texto: 'Hora pico de ventas: ${h.toString().padLeft(2, '0')}:00.',
            icono: Icons.schedule_rounded,
            color: AnaliticaTokens.cocina,
          ),
        );
      }
    }

    final margen = AnaliticaCharts.numOf(kpis['margen_bruto_pct']);
    if (margen > 0) {
      out.add(
        AnaliticaInsight(
          texto:
              'Margen bruto estimado en ${margen.toStringAsFixed(1)}% sobre el periodo.',
          icono: Icons.insights_rounded,
          color: AnaliticaTokens.margen,
        ),
      );
    }

    return out.take(8).toList();
  }
}

class AnaliticaInsightsStrip extends StatelessWidget {
  const AnaliticaInsightsStrip({super.key, required this.insights});

  final List<AnaliticaInsight> insights;

  @override
  Widget build(BuildContext context) {
    if (insights.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Insights',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AnaliticaTokens.inkOf(context),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Lecturas a partir de KPIs del periodo',
          style: TextStyle(
            fontSize: 12,
            color: AnaliticaTokens.inkSoftOf(context),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: insights.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final insight = insights[i];
              return SizedBox(
                width: 260,
                child: AnaliticaSurface(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            insight.icono,
                            size: 14,
                            color: insight.color,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Insight',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                              color: AnaliticaTokens.inkSoftOf(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: Text(
                          insight.texto,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.35,
                            fontWeight: FontWeight.w500,
                            color: AnaliticaTokens.inkOf(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate(delay: (40 * i).ms).fadeIn(duration: 220.ms),
              );
            },
          ),
        ),
      ],
    );
  }
}
