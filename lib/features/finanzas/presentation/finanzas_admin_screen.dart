import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:reserva_canchas/core/widgets/foody_dialogo.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';
import 'package:reserva_canchas/core/red/mostrar_error_snackbar.dart';
import 'package:reserva_canchas/core/saas_ui/saas_ui.dart';
import 'package:reserva_canchas/features/analitica/data/analitica_repository.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_charts.dart';
import 'package:reserva_canchas/features/finanzas/data/finanzas_repository.dart';

const _categorias = [
  'arriendo',
  'servicios',
  'nomina',
  'publicidad',
  'mercado',
  'operativo',
  'otros',
];

const _frecuencias = ['diario', 'semanal', 'quincenal', 'mensual'];

/// Hub financiero premium. Solo UI; cálculos en API.
class FinanzasAdminScreen extends StatefulWidget {
  const FinanzasAdminScreen({
    super.key,
    this.sucursalId,
    this.onVerRentabilidad,
  });

  final String? sucursalId;
  final VoidCallback? onVerRentabilidad;

  @override
  State<FinanzasAdminScreen> createState() => _FinanzasAdminScreenState();
}

class _FinanzasAdminScreenState extends State<FinanzasAdminScreen> {
  final _repo = FinanzasRepository();
  final _analitica = AnaliticaRepository();

  List<Map<String, dynamic>> _fijos = [];
  List<Map<String, dynamic>> _empleados = [];
  List<Map<String, dynamic>> _gastos = [];
  Map<String, dynamic>? _resumen;
  Map<String, dynamic>? _rentabilidad;
  bool _cargando = true;
  String? _error;

  final _moneda = NumberFormat.currency(
    locale: 'es_CO',
    symbol: r'$',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _cargarTodo();
  }

  @override
  void didUpdateWidget(covariant FinanzasAdminScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sucursalId != widget.sucursalId) {
      _cargarTodo();
    }
  }

  Future<void> _cargarTodo() async {
    final sid = widget.sucursalId;
    if (sid == null) {
      setState(() {
        _cargando = false;
        _error = 'Sin sucursal en sesión';
      });
      return;
    }
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final ahora = DateTime.now();
      final desde = DateFormat('yyyy-MM-dd').format(
        DateTime(ahora.year, ahora.month, 1),
      );
      final hasta = DateFormat('yyyy-MM-dd').format(ahora);
      final results = await Future.wait([
        _repo.listarCostosFijos(sid, incluirInactivos: true),
        _repo.listarEmpleados(sid, incluirInactivos: true),
        _repo.listarGastos(sid, desde: desde, hasta: hasta),
        _repo.resumen(sid),
        _analitica.rentabilidad(
          sucursalId: sid,
          preset: 'mes',
          comparar: true,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _fijos = results[0] as List<Map<String, dynamic>>;
        _empleados = results[1] as List<Map<String, dynamic>>;
        _gastos = results[2] as List<Map<String, dynamic>>;
        _resumen = results[3] as Map<String, dynamic>;
        _rentabilidad = results[4] as Map<String, dynamic>;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = mensajeErrorHttp(e, contexto: 'finanzas');
        _cargando = false;
      });
    }
  }

  double _num(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse('$v') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: SaaSTokens.canvas(context),
      child: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _cargarTodo,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _cargarTodo,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                    children: [
                      _header(context),
                      const SizedBox(height: 16),
                      _kpis(context),
                      const SizedBox(height: 8),
                      _charts(context),
                      const SizedBox(height: 8),
                      _distribucionGastos(context),
                      const SizedBox(height: 8),
                      _rentabilidadSeccion(context),
                      const SizedBox(height: 8),
                      _tablaFijos(context),
                      const SizedBox(height: 8),
                      _tablaVariables(context),
                      const SizedBox(height: 8),
                      _tablaNomina(context),
                      const SizedBox(height: 8),
                      SaaSSectionHeader(
                        titulo: 'Facturas',
                        icono: Icons.receipt_outlined,
                      ),
                      const SaaSEmptyState(
                        compacto: true,
                        titulo: 'Facturación en módulo aparte',
                        descripcion:
                            'Pendientes, pagadas y vencidas se gestionan en Facturación cuando DIAN esté activo.',
                        icono: Icons.description_outlined,
                      ),
                      const SizedBox(height: 8),
                      SaaSSectionHeader(
                        titulo: 'Presupuesto',
                        icono: Icons.flag_outlined,
                      ),
                      const SaaSEmptyState(
                        compacto: true,
                        titulo: 'Sin meta mensual configurada',
                        descripcion:
                            'El progreso vs presupuesto aparecerá cuando exista API de presupuestos.',
                        icono: Icons.track_changes_outlined,
                      ),
                      const SizedBox(height: 8),
                      SaaSSectionHeader(
                        titulo: 'Proyección financiera',
                        subtitulo: 'Próximos 12 meses',
                        icono: Icons.timeline,
                      ),
                      const SaaSEmptyState(
                        compacto: true,
                        titulo: 'Proyección no disponible',
                        descripcion:
                            'Ingresos estimados, utilidad y flujo esperado requieren modelo de proyección en backend.',
                        icono: Icons.auto_graph_outlined,
                      ),
                      const SizedBox(height: 8),
                      _alertas(context),
                      const SizedBox(height: 8),
                      _insights(context),
                    ],
                  ),
                ),
    );
  }

  Widget _header(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Finanzas',
                style: TextStyle(
                  fontSize: 11,
                  color: SaaSTokens.inkSoft(context),
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Finanzas',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.6,
                  color: SaaSTokens.ink(context),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'P&L del mes, gastos fijos, nómina y egresos — con claridad de nivel enterprise.',
                style: TextStyle(
                  fontSize: 13,
                  color: SaaSTokens.inkMuted(context),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Actualizar',
          onPressed: _cargarTodo,
          icon: Icon(
            Icons.refresh_rounded,
            color: SaaSTokens.inkMuted(context),
          ),
        ),
        if (widget.onVerRentabilidad != null)
          TextButton(
            onPressed: widget.onVerRentabilidad,
            child: const Text('Rentabilidad'),
          ),
      ],
    );
  }

  Widget _kpis(BuildContext context) {
    final actual = Map<String, dynamic>.from(
      _resumen?['mes_actual'] as Map? ?? {},
    );
    final rent = _rentabilidad?['kpis'] as Map<String, dynamic>? ??
        _rentabilidad?['pnl'] as Map<String, dynamic>? ??
        actual;
    final delta = _num(_resumen?['delta_utilidad_pct']);
    final ventas = _num(actual['ventas_netas'] ?? rent['ventas_netas']);
    final gastos = _num(actual['total_gastos'] ?? rent['total_gastos']);
    final cogs = _num(actual['costo_ventas'] ?? rent['costo_ventas']);
    final utilBruta =
        _num(actual['utilidad_bruta'] ?? rent['utilidad_bruta']);
    final utilNeta = _num(actual['utilidad_neta'] ?? rent['utilidad_neta']);
    final margenNeto =
        _num(actual['margen_neto_pct'] ?? rent['margen_neto_pct']);
    final margenBruto = ventas > 0 ? (utilBruta / ventas) * 100 : 0.0;
    final fijosSum = _fijos
        .where((f) => f['activo'] != false)
        .fold<double>(0, (s, f) => s + _num(f['monto_mensual']));
    final nominaSum = _empleados
        .where((e) => e['activo'] != false)
        .fold<double>(0, (s, e) => s + _num(e['sueldo_base']));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SaaSSectionHeader(
          titulo: 'Indicadores financieros',
          subtitulo: 'Mes en curso',
          icono: Icons.account_balance_outlined,
        ),
        SaaSKpiGrid(
          children: [
            SaaSKpiCard(
              etiqueta: 'Ventas netas',
              valor: _moneda.format(ventas),
              deltaPct: delta,
              icono: Icons.payments_outlined,
              acento: SaaSTokens.ventas,
            ),
            SaaSKpiCard(
              etiqueta: 'Costos variables',
              valor: _moneda.format(cogs),
              icono: Icons.inventory_2_outlined,
              acento: SaaSTokens.pedidos,
              subtitulo: 'COGS del mes',
            ),
            SaaSKpiCard(
              etiqueta: 'Costos fijos',
              valor: _moneda.format(fijosSum),
              icono: Icons.home_work_outlined,
              acento: SaaSTokens.inkMuted(context),
              subtitulo: 'Plantilla mensual',
            ),
            SaaSKpiCard(
              etiqueta: 'Gastos operativos',
              valor: _moneda.format(gastos),
              icono: Icons.receipt_long_outlined,
              acento: SaaSTokens.clientes,
              subtitulo: 'Total egresos mes',
            ),
            SaaSKpiCard(
              etiqueta: 'Margen bruto',
              valor: '${margenBruto.toStringAsFixed(1)}%',
              icono: Icons.trending_up,
              acento: SaaSTokens.inventario,
              subtitulo: _moneda.format(utilBruta),
            ),
            SaaSKpiCard(
              etiqueta: 'Margen neto',
              valor: '${margenNeto.toStringAsFixed(1)}%',
              icono: Icons.percent,
              acento: SaaSTokens.inventario,
              subtitulo: 'Sobre ventas netas',
            ),
            SaaSKpiCard(
              etiqueta: 'Utilidad neta',
              valor: _moneda.format(utilNeta),
              deltaPct: delta,
              icono: Icons.account_balance_wallet_outlined,
              acento: utilNeta >= 0
                  ? SaaSTokens.positivo
                  : SaaSTokens.negativo,
            ),
            SaaSKpiCard(
              etiqueta: 'Nómina mensual',
              valor: _moneda.format(nominaSum),
              icono: Icons.groups_outlined,
              acento: SaaSTokens.pedidos,
              subtitulo: 'Sueldos base activos',
            ),
          ],
        ),
      ],
    );
  }

  Widget _charts(BuildContext context) {
    final actual = Map<String, dynamic>.from(
      _resumen?['mes_actual'] as Map? ?? {},
    );
    final ant = Map<String, dynamic>.from(
      _resumen?['mes_anterior'] as Map? ?? {},
    );
    final vAct = _num(actual['ventas_netas']);
    final gAct = _num(actual['total_gastos']);
    final uAct = _num(actual['utilidad_neta']);
    final vAnt = _num(ant['ventas_netas']);
    final gAnt = _num(ant['total_gastos']);
    final uAnt = _num(ant['utilidad_neta']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SaaSSectionHeader(
          titulo: 'Ingresos vs gastos',
          icono: Icons.bar_chart,
        ),
        SaaSChartsGrid(
          columnsDesktop: 2,
          children: [
            SaaSChartCard(
              titulo: 'Mes actual vs anterior',
              altura: 240,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: SaaSTokens.borderSoft(context),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) {
                          final labels = ['Ventas', 'Gastos', 'Utilidad'];
                          final i = v.toInt();
                          if (i < 0 || i >= labels.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              labels[i],
                              style: TextStyle(
                                fontSize: 11,
                                color: SaaSTokens.inkSoft(context),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    for (final e in [
                      (0, vAct, vAnt),
                      (1, gAct, gAnt),
                      (2, uAct, uAnt),
                    ])
                      BarChartGroupData(
                        x: e.$1,
                        barsSpace: 4,
                        barRods: [
                          BarChartRodData(
                            toY: e.$2.abs(),
                            width: 14,
                            color: SaaSTokens.ventas,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          BarChartRodData(
                            toY: e.$3.abs(),
                            width: 14,
                            color: SaaSTokens.chartMuted(context),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            SaaSChartCard(
              titulo: 'Flujo de caja',
              subtitulo: 'Bancario / proyectado',
              altura: 240,
              vacio: true,
              mensajeVacio:
                  'El flujo de caja bancario aún no está conectado. Usa Caja para el turno operativo.',
              child: const SizedBox.shrink(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _distribucionGastos(BuildContext context) {
    final porCat = <String, double>{};
    for (final g in _gastos) {
      final cat = '${g['categoria'] ?? 'otros'}';
      porCat[cat] = (porCat[cat] ?? 0) + _num(g['monto']);
    }
    final fromRent =
        _rentabilidad?['gastos_por_categoria'] as List<dynamic>? ?? [];
    final items = fromRent.isNotEmpty
        ? fromRent
        : porCat.entries
            .map((e) => {'categoria': e.key, 'total': e.value})
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SaaSSectionHeader(
          titulo: 'Distribución de gastos',
          icono: Icons.pie_chart_outline,
        ),
        SaaSChartCard(
          titulo: 'Por categoría',
          altura: 240,
          vacio: items.isEmpty,
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: PieChart(
                  AnaliticaCharts.pieMetodo(
                    items
                        .map(
                          (e) => {
                            'metodo_pago':
                                '${(e as Map)['categoria'] ?? e['nombre'] ?? 'otros'}',
                            'total': e['total'] ?? e['monto'] ?? 0,
                          },
                        )
                        .toList(),
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: AnaliticaCharts.leyendaPie(
                  items
                      .map(
                        (e) => {
                          'metodo_pago':
                              '${(e as Map)['categoria'] ?? e['nombre'] ?? 'otros'}',
                          'total': e['total'] ?? e['monto'] ?? 0,
                        },
                      )
                      .toList(),
                  'metodo_pago',
                  'total',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _rentabilidadSeccion(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SaaSSectionHeader(
          titulo: 'Rentabilidad',
          icono: Icons.insights_outlined,
          trailing: widget.onVerRentabilidad == null
              ? null
              : TextButton(
                  onPressed: widget.onVerRentabilidad,
                  child: const Text('Ver completo'),
                ),
        ),
        SaaSEmptyState(
          compacto: true,
          titulo: 'Detalle por producto y sucursal',
          descripcion:
              'Abre Centro de Inteligencia → Rentabilidad para P&L completo, punto de equilibrio y cobertura COGS.',
          icono: Icons.open_in_new,
        ),
      ],
    );
  }

  Widget _tablaFijos(BuildContext context) {
    final activos = _fijos.where((f) => f['activo'] != false).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SaaSSectionHeader(
          titulo: 'Gastos fijos',
          icono: Icons.home_work_outlined,
          trailing: FilledButton.tonalIcon(
            onPressed: _dialogoNuevoFijo,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Agregar'),
          ),
        ),
        if (activos.isEmpty)
          const SaaSEmptyState(
            compacto: true,
            titulo: 'Sin gastos fijos',
            descripcion: 'Agrega arriendo, servicios, internet…',
          )
        else
          SaaSResponsiveTable(
            columns: const [
              SaaSTableColumn(id: 'concepto', label: 'Concepto', flex: 3),
              SaaSTableColumn(id: 'categoria', label: 'Categoría', flex: 2),
              SaaSTableColumn(
                id: 'monto',
                label: 'Mensual',
                flex: 2,
                numeric: true,
              ),
            ],
            rows: [
              for (final f in activos)
                {
                  'concepto': f['concepto'] ?? '',
                  'categoria': f['categoria'] ?? 'otros',
                  'monto': _moneda.format(_num(f['monto_mensual'])),
                  '_raw': f,
                },
            ],
            rowActions: (row) {
              final f = row['_raw'] as Map<String, dynamic>;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: () => _pagarFijo(f),
                    child: const Text('Pagar'),
                  ),
                  IconButton(
                    tooltip: 'Editar',
                    onPressed: () => _dialogoEditarFijo(f),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                  ),
                  IconButton(
                    tooltip: 'Eliminar',
                    onPressed: () => _desactivarFijo(f),
                    icon: const Icon(Icons.delete_outline, size: 18),
                  ),
                ],
              );
            },
          ),
      ],
    );
  }

  Future<void> _dialogoEditarFijo(Map<String, dynamic> fijo) async {
    final sid = widget.sucursalId;
    if (sid == null) return;

    final conceptoInicial = (fijo['concepto'] ?? '') as String;
    final montoInicial =
        fijo['monto_mensual'] != null ? _num(fijo['monto_mensual']) : 0.0;
    final categoriaInicial = (fijo['categoria'] ?? 'otros') as String;
    final diaPagoInicial = fijo['dia_pago'] is num
        ? (fijo['dia_pago'] as num).toInt()
        : int.tryParse('${fijo['dia_pago'] ?? ''}') ?? 0;
    final diaPagoTiene = fijo['dia_pago'] != null;
    final notasInicial = (fijo['notas'] ?? '') as String;

    final conceptoCtrl = TextEditingController(text: conceptoInicial);
    final montoCtrl = TextEditingController(
      text: montoInicial > 0 ? montoInicial.toStringAsFixed(0) : '',
    );
    final notasCtrl = TextEditingController(text: notasInicial);
    final diaPagoCtrl = TextEditingController(
      text: diaPagoTiene ? '$diaPagoInicial' : '',
    );

    String categoria = categoriaInicial;
    final ok = await FoodyDialogo.mostrar<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Editar gasto fijo'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: conceptoCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Concepto',
                    hintText: 'Arriendo, luz, gas…',
                  ),
                ),
                TextField(
                  controller: montoCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Monto mensual',
                  ),
                ),
                DropdownButtonFormField<String>(
                  // ignore: deprecated_member_use
                  value: categoria,
                  decoration: const InputDecoration(labelText: 'Categoría'),
                  items: _categorias
                      .map((c) => DropdownMenuItem(
                            value: c,
                            child: Text(c),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      setLocal(() => categoria = v ?? 'otros'),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: diaPagoCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Día de pago (opcional)',
                    hintText: '1..31',
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: notasCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notas (opcional)',
                    hintText: 'Referencia, proveedor, condiciones…',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (ok != true) {
      conceptoCtrl.dispose();
      montoCtrl.dispose();
      notasCtrl.dispose();
      diaPagoCtrl.dispose();
      return;
    }

    final concepto = conceptoCtrl.text.trim();
    final monto = double.tryParse(montoCtrl.text.trim());
    final notas = notasCtrl.text.trim();
    final diaPagoTxt = diaPagoCtrl.text.trim();
    final diaPago = diaPagoTxt.isEmpty ? null : int.tryParse(diaPagoTxt);

    conceptoCtrl.dispose();
    montoCtrl.dispose();
    notasCtrl.dispose();
    diaPagoCtrl.dispose();

    if (concepto.isEmpty || monto == null || monto < 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Concepto y monto válidos requeridos')),
      );
      return;
    }

    try {
      await _repo.actualizarCostoFijo(
        fijo['id'] as String,
        sucursalId: sid,
        concepto: concepto,
        montoMensual: monto,
        categoria: categoria,
        diaPago: diaPago,
        notas: notas.isEmpty ? null : notas,
      );
      await _cargarTodo();
    } catch (e) {
      if (!mounted) return;
      mostrarErrorSnackBar(context, e, contexto: 'finanzas');
    }
  }

  Widget _tablaVariables(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SaaSSectionHeader(
          titulo: 'Costos variables / egresos',
          subtitulo: 'Libro del mes',
          icono: Icons.list_alt_outlined,
          trailing: FilledButton.tonalIcon(
            onPressed: _dialogoGastoManual,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Gasto manual'),
          ),
        ),
        if (_gastos.isEmpty)
          const SaaSEmptyState(
            compacto: true,
            titulo: 'Sin egresos en el periodo',
          )
        else
          SaaSResponsiveTable(
            columns: const [
              SaaSTableColumn(id: 'concepto', label: 'Concepto', flex: 3),
              SaaSTableColumn(id: 'origen', label: 'Origen', flex: 2),
              SaaSTableColumn(id: 'fecha', label: 'Fecha', flex: 2),
              SaaSTableColumn(
                id: 'monto',
                label: 'Monto',
                flex: 2,
                numeric: true,
              ),
            ],
            rows: [
              for (final g in _gastos)
                {
                  'concepto': g['concepto'] ?? '',
                  'origen': g['origen'] ?? '',
                  'fecha': g['fecha'] ?? '',
                  'monto': _moneda.format(_num(g['monto'])),
                },
            ],
          ),
      ],
    );
  }

  Widget _tablaNomina(BuildContext context) {
    final activos = _empleados.where((e) => e['activo'] != false).toList();
    final total = activos.fold<double>(0, (s, e) => s + _num(e['sueldo_base']));
    final pendEmp =
        (_resumen?['pendientes'] as Map?)?['empleados'] as List? ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SaaSSectionHeader(
          titulo: 'Nómina',
          subtitulo:
              'Total mensual ${_moneda.format(total)} · ${pendEmp.length} por pagar',
          icono: Icons.badge_outlined,
          trailing: FilledButton.tonalIcon(
            onPressed: _dialogoNuevoEmpleado,
            icon: const Icon(Icons.person_add_alt_1, size: 18),
            label: const Text('Agregar'),
          ),
        ),
        if (activos.isEmpty)
          const SaaSEmptyState(
            compacto: true,
            titulo: 'Sin empleados',
            descripcion: 'Agrega meseros, cajeros, cocina…',
          )
        else
          SaaSResponsiveTable(
            columns: const [
              SaaSTableColumn(id: 'nombre', label: 'Nombre', flex: 3),
              SaaSTableColumn(id: 'cargo', label: 'Cargo', flex: 2),
              SaaSTableColumn(id: 'freq', label: 'Frecuencia', flex: 2),
              SaaSTableColumn(
                id: 'sueldo',
                label: 'Sueldo',
                flex: 2,
                numeric: true,
              ),
            ],
            rows: [
              for (final e in activos)
                {
                  'nombre': e['nombre'] ?? '',
                  'cargo': e['cargo'] ?? 'Sin cargo',
                  'freq': e['frecuencia_pago'] ?? '',
                  'sueldo': _moneda.format(_num(e['sueldo_base'])),
                  '_raw': e,
                },
            ],
            rowActions: (row) {
              final e = row['_raw'] as Map<String, dynamic>;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: () => _pagarEmpleado(e),
                    child: const Text('Pagar'),
                  ),
                  IconButton(
                    tooltip: 'Desactivar',
                    onPressed: () => _desactivarEmpleado(e),
                    icon: const Icon(Icons.delete_outline, size: 18),
                  ),
                ],
              );
            },
          ),
      ],
    );
  }

  Widget _alertas(BuildContext context) {
    final pend = Map<String, dynamic>.from(
      _resumen?['pendientes'] as Map? ?? {},
    );
    final consejos = (_resumen?['consejos'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final alerts = <Widget>[];

    if (_num(pend['urgentes']) > 0) {
      alerts.add(
        SaaSPriorityAlert(
          titulo: 'Pagos vencidos',
          detalle:
              '${_num(pend['urgentes']).toInt()} ítem(s) requieren atención',
          prioridad: 'alta',
        ),
      );
    }
    if (_num(pend['cantidad']) > 0) {
      alerts.add(
        SaaSPriorityAlert(
          titulo: 'Pagos próximos',
          detalle:
              '${_num(pend['cantidad']).toInt()} · ≈ ${_moneda.format(_num(pend['total_estimado']))}',
          prioridad: 'media',
        ),
      );
    }
    for (final c in consejos.where((c) => c['nivel'] == 'alerta').take(3)) {
      alerts.add(
        SaaSPriorityAlert(
          titulo: '${c['mensaje']}',
          prioridad: 'alta',
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SaaSSectionHeader(
          titulo: 'Alertas financieras',
          icono: Icons.notification_important_outlined,
        ),
        if (alerts.isEmpty)
          const SaaSEmptyState(
            compacto: true,
            titulo: 'Sin alertas',
            descripcion: 'No hay pagos urgentes ni señales de riesgo.',
            icono: Icons.check_circle_outline,
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final a in alerts)
                SizedBox(width: 340, child: a),
            ],
          ),
      ],
    );
  }

  Widget _insights(BuildContext context) {
    final consejos = (_resumen?['consejos'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final actual = Map<String, dynamic>.from(
      _resumen?['mes_actual'] as Map? ?? {},
    );
    final textos = <String>[
      for (final c in consejos) '${c['mensaje']}',
    ];
    final ventas = _num(actual['ventas_netas']);
    final nomina = _empleados
        .where((e) => e['activo'] != false)
        .fold<double>(0, (s, e) => s + _num(e['sueldo_base']));
    if (ventas > 0 && nomina > 0) {
      textos.add(
        'La nómina representa el ${((nomina / ventas) * 100).toStringAsFixed(0)}% de las ventas netas del mes.',
      );
    }
    final delta = _num(_resumen?['delta_utilidad_pct']);
    if (delta != 0) {
      textos.add(
        delta > 0
            ? 'La utilidad mejoró un ${delta.toStringAsFixed(0)}% frente al mes anterior.'
            : 'La utilidad bajó un ${delta.abs().toStringAsFixed(0)}% frente al mes anterior.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SaaSSectionHeader(
          titulo: 'Insights financieros',
          icono: Icons.auto_awesome_outlined,
        ),
        if (textos.isEmpty)
          const SaaSEmptyState(
            compacto: true,
            titulo: 'Sin insights todavía',
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final t in textos.take(6))
                SizedBox(width: 340, child: SaaSInsightCard(texto: t)),
            ],
          ),
      ],
    );
  }

  // ——— CRUD (lógica existente) ———

  Future<void> _dialogoNuevoFijo() async {
    final sid = widget.sucursalId;
    if (sid == null) return;
    final conceptoCtrl = TextEditingController();
    final montoCtrl = TextEditingController();
    String categoria = 'servicios';
    final ok = await FoodyDialogo.mostrar<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Nuevo gasto fijo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: conceptoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Concepto',
                  hintText: 'Arriendo, luz, gas…',
                ),
              ),
              TextField(
                controller: montoCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: const InputDecoration(labelText: 'Monto mensual'),
              ),
              DropdownButtonFormField<String>(
                // ignore: deprecated_member_use
                value: categoria,
                decoration: const InputDecoration(labelText: 'Categoría'),
                items: _categorias
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setLocal(() => categoria = v ?? 'otros'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final monto = double.tryParse(montoCtrl.text.trim());
    if (conceptoCtrl.text.trim().isEmpty || monto == null || monto < 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Concepto y monto válidos requeridos')),
      );
      return;
    }
    try {
      await _repo.crearCostoFijo(
        sucursalId: sid,
        concepto: conceptoCtrl.text.trim(),
        montoMensual: monto,
        categoria: categoria,
      );
      await _cargarTodo();
    } catch (e) {
      if (!mounted) return;
      mostrarErrorSnackBar(context, e, contexto: 'finanzas');
    }
  }

  Future<void> _dialogoNuevoEmpleado() async {
    final sid = widget.sucursalId;
    if (sid == null) return;
    final nombreCtrl = TextEditingController();
    final cargoCtrl = TextEditingController();
    final sueldoCtrl = TextEditingController();
    String frecuencia = 'quincenal';
    final ok = await FoodyDialogo.mostrar<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Nuevo empleado'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreCtrl,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              TextField(
                controller: cargoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Cargo',
                  hintText: 'Mesero, cajero…',
                ),
              ),
              TextField(
                controller: sueldoCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: const InputDecoration(labelText: 'Sueldo base'),
              ),
              DropdownButtonFormField<String>(
                // ignore: deprecated_member_use
                value: frecuencia,
                decoration: const InputDecoration(labelText: 'Frecuencia'),
                items: _frecuencias
                    .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                    .toList(),
                onChanged: (v) => setLocal(() => frecuencia = v ?? 'mensual'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final sueldo = double.tryParse(sueldoCtrl.text.trim());
    if (nombreCtrl.text.trim().isEmpty || sueldo == null || sueldo < 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nombre y sueldo válidos requeridos')),
      );
      return;
    }
    try {
      await _repo.crearEmpleado(
        sucursalId: sid,
        nombre: nombreCtrl.text.trim(),
        cargo: cargoCtrl.text.trim().isEmpty ? null : cargoCtrl.text.trim(),
        sueldoBase: sueldo,
        frecuenciaPago: frecuencia,
      );
      await _cargarTodo();
    } catch (e) {
      if (!mounted) return;
      mostrarErrorSnackBar(context, e, contexto: 'finanzas');
    }
  }

  Future<void> _dialogoGastoManual() async {
    final sid = widget.sucursalId;
    if (sid == null) return;
    final conceptoCtrl = TextEditingController();
    final montoCtrl = TextEditingController();
    String categoria = 'otros';
    final ok = await FoodyDialogo.mostrar<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Gasto manual'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'No descuenta de la caja del turno (p. ej. transferencia).',
                style: TextStyle(
                  fontSize: 12,
                  color: SaaSTokens.inkMuted(context),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: conceptoCtrl,
                decoration: const InputDecoration(labelText: 'Concepto'),
              ),
              TextField(
                controller: montoCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: const InputDecoration(labelText: 'Monto'),
              ),
              DropdownButtonFormField<String>(
                // ignore: deprecated_member_use
                value: categoria,
                decoration: const InputDecoration(labelText: 'Categoría'),
                items: _categorias
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setLocal(() => categoria = v ?? 'otros'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Registrar'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final monto = double.tryParse(montoCtrl.text.trim());
    if (conceptoCtrl.text.trim().isEmpty || monto == null || monto <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Concepto y monto válidos requeridos')),
      );
      return;
    }
    try {
      await _repo.crearGastoManual(
        sucursalId: sid,
        concepto: conceptoCtrl.text.trim(),
        monto: monto,
        categoria: categoria,
      );
      await _cargarTodo();
    } catch (e) {
      if (!mounted) return;
      mostrarErrorSnackBar(context, e, contexto: 'finanzas');
    }
  }

  Future<void> _pagarFijo(Map<String, dynamic> f) async {
    final sid = widget.sucursalId;
    if (sid == null) return;
    final pago = await _dialogoPago(
      titulo: 'Registrar pago',
      nombre: '${f['concepto']}',
      montoSugerido: _num(f['monto_mensual']),
    );
    if (pago == null) return;
    try {
      await _repo.pagarCostoFijo(
        f['id'] as String,
        sucursalId: sid,
        monto: pago.monto,
        periodoDesde: pago.periodoDesde,
        periodoHasta: pago.periodoHasta,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pago registrado')),
      );
      await _cargarTodo();
    } catch (e) {
      if (!mounted) return;
      mostrarErrorSnackBar(context, e, contexto: 'finanzas');
    }
  }

  Future<void> _pagarEmpleado(Map<String, dynamic> e) async {
    final sid = widget.sucursalId;
    if (sid == null) return;
    final pago = await _dialogoPago(
      titulo: 'Registrar nómina',
      nombre: '${e['nombre']} (${e['frecuencia_pago']})',
      montoSugerido: _num(e['sueldo_base']),
    );
    if (pago == null) return;
    try {
      await _repo.pagarEmpleado(
        e['id'] as String,
        sucursalId: sid,
        monto: pago.monto,
        periodoDesde: pago.periodoDesde,
        periodoHasta: pago.periodoHasta,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nómina registrada')),
      );
      await _cargarTodo();
    } catch (e) {
      if (!mounted) return;
      mostrarErrorSnackBar(context, e, contexto: 'finanzas');
    }
  }

  Future<({double monto, String? periodoDesde, String? periodoHasta})?>
      _dialogoPago({
    required String titulo,
    required String nombre,
    required double montoSugerido,
  }) async {
    final montoCtrl = TextEditingController(
      text: montoSugerido > 0 ? montoSugerido.toStringAsFixed(0) : '',
    );
    final desdeCtrl = TextEditingController();
    final hastaCtrl = TextEditingController();
    final ok = await FoodyDialogo.mostrar<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                nombre,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'No afecta el arqueo de caja.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: SaaSTokens.inkMuted(ctx),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: montoCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Monto a registrar',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: desdeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Periodo desde (YYYY-MM-DD, opcional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: hastaCtrl,
                decoration: const InputDecoration(
                  labelText: 'Periodo hasta (YYYY-MM-DD, opcional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Pagar'),
          ),
        ],
      ),
    );
    if (ok != true) {
      montoCtrl.dispose();
      desdeCtrl.dispose();
      hastaCtrl.dispose();
      return null;
    }
    final monto = double.tryParse(montoCtrl.text.trim()) ?? 0;
    final desde = desdeCtrl.text.trim();
    final hasta = hastaCtrl.text.trim();
    montoCtrl.dispose();
    desdeCtrl.dispose();
    hastaCtrl.dispose();
    if (monto <= 0) return null;
    return (
      monto: monto,
      periodoDesde: desde.isEmpty ? null : desde,
      periodoHasta: hasta.isEmpty ? null : hasta,
    );
  }

  Future<void> _desactivarFijo(Map<String, dynamic> f) async {
    final sid = widget.sucursalId;
    if (sid == null) return;
    try {
      await _repo.eliminarCostoFijo(f['id'] as String, sucursalId: sid);
      await _cargarTodo();
    } catch (e) {
      if (!mounted) return;
      mostrarErrorSnackBar(context, e, contexto: 'finanzas');
    }
  }

  Future<void> _desactivarEmpleado(Map<String, dynamic> e) async {
    final sid = widget.sucursalId;
    if (sid == null) return;
    try {
      await _repo.actualizarEmpleado(
        e['id'] as String,
        sucursalId: sid,
        activo: false,
      );
      await _cargarTodo();
    } catch (e) {
      if (!mounted) return;
      mostrarErrorSnackBar(context, e, contexto: 'finanzas');
    }
  }
}
