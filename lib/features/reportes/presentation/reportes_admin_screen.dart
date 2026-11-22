import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';
import 'package:reserva_canchas/core/red/mostrar_error_snackbar.dart';
import 'package:reserva_canchas/core/saas_ui/saas_ui.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_chart_card.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_charts.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_kpi_card.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_section.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_skeleton.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_surface.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_tokens.dart';
import 'package:reserva_canchas/features/auditoria/data/auditoria_repository.dart';
import 'package:reserva_canchas/features/reportes/data/reportes_repository.dart';
import 'package:reserva_canchas/features/reportes/utils/reporte_export_foody.dart';
import 'package:share_plus/share_plus.dart';

/// Reportes admin — misma línea visual que Centro de Inteligencia.
class ReportesAdminScreen extends StatefulWidget {
  const ReportesAdminScreen({
    super.key,
    this.sucursalId,
    this.onIrAnalitica,
  });

  final String? sucursalId;

  /// NAV-ADM2-12: puente a Centro de Análisis.
  final VoidCallback? onIrAnalitica;

  @override
  State<ReportesAdminScreen> createState() => _ReportesAdminScreenState();
}

class _ReportesAdminScreenState extends State<ReportesAdminScreen>
    with SingleTickerProviderStateMixin {
  ColorScheme get _scheme => Theme.of(context).colorScheme;

  final _repo = ReportesRepository();
  final _auditoriaRepo = AuditoriaRepository();
  late TabController _tabs;
  int _dias = 7;
  bool _cargando = true;
  String? _error;
  DateTime _actualizadoEn = DateTime.now();

  Map<String, dynamic>? _financiero;
  Map<String, dynamic>? _productos;
  Map<String, dynamic>? _pedidos;
  Map<String, dynamic>? _timeline;
  bool _cargandoTimeline = false;

  final _moneda = NumberFormat.currency(
    locale: 'es_CO',
    symbol: r'$',
    decimalDigits: 0,
  );
  final _fecha = DateFormat('yyyy-MM-dd');

  static const _periodos = [
    (1, 'Hoy'),
    (7, '7d'),
    (30, '30d'),
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _tabs.addListener(() {
      if (_tabs.index == 3 && _timeline == null && !_cargandoTimeline) {
        _cargarTimeline();
      }
    });
    _cargar();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  (String, String) _rango() {
    final hasta = DateTime.now();
    final desde = hasta.subtract(Duration(days: _dias - 1));
    return (_fecha.format(desde), _fecha.format(hasta));
  }

  Future<void> _cargarTimeline() async {
    final sid = widget.sucursalId;
    if (sid == null) return;
    setState(() => _cargandoTimeline = true);
    final (desde, hasta) = _rango();
    try {
      final data = await _auditoriaRepo.timeline(
        desde: desde,
        hasta: hasta,
        sucursalId: sid,
      );
      if (mounted) {
        setState(() {
          _timeline = data;
          _cargandoTimeline = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _cargandoTimeline = false);
    }
  }

  Future<void> _cargar() async {
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
    final (desde, hasta) = _rango();
    try {
      final results = await Future.wait([
        _repo.financiero(sucursalId: sid, desde: desde, hasta: hasta),
        _repo.productos(sucursalId: sid, desde: desde, hasta: hasta),
        _repo.pedidos(sucursalId: sid, desde: desde, hasta: hasta),
      ]);
      if (mounted) {
        setState(() {
          _financiero = results[0];
          _productos = results[1];
          _pedidos = results[2];
          _timeline = null;
          _cargando = false;
          _actualizadoEn = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = mensajeErrorHttp(e, contexto: 'reportes');
          _cargando = false;
        });
      }
    }
  }

  double _num(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

  String _nombreArchivo(String ext) {
    final (desde, hasta) = _rango();
    return 'foody-reportes-$desde-$hasta.$ext';
  }

  Future<void> _exportarPdf() async {
    if (_financiero == null && _productos == null && _pedidos == null) return;
    final (desde, hasta) = _rango();
    try {
      final bytes = await ReporteExportFoody.generarPdf(
        desde: desde,
        hasta: hasta,
        financiero: _financiero,
        productos: _productos,
        pedidos: _pedidos,
      );
      await Share.shareXFiles(
        [
          XFile.fromData(
            bytes,
            mimeType: 'application/pdf',
            name: _nombreArchivo('pdf'),
          ),
        ],
        subject: 'Reporte Foody $desde — $hasta',
      );
    } catch (e) {
      if (mounted) {
        mostrarErrorSnackBar(context, e, contexto: 'exportar PDF');
      }
    }
  }

  Future<void> _exportarCsv() async {
    if (_financiero == null && _productos == null && _pedidos == null) return;
    final (desde, hasta) = _rango();
    try {
      final bytes = ReporteExportFoody.generarCsv(
        desde: desde,
        hasta: hasta,
        financiero: _financiero,
        productos: _productos,
        pedidos: _pedidos,
      );
      await Share.shareXFiles(
        [
          XFile.fromData(
            bytes,
            mimeType: 'text/csv',
            name: _nombreArchivo('csv'),
          ),
        ],
        subject: 'Reporte Foody $desde — $hasta',
      );
    } catch (e) {
      if (mounted) {
        mostrarErrorSnackBar(context, e, contexto: 'exportar CSV');
      }
    }
  }

  void _mostrarExportar() {
    if (_cargando || _error != null) return;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: _scheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Exportar reporte',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('PDF'),
              subtitle: const Text('Informe completo'),
              onTap: () {
                Navigator.pop(ctx);
                _exportarPdf();
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart_outlined),
              title: const Text('CSV / Excel'),
              onTap: () {
                Navigator.pop(ctx);
                _exportarCsv();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final (desde, hasta) = _rango();
    final hora = DateFormat('HH:mm').format(_actualizadoEn);

    return ColoredBox(
      color: _scheme.surface,
      child: SaasScrollableShell(
        header: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Admin / Reportes',
                        style: TextStyle(
                          fontSize: 11,
                          color: _scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Reportes',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                          color: _scheme.onSurface,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$desde → $hasta · Act. $hora',
                        style: TextStyle(
                          fontSize: 12,
                          color: _scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.onIrAnalitica != null)
                  TextButton(
                    onPressed: widget.onIrAnalitica,
                    style: TextButton.styleFrom(
                      foregroundColor: _scheme.onSurfaceVariant,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('Análisis'),
                  ),
                IconButton(
                  tooltip: 'Exportar',
                  onPressed:
                      _cargando || _error != null ? null : _mostrarExportar,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.download_rounded, size: 20),
                  color: _scheme.onSurfaceVariant,
                ),
                IconButton(
                  tooltip: 'Actualizar',
                  onPressed: _cargar,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  color: _scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final p in _periodos) ...[
                    _PeriodChip(
                      label: p.$2,
                      selected: _dias == p.$1,
                      onTap: () {
                        setState(() => _dias = p.$1);
                        _cargar();
                      },
                    ),
                    const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: _scheme.outlineVariant),
                  ),
                ),
                child: TabBar(
                  controller: _tabs,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: _scheme.onSurface,
                  unselectedLabelColor: _scheme.onSurfaceVariant,
                  indicatorColor: _scheme.onSurface,
                  indicatorWeight: 2,
                  dividerColor: Colors.transparent,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 12.5,
                  ),
                  tabs: const [
                    Tab(text: 'Financiero'),
                    Tab(text: 'Productos'),
                    Tab(text: 'Pedidos'),
                    Tab(text: 'Auditoría'),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _cargando
                  ? AnaliticaSkeleton.tab()
                  : _error != null
                      ? _errorView()
                      : TabBarView(
                          controller: _tabs,
                          children: [
                            _tabFinanciero(),
                            _tabProductos(),
                            _tabPedidos(),
                            _tabAuditoria(),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: AnaliticaSurface(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_outlined,
                size: 36,
                color: _scheme.onSurfaceVariant,
              ),
              const SizedBox(height: 10),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _scheme.onSurface,
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _cargar,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Reintentar'),
                style: FilledButton.styleFrom(
                  backgroundColor: _scheme.primary,
                  foregroundColor: _scheme.onPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabFinanciero() {
    final r = _financiero?['resumen'] as Map<String, dynamic>? ?? {};
    final cuadre = _financiero?['cuadre_caja'] as Map<String, dynamic>? ?? {};
    final porTipo = _financiero?['por_tipo'] as List<dynamic>? ?? [];
    final porMetodoCaja = cuadre['por_metodo_caja'] as List<dynamic>? ?? [];
    final diferencia = _num(cuadre['diferencia']);

    Color colorDiferencia() {
      if (diferencia.abs() < 1) return AnaliticaTokens.inventario;
      if (diferencia.abs() <= 5000) return _scheme.onSurfaceVariant;
      return AnaliticaTokens.alertas;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        const AnaliticaSectionHeader(
          titulo: 'Resumen financiero',
          subtitulo:
              'Tickets = total de pedidos del período (pueden incluir sin cobrar)',
          icono: Icons.payments_outlined,
        ),
        AnaliticaKpiGrid(
          children: [
            AnaliticaKpiCard(
              etiqueta: 'Tickets',
              valor: _moneda.format(_num(r['ventas_total'])),
              icono: Icons.payments_outlined,
              acento: AnaliticaTokens.ventas,
              destacado: true,
            ),
            AnaliticaKpiCard(
              etiqueta: 'Pedidos',
              valor: '${r['pedidos'] ?? 0}',
              icono: Icons.receipt_long_outlined,
              acento: AnaliticaTokens.pedidos,
              destacado: true,
            ),
            AnaliticaKpiCard(
              etiqueta: 'Ticket prom.',
              valor: _moneda.format(_num(r['ticket_promedio'])),
              icono: Icons.shopping_bag_outlined,
              acento: AnaliticaTokens.clientes,
            ),
            AnaliticaKpiCard(
              etiqueta: 'Domicilios',
              valor: _moneda.format(_num(r['costo_domicilio'])),
              icono: Icons.delivery_dining_outlined,
              acento: _scheme.onSurfaceVariant,
            ),
          ],
        ),
        const SizedBox(height: 16),
        const AnaliticaSectionHeader(
          titulo: 'Cuadre de caja',
          subtitulo: 'Tickets vs cobrado neto (universos distintos)',
          icono: Icons.balance_outlined,
        ),
        AnaliticaSurface(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _filaCuadre(
                (cuadre['etiqueta_ventas_pedidos'] as String?) ??
                    'Tickets (total pedidos)',
                _moneda.format(_num(cuadre['ventas_pedidos'])),
              ),
              _filaCuadre(
                (cuadre['etiqueta_ventas_caja'] as String?) ??
                    'Cobrado en caja (neto)',
                _moneda.format(_num(cuadre['ventas_movimientos_caja'])),
              ),
              Divider(height: 20, color: _scheme.outlineVariant),
              _filaCuadre(
                'Diferencia',
                _moneda.format(diferencia),
                destacado: true,
                color: colorDiferencia(),
              ),
              const SizedBox(height: 8),
              Text(
                (cuadre['nota_universos'] as String?)?.trim().isNotEmpty == true
                    ? cuadre['nota_universos'] as String
                    : diferencia.abs() < 1
                        ? 'Cuadre OK — tickets y caja coinciden.'
                        : diferencia > 0
                            ? 'Hay más en tickets que en caja (cobros pendientes o sin registrar).'
                            : 'Hay más en caja que en tickets (revisar movimientos manuales o duplicados).',
                style: TextStyle(
                  fontSize: 12,
                  color: _scheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
              if ((cuadre['movimientos_venta'] ?? 0) != 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${cuadre['movimientos_venta']} movimiento(s) de venta en caja',
                    style: TextStyle(
                      fontSize: 12,
                      color: _scheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (porMetodoCaja.isNotEmpty) ...[
          const SizedBox(height: 16),
          const AnaliticaSectionHeader(
            titulo: 'Caja por método',
            icono: Icons.account_balance_wallet_outlined,
          ),
          ...porMetodoCaja.map((item) {
            final m = item as Map<String, dynamic>;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: AnaliticaSurface(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Expanded(child: Text('${m['metodo_pago']}')),
                    Text(
                      _moneda.format(_num(m['total'])),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
        const SizedBox(height: 16),
        const AnaliticaSectionHeader(
          titulo: 'Por tipo de pedido',
          icono: Icons.hub_outlined,
        ),
        if (porTipo.isEmpty)
          Text(
            'Sin datos en el período',
            style: TextStyle(color: _scheme.onSurfaceVariant),
          )
        else
          ...porTipo.map((item) {
            final m = item as Map<String, dynamic>;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: AnaliticaSurface(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${m['tipo']}'.replaceAll('_', ' '),
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    Text(
                      '${m['pedidos']} · ${_moneda.format(_num(m['ventas']))}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _tabProductos() {
    final ranking = _productos?['ranking'] as List<dynamic>? ?? [];

    if (ranking.isEmpty) {
      return Center(
        child: Text(
          'Sin ventas de productos en el período',
          style: TextStyle(color: _scheme.onSurfaceVariant),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        AnaliticaSectionHeader(
          titulo: 'Ranking de productos',
          subtitulo: '${ranking.length} ítems',
          icono: Icons.bar_chart,
        ),
        if (ranking.length >= 2)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AnaliticaChartCard(
              titulo: 'Top productos',
              subtitulo: 'Por ventas',
              icono: Icons.show_chart,
              altura: 180,
              child: BarChart(
                AnaliticaCharts.barrasHorizontales(
                  ranking,
                  valorKey: 'ventas',
                  nombreKey: 'nombre',
                  color: AnaliticaTokens.chart,
                ),
              ),
            ),
          ),
        for (var i = 0; i < ranking.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: AnaliticaSurface(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (ranking[i] as Map)['nombre'] as String? ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${(ranking[i] as Map)['cantidad']} unidades',
                          style: TextStyle(
                            fontSize: 12,
                            color: _scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _moneda.format(_num((ranking[i] as Map)['ventas'])),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _tabPedidos() {
    final porEstado = _pedidos?['por_estado'] as List<dynamic>? ?? [];
    final porDia = _pedidos?['por_dia'] as List<dynamic>? ?? [];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        if (porDia.length >= 2) ...[
          const AnaliticaSectionHeader(
            titulo: 'Tendencia',
            subtitulo: 'Ventas por día',
            icono: Icons.timeline,
          ),
          AnaliticaChartCard(
            titulo: 'Tendencia por día',
            subtitulo: 'Serie del período',
            icono: Icons.show_chart,
            child: LineChart(AnaliticaCharts.lineaDia(porDia)),
          ),
          const SizedBox(height: 16),
        ],
        const AnaliticaSectionHeader(
          titulo: 'Por estado',
          icono: Icons.flag_outlined,
        ),
        if (porEstado.isEmpty)
          Text(
            'Sin pedidos',
            style: TextStyle(color: _scheme.onSurfaceVariant),
          )
        else
          ...porEstado.map((item) {
            final m = item as Map<String, dynamic>;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: AnaliticaSurface(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${m['estado']}'.replaceAll('_', ' '),
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    Text(
                      '${m['total']}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            );
          }),
        const SizedBox(height: 16),
        const AnaliticaSectionHeader(
          titulo: 'Detalle por día',
          icono: Icons.calendar_today_outlined,
        ),
        if (porDia.isEmpty)
          Text(
            'Sin datos',
            style: TextStyle(color: _scheme.onSurfaceVariant),
          )
        else
          ...porDia.map((item) {
            final m = item as Map<String, dynamic>;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: AnaliticaSurface(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Expanded(child: Text('${m['dia']}')),
                    Text(
                      '${m['pedidos']} ped. · ${_moneda.format(_num(m['ventas']))}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _tabAuditoria() {
    if (_cargandoTimeline) {
      return AnaliticaSkeleton.tab();
    }
    final eventos = (_timeline?['eventos'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    if (eventos.isEmpty) {
      return Center(
        child: Text(
          'Sin eventos en el período',
          style: TextStyle(color: _scheme.onSurfaceVariant),
        ),
      );
    }
    final horaFmt = DateFormat('HH:mm');
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        AnaliticaSectionHeader(
          titulo: 'Timeline de auditoría',
          subtitulo: '${eventos.length} eventos',
          icono: Icons.history,
        ),
        ...eventos.map((e) {
          final fuente = e['fuente'] as String? ?? '—';
          final cuando = DateTime.tryParse('${e['ocurrido_at']}')?.toLocal();
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: AnaliticaSurface(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      fuente.substring(0, 1).toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${e['tipo'] ?? e['accion'] ?? fuente}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          cuando != null ? horaFmt.format(cuando) : '',
                          style: TextStyle(
                            fontSize: 11,
                            color: _scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      fuente,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: _scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _filaCuadre(
    String etiqueta,
    String valor, {
    bool destacado = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              etiqueta,
              style: TextStyle(
                fontSize: 13,
                color: _scheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            valor,
            style: TextStyle(
              fontWeight: destacado ? FontWeight.w700 : FontWeight.w600,
              fontSize: destacado ? 17 : 14,
              color: color ?? _scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AnaliticaTokens.ink : AnaliticaTokens.surface,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: selected ? AnaliticaTokens.ink : AnaliticaTokens.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: selected ? Colors.white : AnaliticaTokens.inkMuted,
            ),
          ),
        ),
      ),
    );
  }
}
