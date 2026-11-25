import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
import 'package:reserva_canchas/core/mapas/mapa_foody.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';
import 'package:reserva_canchas/core/realtime/foody_realtime.dart';
import 'package:reserva_canchas/core/realtime/poll_realtime_respaldo.dart';
import 'package:reserva_canchas/core/sesion/sesion_staff_service.dart';
import 'package:reserva_canchas/features/auth/data/auth_repository.dart';
import 'package:reserva_canchas/features/domiciliarios/data/domiciliarios_independientes_repository.dart';
import 'package:reserva_canchas/features/domiciliarios/presentation/widgets/filtro_fechas_chips.dart';
import 'package:reserva_canchas/features/domiciliarios/presentation/widgets/ganancias_estimadas_resumen.dart';
import 'package:reserva_canchas/features/domiciliarios/presentation/widgets/tarjeta_oferta_in_driver.dart';
import 'package:reserva_canchas/features/domiciliarios/presentation/widgets/tarjeta_pedido_domiciliario.dart';
import 'package:reserva_canchas/features/domiciliarios/services/tracking_ubicacion_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Dashboard repartidor independiente — mapa, activos, ingresos, perfil.
class DashboardDomiciliarioIndependienteScreen extends StatefulWidget {
  const DashboardDomiciliarioIndependienteScreen({super.key});

  @override
  State<DashboardDomiciliarioIndependienteScreen> createState() =>
      _DashboardDomiciliarioIndependienteScreenState();
}

class _DashboardDomiciliarioIndependienteScreenState
    extends State<DashboardDomiciliarioIndependienteScreen> {
  final _repo = DomiciliariosIndependientesRepository();
  final _tracking = TrackingUbicacionService();
  int _nav = 0;
  List<Map<String, dynamic>> _ofertas = [];
  List<Map<String, dynamic>> _pedidos = [];
  List<Map<String, dynamic>> _gananciasItems = [];
  Map<String, dynamic>? _gananciasResumen;
  bool _turnoActivo = false;
  bool _gpsActivo = false;
  bool _cargando = true;
  bool _cargandoGanancias = false;
  String? _error;
  String _nombre = 'Repartidor';
  String? _email;
  String? _domiciliarioId;
  String? _ofertaProcesando;
  int _indiceOferta = 0;
  LatLng? _miUbicacion;
  LatLng? _focoMapa;
  PollRealtimeRespaldo? _pollRespaldo;
  RealtimeChannel? _canalRealtime;
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
    _iniciar();
    _pollRespaldo = PollRealtimeRespaldo(
      onActualizar: () async {
        if (_turnoActivo) await _cargar(silencioso: true);
      },
    );
    unawaited(_pollRespaldo!.iniciar());
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

  Future<void> _iniciar() async {
    final sesion = await SesionStaffService.cargar();
    if (sesion == null) {
      if (mounted) context.go('/domiciliario/login');
      return;
    }
    setState(() {
      _nombre = sesion.usuario['nombre']?.toString() ?? _nombre;
      _email = sesion.usuario['email']?.toString();
    });
    _domiciliarioId = sesion.usuario['id'] as String?;
    if (_domiciliarioId != null) {
      _canalRealtime = FoodyRealtime.suscribirDomiciliarioIndep(
        _domiciliarioId!,
        onActualizado: () => _cargar(silencioso: true),
        onOfertaExpirada: () => _cargar(silencioso: true),
        onPedidoDesasignado: () => _cargar(silencioso: true),
      );
    }
    await _actualizarMiUbicacion();
    await _cargar();
  }

  Future<void> _actualizarMiUbicacion() async {
    try {
      final pos = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() => _miUbicacion = LatLng(pos.latitude, pos.longitude));
    } catch (_) {}
  }

  Future<void> _cargar({bool silencioso = false}) async {
    if (!silencioso) {
      setState(() {
        _cargando = true;
        _error = null;
      });
    }
    try {
      final ofertas = await _repo.ofertasActivas();
      final pedidos = await _repo.pedidosActivos();
      final turno = await _repo.sesionActiva();
      if (!mounted) return;
      var indice = _indiceOferta;
      if (indice >= ofertas.length) indice = 0;
      setState(() {
        _ofertas = ofertas;
        _pedidos = pedidos;
        _turnoActivo = turno || pedidos.isNotEmpty;
        _indiceOferta = indice;
        _cargando = false;
        _focoMapa = _resolverFocoMapa(ofertas, pedidos, indice);
      });
      _sincronizarTracking();
      if (_nav == 2) await _cargarGanancias();
    } catch (e) {
      if (mounted && !silencioso) {
        setState(() {
          _error = mensajeErrorHttp(e, contexto: 'datos');
          _cargando = false;
        });
      }
    }
  }

  Future<void> _cargarGanancias() async {
    setState(() => _cargandoGanancias = true);
    try {
      final data = await _repo.ganancias(
        desde: _filtro.desdeIso,
        hasta: _filtro.hastaIso,
      );
      if (!mounted) return;
      final items = (data['items'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      setState(() {
        _gananciasItems = items;
        _gananciasResumen = data['resumen'] is Map
            ? Map<String, dynamic>.from(data['resumen'] as Map)
            : null;
        _cargandoGanancias = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _cargandoGanancias = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensajeErrorHttp(e, contexto: 'ganancias estimadas')),
          ),
        );
      }
    }
  }

  LatLng? _resolverFocoMapa(
    List<Map<String, dynamic>> ofertas,
    List<Map<String, dynamic>> pedidos,
    int indiceOferta,
  ) {
    Map<String, dynamic>? ref;
    if (pedidos.isNotEmpty) {
      ref = pedidos.first;
    } else if (ofertas.isNotEmpty) {
      final i = indiceOferta.clamp(0, ofertas.length - 1);
      ref = ofertas[i];
    }
    if (ref != null) {
      final lat = _parseCoord(ref['lat']);
      final lng = _parseCoord(ref['lng']);
      if (lat != null && lng != null) return LatLng(lat, lng);
    }
    return _miUbicacion;
  }

  static double? _parseCoord(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse('$v');
  }

  Future<void> _iniciarTurno() async {
    try {
      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
      }
      if (permiso != LocationPermission.always &&
          permiso != LocationPermission.whileInUse) {
        throw Exception('Activa el permiso de ubicación para el turno');
      }
      final pos = await Geolocator.getCurrentPosition();
      await _repo.iniciarSesion(lat: pos.latitude, lng: pos.longitude);
      setState(() {
        _turnoActivo = true;
        _miUbicacion = LatLng(pos.latitude, pos.longitude);
      });
      await _cargar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Conectado — esperando ofertas')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensajeErrorHttp(e, contexto: 'turno'))),
        );
      }
    }
  }

  void _sincronizarTracking() {
    if (!_turnoActivo) {
      _tracking.detener();
      if (mounted) setState(() => _gpsActivo = false);
      return;
    }
    final enCamino = _pedidos.where((p) => '${p['estado']}' == 'en_camino');
    if (enCamino.isEmpty) {
      _tracking.detener();
      if (mounted) setState(() => _gpsActivo = false);
      return;
    }
    final pedidoId = enCamino.first['id'] as String?;
    _tracking.iniciar(
      (lat, lng) => _repo.actualizarUbicacion(
        lat: lat,
        lng: lng,
        pedidoId: pedidoId,
      ),
    );
    if (mounted) setState(() => _gpsActivo = true);
  }

  Future<void> _responder(String ofertaId, String respuesta) async {
    if (_ofertaProcesando != null) return;
    setState(() => _ofertaProcesando = ofertaId);
    try {
      await _repo.responderOferta(ofertaId, respuesta);
      await _cargar();
      if (!mounted) return;
      if (respuesta == 'aceptada') {
        setState(() => _nav = 1);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pedido aceptado — ¡vamos!')),
        );
      }
    } catch (e) {
      if (mounted) {
        final msg = mensajeErrorHttp(e, contexto: 'oferta');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              msg.contains('ya tomó') || msg.contains('ya no')
                  ? 'Otro repartidor aceptó este pedido antes'
                  : msg,
            ),
          ),
        );
        await _cargar(silencioso: true);
      }
    } finally {
      if (mounted) setState(() => _ofertaProcesando = null);
    }
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

  Future<String?> _elegirMetodoPago(Map<String, dynamic> pedido) async {
    final saldoPendiente = num.tryParse('${pedido['saldo_pendiente']}');
    const opciones = [
      ('efectivo', 'Efectivo'),
      ('tarjeta', 'Tarjeta'),
      ('transferencia', 'Transferencia'),
      ('nequi', 'Nequi'),
    ];
    return showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Método de pago al entregar',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  if (saldoPendiente != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Saldo pendiente ${_moneda.format(saldoPendiente)}',
                      ),
                    ),
                ],
              ),
            ),
            for (final op in opciones)
              ListTile(
                title: Text(op.$2),
                onTap: () => Navigator.pop(ctx, op.$1),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _entregar(Map<String, dynamic> pedido) async {
    try {
      var metodo = pedido['metodo_pago'] as String?;
      final requiereApi = pedido['requiere_cobro'];
      final requiereCobro = requiereApi is bool
          ? requiereApi
          : metodo == null || metodo == 'pendiente';
      if (requiereCobro) {
        metodo = await _elegirMetodoPago(pedido);
        if (metodo == null) return;
      }
      await _repo.confirmarEntrega(
        pedido['id'] as String,
        metodoPago: metodo,
      );
      await _cargar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${pedido['numero_pedido']} entregado')),
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

  Future<void> _desconectarTurno() async {
    try {
      await _repo.cerrarSesion();
      _tracking.detener();
      if (!mounted) return;
      setState(() {
        _turnoActivo = false;
        _ofertas = [];
        _indiceOferta = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Turno cerrado — ya no recibes ofertas')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensajeErrorHttp(e, contexto: 'turno'))),
        );
      }
    }
  }

  Future<void> _cerrarSesion() async {
    try {
      if (_turnoActivo) await _repo.cerrarSesion();
    } catch (_) {}
    await AuthRepository().logout();
    if (!mounted) return;
    context.go('/domiciliario/login');
  }

  void _cambiarOferta(int delta) {
    if (_ofertas.length < 2) return;
    setState(() {
      _indiceOferta = (_indiceOferta + delta) % _ofertas.length;
      if (_indiceOferta < 0) _indiceOferta += _ofertas.length;
      _focoMapa = _resolverFocoMapa(_ofertas, _pedidos, _indiceOferta);
    });
  }

  List<MarcadorFoody> _marcadoresMapa() {
    final lista = <MarcadorFoody>[];
    if (_miUbicacion != null) {
      lista.add(MarcadorFoody(
        lat: _miUbicacion!.latitude,
        lng: _miUbicacion!.longitude,
        color: ColoresFoody.primario,
        icono: Icons.two_wheeler,
        etiqueta: 'Tú',
      ));
    }
    for (final o in _ofertas) {
      final lat = _parseCoord(o['lat']);
      final lng = _parseCoord(o['lng']);
      if (lat != null && lng != null) {
        lista.add(MarcadorFoody(
          lat: lat,
          lng: lng,
          color: ColoresFoody.acento,
          icono: Icons.local_offer_outlined,
        ));
      }
    }
    for (final p in _pedidos) {
      final lat = _parseCoord(p['lat']);
      final lng = _parseCoord(p['lng']);
      if (lat != null && lng != null) {
        lista.add(MarcadorFoody(
          lat: lat,
          lng: lng,
          color: ColoresFoody.secundario,
          icono: Icons.person_pin_circle,
        ));
      }
    }
    return lista;
  }

  void _onNav(int i) {
    setState(() => _nav = i);
    if (i == 2) unawaited(_cargarGanancias());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _cargando && _nav == 0
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _nav == 0
              ? Center(
                  child: Card(
                    margin: const EdgeInsets.all(24),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: _cargar,
                            child: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : IndexedStack(
                  index: _nav,
                  children: [
                    _vistaMapaOfertas(),
                    _vistaActivos(),
                    _vistaIngresos(),
                    _vistaPerfil(),
                  ],
                ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _nav,
        onDestinationSelected: _onNav,
        destinations: [
          NavigationDestination(
            icon: Badge(
              isLabelVisible: _ofertas.isNotEmpty,
              label: Text('${_ofertas.length}'),
              child: const Icon(Icons.map_outlined),
            ),
            selectedIcon: const Icon(Icons.map),
            label: 'Ofertas',
          ),
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

  Widget _vistaMapaOfertas() {
    final centro = _focoMapa ?? _miUbicacion ?? const LatLng(10.4631, -73.2532);
    final ofertaVisible = _ofertas.isNotEmpty
        ? _ofertas[_indiceOferta.clamp(0, _ofertas.length - 1)]
        : null;

    return Stack(
      fit: StackFit.expand,
      children: [
        MapaFoody(
          centro: centro,
          zoom: 14,
          marcadores: _marcadoresMapa(),
          mostrarAtribucion: true,
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.35),
                Colors.transparent,
                Colors.black.withValues(alpha: 0.08),
              ],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _nombre,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          shadows: [
                            Shadow(blurRadius: 6, color: Colors.black45),
                          ],
                        ),
                      ),
                      Text(
                        _turnoActivo ? 'En línea' : 'Desconectado',
                        style: TextStyle(
                          color: _turnoActivo
                              ? ColoresFoody.acento
                              : Colors.white70,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          shadows: const [
                            Shadow(blurRadius: 6, color: Colors.black45),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (_gpsActivo)
                  const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Chip(
                      avatar: Icon(Icons.gps_fixed, size: 14),
                      label: Text('GPS', style: TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                IconButton(
                  tooltip: 'Actualizar',
                  onPressed: _cargar,
                  icon: const Icon(Icons.refresh, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
        if (!_turnoActivo)
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Material(
                borderRadius: BorderRadius.circular(16),
                elevation: 8,
                child: ListTile(
                  title: const Text('Conéctate para recibir pedidos'),
                  subtitle: const Text('Activa tu ubicación y disponibilidad'),
                  trailing: FilledButton(
                    onPressed: _iniciarTurno,
                    child: const Text('Conectarme'),
                  ),
                ),
              ),
            ),
          ),
        if (_turnoActivo && ofertaVisible == null && _pedidos.isEmpty)
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Material(
                borderRadius: BorderRadius.circular(16),
                elevation: 8,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.radar,
                        size: 40,
                        color: ColoresFoody.primario.withValues(alpha: 0.7),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Esperando ofertas cercanas…',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Te avisaremos cuando haya un domicilio en tu radio',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (ofertaVisible != null && _pedidos.isEmpty)
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_ofertas.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton.filled(
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: ColoresFoody.primario,
                            ),
                            onPressed: () => _cambiarOferta(-1),
                            icon: const Icon(Icons.chevron_left),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Oferta ${_indiceOferta + 1} de ${_ofertas.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              shadows: [
                                Shadow(blurRadius: 6, color: Colors.black45),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          IconButton.filled(
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: ColoresFoody.primario,
                            ),
                            onPressed: () => _cambiarOferta(1),
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ],
                      ),
                    ),
                  TarjetaOfertaInDriver(
                    oferta: ofertaVisible,
                    indice: _indiceOferta + 1,
                    total: _ofertas.length,
                    procesando:
                        _ofertaProcesando == '${ofertaVisible['oferta_id']}',
                    onExpirada: () => _cargar(silencioso: true),
                    onAceptar: () => _responder(
                      '${ofertaVisible['oferta_id']}',
                      'aceptada',
                    ),
                    onRechazar: () => _responder(
                      '${ofertaVisible['oferta_id']}',
                      'rechazada',
                    ),
                    onVerUbicacion: (lat, lng) {
                      setState(() => _focoMapa = LatLng(lat, lng));
                      mostrarMapaOferta(
                        context,
                        lat: lat,
                        lng: lng,
                        direccion:
                            ofertaVisible['direccion_entrega'] as String?,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        if (_pedidos.isNotEmpty)
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              child: Material(
                borderRadius: BorderRadius.circular(16),
                color: Colors.white,
                child: ListTile(
                  leading: const Icon(Icons.delivery_dining),
                  title: Text(
                    'Tienes ${_pedidos.length} pedido(s) activo(s)',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  trailing: FilledButton(
                    onPressed: () => _onNav(1),
                    child: const Text('Ver'),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _vistaActivos() {
    if (_pedidos.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.delivery_dining_outlined,
                size: 64,
                color: ColoresFoody.primario.withValues(alpha: 0.45),
              ),
              const SizedBox(height: 16),
              const Text(
                'Sin pedidos activos',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Acepta una oferta en el mapa para empezar una entrega',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => _onNav(0),
                child: const Text('Ir a ofertas'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
        itemCount: _pedidos.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final p = _pedidos[i];
          final estado = '${p['estado_asignacion'] ?? p['estado']}';
          return TarjetaPedidoDomiciliario(
            pedido: p,
            mostrarMiniMapa: true,
            mostrarIrRestaurante: true,
            onSalir:
                estado == 'asignado' ? () => _enCamino('${p['id']}') : null,
            onEntregar: estado == 'en_camino' ? () => _entregar(p) : null,
          );
        },
      ),
    );
  }

  Widget _vistaIngresos() {
    final resumen = _gananciasResumen ?? {};
    final total = num.tryParse('${resumen['total_ganancia']}') ?? 0;
    final entregas = resumen['entregas'] ?? _gananciasItems.length;

    return Column(
      children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Estimación de ganancias',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  onPressed: _cargarGanancias,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: FiltroFechasChips(
            seleccionado: _filtro,
            onChanged: (f) {
              setState(() => _filtro = f);
              _cargarGanancias();
            },
          ),
        ),
        if (_cargandoGanancias) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _cargarGanancias,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                GananciasEstimadasResumen(
                  total: total,
                  registros: entregas is num
                      ? entregas.toInt()
                      : int.tryParse('$entregas') ?? _gananciasItems.length,
                ),
                if (_gananciasItems.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Center(
                      child: Text(
                        'Sin ganancias en este rango',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ),
                  )
                else
                  for (final g in _gananciasItems)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(
                          g['numero_pedido'] as String? ?? 'Entrega',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(() {
                          final raw = g['created_at'];
                          final dt = DateTime.tryParse('$raw');
                          final fecha =
                              dt != null ? _fecha.format(dt.toLocal()) : '$raw';
                          final estado = switch (g['estado_asignacion']) {
                            'asignado' => 'Oferta aceptada',
                            'en_camino' => 'En camino',
                            'entregado' => 'Entrega registrada',
                            'cancelado' => 'Asignación cancelada',
                            _ => 'Estado no disponible',
                          };
                          return '$fecha · $estado';
                        }()),
                        trailing: Text(
                          _moneda.format(
                            num.tryParse('${g['ganancia_domiciliario']}') ?? 0,
                          ),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: ColoresFoody.secundario,
                          ),
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _vistaPerfil() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 48, 16, 24),
      children: [
        CircleAvatar(
          radius: 36,
          backgroundColor: ColoresFoody.secundario.withValues(alpha: 0.2),
          child: Text(
            _nombre.isNotEmpty ? _nombre[0].toUpperCase() : 'R',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: ColoresFoody.secundario,
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
        Chip(
          label: Text(_turnoActivo ? 'Turno activo' : 'Fuera de turno'),
          backgroundColor: _turnoActivo
              ? ColoresFoody.exito.withValues(alpha: 0.15)
              : ColoresFoody.grisSuave,
        ),
        const SizedBox(height: 16),
        if (_turnoActivo)
          ListTile(
            leading: const Icon(Icons.power_settings_new),
            title: const Text('Desconectar turno'),
            subtitle: const Text('Dejas de recibir ofertas'),
            onTap: _desconectarTurno,
          )
        else
          ListTile(
            leading: const Icon(Icons.wifi_tethering),
            title: const Text('Iniciar turno'),
            onTap: _iniciarTurno,
          ),
        ListTile(
          leading: const Icon(Icons.badge_outlined),
          title: const Text('Documentos'),
          onTap: () => context.push('/domiciliario/documentos'),
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
}
