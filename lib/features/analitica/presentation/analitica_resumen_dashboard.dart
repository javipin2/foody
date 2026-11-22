import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:reserva_canchas/core/saas_ui/saas_ui.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_charts.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_heatmap.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_insights.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_pedidos_tabla.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_tokens.dart';

/// Dashboard Resumen — layout premium 9 filas (solo UI).
class AnaliticaResumenDashboard extends StatefulWidget {
  const AnaliticaResumenDashboard({
    super.key,
    required this.resumen,
    required this.ventas,
    required this.topProductos,
    required this.pedidosRecientes,
    this.productosMenosVendidos = const [],
    this.cocinas,
    this.bannerComparativa,
    this.onIrVentas,
    this.onIrRiesgo,
    this.onIrCaja,
    this.onIrPedidos,
    this.onIrCocinas,
  });

  final Map<String, dynamic>? resumen;
  final Map<String, dynamic>? ventas;
  final List<dynamic> topProductos;
  final List<dynamic> pedidosRecientes;
  final List<dynamic> productosMenosVendidos;
  final Map<String, dynamic>? cocinas;
  final Widget? bannerComparativa;
  final VoidCallback? onIrVentas;
  final VoidCallback? onIrRiesgo;
  final VoidCallback? onIrCaja;
  final VoidCallback? onIrPedidos;
  final VoidCallback? onIrCocinas;

  @override
  State<AnaliticaResumenDashboard> createState() =>
      _AnaliticaResumenDashboardState();
}

class _AnaliticaResumenDashboardState extends State<AnaliticaResumenDashboard> {
  /// horas | dias | semanas | meses
  String _granularidad = 'dias';

  static final _moneda = NumberFormat.currency(
    locale: 'es_CO',
    symbol: r'$',
    decimalDigits: 0,
  );

  double _num(dynamic v) => AnaliticaCharts.numOf(v);

  List<double> _spark(List<dynamic> serie, String key) =>
      serie.map((e) => _num((e as Map)[key])).toList();

  @override
  Widget build(BuildContext context) {
    final resumen = widget.resumen;
    final ventas = widget.ventas;
    final kpis = resumen?['kpis'] as Map<String, dynamic>? ?? {};
    final periodo = resumen?['periodo'] as Map<String, dynamic>?;
    final label = periodo?['label'] as String? ?? 'Periodo';
    final comparativa = resumen?['comparativa'] as Map<String, dynamic>?;
    final delta = comparativa?['delta'] as Map<String, dynamic>?;
    final ant = comparativa?['anterior'] as Map<String, dynamic>?;
    final tieneDelta = comparativa != null;

    final porHora = ventas?['por_hora'] as List<dynamic>? ?? [];
    final porDia = ventas?['por_dia'] as List<dynamic>? ?? [];
    final porMetodo = ventas?['por_metodo'] as List<dynamic>? ?? [];
    final porTipo = ventas?['por_tipo'] as List<dynamic>? ?? [];
    final porCategoria = ventas?['por_categoria'] as List<dynamic>? ?? [];
    final alertas = resumen?['alertas_abiertas_lista'] as List<dynamic>? ?? [];
    final spark = _spark(porDia.isNotEmpty ? porDia : porHora, 'ventas');
    final sparkPedidos = _spark(
      porDia.isNotEmpty ? porDia : porHora,
      porDia.isNotEmpty ? 'pedidos' : 'pedidos',
    );

    final insights = AnaliticaInsightsBuilder.from(
      resumen: resumen,
      ventas: ventas,
      topProductos: widget.topProductos,
    );

    final listaCocinas = widget.cocinas?['cocinas'] as List<dynamic>? ?? [];
    final ventasAnt = ant == null ? null : _num(ant['ventas_netas']);

    return ColoredBox(
      color: SaaSTokens.canvas(context),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          if (widget.bannerComparativa != null) ...[
            widget.bannerComparativa!,
            const SizedBox(height: 12),
          ],

          // ——— Fila 1: KPIs ———
          SaaSSectionHeader(
            titulo: 'Indicadores clave',
            subtitulo: label,
            icono: Icons.insights_outlined,
          ),
          SaaSKpiGrid(
            children: [
              SaaSKpiCard(
                etiqueta: 'Ventas netas',
                valor: _moneda.format(_num(kpis['ventas_netas'])),
                deltaPct: tieneDelta ? _num(delta?['ventas_netas_pct']) : null,
                icono: Icons.payments_outlined,
                acento: SaaSTokens.ventas,
                sparkline: spark,
                tooltip: 'Ir a Ventas',
                onTap: widget.onIrVentas,
              ),
              SaaSKpiCard(
                etiqueta: 'Pedidos',
                valor: '${kpis['pedidos'] ?? 0}',
                deltaPct: delta?['pedidos_pct'] != null
                    ? _num(delta?['pedidos_pct'])
                    : null,
                icono: Icons.receipt_long_outlined,
                acento: SaaSTokens.pedidos,
                sparkline: sparkPedidos.length >= 2 ? sparkPedidos : spark,
                onTap: widget.onIrVentas,
              ),
              SaaSKpiCard(
                etiqueta: 'Ticket promedio',
                valor: _moneda.format(_num(kpis['ticket_promedio'])),
                deltaPct: tieneDelta && delta?['ticket_promedio_pct'] != null
                    ? _num(delta?['ticket_promedio_pct'])
                    : null,
                icono: Icons.shopping_bag_outlined,
                acento: SaaSTokens.clientes,
                sparkline: spark,
              ),
              SaaSKpiCard(
                etiqueta: 'Margen bruto',
                valor: '${_num(kpis['margen_bruto_pct']).toStringAsFixed(1)}%',
                subtitulo: _moneda.format(_num(kpis['margen_bruto_estimado'])),
                deltaPct: tieneDelta && delta?['margen_bruto_pct'] != null
                    ? _num(delta?['margen_bruto_pct'])
                    : null,
                icono: Icons.trending_up,
                acento: SaaSTokens.inventario,
                sparkline: spark,
              ),
              SaaSKpiCard(
                etiqueta: 'Cancelaciones',
                valor: '${_num(kpis['pct_cancelacion']).toStringAsFixed(1)}%',
                deltaPct: tieneDelta && delta?['pct_cancelacion_pct'] != null
                    ? _num(delta?['pct_cancelacion_pct'])
                    : null,
                invertirDelta: true,
                icono: Icons.cancel_outlined,
                acento: SaaSTokens.alertas,
                onTap: widget.onIrRiesgo,
                sparkline: spark,
              ),
              SaaSKpiCard(
                etiqueta: 'Alertas',
                valor: '${kpis['alertas_abiertas'] ?? 0}',
                icono: Icons.warning_amber_outlined,
                acento: SaaSTokens.alertas,
                onTap: widget.onIrRiesgo,
                subtitulo: 'Abiertas ahora',
              ),
              SaaSKpiCard(
                etiqueta: 'Pedidos activos',
                valor: '${widget.pedidosRecientes.length}',
                icono: Icons.bolt_outlined,
                acento: SaaSTokens.pedidos,
                onTap: widget.onIrPedidos,
                subtitulo: 'En lista reciente',
              ),
              SaaSKpiCard(
                etiqueta: 'Ganancia est.',
                valor: _moneda.format(_num(kpis['margen_bruto_estimado'])),
                deltaPct: tieneDelta ? _num(delta?['ventas_netas_pct']) : null,
                icono: Icons.account_balance_wallet_outlined,
                acento: SaaSTokens.inventario,
                sparkline: spark,
              ),
            ],
          ),

          // ——— Fila 2: gráfico principal ———
          const SizedBox(height: 8),
          SaaSSectionHeader(
            titulo: 'Ventas vs periodo anterior',
            subtitulo: 'Tendencia principal',
            icono: Icons.show_chart,
            trailing: _granularidadChips(context),
          ),
          SaaSChartCard(
            titulo: _granularidad == 'horas'
                ? 'Ventas por hora'
                : 'Tendencia de ventas',
            subtitulo: ventasAnt != null
                ? 'Línea punteada = promedio diario periodo anterior'
                : 'Serie del periodo seleccionado',
            icono: Icons.timeline,
            altura: 320,
            vacio: _granularidad == 'horas' ? porHora.isEmpty : porDia.isEmpty,
            trailing: TextButton(
              onPressed: widget.onIrVentas,
              child: const Text('Detalle'),
            ),
            child: _granularidad == 'horas'
                ? BarChart(AnaliticaCharts.barrasHora(porHora))
                : LineChart(
                    AnaliticaCharts.lineaDiaVsAnterior(
                      porDia,
                      ventasAnteriorTotal: ventasAnt,
                    ),
                  ),
          ),

          // ——— Fila 3: 4 tarjetas ———
          const SizedBox(height: 8),
          SaaSSectionHeader(
            titulo: 'Distribución operativa',
            icono: Icons.grid_view_outlined,
          ),
          SaaSChartsGrid(
            columnsDesktop: 2,
            children: [
              SaaSChartCard(
                titulo: 'Ventas por hora',
                icono: Icons.schedule_outlined,
                altura: 220,
                vacio: porHora.isEmpty,
                child: BarChart(AnaliticaCharts.barrasHora(porHora)),
              ),
              SaaSChartCard(
                titulo: 'Heatmap horario',
                subtitulo: 'Intensidad de ventas',
                icono: Icons.grid_on_outlined,
                altura: 220,
                vacio: porHora.isEmpty,
                child: AnaliticaHeatmapHoras(porHora: porHora),
              ),
              SaaSChartCard(
                titulo: 'Top productos',
                icono: Icons.star_outline,
                altura: 220,
                vacio: widget.topProductos.isEmpty,
                child: BarChart(
                  AnaliticaCharts.barrasHorizontales(
                    widget.topProductos,
                    valorKey: 'cantidad',
                    nombreKey: 'nombre',
                    color: AnaliticaTokens.chart,
                  ),
                ),
              ),
              SaaSChartCard(
                titulo: 'Categorías',
                icono: Icons.category_outlined,
                altura: 220,
                vacio: porCategoria.isEmpty,
                child: BarChart(
                  AnaliticaCharts.barrasHorizontales(
                    porCategoria,
                    valorKey: 'ventas',
                    nombreKey: 'nombre',
                    color: AnaliticaTokens.chart,
                  ),
                ),
              ),
            ],
          ),

          // ——— Fila 4 ———
          const SizedBox(height: 8),
          SaaSSectionHeader(
            titulo: 'Mix y ranking',
            icono: Icons.pie_chart_outline,
          ),
          SaaSChartsGrid(
            columnsDesktop: 2,
            children: [
              SaaSChartCard(
                titulo: 'Métodos de pago',
                icono: Icons.credit_card_outlined,
                altura: 220,
                vacio: porMetodo.isEmpty,
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: PieChart(AnaliticaCharts.pieMetodo(porMetodo)),
                    ),
                    Expanded(
                      flex: 3,
                      child: AnaliticaCharts.leyendaPie(
                        porMetodo,
                        'metodo_pago',
                        'total',
                      ),
                    ),
                  ],
                ),
              ),
              SaaSChartCard(
                titulo: 'Canales',
                icono: Icons.hub_outlined,
                altura: 220,
                vacio: porTipo.isEmpty,
                child: BarChart(
                  AnaliticaCharts.barrasHorizontales(
                    porTipo
                        .map(
                          (e) => {
                            'nombre':
                                '${(e as Map)['tipo']}'.replaceAll('_', ' '),
                            'ventas': e['ventas'],
                          },
                        )
                        .toList(),
                    valorKey: 'ventas',
                    nombreKey: 'nombre',
                    color: AnaliticaTokens.chart,
                  ),
                ),
              ),
              SaaSChartCard(
                titulo: 'Más vendidos',
                icono: Icons.emoji_events_outlined,
                altura: 220,
                vacio: widget.topProductos.isEmpty,
                child: _rankingLista(context, widget.topProductos, 'cantidad'),
              ),
              SaaSChartCard(
                titulo: 'Menos vendidos',
                icono: Icons.trending_down,
                altura: 220,
                vacio: widget.productosMenosVendidos.isEmpty,
                mensajeVacio: 'Sin ranking inferior en este periodo',
                child: _rankingLista(
                  context,
                  widget.productosMenosVendidos,
                  'cantidad',
                ),
              ),
            ],
          ),

          // ——— Fila 5: Meseros + Cocina ———
          const SizedBox(height: 8),
          SaaSSectionHeader(
            titulo: 'Equipo y cocina',
            icono: Icons.groups_outlined,
          ),
          LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth >= 900;
              final meseros = SaaSEmptyState(
                compacto: true,
                titulo: 'Ranking de meseros',
                descripcion:
                    'Usa el filtro avanzado «Mesero» para acotar. El ranking detallado estará disponible cuando el API lo exponga.',
                icono: Icons.person_outline,
              );
              final cocina = listaCocinas.isEmpty
                  ? SaaSEmptyState(
                      compacto: true,
                      titulo: 'Sin datos de cocina',
                      descripcion: 'No hay métricas de preparación en este periodo.',
                      icono: Icons.soup_kitchen_outlined,
                    )
                  : _cocinaCards(context, listaCocinas);
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: meseros),
                    const SizedBox(width: 10),
                    Expanded(child: cocina),
                  ],
                );
              }
              return Column(
                children: [
                  meseros,
                  const SizedBox(height: 10),
                  cocina,
                ],
              );
            },
          ),

          // ——— Fila 6: Clientes ———
          const SizedBox(height: 8),
          SaaSSectionHeader(
            titulo: 'Clientes',
            icono: Icons.people_outline,
          ),
          SaaSEmptyState(
            compacto: true,
            titulo: 'Segmentación de clientes',
            descripcion:
                'Filtra por segmento en Filtros avanzados. KPIs de nuevos/recurrentes/retención se mostrarán cuando el backend los entregue.',
            icono: Icons.person_add_alt_1_outlined,
          ),

          // ——— Fila 7: Actividad ———
          const SizedBox(height: 8),
          SaaSSectionHeader(
            titulo: 'Actividad reciente',
            subtitulo: 'Últimos pedidos del periodo',
            icono: Icons.table_rows_outlined,
          ),
          AnaliticaPedidosTabla(
            pedidos: widget.pedidosRecientes,
            onVerMas: widget.onIrPedidos,
          ),

          // ——— Fila 8: Alertas ———
          const SizedBox(height: 8),
          SaaSSectionHeader(
            titulo: 'Alertas inteligentes',
            icono: Icons.notification_important_outlined,
            trailing: TextButton(
              onPressed: widget.onIrRiesgo,
              child: const Text('Riesgo'),
            ),
          ),
          if (alertas.isEmpty)
            const SaaSEmptyState(
              compacto: true,
              titulo: 'Sin alertas abiertas',
              descripcion: 'Todo en orden en este periodo.',
              icono: Icons.check_circle_outline,
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final raw in alertas.take(6))
                  SizedBox(
                    width: 360,
                    child: SaaSPriorityAlert(
                      titulo: (raw as Map)['descripcion'] as String? ??
                          raw['tipo'] as String? ??
                          'Alerta',
                      detalle: raw['nivel'] as String?,
                      prioridad: _mapPrioridad(raw['nivel'] as String?),
                      onTap: widget.onIrRiesgo,
                    ),
                  ),
              ],
            ),

          // ——— Fila 9: Insights ———
          const SizedBox(height: 8),
          SaaSSectionHeader(
            titulo: 'Insights automáticos',
            icono: Icons.auto_awesome_outlined,
          ),
          if (insights.isEmpty)
            const SaaSEmptyState(
              compacto: true,
              titulo: 'Sin insights aún',
              descripcion: 'Activa «Comparar» o amplía el periodo.',
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final i in insights.take(8))
                  SizedBox(
                    width: 340,
                    child: SaaSInsightCard(texto: i.texto, icono: i.icono),
                  ),
              ],
            ),

          if (widget.onIrCaja != null) ...[
            const SizedBox(height: 16),
            SaaSSurface(
              onTap: widget.onIrCaja,
              child: Row(
                children: [
                  Icon(
                    Icons.point_of_sale_outlined,
                    size: 18,
                    color: SaaSTokens.inkMuted(context),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cuadre de caja',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13.5,
                            color: SaaSTokens.ink(context),
                          ),
                        ),
                        Text(
                          'Diferencias, gastos y CxC',
                          style: TextStyle(
                            fontSize: 12,
                            color: SaaSTokens.inkSoft(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward,
                    size: 16,
                    color: SaaSTokens.inkSoft(context),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _granularidadChips(BuildContext context) {
    Widget chip(String id, String label) {
      final sel = _granularidad == id;
      return Padding(
        padding: const EdgeInsets.only(left: 4),
        child: SaaSActionChip(
          label: label,
          selected: sel,
          onTap: () => setState(() => _granularidad = id),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        chip('horas', 'Horas'),
        chip('dias', 'Días'),
        // Semanas/meses: misma serie diaria (agrupación visual futura).
        chip('semanas', 'Semanas'),
        chip('meses', 'Meses'),
      ],
    );
  }

  Widget _rankingLista(
    BuildContext context,
    List<dynamic> items,
    String valorKey,
  ) {
    return ListView.separated(
      itemCount: items.take(6).length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        color: SaaSTokens.borderSoft(context),
      ),
      itemBuilder: (context, i) {
        final m = items[i] as Map;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Text(
                '${i + 1}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: SaaSTokens.inkSoft(context),
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${m['nombre'] ?? '—'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: SaaSTokens.ink(context),
                  ),
                ),
              ),
              Text(
                '${m[valorKey] ?? 0}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: SaaSTokens.ink(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _cocinaCards(BuildContext context, List<dynamic> lista) {
    return Column(
      children: [
        for (final raw in lista.take(4))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SaaSSurface(
              onTap: widget.onIrCocinas,
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${(raw as Map)['nombre'] ?? 'Cocina'}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: SaaSTokens.ink(context),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Prep. ${_num(raw['tiempo_promedio_min'] ?? raw['minutos_promedio']).toStringAsFixed(0)} min · '
                          '${raw['unidades'] ?? raw['pedidos'] ?? 0} uds',
                          style: TextStyle(
                            fontSize: 12,
                            color: SaaSTokens.inkMuted(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _moneda.format(_num(raw['ingresos'] ?? raw['ventas'])),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: SaaSTokens.ink(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  String _mapPrioridad(String? nivel) {
    final n = (nivel ?? '').toLowerCase();
    if (n.contains('crit') || n.contains('alto')) return 'alta';
    if (n.contains('bajo') || n.contains('info')) return 'baja';
    return 'media';
  }
}
