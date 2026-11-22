import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_skeleton.dart';
import 'package:intl/intl.dart';
import 'package:reserva_canchas/core/widgets/foody_estado_ui.dart';
import 'package:reserva_canchas/features/admin/data/dashboard_repository.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_chart_card.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_charts.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_tokens.dart';

/// Gráficos del dashboard — mismos cards/charts que Analítica.
class DashboardGraficosWidget extends StatefulWidget {
  const DashboardGraficosWidget({
    super.key,
    this.sucursalId,
    this.onIrReportes,
    this.onIrAnalitica,
  });

  final String? sucursalId;
  final VoidCallback? onIrReportes;
  final VoidCallback? onIrAnalitica;

  @override
  State<DashboardGraficosWidget> createState() =>
      _DashboardGraficosWidgetState();
}

class _DashboardGraficosWidgetState extends State<DashboardGraficosWidget> {
  ColorScheme get _scheme => Theme.of(context).colorScheme;

  final _repo = DashboardRepository();
  late Future<Map<String, dynamic>> _future;

  final _moneda = NumberFormat.currency(
    locale: 'es_CO',
    symbol: r'$',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _recargar();
  }

  @override
  void didUpdateWidget(DashboardGraficosWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sucursalId != widget.sucursalId) _recargar();
  }

  void _recargar() {
    setState(() {
      _future = _repo.graficos(sucursalId: widget.sucursalId);
    });
  }

  String _etiquetaTipo(String tipo) => switch (tipo) {
        'mesa' => 'Mesa',
        'domicilio' => 'Domicilio',
        'para_llevar' => 'Para llevar',
        'encargo' => 'Encargo',
        _ => tipo,
      };

  /// Adapta mix por canal al formato de pie/leyenda de Analítica.
  List<Map<String, dynamic>> _mixCanal(List<dynamic> porTipo) {
    final out = <Map<String, dynamic>>[];
    for (final raw in porTipo) {
      final m = Map<String, dynamic>.from(raw as Map);
      out.add({
        'metodo_pago': _etiquetaTipo('${m['tipo'] ?? ''}'),
        'total': m['pedidos'] ?? 0,
        'ventas': m['ventas'] ?? 0,
        'pedidos': m['pedidos'] ?? 0,
      });
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              Icons.show_chart,
              size: 16,
              color: _scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tendencia y mix',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.1,
                      color: _scheme.onSurface,
                    ),
                  ),
                  Text(
                    'Tendencia de la sede (7 días)',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: _scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (widget.onIrReportes != null)
              TextButton(
                onPressed: widget.onIrReportes,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: _scheme.onSurfaceVariant,
                ),
                child: const Text('Reportes'),
              ),
            if (widget.onIrAnalitica != null)
              TextButton(
                onPressed: widget.onIrAnalitica,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: _scheme.onSurfaceVariant,
                ),
                child: const Text('Análisis'),
              ),
            IconButton(
              tooltip: 'Actualizar',
              onPressed: _recargar,
              visualDensity: VisualDensity.compact,
              icon: Icon(
                Icons.refresh,
                size: 20,
                color: _scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return AnaliticaSkeleton.seccion(
                etiqueta: 'Cargando gráficos de la sede',
                altura: 180,
              );
            }
            if (snapshot.hasError) {
              return FoodyEstadoUi.desdeExcepcion(
                error: snapshot.error!,
                contexto: 'cargar gráficos',
                onReintentar: _recargar,
              );
            }
            final d = snapshot.data!;
            final porDia = d['ventas_7_dias'] as List<dynamic>? ?? [];
            final porTipo = d['pedidos_por_tipo_hoy'] as List<dynamic>? ?? [];
            final top = d['top_productos_7d'] as List<dynamic>? ?? [];
            final mix = _mixCanal(porTipo);

            return AnaliticaChartsGrid(
              columnsDesktop: 2,
              children: [
                AnaliticaChartCard(
                  titulo: 'Ventas — últimos 7 días',
                  subtitulo: 'Serie temporal',
                  icono: Icons.timeline,
                  vacio: porDia.isEmpty,
                  mensajeVacio: 'Sin ventas en la semana',
                  child: LineChart(AnaliticaCharts.lineaDia(porDia)),
                ),
                AnaliticaChartCard(
                  titulo: 'Pedidos hoy por canal',
                  subtitulo: 'Mix del día',
                  icono: Icons.pie_chart_outline,
                  vacio: mix.isEmpty,
                  mensajeVacio: 'Sin pedidos hoy',
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: PieChart(AnaliticaCharts.pieMetodo(mix)),
                      ),
                      Expanded(
                        flex: 3,
                        child: _leyendaCanal(mix),
                      ),
                    ],
                  ),
                ),
                AnaliticaChartCard(
                  titulo: 'Top productos — 7 días',
                  subtitulo: 'Por unidades',
                  icono: Icons.bar_chart,
                  vacio: top.isEmpty,
                  mensajeVacio: 'Sin productos vendidos',
                  altura: 200,
                  child: BarChart(
                    AnaliticaCharts.barrasHorizontales(
                      top,
                      valorKey: 'cantidad',
                      nombreKey: 'nombre',
                      color: AnaliticaTokens.chart,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _leyendaCanal(List<Map<String, dynamic>> mix) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < mix.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: AnaliticaCharts
                        .colores[i % AnaliticaCharts.colores.length],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${mix[i]['metodo_pago']}',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: _scheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${AnaliticaCharts.numOf(mix[i]['pedidos']).toInt()} · ${_moneda.format(mix[i]['ventas'])}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
