import 'dart:async';

import 'package:flutter/material.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_skeleton.dart';
import 'package:intl/intl.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';
import 'package:reserva_canchas/core/utilidades/parsear_numero.dart';
import 'package:reserva_canchas/features/admin/data/dashboard_repository.dart';
import 'package:reserva_canchas/features/admin/data/pedidos_repository.dart';
import 'package:reserva_canchas/features/admin/domain/pedido_admin_model.dart';
import 'package:reserva_canchas/features/alertas/data/alertas_repository.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_tokens.dart';
import 'package:reserva_canchas/features/inventario/data/inventario_repository.dart';
import 'package:reserva_canchas/features/mesa/data/mesas_repository.dart';

/// Dashboard operativo: KPIs del día + acordeones de riesgo
/// (mesas demoradas → domicilio planta → stock → alertas).
class DashboardResumenWidget extends StatefulWidget {
  const DashboardResumenWidget({
    super.key,
    this.sucursalId,
    this.onIrPedidos,
    this.onIrMesas,
    this.onIrAlertas,
    this.onIrCaja,
    this.onIrReportes,
    this.onIrInsumos,
    this.onIrDomiciliarios,
    this.onIrCocinaKds,
  });

  final String? sucursalId;
  final VoidCallback? onIrPedidos;
  final VoidCallback? onIrMesas;
  final VoidCallback? onIrAlertas;
  final VoidCallback? onIrCaja;

  /// Ventas del día = SUM pedidos; navega a Reportes (no Caja).
  final VoidCallback? onIrReportes;
  final VoidCallback? onIrInsumos;
  final VoidCallback? onIrDomiciliarios;
  final VoidCallback? onIrCocinaKds;

  @override
  State<DashboardResumenWidget> createState() => _DashboardResumenWidgetState();
}

class _DashboardResumenWidgetState extends State<DashboardResumenWidget> {
  ColorScheme get _scheme => Theme.of(context).colorScheme;

  final _dash = DashboardRepository();
  final _mesasRepo = MesasRepository();
  final _pedidosRepo = PedidosRepository();
  final _alertasRepo = AlertasRepository();
  final _invRepo = InventarioRepository();

  final _moneda = NumberFormat.currency(
    locale: 'es_CO',
    symbol: r'$',
    decimalDigits: 0,
  );

  // Umbrales alineados a mesas/KDS/alertas existentes.
  static const _qrMin = 3;
  static const _cocinaMin = 20;
  static const _cobroMin = 10;
  static const _domiEnRutaMin = 25;
  static const _domiSinAsignarMin = 8;
  static const _maxFilas = 8;
  // DASH-FRESH / DASH-RT: snapshot + poll (Inicio no usa Realtime).
  static const _pollSeg = 75;

  bool _cargando = true;
  String? _error;
  Map<String, dynamic>? _resumen;
  List<_MesaDemora> _mesas = [];
  List<_DomiTardio> _domicilios = [];
  List<Map<String, dynamic>> _stock = [];
  List<Map<String, dynamic>> _alertas = [];
  DateTime? _actualizadoEn;
  Timer? _poll;

  final Set<String> _abiertos = {'mesas'};

  @override
  void initState() {
    super.initState();
    _cargar();
    _poll = Timer.periodic(
      const Duration(seconds: _pollSeg),
      (_) => _cargar(silencioso: true),
    );
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DashboardResumenWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sucursalId != widget.sucursalId) _cargar();
  }

  Future<void> _cargar({bool silencioso = false}) async {
    final sid = widget.sucursalId;
    if (sid == null) {
      setState(() {
        _cargando = false;
        _error = 'Sin sucursal asignada';
      });
      return;
    }
    if (!silencioso) {
      setState(() {
        _cargando = true;
        _error = null;
      });
    }

    // ponytail: cargas independientes — un 403/cast no tumba todo el centro.
    Map<String, dynamic>? resumen;
    var mesasRaw = <Map<String, dynamic>>[];
    var pedidos = <PedidoAdminModel>[];
    var alertas = <Map<String, dynamic>>[];
    var insumos = <Map<String, dynamic>>[];
    final fallos = <String>[];

    try {
      resumen = await _dash.resumen(sucursalId: sid);
    } catch (e) {
      fallos.add(mensajeErrorHttp(e, contexto: 'resumen'));
    }
    try {
      mesasRaw = await _mesasRepo.listar(sid);
    } catch (e) {
      fallos.add(mensajeErrorHttp(e, contexto: 'mesas'));
    }
    try {
      pedidos = await _pedidosRepo.listarActivos(sucursalId: sid);
    } catch (e) {
      fallos.add(mensajeErrorHttp(e, contexto: 'pedidos'));
    }
    try {
      alertas = await _alertasRepo.listar(sid, soloPendientes: true);
    } catch (e) {
      fallos.add(mensajeErrorHttp(e, contexto: 'alertas'));
    }
    try {
      insumos = await _invRepo.ingredientes(sid);
    } catch (e) {
      fallos.add(mensajeErrorHttp(e, contexto: 'inventario'));
    }

    if (!mounted) return;

    // Solo bloquea UI si falló TODO (ni KPIs ni listas).
    if (resumen == null &&
        mesasRaw.isEmpty &&
        pedidos.isEmpty &&
        alertas.isEmpty &&
        insumos.isEmpty &&
        fallos.isNotEmpty) {
      if (!silencioso) {
        setState(() {
          _cargando = false;
          _error = fallos.first;
        });
      }
      return;
    }

    final mesas = _filtrarMesasDemora(mesasRaw);
    final domis = _filtrarDomiciliosTardios(pedidos);
    final stock = _filtrarStockBajo(insumos);
    final alertasTop = _ordenarAlertas(alertas).take(_maxFilas).toList();

    final abiertos = <String>{};
    if (mesas.isNotEmpty) abiertos.add('mesas');
    if (domis.isNotEmpty) abiertos.add('domicilios');
    if (stock.isNotEmpty) abiertos.add('stock');
    if (abiertos.isEmpty && alertasTop.isNotEmpty) abiertos.add('alertas');
    if (abiertos.isEmpty) abiertos.add('mesas');

    setState(() {
      _resumen = resumen;
      _mesas = mesas;
      _domicilios = domis;
      _stock = stock;
      _alertas = alertasTop;
      _actualizadoEn = DateTime.now();
      if (!silencioso) {
        _abiertos
          ..clear()
          ..addAll(abiertos);
        _cargando = false;
        _error = null;
      }
    });
  }

  List<_MesaDemora> _filtrarMesasDemora(List<Map<String, dynamic>> mesas) {
    final now = DateTime.now();
    final out = <_MesaDemora>[];
    for (final m in mesas) {
      final estado = m['pedido_estado'] as String?;
      if (estado == null) continue;
      final raw = m['pedido_creado_at'];
      final desde = raw != null ? DateTime.tryParse('$raw')?.toLocal() : null;
      if (desde == null) continue;
      final min = now.difference(desde).inMinutes;
      final nombre = m['nombre'] as String? ?? 'Mesa';

      if (estado == 'pendiente_aprobacion' && min >= _qrMin) {
        out.add(_MesaDemora(
          nombre: nombre,
          motivo: 'QR sin aceptar',
          minutos: min,
          severidad: min >= 5 ? 0 : 1,
          mesaId: m['id'] as String?,
        ));
      } else if ((estado == 'confirmado' || estado == 'en_cocina') &&
          min >= _cocinaMin) {
        out.add(_MesaDemora(
          nombre: nombre,
          motivo: 'Pedido en cocina',
          minutos: min,
          severidad: min >= 30 ? 0 : 1,
          mesaId: m['id'] as String?,
        ));
      } else if ((estado == 'listo' || estado == 'pagando') &&
          min >= _cobroMin) {
        out.add(_MesaDemora(
          nombre: nombre,
          motivo: estado == 'pagando' ? 'En cobro' : 'Listo sin cobrar',
          minutos: min,
          severidad: min >= 20 ? 0 : 1,
          mesaId: m['id'] as String?,
        ));
      }
    }
    out.sort((a, b) {
      final s = a.severidad.compareTo(b.severidad);
      if (s != 0) return s;
      return b.minutos.compareTo(a.minutos);
    });
    return out.take(_maxFilas).toList();
  }

  List<_DomiTardio> _filtrarDomiciliosTardios(List<PedidoAdminModel> pedidos) {
    final now = DateTime.now();
    final out = <_DomiTardio>[];
    for (final p in pedidos) {
      if (p.tipo != 'domicilio') continue;
      // planta: tienen domiciliario_nombre o van a asignarse en sede
      final min = now.difference(p.estadoDesde.toLocal()).inMinutes;
      if (p.estado == 'listo' && min >= _domiSinAsignarMin) {
        out.add(_DomiTardio(
          numero: p.numeroPedido,
          detalle: p.domiciliarioNombre?.isNotEmpty == true
              ? 'Listo · ${p.domiciliarioNombre}'
              : 'Listo · sin asignar',
          minutos: min,
          severidad: 0,
        ));
      } else if ((p.estado == 'asignado' || p.estado == 'en_camino') &&
          min >= _domiEnRutaMin) {
        out.add(_DomiTardio(
          numero: p.numeroPedido,
          detalle: p.domiciliarioNombre?.isNotEmpty == true
              ? '${_estadoDomi(p.estado)} · ${p.domiciliarioNombre}'
              : _estadoDomi(p.estado),
          minutos: min,
          severidad: min >= 40 ? 0 : 1,
        ));
      }
    }
    out.sort((a, b) {
      final s = a.severidad.compareTo(b.severidad);
      if (s != 0) return s;
      return b.minutos.compareTo(a.minutos);
    });
    return out.take(_maxFilas).toList();
  }

  String _estadoDomi(String e) => switch (e) {
        'asignado' => 'Asignado',
        'en_camino' => 'En camino',
        _ => e,
      };

  List<Map<String, dynamic>> _filtrarStockBajo(
    List<Map<String, dynamic>> insumos,
  ) {
    // stock_* llega como String desde Postgres numeric (ej. "20.000").
    final bajos = insumos.where((i) {
      if (i['bajo_minimo'] == true) return true;
      final actual = parsearDouble(i['stock_actual']);
      final minimo = parsearDouble(i['stock_minimo']);
      return minimo > 0 && actual <= minimo;
    }).toList();
    bajos.sort((a, b) {
      final aa = parsearDouble(a['stock_actual']);
      final am = parsearDouble(a['stock_minimo'], porDefecto: 1);
      final ba = parsearDouble(b['stock_actual']);
      final bm = parsearDouble(b['stock_minimo'], porDefecto: 1);
      final ra = am == 0 ? 0.0 : aa / am;
      final rb = bm == 0 ? 0.0 : ba / bm;
      return ra.compareTo(rb);
    });
    return bajos.take(_maxFilas).toList();
  }

  List<Map<String, dynamic>> _ordenarAlertas(
    List<Map<String, dynamic>> alertas,
  ) {
    int rank(String? n) => switch (n) {
          'critico' => 0,
          'alto' => 1,
          'medio' => 2,
          'bajo' => 3,
          _ => 4,
        };
    final copy = List<Map<String, dynamic>>.from(alertas);
    copy.sort((a, b) {
      final r =
          rank(a['nivel'] as String?).compareTo(rank(b['nivel'] as String?));
      if (r != 0) return r;
      final ca = DateTime.tryParse('${a['created_at']}') ?? DateTime(1970);
      final cb = DateTime.tryParse('${b['created_at']}') ?? DateTime(1970);
      return cb.compareTo(ca);
    });
    return copy;
  }

  void _toggle(String id) {
    setState(() {
      if (_abiertos.contains(id)) {
        _abiertos.remove(id);
      } else {
        _abiertos.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(),
        const SizedBox(height: 12),
        if (_cargando)
          AnaliticaSkeleton.seccion(etiqueta: 'Cargando resumen de operación')
        else if (_error != null)
          _errorBox()
        else ...[
          _kpis(),
          const SizedBox(height: 16),
          _acordeon(
            id: 'mesas',
            titulo: 'Mesas con demora',
            subtitulo: 'QR, cocina o cobro por encima del umbral',
            icono: Icons.table_restaurant_outlined,
            count: _mesas.length,
            colorCount: AnaliticaTokens.alertas,
            onVerTodo: widget.onIrMesas,
            verTodoLabel: 'Ver salón',
            hijo: _mesas.isEmpty
                ? _vacioAcordeon('Ninguna mesa demorada ahora')
                : Column(
                    children: [
                      for (final m in _mesas) _filaMesa(m),
                    ],
                  ),
          ),
          const SizedBox(height: 10),
          _acordeon(
            id: 'domicilios',
            titulo: 'Domicilios planta',
            subtitulo: 'Sin asignar o en ruta más de lo estimado',
            icono: Icons.delivery_dining_outlined,
            count: _domicilios.length,
            colorCount: AnaliticaTokens.domicilio,
            onVerTodo: widget.onIrDomiciliarios ?? widget.onIrPedidos,
            verTodoLabel: 'Ver domicilio',
            hijo: _domicilios.isEmpty
                ? _vacioAcordeon('Sin domicilios tardíos de planta')
                : Column(
                    children: [
                      for (final d in _domicilios) _filaDomi(d),
                    ],
                  ),
          ),
          const SizedBox(height: 10),
          _acordeon(
            id: 'stock',
            titulo: 'Stock bajo',
            subtitulo: 'Insumos en o bajo el mínimo',
            icono: Icons.inventory_2_outlined,
            count: _stock.length,
            colorCount: const Color(0xFFD97706),
            onVerTodo: widget.onIrInsumos,
            verTodoLabel: 'Ver insumos',
            hijo: _stock.isEmpty
                ? _vacioAcordeon('Inventario sin alertas de mínimo')
                : Column(
                    children: [
                      for (final s in _stock) _filaStock(s),
                    ],
                  ),
          ),
          const SizedBox(height: 10),
          _acordeon(
            id: 'alertas',
            titulo: 'Alertas',
            subtitulo: 'Las más graves primero (crítico → bajo)',
            icono: Icons.notifications_active_outlined,
            count: _alertas.length,
            colorCount: AnaliticaTokens.alertas,
            onVerTodo: widget.onIrAlertas,
            verTodoLabel: 'Ver todas',
            hijo: _alertas.isEmpty
                ? _vacioAcordeon('Sin alertas pendientes')
                : Column(
                    children: [
                      for (final a in _alertas) _filaAlerta(a),
                    ],
                  ),
          ),
        ],
      ],
    );
  }

  Widget _header() {
    final hora = _actualizadoEn != null
        ? DateFormat('HH:mm').format(_actualizadoEn!)
        : null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Centro de operación',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: _scheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                hora == null
                    ? 'Solo lo que requiere atención ahora'
                    : 'Actualizado $hora · refresco cada ${_pollSeg}s (no en vivo)',
                style: TextStyle(
                  fontSize: 13,
                  color: _scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Actualizar',
          onPressed: _cargando ? null : _cargar,
          icon: Icon(Icons.refresh, color: _scheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _kpis() {
    final d = _resumen ?? {};
    final qrPend = parsearNumero(d['pedidos_pendientes_qr']).toInt();
    final items = [
      _Kpi(
        'Ventas hoy',
        _moneda.format(d['ventas_hoy'] ?? 0),
        AnaliticaTokens.ventas,
        widget.onIrReportes ?? widget.onIrCaja,
      ),
      _Kpi(
        'Activos',
        '${d['pedidos_activos'] ?? 0}',
        AnaliticaTokens.pedidos,
        widget.onIrPedidos,
      ),
      _Kpi(
        'Cerrados hoy',
        '${d['pedidos_completados_hoy'] ?? 0}',
        AnaliticaTokens.inventario,
        widget.onIrPedidos,
      ),
      _Kpi(
        'QR pendientes',
        '$qrPend',
        AnaliticaTokens.clientes,
        widget.onIrMesas,
      ),
      _Kpi(
        'Alertas',
        '${d['alertas_pendientes'] ?? _alertas.length}',
        AnaliticaTokens.alertas,
        widget.onIrAlertas,
      ),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 900
            ? 5
            : c.maxWidth >= 720
                ? 3
                : 2;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final k in items)
              SizedBox(
                width: (c.maxWidth - 8 * (cols - 1)) / cols,
                child: _kpiCard(k),
              ),
          ],
        );
      },
    );
  }

  Widget _kpiCard(_Kpi k) {
    return Material(
      color: _scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
      child: InkWell(
        onTap: k.onTap,
        borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
            border: Border.all(color: _scheme.outlineVariant),
            boxShadow: AnaliticaTokens.shadowSoft,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.circle, size: 7, color: k.color),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        k.titulo,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  k.valor,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: _scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _acordeon({
    required String id,
    required String titulo,
    required String subtitulo,
    required IconData icono,
    required int count,
    required Color colorCount,
    required Widget hijo,
    VoidCallback? onVerTodo,
    String? verTodoLabel,
  }) {
    final abierto = _abiertos.contains(id);
    return Material(
      color: _scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
          border: Border.all(
            color: count > 0
                ? colorCount.withValues(alpha: 0.28)
                : _scheme.outlineVariant,
          ),
          boxShadow: AnaliticaTokens.shadowSoft,
        ),
        child: Column(
          children: [
            InkWell(
              onTap: () => _toggle(id),
              borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: colorCount.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icono, size: 20, color: colorCount),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            titulo,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: _scheme.onSurface,
                            ),
                          ),
                          Text(
                            subtitulo,
                            style: TextStyle(
                              fontSize: 12,
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
                        color: count > 0
                            ? colorCount.withValues(alpha: 0.12)
                            : _scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'monospace',
                          color:
                              count > 0 ? colorCount : _scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Icon(
                      abierto ? Icons.expand_less : Icons.expand_more,
                      color: _scheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
            if (abierto) ...[
              Divider(height: 1, color: _scheme.outlineVariant),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                child: hijo,
              ),
              if (onVerTodo != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: onVerTodo,
                    style: TextButton.styleFrom(
                      foregroundColor: _scheme.onSurfaceVariant,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text(verTodoLabel ?? 'Ver más'),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _vacioAcordeon(String texto) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_outline,
            size: 18,
            color: AnaliticaTokens.inventario,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(
                fontSize: 13,
                color: _scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filaMesa(_MesaDemora m) {
    final aCocina = m.motivo.contains('cocina');
    return _filaBase(
      titulo: m.nombre,
      subtitulo: m.motivo,
      trailing: _badgeMin(m.minutos, grave: m.severidad == 0),
      onTap: aCocina
          ? (widget.onIrCocinaKds ?? widget.onIrMesas)
          : widget.onIrMesas,
    );
  }

  Widget _filaDomi(_DomiTardio d) {
    return _filaBase(
      titulo: d.numero,
      subtitulo: d.detalle,
      trailing: _badgeMin(d.minutos, grave: d.severidad == 0),
      onTap: widget.onIrDomiciliarios ?? widget.onIrPedidos,
    );
  }

  Widget _filaStock(Map<String, dynamic> s) {
    final nombre = s['nombre'] as String? ?? 'Insumo';
    final actual = s['stock_actual'];
    final minimo = s['stock_minimo'];
    final unidad = s['unidad'] as String? ?? '';
    return _filaBase(
      titulo: nombre,
      subtitulo: 'Stock $actual $unidad · mín. $minimo',
      trailing: const Icon(
        Icons.warning_amber_rounded,
        size: 18,
        color: Color(0xFFD97706),
      ),
      onTap: widget.onIrInsumos,
    );
  }

  Widget _filaAlerta(Map<String, dynamic> a) {
    final nivel = a['nivel'] as String? ?? '';
    final tipo = a['tipo'] as String? ?? '';
    final desc = a['descripcion'] as String? ?? tipo;
    return _filaBase(
      titulo: desc,
      subtitulo: _etiquetaTipo(tipo),
      trailing: _badgeNivel(nivel),
      onTap: widget.onIrAlertas,
    );
  }

  Widget _filaBase({
    required String titulo,
    required String subtitulo,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: _scheme.onSurface,
                      ),
                    ),
                    Text(
                      subtitulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: _scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing,
            ],
          ),
        ),
      ),
    );
  }

  Widget _badgeMin(int min, {required bool grave}) {
    final color = grave ? AnaliticaTokens.alertas : const Color(0xFFD97706);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '${min}m',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          fontFamily: 'monospace',
          color: color,
        ),
      ),
    );
  }

  Widget _badgeNivel(String nivel) {
    final color = switch (nivel) {
      'critico' || 'alto' => AnaliticaTokens.alertas,
      'medio' => const Color(0xFFD97706),
      _ => _scheme.onSurfaceVariant,
    };
    final label = switch (nivel) {
      'critico' => 'Crítico',
      'alto' => 'Alto',
      'medio' => 'Medio',
      'bajo' => 'Bajo',
      _ => nivel,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  String _etiquetaTipo(String tipo) => switch (tipo) {
        'demora_cocina' => 'Demora cocina',
        'demora_excesiva_entrega' => 'Demora entrega',
        'stock_minimo_alcanzado' => 'Stock mínimo',
        'salio_sin_pagar' => 'Salió sin pagar',
        'intento_pedido_sin_stock' => 'Sin stock',
        _ => tipo.replaceAll('_', ' '),
      };

  Widget _errorBox() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
        border: Border.all(color: _scheme.outlineVariant),
      ),
      child: Column(
        children: [
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: _scheme.onSurface),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _cargar,
            style: FilledButton.styleFrom(
              backgroundColor: _scheme.primary,
              foregroundColor: _scheme.onPrimary,
            ),
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}

class _Kpi {
  const _Kpi(this.titulo, this.valor, this.color, this.onTap);
  final String titulo;
  final String valor;
  final Color color;
  final VoidCallback? onTap;
}

class _MesaDemora {
  const _MesaDemora({
    required this.nombre,
    required this.motivo,
    required this.minutos,
    required this.severidad,
    this.mesaId,
  });
  final String nombre;
  final String motivo;
  final int minutos;
  final int severidad;
  final String? mesaId;
}

class _DomiTardio {
  const _DomiTardio({
    required this.numero,
    required this.detalle,
    required this.minutos,
    required this.severidad,
  });
  final String numero;
  final String detalle;
  final int minutos;
  final int severidad;
}
