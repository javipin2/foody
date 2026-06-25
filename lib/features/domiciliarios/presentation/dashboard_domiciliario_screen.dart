import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';
import 'package:reserva_canchas/core/realtime/foody_realtime.dart';
import 'package:reserva_canchas/core/sesion/sesion_staff_service.dart';
import 'package:latlong2/latlong.dart';
import 'package:reserva_canchas/core/mapas/mapa_foody.dart';
import 'package:reserva_canchas/core/mapas/utilidad_navegacion.dart';
import 'package:reserva_canchas/features/domiciliarios/data/domiciliarios_repository.dart';

/// Dashboard domiciliario de planta — activos, historial y estadísticas.
class DashboardDomiciliarioScreen extends StatefulWidget {
  const DashboardDomiciliarioScreen({super.key});

  @override
  State<DashboardDomiciliarioScreen> createState() =>
      _DashboardDomiciliarioScreenState();
}

class _DashboardDomiciliarioScreenState extends State<DashboardDomiciliarioScreen>
    with SingleTickerProviderStateMixin {
  final _repo = DomiciliariosRepository();
  late TabController _tabs;
  List<Map<String, dynamic>> _pedidos = [];
  List<Map<String, dynamic>> _historial = [];
  Map<String, dynamic>? _stats;
  bool _cargando = true;
  String? _error;
  String _nombre = 'Domiciliario';
  String? _usuarioId;
  RealtimeChannel? _canalRealtime;
  Timer? _pollRespaldo;

  final _moneda = NumberFormat.currency(
    locale: 'es_CO',
    symbol: r'$',
    decimalDigits: 0,
  );
  final _fecha = DateFormat('d MMM · HH:mm', 'es_CO');

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _inicializar();
  }

  Future<void> _inicializar() async {
    final sesion = await SesionStaffService.cargar();
    _usuarioId = sesion?.usuario['id'] as String?;
    await _cargar();
    if (_usuarioId != null) {
      _canalRealtime = FoodyRealtime.suscribirDomiciliarioPlanta(
        _usuarioId!,
        onActualizado: () => _cargar(silencioso: true),
      );
      _pollRespaldo = Timer.periodic(
        const Duration(seconds: 60),
        (_) => _cargar(silencioso: true),
      );
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    _pollRespaldo?.cancel();
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
      final pedidos = await _repo.pedidosAsignados();
      final historial = await _repo.historialEntregas();
      final stats = await _repo.estadisticasPlanta();
      if (mounted) {
        setState(() {
          _nombre = sesion?.usuario['nombre']?.toString() ?? _nombre;
          _pedidos = pedidos;
          _historial = historial;
          _stats = stats;
          _cargando = false;
        });
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

  Future<void> _cerrarSesion() async {
    await SesionStaffService.cerrar();
    if (mounted) context.go('/admin/login');
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
    try {
      await _repo.confirmarEntrega(
        pedido['id'] as String,
        metodoPago: pedido['metodo_pago'] as String?,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Foody — Domiciliario'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Activos', icon: Icon(Icons.delivery_dining)),
            Tab(text: 'Historial', icon: Icon(Icons.history)),
            Tab(text: 'Stats', icon: Icon(Icons.bar_chart)),
          ],
        ),
        actions: [
          IconButton(tooltip: 'Actualizar', onPressed: _cargar, icon: const Icon(Icons.refresh)),
          IconButton(tooltip: 'Salir', onPressed: _cerrarSesion, icon: const Icon(Icons.logout)),
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
                      FilledButton(onPressed: _cargar, child: const Text('Reintentar')),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabs,
                  children: [
                    _tabActivos(),
                    _tabHistorial(),
                    _tabStats(),
                  ],
                ),
    );
  }

  Widget _tabActivos() {
    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Hola, $_nombre', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            _pedidos.isEmpty
                ? 'Sin entregas pendientes'
                : '${_pedidos.length} pedido(s) activo(s)',
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 16),
          if (_pedidos.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('Esperando asignación del restaurante')),
              ),
            )
          else
            ..._pedidos.map(_tarjetaPedidoActivo),
        ],
      ),
    );
  }

  Widget _tarjetaPedidoActivo(Map<String, dynamic> p) {
    final estado = p['estado'] as String? ?? '';
    final total = p['total'];
    final lat = p['lat'];
    final lng = p['lng'];
    final latNum = lat is num ? lat.toDouble() : double.tryParse('$lat');
    final lngNum = lng is num ? lng.toDouble() : double.tryParse('$lng');
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              p['numero_pedido'] as String? ?? '',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(p['cliente_nombre'] as String? ?? 'Cliente'),
            if (p['direccion_entrega'] != null) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_outlined, size: 18),
                  const SizedBox(width: 4),
                  Expanded(child: Text(p['direccion_entrega'] as String)),
                ],
              ),
            ],
            if (latNum != null && lngNum != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: MapaFoody(
                  altura: 140,
                  centro: LatLng(latNum, lngNum),
                  zoom: 15,
                  interactuable: false,
                  mostrarControles: false,
                  marcadores: [
                    MarcadorFoody(
                      lat: latNum,
                      lng: lngNum,
                      color: ColoresFoody.secundario,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => UtilidadNavegacion.abrir(
                      lat: latNum,
                      lng: lngNum,
                      etiqueta: p['direccion_entrega'] as String?,
                    ),
                    icon: const Icon(Icons.navigation_outlined, size: 18),
                    label: const Text('Navegar'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Text(
              _moneda.format(total is num ? total : num.tryParse('$total') ?? 0),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            if (estado == 'asignado')
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _enCamino(p['id'] as String),
                  icon: const Icon(Icons.two_wheeler),
                  label: const Text('Salir en camino'),
                ),
              ),
            if (estado == 'en_camino')
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _entregar(p),
                  style: FilledButton.styleFrom(backgroundColor: ColoresFoody.exito),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Confirmar entrega'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _tabHistorial() {
    if (_historial.isEmpty) {
      return const Center(child: Text('Aún no tienes entregas completadas'));
    }
    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _historial.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final h = _historial[i];
          final total = h['total'];
          final fecha = h['entregado_at'] ?? h['asignado_at'];
          String? fechaTxt;
          if (fecha != null) {
            final dt = DateTime.tryParse('$fecha');
            if (dt != null) fechaTxt = _fecha.format(dt.toLocal());
          }
          return ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            tileColor: ColoresFoody.grisSuave,
            title: Text(h['numero_pedido'] as String? ?? ''),
            subtitle: Text(
              '${h['cliente_nombre'] ?? ''}${fechaTxt != null ? ' · $fechaTxt' : ''}',
            ),
            trailing: Text(
              _moneda.format(total is num ? total : num.tryParse('$total') ?? 0),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          );
        },
      ),
    );
  }

  Widget _tabStats() {
    final s = _stats ?? {};
    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _statCard('Entregas hoy', '${s['entregas_hoy'] ?? 0}', Icons.today),
          _statCard('Esta semana', '${s['entregas_semana'] ?? 0}', Icons.date_range),
          _statCard('Este mes', '${s['entregas_mes'] ?? 0}', Icons.calendar_month),
          _statCard(
            'Promedio entrega',
            s['tiempo_promedio_min'] != null
                ? '${s['tiempo_promedio_min']} min'
                : '—',
            Icons.timer_outlined,
          ),
        ],
      ),
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
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
