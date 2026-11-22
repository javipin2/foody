import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
import 'package:reserva_canchas/core/mapas/mapa_foody.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';
import 'package:reserva_canchas/core/realtime/foody_realtime.dart';
import 'package:reserva_canchas/core/realtime/poll_realtime_respaldo.dart';
import 'package:reserva_canchas/core/rutas/redireccion_staff.dart';
import 'package:reserva_canchas/core/sesion/sesion_staff_service.dart';
import 'package:reserva_canchas/features/domiciliarios/data/domiciliarios_repository.dart';
import 'package:reserva_canchas/features/domiciliarios/presentation/widgets/filtro_fechas_chips.dart';
import 'package:reserva_canchas/features/domiciliarios/presentation/widgets/tarjeta_pedido_domiciliario.dart';
import 'package:reserva_canchas/features/domiciliarios/services/tracking_ubicacion_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Dashboard domiciliario de planta — app repartidor (activos, historial, ingresos, perfil).
class DashboardDomiciliarioScreen extends StatefulWidget {
  const DashboardDomiciliarioScreen({
    super.key,
    this.pedidoIdInicial,
  });

  final String? pedidoIdInicial;

  @override
  State<DashboardDomiciliarioScreen> createState() =>
      _DashboardDomiciliarioScreenState();
}

class _DashboardDomiciliarioScreenState extends State<DashboardDomiciliarioScreen> {
  final _repo = DomiciliariosRepository();
  final _tracking = TrackingUbicacionService();
  int _nav = 0;
  List<Map<String, dynamic>> _pedidos = [];
  List<Map<String, dynamic>> _historial = [];
  Map<String, dynamic>? _stats;
  bool _cargando = true;
  String? _error;
  String _nombre = 'Domiciliario';
  String? _email;
  String? _usuarioId;
  bool _gpsActivo = false;
  RealtimeChannel? _canalRealtime;
  PollRealtimeRespaldo? _pollRespaldo;
  Set<String> _idsPedidosVistos = {};
  bool _primerCarga = true;
  FiltroFechasResultado _filtro =
      const FiltroFechasResultado(rango: RangoFechasDomi.hoy);

  final _moneda = NumberFormat.currency(
    locale: 'es_CO',
    symbol: r'$',
    decimalDigits: 0,
  );
  final _fecha = DateFormat('d MMM · HH:mm', 'es_CO');

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  Future<void> _inicializar() async {
    final sesion = await SesionStaffService.cargar();
    _usuarioId = sesion?.usuario['id'] as String?;
    _email = sesion?.usuario['email']?.toString();
    await _cargar();
    if (_usuarioId != null) {
      _canalRealtime = FoodyRealtime.suscribirDomiciliarioPlanta(
        _usuarioId!,
        onActualizado: () => _cargar(silencioso: true),
        onDesasignado: () => _cargar(silencioso: true),
        onReconectado: () => _cargar(silencioso: true),
      );
      // RT-FALL-01: unificar con PollRealtimeRespaldo (antes Timer 60s fijo).
      _pollRespaldo = PollRealtimeRespaldo(
        onActualizar: () => _cargar(silencioso: true),
      );
      unawaited(_pollRespaldo!.iniciar());
    }
  }

  @override
  void dispose() {
    _pollRespaldo?.detener();
    _tracking.detener();
    if (_canalRealtime != null) {
      Supabase.instance.client.removeChannel(_canalRealtime!);
    }
    super.dispose();
  }

  Future<void> _cargar({bool silencioso = false}) async {
    if (!silencioso) {
      setState(() {
        _cargando = true;
        _error = null;
      });
    }
    try {
      final sesion = await SesionStaffService.cargar();
      final desde = _filtro.desdeIso;
      final hasta = _filtro.hastaIso;
      final pedidos = await _repo.pedidosAsignados();
      final historial = await _repo.historialEntregas(
        desde: desde,
        hasta: hasta,
      );
      final stats = await _repo.estadisticasPlanta(
        desde: desde,
        hasta: hasta,
      );
      if (mounted) {
        final idsNuevos = pedidos
            .map((p) => '${p['id']}')
            .where((id) => id.isNotEmpty)
            .toSet();
        final recien = idsNuevos.difference(_idsPedidosVistos);
        setState(() {
          _nombre = sesion?.usuario['nombre']?.toString() ?? _nombre;
          _email = sesion?.usuario['email']?.toString() ?? _email;
          _pedidos = pedidos;
          _historial = historial;
          _stats = stats;
          _cargando = false;
          _idsPedidosVistos = idsNuevos;
        });
        _sincronizarTracking();
        if (!_primerCarga && recien.isNotEmpty && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                recien.length == 1
                    ? 'Nueva entrega asignada'
                    : '${recien.length} nuevas entregas asignadas',
              ),
            ),
          );
          setState(() => _nav = 0);
        }
        _primerCarga = false;
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = mensajeErrorHttp(e, contexto: 'dashboard domiciliario');
          _cargando = false;
        });
      }
    }
  }

  void _sincronizarTracking() {
    final enCamino = _pedidos.where((p) {
      final est = p['estado'] as String? ?? '';
      final asig = p['estado_asignacion'] as String? ?? '';
      return est == 'en_camino' || asig == 'en_camino';
    }).toList();

    if (enCamino.isEmpty) {
      _tracking.detener();
      if (mounted) setState(() => _gpsActivo = false);
      return;
    }

    final pedidoId = enCamino.first['id'] as String?;
    _tracking.iniciar(
      (lat, lng) => _repo.registrarUbicacion(
        lat: lat,
        lng: lng,
        pedidoId: pedidoId,
      ),
    );
    if (mounted) setState(() => _gpsActivo = true);
  }

  Future<void> _cerrarSesion() async {
    await cerrarSesionStaff(context);
  }

  Future<void> _enCamino(String pedidoId) async {
    try {
      await _repo.marcarEnCamino(pedidoId);
      await _cargar();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensajeErrorHttp(e, contexto: 'salida'))),
        );
      }
    }
  }

  Future<void> _entregar(Map<String, dynamic> pedido) async {
    final metodoOriginal = pedido['metodo_pago'] as String?;
    final yaPagado =
        metodoOriginal != null && metodoOriginal != 'pendiente';
    final cobro = yaPagado
        ? (metodo: metodoOriginal, metodoDomicilio: null)
        : await _elegirCobro(pedido);
    if (cobro == null) return;

    try {
      await _repo.confirmarEntrega(
        pedido['id'] as String,
        metodoPago: cobro.metodo,
        metodoPagoDomicilio: cobro.metodoDomicilio,
      );
      await _cargar();
      if (mounted) {
        final aCuenta = cobro.metodo == 'pendiente_liquidacion';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              aCuenta
                  ? '${pedido['numero_pedido']} entregado — queda a tu cuenta'
                  : '${pedido['numero_pedido']} entregado',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensajeErrorHttp(e, contexto: 'entrega'))),
        );
      }
    }
  }

  Future<({String metodo, String? metodoDomicilio})?> _elegirCobro(
    Map<String, dynamic> pedido,
  ) async {
    final permiteFiado = pedido['permite_fiado_domiciliario'] == true;
    final costoDom = num.tryParse('${pedido['costo_domicilio']}') ?? 0;
    final total = num.tryParse('${pedido['total']}') ?? 0;
    final producto =
        num.tryParse('${pedido['subtotal']}') ?? (total - costoDom);

    const metodos = [
      ('efectivo', 'Efectivo', Icons.payments),
      ('tarjeta', 'Tarjeta', Icons.credit_card),
      ('transferencia', 'Transferencia', Icons.account_balance),
      ('nequi', 'Nequi', Icons.phone_android),
    ];

    return showModalBottomSheet<({String metodo, String? metodoDomicilio})>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        var metodoProd = 'efectivo';
        var metodoDom = 'efectivo';
        var mixto = false;
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            Widget chips(
              String seleccionado,
              ValueChanged<String> onSel,
            ) {
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final m in metodos)
                    ChoiceChip(
                      label: Text(m.$2),
                      selected: seleccionado == m.$1,
                      onSelected: (_) => setLocal(() => onSel(m.$1)),
                      avatar: Icon(m.$3, size: 16),
                    ),
                ],
              );
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: MediaQuery.viewInsetsOf(ctx).bottom + 16,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Cobro · ${pedido['numero_pedido'] ?? ''}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Producto ${_moneda.format(producto)}'
                        '${costoDom > 0 ? ' · Domicilio ${_moneda.format(costoDom)}' : ''}'
                        ' · Total ${_moneda.format(total)}',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        mixto ? 'Pago del producto' : 'Método de pago',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      chips(metodoProd, (v) => metodoProd = v),
                      if (costoDom > 0) ...[
                        const SizedBox(height: 12),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Pago mixto'),
                          subtitle: const Text(
                            'Producto y domicilio con métodos distintos',
                          ),
                          value: mixto,
                          onChanged: (v) => setLocal(() => mixto = v),
                        ),
                        if (mixto) ...[
                          const Text(
                            'Pago del domicilio',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          chips(metodoDom, (v) => metodoDom = v),
                        ],
                      ],
                      if (permiteFiado) ...[
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () => Navigator.pop(ctx, (
                            metodo: 'pendiente_liquidacion',
                            metodoDomicilio: null,
                          )),
                          icon: const Icon(Icons.schedule),
                          label: const Text('Dejar a mi cuenta'),
                        ),
                      ],
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, (
                          metodo: metodoProd,
                          metodoDomicilio: mixto ? metodoDom : null,
                        )),
                        style: FilledButton.styleFrom(
                          backgroundColor: ColoresFoody.secundario,
                          minimumSize: const Size.fromHeight(48),
                        ),
                        child: const Text('Confirmar cobro'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  double get _saldoPorLiquidar =>
      num.tryParse('${_stats?['saldo_por_liquidar']}')?.toDouble() ?? 0;

  String get _tituloNav {
    switch (_nav) {
      case 1:
        return 'Historial';
      case 2:
        return 'Ingresos';
      case 3:
        return 'Perfil';
      default:
        return 'Mi ruta';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_tituloNav),
        actions: [
          if (_gpsActivo)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Chip(
                avatar: Icon(Icons.gps_fixed, size: 14),
                label: Text('GPS', style: TextStyle(fontSize: 11)),
                visualDensity: VisualDensity.compact,
              ),
            ),
          if (_nav != 3)
            IconButton(
              tooltip: 'Actualizar',
              onPressed: _cargar,
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: _cargando
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
              : Column(
                  children: [
                    if (_saldoPorLiquidar > 0 && _nav != 3)
                      Material(
                        color: ColoresFoody.acento.withValues(alpha: 0.35),
                        child: ListTile(
                          dense: true,
                          leading: const Icon(
                            Icons.account_balance_wallet_outlined,
                          ),
                          title: Text(
                            'Por liquidar ${_moneda.format(_saldoPorLiquidar)}',
                          ),
                          subtitle: const Text(
                            'Entrégalo en caja al volver al local',
                          ),
                        ),
                      ),
                    Expanded(
                      child: IndexedStack(
                        index: _nav,
                        children: [
                          _tabActivos(),
                          _tabHistorial(),
                          _tabIngresos(),
                          _tabPerfil(),
                        ],
                      ),
                    ),
                  ],
                ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _nav,
        onDestinationSelected: (i) => setState(() => _nav = i),
        destinations: [
          NavigationDestination(
            icon: Badge(
              isLabelVisible: _pedidos.isNotEmpty,
              label: Text('${_pedidos.length}'),
              child: const Icon(Icons.delivery_dining_outlined),
            ),
            selectedIcon: const Icon(Icons.delivery_dining),
            label: 'Activos',
          ),
          const NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'Historial',
          ),
          const NavigationDestination(
            icon: Icon(Icons.payments_outlined),
            selectedIcon: Icon(Icons.payments),
            label: 'Ingresos',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }

  LatLng? _centroMapaPlanta() {
    for (final p in _pedidos) {
      final lat = p['lat'];
      final lng = p['lng'];
      final latNum = lat is num ? lat.toDouble() : double.tryParse('$lat');
      final lngNum = lng is num ? lng.toDouble() : double.tryParse('$lng');
      if (latNum != null && lngNum != null) return LatLng(latNum, lngNum);
    }
    return const LatLng(10.4631, -73.2532);
  }

  List<MarcadorFoody> _marcadoresPlanta() {
    return _pedidos
        .map((p) {
          final lat = p['lat'];
          final lng = p['lng'];
          final latNum = lat is num ? lat.toDouble() : double.tryParse('$lat');
          final lngNum = lng is num ? lng.toDouble() : double.tryParse('$lng');
          if (latNum == null || lngNum == null) return null;
          final enCamino = '${p['estado']}' == 'en_camino' ||
              '${p['estado_asignacion']}' == 'en_camino';
          return MarcadorFoody(
            lat: latNum,
            lng: lngNum,
            color: enCamino ? ColoresFoody.primario : ColoresFoody.secundario,
            icono: Icons.person_pin_circle,
            etiqueta: p['numero_pedido'] as String?,
          );
        })
        .whereType<MarcadorFoody>()
        .toList();
  }

  String _estadoPedido(Map<String, dynamic> p) {
    final asig = p['estado_asignacion'] as String?;
    if (asig != null && asig.isNotEmpty) return asig;
    return p['estado'] as String? ?? '';
  }

  Widget _listaPaneles({ScrollController? scrollController}) {
    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      itemCount: _pedidos.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final p = _pedidos[i];
        final estado = _estadoPedido(p);
        final destacado = widget.pedidoIdInicial != null &&
            '${p['id']}' == widget.pedidoIdInicial;
        return DecoratedBox(
          decoration: destacado
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: ColoresFoody.primario, width: 2),
                )
              : const BoxDecoration(),
          child: TarjetaPedidoDomiciliario(
            pedido: p,
            mostrarMiniMapa: false,
            onSalir: estado == 'asignado'
                ? () => _enCamino(p['id'] as String)
                : null,
            onEntregar:
                estado == 'en_camino' ? () => _entregar(p) : null,
          ),
        );
      },
    );
  }

  Widget _mapaFondo() {
    return Stack(
      fit: StackFit.expand,
      children: [
        MapaFoody(
          centro: _centroMapaPlanta()!,
          zoom: 13,
          marcadores: _marcadoresPlanta(),
          mostrarAtribucion: true,
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.25),
                Colors.transparent,
                Colors.black.withValues(alpha: 0.06),
              ],
            ),
          ),
        ),
        Positioned(
          top: 8,
          left: 12,
          right: 12,
          child: SafeArea(
            bottom: false,
            child: Text(
              'Hola, $_nombre · ${_pedidos.length} activo(s)',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                shadows: [Shadow(blurRadius: 6, color: Colors.black45)],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _estadoVacio({
    required IconData icono,
    required String titulo,
    required String subtitulo,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 64, color: ColoresFoody.primario.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              subtitulo,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabActivos() {
    if (_pedidos.isEmpty) {
      return RefreshIndicator(
        onRefresh: _cargar,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.55,
              child: _estadoVacio(
                icono: Icons.two_wheeler_outlined,
                titulo: 'Sin entregas pendientes',
                subtitulo: 'Cuando el restaurante te asigne un pedido aparecerá aquí',
              ),
            ),
          ],
        ),
      );
    }

    final ancho = MediaQuery.sizeOf(context).width;
    if (ancho >= 720) {
      return Row(
        children: [
          Expanded(flex: 3, child: _mapaFondo()),
          SizedBox(
            width: ancho.clamp(320, 440),
            child: Material(
              elevation: 8,
              child: RefreshIndicator(
                onRefresh: _cargar,
                child: _listaPaneles(),
              ),
            ),
          ),
        ],
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        _mapaFondo(),
        DraggableScrollableSheet(
          initialChildSize: 0.45,
          minChildSize: 0.28,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            return Material(
              elevation: 12,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              clipBehavior: Clip.antiAlias,
              child: RefreshIndicator(
                onRefresh: _cargar,
                child: _listaPaneles(scrollController: scrollController),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _tabHistorial() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: FiltroFechasChips(
            seleccionado: _filtro,
            onChanged: (f) {
              setState(() => _filtro = f);
              _cargar();
            },
          ),
        ),
        Expanded(
          child: _historial.isEmpty
              ? RefreshIndicator(
                  onRefresh: _cargar,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: 280,
                        child: _estadoVacio(
                          icono: Icons.receipt_long_outlined,
                          titulo: 'Sin entregas en este rango',
                          subtitulo: 'Cambia el filtro de fechas o completa una entrega',
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _historial.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final h = _historial[i];
                      final total = h['total'];
                      final metodo = h['metodo_pago'];
                      final fecha = h['entregado_at'] ?? h['asignado_at'];
                      String? fechaTxt;
                      if (fecha != null) {
                        final dt = DateTime.tryParse('$fecha');
                        if (dt != null) fechaTxt = _fecha.format(dt.toLocal());
                      }
                      return Card(
                        elevation: 0,
                        color: ColoresFoody.grisSuave,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: ListTile(
                          title: Text(
                            h['numero_pedido'] as String? ?? '',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            [
                              h['cliente_nombre'] ?? '',
                              if (h['direccion_entrega'] != null)
                                h['direccion_entrega'],
                              if (fechaTxt != null) fechaTxt,
                              if (metodo != null) '$metodo',
                            ].where((e) => '$e'.trim().isNotEmpty).join(' · '),
                          ),
                          isThreeLine: true,
                          trailing: Text(
                            _moneda.format(
                              total is num
                                  ? total
                                  : num.tryParse('$total') ?? 0,
                            ),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _tabIngresos() {
    final s = _stats ?? {};
    final cobrado = num.tryParse('${s['total_cobrado_rango']}') ?? 0;
    final rango = s['entregas_rango'] ?? 0;
    final hoy = s['entregas_hoy'] ?? 0;
    final semana = s['entregas_semana'] ?? 0;
    final mes = s['entregas_mes'] ?? 0;
    final prom = s['tiempo_promedio_min'];

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FiltroFechasChips(
            seleccionado: _filtro,
            onChanged: (f) {
              setState(() => _filtro = f);
              _cargar();
            },
          ),
          const SizedBox(height: 16),
          Card(
            color: ColoresFoody.primario.withValues(alpha: 0.08),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cobrado en el rango',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _moneda.format(cobrado),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text('$rango entrega(s)'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _statCard('Entregas hoy', '$hoy', Icons.today),
          _statCard('Esta semana', '$semana', Icons.date_range),
          _statCard('Este mes', '$mes', Icons.calendar_month),
          if (prom != null)
            _statCard('Promedio entrega', '$prom min', Icons.timer_outlined),
          if (_saldoPorLiquidar > 0)
            _statCard(
              'Por liquidar',
              _moneda.format(_saldoPorLiquidar),
              Icons.account_balance_wallet_outlined,
            ),
        ],
      ),
    );
  }

  Widget _tabPerfil() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        CircleAvatar(
          radius: 36,
          backgroundColor: ColoresFoody.primario.withValues(alpha: 0.15),
          child: Text(
            _nombre.isNotEmpty ? _nombre[0].toUpperCase() : 'D',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: ColoresFoody.primario,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _nombre,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        if (_email != null)
          Text(_email!, style: TextStyle(color: Colors.grey.shade700)),
        const SizedBox(height: 8),
        const Chip(label: Text('Domiciliario de planta')),
        const SizedBox(height: 24),
        ListTile(
          leading: const Icon(Icons.refresh),
          title: const Text('Actualizar datos'),
          onTap: _cargar,
        ),
        ListTile(
          leading: Icon(Icons.logout, color: ColoresFoody.error),
          title: Text(
            'Cerrar sesión',
            style: TextStyle(color: ColoresFoody.error),
          ),
          onTap: _cerrarSesion,
        ),
      ],
    );
  }

  Widget _statCard(String titulo, String valor, IconData icono) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: ColoresFoody.primario.withValues(alpha: 0.12),
          child: Icon(icono, color: ColoresFoody.primario),
        ),
        title: Text(titulo),
        trailing: Text(
          valor,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
