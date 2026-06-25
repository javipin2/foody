import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';
import 'package:reserva_canchas/features/reportes/data/reportes_repository.dart';
import 'package:reserva_canchas/features/auditoria/data/auditoria_repository.dart';

/// Reportes básicos admin (Sprint 9 — MVP).
class ReportesAdminScreen extends StatefulWidget {
  const ReportesAdminScreen({super.key, this.sucursalId});

  final String? sucursalId;

  @override
  State<ReportesAdminScreen> createState() => _ReportesAdminScreenState();
}

class _ReportesAdminScreenState extends State<ReportesAdminScreen>
    with SingleTickerProviderStateMixin {
  final _repo = ReportesRepository();
  final _auditoriaRepo = AuditoriaRepository();
  late TabController _tabs;
  int _dias = 7;
  bool _cargando = true;
  String? _error;

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

  @override
  Widget build(BuildContext context) {
    final (desde, hasta) = _rango();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
          child: Row(
            children: [
              Text('Reportes', style: Theme.of(context).textTheme.headlineSmall),
              const Spacer(),
              DropdownButton<int>(
                value: _dias,
                items: const [
                  DropdownMenuItem(value: 1, child: Text('Hoy')),
                  DropdownMenuItem(value: 7, child: Text('7 días')),
                  DropdownMenuItem(value: 30, child: Text('30 días')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _dias = v);
                  _cargar();
                },
              ),
              IconButton(
                tooltip: 'Actualizar',
                onPressed: _cargar,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Período: $desde → $hasta',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          ),
        ),
        TabBar(
          controller: _tabs,
          labelColor: ColoresFoody.primario,
          tabs: const [
            Tab(text: 'Financiero'),
            Tab(text: 'Productos'),
            Tab(text: 'Pedidos'),
            Tab(text: 'Auditoría'),
          ],
        ),
        Expanded(
          child: _cargando
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: _cargar,
                            child: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    )
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
    );
  }

  Widget _tabFinanciero() {
    final r = _financiero?['resumen'] as Map<String, dynamic>? ?? {};
    final cuadre = _financiero?['cuadre_caja'] as Map<String, dynamic>? ?? {};
    final porTipo = _financiero?['por_tipo'] as List<dynamic>? ?? [];
    final porMetodoCaja =
        cuadre['por_metodo_caja'] as List<dynamic>? ?? [];
    final diferencia = _num(cuadre['diferencia']);

    Color colorDiferencia() {
      if (diferencia.abs() < 1) return ColoresFoody.secundario;
      if (diferencia.abs() <= 5000) return ColoresFoody.acento;
      return Colors.red.shade700;
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _tarjeta('Ventas', _moneda.format(_num(r['ventas_total']))),
            _tarjeta('Pedidos', '${r['pedidos'] ?? 0}'),
            _tarjeta('Ticket prom.', _moneda.format(_num(r['ticket_promedio']))),
            _tarjeta('Domicilios', _moneda.format(_num(r['costo_domicilio']))),
          ],
        ),
        const SizedBox(height: 20),
        Text('Cuadre caja', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Compara ventas en pedidos vs movimientos de caja registrados.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
        const SizedBox(height: 12),
        Card(
          color: colorDiferencia().withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _filaCuadre(
                  'Ventas (pedidos)',
                  _moneda.format(_num(cuadre['ventas_pedidos'])),
                ),
                _filaCuadre(
                  'Ventas (movimientos caja)',
                  _moneda.format(_num(cuadre['ventas_movimientos_caja'])),
                ),
                const Divider(height: 20),
                _filaCuadre(
                  'Diferencia',
                  _moneda.format(diferencia),
                  destacado: true,
                  color: colorDiferencia(),
                ),
                const SizedBox(height: 8),
                Text(
                  diferencia.abs() < 1
                      ? 'Cuadre OK — pedidos y caja coinciden.'
                      : diferencia > 0
                          ? 'Hay más ventas en pedidos que en caja (cobros sin registrar o pendientes).'
                          : 'Hay más en caja que en pedidos (revisar movimientos manuales o duplicados).',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                  ),
                ),
                if ((cuadre['movimientos_venta'] ?? 0) != 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${cuadre['movimientos_venta']} movimiento(s) de venta en caja',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (porMetodoCaja.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Caja por método de pago',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          ...porMetodoCaja.map((item) {
            final m = item as Map<String, dynamic>;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text('${m['metodo_pago']}'),
              trailing: Text(_moneda.format(_num(m['total']))),
            );
          }),
        ],
        const SizedBox(height: 20),
        Text('Por tipo de pedido', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (porTipo.isEmpty)
          const Text('Sin datos en el período')
        else
          ...porTipo.map((item) {
            final m = item as Map<String, dynamic>;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${m['tipo']}'),
              trailing: Text(
                '${m['pedidos']} · ${_moneda.format(_num(m['ventas']))}',
              ),
            );
          }),
      ],
    );
  }

  Widget _tabProductos() {
    final ranking = _productos?['ranking'] as List<dynamic>? ?? [];

    if (ranking.isEmpty) {
      return const Center(child: Text('Sin ventas de productos en el período'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: ranking.length,
      itemBuilder: (_, i) {
        final p = ranking[i] as Map<String, dynamic>;
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: ColoresFoody.primario.withValues(alpha: 0.15),
              child: Text('${i + 1}'),
            ),
            title: Text(p['nombre'] as String? ?? ''),
            subtitle: Text('${p['cantidad']} unidades'),
            trailing: Text(
              _moneda.format(_num(p['ventas'])),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        );
      },
    );
  }

  Widget _tabPedidos() {
    final porEstado = _pedidos?['por_estado'] as List<dynamic>? ?? [];
    final porDia = _pedidos?['por_dia'] as List<dynamic>? ?? [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Por estado', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (porEstado.isEmpty)
          const Text('Sin pedidos')
        else
          ...porEstado.map((item) {
            final m = item as Map<String, dynamic>;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${m['estado']}'),
              trailing: Text('${m['total']}'),
            );
          }),
        const SizedBox(height: 20),
        Text('Por día', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (porDia.isEmpty)
          const Text('Sin datos')
        else
          ...porDia.map((item) {
            final m = item as Map<String, dynamic>;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${m['dia']}'),
              trailing: Text(
                '${m['pedidos']} ped. · ${_moneda.format(_num(m['ventas']))}',
              ),
            );
          }),
      ],
    );
  }

  Widget _tabAuditoria() {
    if (_cargandoTimeline) {
      return const Center(child: CircularProgressIndicator());
    }
    final eventos = (_timeline?['eventos'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    if (eventos.isEmpty) {
      return const Center(child: Text('Sin eventos en el período'));
    }
    final hora = DateFormat('HH:mm');
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: eventos.length,
      itemBuilder: (_, i) {
        final e = eventos[i];
        final fuente = e['fuente'] as String? ?? '—';
        final cuando = DateTime.tryParse('${e['ocurrido_at']}')?.toLocal();
        return Card(
          child: ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 16,
              backgroundColor: ColoresFoody.primario.withValues(alpha: 0.12),
              child: Text(
                fuente.substring(0, 1).toUpperCase(),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(
              '${e['tipo'] ?? e['accion'] ?? fuente}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            subtitle: Text(
              cuando != null ? hora.format(cuando) : '',
              style: const TextStyle(fontSize: 11),
            ),
            trailing: Chip(
              label: Text(fuente, style: const TextStyle(fontSize: 10)),
              visualDensity: VisualDensity.compact,
            ),
          ),
        );
      },
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
          Expanded(child: Text(etiqueta)),
          Text(
            valor,
            style: TextStyle(
              fontWeight: destacado ? FontWeight.bold : FontWeight.w600,
              fontSize: destacado ? 18 : 15,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjeta(String titulo, String valor) {
    return SizedBox(
      width: 160,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: TextStyle(color: Colors.grey.shade700)),
              const SizedBox(height: 8),
              Text(
                valor,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
