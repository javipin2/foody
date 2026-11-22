import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:reserva_canchas/core/mapas/mapa_foody.dart';
import 'package:intl/intl.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';
import 'package:reserva_canchas/core/realtime/foody_realtime.dart';
import 'package:reserva_canchas/core/realtime/poll_realtime_respaldo.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_tokens.dart';
import 'package:reserva_canchas/features/pedidos/data/pedidos_cliente_repository.dart';
import 'package:reserva_canchas/features/pedidos/presentation/widgets/pedido_estado_pill.dart';
import 'package:reserva_canchas/core/widgets/foody_estado_ui.dart';
import 'package:reserva_canchas/services/app_backend.dart';
import 'package:reserva_canchas/services/mesa_sesion_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Seguimiento del pedido con actualización en tiempo real (broadcast NestJS → Supabase).
class SeguimientoPedidoScreen extends StatefulWidget {
  const SeguimientoPedidoScreen({
    super.key,
    required this.pedidoId,
    this.seguimientoToken,
  });

  final String pedidoId;
  final String? seguimientoToken;

  @override
  State<SeguimientoPedidoScreen> createState() =>
      _SeguimientoPedidoScreenState();
}

class _SeguimientoPedidoScreenState extends State<SeguimientoPedidoScreen> {
  final _repo = PedidosClienteRepository();
  final _formatoMoneda = NumberFormat.currency(
    locale: 'es_CO',
    symbol: r'$',
    decimalDigits: 0,
  );
  final _formatoHora = DateFormat('d MMM · HH:mm', 'es_CO');
  Map<String, dynamic>? _datos;
  String? _error;
  bool _llamandoMesera = false;
  bool _calificando = false;
  RealtimeChannel? _canal;
  PollRealtimeRespaldo? _pollRespaldo;
  Timer? _pollCamino;
  double? _repartidorLatRt;
  double? _repartidorLngRt;
  DateTime? _ultimaUbicacionRt;
  String? _seguimientoToken;

  @override
  void initState() {
    super.initState();
    _seguimientoToken = widget.seguimientoToken;
    unawaited(_iniciar());
  }

  Future<void> _iniciar() async {
    await _cargar();
    _suscribirRealtime();
    _pollRespaldo = PollRealtimeRespaldo(onActualizar: _cargar);
    unawaited(_pollRespaldo!.iniciar());
  }

  @override
  void dispose() {
    FoodyRealtime.liberarCanal(_canal);
    _pollRespaldo?.detener();
    _pollCamino?.cancel();
    super.dispose();
  }

  void _onUbicacionRepartidor(Map<String, dynamic> payload) {
    final lat = payload['repartidor_lat'];
    final lng = payload['repartidor_lng'];
    if (lat == null || lng == null) return;
    final latN = lat is num ? lat.toDouble() : double.tryParse('$lat');
    final lngN = lng is num ? lng.toDouble() : double.tryParse('$lng');
    if (latN == null || lngN == null) return;
    if (!mounted) return;
    setState(() {
      _repartidorLatRt = latN;
      _repartidorLngRt = lngN;
      _ultimaUbicacionRt = DateTime.now();
    });
  }

  void _ajustarPollCamino(String estado) {
    _pollCamino?.cancel();
    _pollCamino = null;
    if (estado != 'en_camino') return;
    _pollCamino = Timer.periodic(const Duration(seconds: 15), (_) {
      unawaited(_cargar(silencioso: true));
    });
  }

  void _suscribirRealtime() {
    if (!AppBackend.supabaseReady) return;
    final token = _seguimientoToken;
    if (token == null || token.isEmpty) return;

    _canal = FoodyRealtime.suscribirPedido(
      widget.pedidoId,
      token,
      onEstadoActualizado: _cargar,
      onUbicacionRepartidor: _onUbicacionRepartidor,
    );
  }

  Future<void> _cargar({bool silencioso = false}) async {
    try {
      final d = await _repo.estadoPedido(
        widget.pedidoId,
        seguimientoToken: _seguimientoToken,
      );
      if (mounted) {
        final estado = d['estado_actual'] as String? ?? '';
        final tokenRt = d['seguimiento_token'] as String?;
        final necesitaRt = tokenRt != null &&
            tokenRt.isNotEmpty &&
            tokenRt != _seguimientoToken;
        setState(() {
          _datos = d;
          _error = null;
          if (tokenRt != null && tokenRt.isNotEmpty) {
            _seguimientoToken = tokenRt;
          }
          if (estado != 'en_camino') {
            _repartidorLatRt = null;
            _repartidorLngRt = null;
          }
        });
        if (necesitaRt) {
          FoodyRealtime.liberarCanal(_canal);
          _suscribirRealtime();
        }
        _ajustarPollCamino(estado);
      }
    } catch (e) {
      if (mounted && !silencioso) setState(() => _error = '$e');
    }
  }

  String _etiqueta(String estado) =>
      PedidoEstadoPill.etiqueta(estado, paraCliente: true);

  String _textoUltimaUbicacion() {
    final t = _ultimaUbicacionRt;
    if (t == null) return '';
    final seg = DateTime.now().difference(t).inSeconds;
    if (seg < 5) return 'Ubicación actualizada ahora';
    if (seg < 60) return 'Ubicación hace $seg s';
    return 'Ubicación hace ${seg ~/ 60} min';
  }

  bool _puedeCancelarCliente(Map<String, dynamic>? datos) {
    if (datos == null) return false;
    final estado = datos['estado_actual'] as String? ?? '';
    const permitidos = {
      'pendiente_aprobacion',
      'pendiente',
      'confirmado',
    };
    if (!permitidos.contains(estado)) return false;
    if (estado != 'confirmado') return true;
    final raw = datos['created_at'];
    if (raw == null) return false;
    final creado = DateTime.tryParse('$raw');
    if (creado == null) return false;
    return DateTime.now().difference(creado.toLocal()).inMinutes <= 2;
  }

  String? _textoLimiteCancelar(Map<String, dynamic>? datos) {
    if (datos == null) return null;
    if ((datos['estado_actual'] as String?) != 'confirmado') return null;
    final raw = datos['created_at'];
    final creado = raw != null ? DateTime.tryParse('$raw') : null;
    if (creado == null) return null;
    final restante = 120 - DateTime.now().difference(creado.toLocal()).inSeconds;
    if (restante <= 0) return null;
    return 'Puedes cancelar durante ${(restante / 60).ceil()} min más';
  }

  bool _puedeLlamarMesera(String estado, String? mesaId) {
    if (mesaId == null || mesaId.isEmpty) return false;
    return const {
      'pendiente_aprobacion',
      'pendiente',
      'confirmado',
      'en_cocina',
      'listo',
      'pagando',
    }.contains(estado);
  }

  Future<void> _llamarMesera() async {
    if (_llamandoMesera) return;
    setState(() => _llamandoMesera = true);
    try {
      final res = await _repo.llamarMesera(pedidoId: widget.pedidoId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              res['mensaje'] as String? ?? 'Avisamos a la mesera',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensajeErrorHttp(e, contexto: 'llamar mesera'))),
        );
      }
    } finally {
      if (mounted) setState(() => _llamandoMesera = false);
    }
  }

  Future<void> _cancelarPedido() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar pedido'),
        content: TextField(
          controller: ctrl,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Motivo (mínimo 3 caracteres)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim().length >= 3),
            style: FilledButton.styleFrom(
              backgroundColor: ColoresFoody.error,
            ),
            child: const Text('Cancelar pedido'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) {
      ctrl.dispose();
      return;
    }
    final motivo = ctrl.text.trim();
    ctrl.dispose();
    try {
      await _repo.cancelarPedido(pedidoId: widget.pedidoId, motivo: motivo);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pedido cancelado')),
        );
        await _cargar();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensajeErrorHttp(e, contexto: 'cancelar'))),
        );
      }
    }
  }

  Future<void> _calificarEntrega() async {
    var estrellas = 5;
    final comentarioCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSt) => AlertDialog(
          title: const Text('¿Cómo fue tu domicilio?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final n = i + 1;
                  return IconButton(
                    onPressed: () => setSt(() => estrellas = n),
                    icon: Icon(
                      n <= estrellas ? Icons.star : Icons.star_border,
                      color: ColoresFoody.acento,
                      size: 32,
                    ),
                  );
                }),
              ),
              TextField(
                controller: comentarioCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Comentario (opcional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Omitir'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Enviar'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) {
      comentarioCtrl.dispose();
      return;
    }
    final comentario = comentarioCtrl.text.trim();
    comentarioCtrl.dispose();
    setState(() => _calificando = true);
    try {
      await _repo.calificarDomicilio(
        pedidoId: widget.pedidoId,
        estrellas: estrellas,
        comentario: comentario.isEmpty ? null : comentario,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gracias por tu calificación')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensajeErrorHttp(e, contexto: 'calificar')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _calificando = false);
    }
  }

  LatLng _centroMapa(
    double latEntrega,
    double lngEntrega,
    double? latRepartidor,
    double? lngRepartidor,
  ) {
    if (latRepartidor != null && lngRepartidor != null) {
      return LatLng(
        (latEntrega + latRepartidor) / 2,
        (lngEntrega + lngRepartidor) / 2,
      );
    }
    return LatLng(latEntrega, lngEntrega);
  }

  Future<void> _volverAlMenuMesa() async {
    final sesion = await MesaSesionService.obtener();
    if (sesion != null && mounted) {
      context.go(sesion.rutaMenu);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AnaliticaTokens.canvas,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: AnaliticaTokens.surface,
        foregroundColor: AnaliticaTokens.ink,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        title: const Text(
          'Seguimiento',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: AnaliticaTokens.ink,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _cargar,
            icon: const Icon(Icons.refresh, color: AnaliticaTokens.inkMuted),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      floatingActionButton: FutureBuilder<MesaSesion?>(
        future: MesaSesionService.obtener(),
        builder: (context, snap) {
          if (!snap.hasData || snap.data == null) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            onPressed: _volverAlMenuMesa,
            backgroundColor: AnaliticaTokens.ink,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.restaurant_menu),
            label: const Text('Seguir pidiendo'),
          );
        },
      ),
      body: _error != null
          ? FoodyEstadoUi.error(
              mensaje: _error!,
              onReintentar: _cargar,
            )
          : _datos == null
              ? FoodyEstadoUi.cargando(mensaje: 'Cargando tu pedido…')
              : _contenido(),
    );
  }

  Widget _contenido() {
    final estado = _datos!['estado_actual'] as String? ?? '';
    final tipo = _datos!['tipo'] as String? ?? '';
    final lat = _datos!['lat'];
    final lng = _datos!['lng'];
    final repLat = _repartidorLatRt ?? _datos!['repartidor_lat'];
    final repLng = _repartidorLngRt ?? _datos!['repartidor_lng'];
    final latNum = lat is num ? lat.toDouble() : double.tryParse('$lat');
    final lngNum = lng is num ? lng.toDouble() : double.tryParse('$lng');
    final repLatNum =
        repLat is num ? repLat.toDouble() : double.tryParse('$repLat');
    final repLngNum =
        repLng is num ? repLng.toDouble() : double.tryParse('$repLng');
    final direccion = _datos!['direccion_entrega'] as String?;
    final historial =
        (_datos!['historial'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final total = _datos!['total'];
    final mesaId = _datos!['mesa_id'] as String?;
    final mesaNombre = _datos!['mesa_nombre'] as String?;
    final eta = _datos!['tiempo_estimado_minutos'];
    final etaMin = eta is num ? eta.toInt() : int.tryParse('$eta');

    return RefreshIndicator(
      color: AnaliticaTokens.ink,
      onRefresh: _cargar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 88),
        children: [
          Text(
            _datos!['numero_pedido'] as String? ?? '',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AnaliticaTokens.ink,
                  letterSpacing: -0.5,
                ),
          ),
          if (total != null) ...[
            const SizedBox(height: 6),
            Text(
              _formatoMoneda.format(
                total is num ? total : double.tryParse('$total') ?? 0,
              ),
              style: const TextStyle(
                fontSize: 18,
                color: ColoresFoody.primario,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AnaliticaTokens.surface,
              borderRadius: BorderRadius.circular(AnaliticaTokens.r16),
              border: Border.all(color: AnaliticaTokens.border),
              boxShadow: AnaliticaTokens.shadowSoft,
            ),
            child: Column(
              children: [
                Icon(
                  _iconoEstado(estado),
                  size: 40,
                  color: AnaliticaTokens.ink,
                ),
                const SizedBox(height: 12),
                PedidoEstadoPill(
                  estado: estado,
                  paraCliente: true,
                  grande: true,
                ),
                if (!AppBackend.supabaseReady)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Sin Realtime — usa actualizar',
                      style: TextStyle(
                        fontSize: 12,
                        color: AnaliticaTokens.inkMuted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_puedeCancelarCliente(_datos)) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _cancelarPedido,
              icon: const Icon(Icons.cancel_outlined,
                  color: AnaliticaTokens.alertas),
              label: const Text(
                'Cancelar mi pedido',
                style: TextStyle(color: AnaliticaTokens.alertas),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AnaliticaTokens.alertas),
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _textoLimiteCancelar(_datos) ??
                  'Solo antes de que cocina empiece a prepararlo',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: AnaliticaTokens.inkMuted,
              ),
            ),
          ],
          if (_puedeLlamarMesera(estado, mesaId)) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _llamandoMesera ? null : _llamarMesera,
              icon: _llamandoMesera
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.notifications_active_outlined),
              label: Text(
                mesaNombre != null
                    ? 'Llamar mesera · $mesaNombre'
                    : 'Llamar mesera',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AnaliticaTokens.ink,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Para cambios en tu pedido o atención en mesa',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AnaliticaTokens.inkMuted),
            ),
          ],
          if (tipo == 'domicilio') ...[
            const SizedBox(height: 24),
            const Text(
              'Entrega',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: AnaliticaTokens.ink,
              ),
            ),
            const SizedBox(height: 10),
            if (etaMin != null && etaMin > 0 && estado != 'entregado')
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.schedule,
                        size: 18, color: ColoresFoody.primario),
                    const SizedBox(width: 6),
                    Text(
                      'Tiempo estimado: ~$etaMin min',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AnaliticaTokens.ink,
                      ),
                    ),
                  ],
                ),
              ),
            if (direccion != null && direccion.isNotEmpty)
              Text(
                direccion,
                style: const TextStyle(color: AnaliticaTokens.inkMuted),
              ),
            if (latNum != null && lngNum != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(AnaliticaTokens.r16),
                child: MapaFoody(
                  key: ValueKey(
                    '${repLatNum ?? 0}_${repLngNum ?? 0}_${latNum}_$lngNum',
                  ),
                  altura: 200,
                  centro: _centroMapa(
                    latNum,
                    lngNum,
                    repLatNum,
                    repLngNum,
                  ),
                  zoom: repLatNum != null ? 14 : 15,
                  marcadores: [
                    MarcadorFoody(
                      lat: latNum,
                      lng: lngNum,
                      etiqueta: 'Tu entrega',
                      color: AnaliticaTokens.pedidos,
                      icono: Icons.home_outlined,
                    ),
                    if (repLatNum != null && repLngNum != null)
                      MarcadorFoody(
                        lat: repLatNum,
                        lng: repLngNum,
                        etiqueta: 'Repartidor',
                        color: ColoresFoody.primario,
                        icono: Icons.delivery_dining,
                      ),
                  ],
                  mostrarControles: false,
                  interactuable: false,
                ),
              ),
              if (estado == 'en_camino')
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        repLatNum != null
                            ? 'Repartidor en camino — ubicación en vivo'
                            : 'El repartidor va hacia tu ubicación',
                        style: const TextStyle(
                          color: AnaliticaTokens.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_ultimaUbicacionRt != null && repLatNum != null)
                        Text(
                          _textoUltimaUbicacion(),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AnaliticaTokens.inkMuted,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
            if (estado == 'entregado' || estado == 'pagado') ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _calificando ? null : _calificarEntrega,
                icon: _calificando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.star_outline),
                label: const Text('Calificar entrega'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AnaliticaTokens.ink,
                  side: const BorderSide(color: AnaliticaTokens.border),
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
                  ),
                ),
              ),
            ],
          ],
          const SizedBox(height: 28),
          const Text(
            'Historial',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: AnaliticaTokens.ink,
            ),
          ),
          const SizedBox(height: 12),
          ...historial.asMap().entries.map((entry) {
            final h = entry.value;
            final esUltimo = entry.key == historial.length - 1;
            final est = h['estado'] as String? ?? '';
            final fechaRaw = h['fecha'];
            String? horaTexto;
            if (fechaRaw != null) {
              final dt = DateTime.tryParse('$fechaRaw');
              if (dt != null) {
                horaTexto = _formatoHora.format(dt.toLocal());
              }
            }
            return _PasoTimeline(
              titulo: _etiqueta(est),
              subtitulo: horaTexto,
              activo: esUltimo,
              completado: !esUltimo || estado == est,
            );
          }),
          if (historial.isEmpty)
            const Text(
              'Aún no hay movimientos registrados',
              style: TextStyle(color: AnaliticaTokens.inkMuted),
            ),
        ],
      ),
    );
  }

  IconData _iconoEstado(String estado) {
    switch (estado) {
      case 'en_cocina':
        return Icons.restaurant;
      case 'listo':
        return Icons.check_circle_outline;
      case 'en_camino':
        return Icons.delivery_dining;
      case 'entregado':
      case 'pagado':
        return Icons.celebration_outlined;
      case 'cancelado':
      case 'rechazado':
        return Icons.cancel_outlined;
      default:
        return Icons.receipt_long;
    }
  }
}

class _PasoTimeline extends StatelessWidget {
  const _PasoTimeline({
    required this.titulo,
    this.subtitulo,
    required this.activo,
    required this.completado,
  });

  final String titulo;
  final String? subtitulo;
  final bool activo;
  final bool completado;

  @override
  Widget build(BuildContext context) {
    final color = activo
        ? ColoresFoody.primario
        : completado
            ? AnaliticaTokens.inventario
            : AnaliticaTokens.inkSoft;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.15),
              border: Border.all(color: color, width: 2),
            ),
            child: completado || activo
                ? Icon(
                    activo ? Icons.radio_button_checked : Icons.check,
                    size: 16,
                    color: color,
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TextStyle(
                    fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
                    color: activo ? AnaliticaTokens.ink : AnaliticaTokens.inkMuted,
                  ),
                ),
                if (subtitulo != null)
                  Text(
                    subtitulo!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AnaliticaTokens.inkSoft,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
