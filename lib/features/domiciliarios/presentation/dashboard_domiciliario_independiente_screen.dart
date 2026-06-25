import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';
import 'package:reserva_canchas/core/realtime/foody_realtime.dart';
import 'package:reserva_canchas/core/sesion/sesion_staff_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:reserva_canchas/features/auth/data/auth_repository.dart';
import 'package:reserva_canchas/features/domiciliarios/data/domiciliarios_independientes_repository.dart';

/// Dashboard domiciliario independiente — ofertas, aceptar, entregar (Sprint 7).
class DashboardDomiciliarioIndependienteScreen extends StatefulWidget {
  const DashboardDomiciliarioIndependienteScreen({super.key});

  @override
  State<DashboardDomiciliarioIndependienteScreen> createState() =>
      _DashboardDomiciliarioIndependienteScreenState();
}

class _DashboardDomiciliarioIndependienteScreenState
    extends State<DashboardDomiciliarioIndependienteScreen> {
  final _repo = DomiciliariosIndependientesRepository();
  List<Map<String, dynamic>> _ofertas = [];
  List<Map<String, dynamic>> _pedidos = [];
  bool _turnoActivo = false;
  bool _cargando = true;
  String? _error;
  String _nombre = 'Repartidor';
  String? _domiciliarioId;
  Timer? _poll;
  RealtimeChannel? _canalRealtime;

  final _moneda = NumberFormat.currency(locale: 'es_CO', symbol: r'$', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _iniciar();
    _poll = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _cargar(silencioso: true),
    );
  }

  @override
  void dispose() {
    _poll?.cancel();
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
    setState(() => _nombre = sesion.usuario['nombre']?.toString() ?? _nombre);
    _domiciliarioId = sesion.usuario['id'] as String?;
    if (_domiciliarioId != null) {
      _canalRealtime = FoodyRealtime.suscribirDomiciliarioIndep(
        _domiciliarioId!,
        onActualizado: () => _cargar(silencioso: true),
      );
    }
    await _cargar();
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
      if (mounted) {
        setState(() {
          _ofertas = ofertas;
          _pedidos = pedidos;
          _turnoActivo = true;
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted && !silencioso) {
        setState(() {
          _error = mensajeErrorHttp(e, contexto: 'datos');
          _cargando = false;
        });
      }
    }
  }

  Future<void> _iniciarTurno() async {
    try {
      // Coordenadas demo cerca de sucursal Centro Valledupar
      await _repo.iniciarSesion(lat: 10.464100, lng: -73.252500);
      setState(() => _turnoActivo = true);
      await _cargar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Turno iniciado — disponible para ofertas')),
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

  Future<void> _responder(String ofertaId, String respuesta) async {
    try {
      await _repo.responderOferta(ofertaId, respuesta);
      await _cargar();
      if (mounted && respuesta == 'aceptada') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pedido aceptado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensajeErrorHttp(e, contexto: 'oferta'))),
        );
      }
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

  Future<void> _entregar(String pedidoId) async {
    try {
      await _repo.confirmarEntrega(pedidoId);
      await _cargar();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensajeErrorHttp(e, contexto: 'entrega'))),
        );
      }
    }
  }

  Future<void> _cerrarSesion() async {
    await AuthRepository().logout();
    if (mounted) context.go('/domiciliario/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Hola, $_nombre'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh),
            onPressed: _cargar,
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: _cerrarSesion,
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargar,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (!_turnoActivo)
                    Card(
                      color: ColoresFoody.acento.withValues(alpha: 0.25),
                      child: ListTile(
                        title: const Text('Inicia tu turno'),
                        subtitle: const Text(
                          'Debes estar disponible para recibir ofertas de domicilio',
                        ),
                        trailing: FilledButton(
                          onPressed: _iniciarTurno,
                          child: const Text('Conectarme'),
                        ),
                      ),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(_error!, style: TextStyle(color: ColoresFoody.error)),
                    ),
                  Text('Ofertas activas', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (_ofertas.isEmpty)
                    const Text('Sin ofertas por ahora — mantente conectado'),
                  ..._ofertas.map(_tarjetaOferta),
                  const SizedBox(height: 24),
                  Text('Mis entregas', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (_pedidos.isEmpty) const Text('Sin pedidos asignados'),
                  ..._pedidos.map(_tarjetaPedido),
                ],
              ),
            ),
    );
  }

  Widget _tarjetaOferta(Map<String, dynamic> o) {
    final expira = DateTime.tryParse('${o['expira_at']}')?.toLocal();
    final domicilio = double.tryParse('${o['costo_domicilio']}') ?? 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Pedido ${o['numero_pedido']}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('${o['sucursal_nombre']} → ${o['direccion_entrega'] ?? '—'}'),
            Text('Ganas: ${_moneda.format(domicilio * 0.85)} (aprox.)'),
            if (expira != null)
              Text(
                'Expira: ${expira.hour}:${expira.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _responder('${o['oferta_id']}', 'rechazada'),
                    child: const Text('Rechazar'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: () => _responder('${o['oferta_id']}', 'aceptada'),
                    child: const Text('Aceptar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tarjetaPedido(Map<String, dynamic> p) {
    final estado = '${p['estado']}';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text('Pedido ${p['numero_pedido']}'),
        subtitle: Text(
          '${p['cliente_nombre'] ?? 'Cliente'}\n'
          '${p['direccion_entrega'] ?? '—'}\n'
          'Total: ${_moneda.format(double.tryParse('${p['total']}') ?? 0)}',
        ),
        isThreeLine: true,
        trailing: estado == 'asignado'
            ? FilledButton(
                onPressed: () => _enCamino('${p['id']}'),
                child: const Text('Salir'),
              )
            : estado == 'en_camino'
                ? FilledButton(
                    onPressed: () => _entregar('${p['id']}'),
                    child: const Text('Entregué'),
                  )
                : null,
      ),
    );
  }
}
