import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:reserva_canchas/core/mapas/mapa_foody.dart';
import 'package:intl/intl.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
import 'package:reserva_canchas/core/realtime/foody_realtime.dart';
import 'package:reserva_canchas/features/pedidos/data/pedidos_cliente_repository.dart';
import 'package:reserva_canchas/services/app_backend.dart';
import 'package:reserva_canchas/services/mesa_sesion_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Seguimiento del pedido con actualización en tiempo real (broadcast NestJS → Supabase).
class SeguimientoPedidoScreen extends StatefulWidget {
  const SeguimientoPedidoScreen({super.key, required this.pedidoId});

  final String pedidoId;

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
  RealtimeChannel? _canal;

  static const _etiquetasEstado = {
    'pendiente_aprobacion': 'Esperando mesera',
    'pendiente': 'Pedido recibido',
    'confirmado': 'En preparación',
    'en_cocina': 'En preparación',
    'listo': 'Listo para recoger',
    'en_camino': 'En camino',
    'entregado': 'Entregado',
    'pagado': 'Pagado',
    'cancelado': 'Cancelado',
    'rechazado': 'Rechazado',
  };

  @override
  void initState() {
    super.initState();
    _cargar();
    _suscribirRealtime();
  }

  @override
  void dispose() {
    _canal?.unsubscribe();
    super.dispose();
  }

  void _suscribirRealtime() {
    if (!AppBackend.supabaseReady) return;

    _canal = FoodyRealtime.suscribirPedido(
      widget.pedidoId,
      onEstadoActualizado: _cargar,
    );
  }

  Future<void> _cargar() async {
    try {
      final d = await _repo.estadoPedido(widget.pedidoId);
      if (mounted) {
        setState(() {
          _datos = d;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  String _etiqueta(String estado) =>
      _etiquetasEstado[estado] ?? estado.replaceAll('_', ' ');

  Future<void> _volverAlMenuMesa() async {
    final sesion = await MesaSesionService.obtener();
    if (sesion != null && mounted) {
      context.go(sesion.rutaMenu);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seguimiento'),
        actions: [
          IconButton(
            onPressed: _cargar,
            icon: const Icon(Icons.refresh),
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
            icon: const Icon(Icons.restaurant_menu),
            label: const Text('Seguir pidiendo'),
          );
        },
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _cargar,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            )
          : _datos == null
              ? const Center(child: CircularProgressIndicator())
              : _contenido(),
    );
  }

  Widget _contenido() {
    final estado = _datos!['estado_actual'] as String? ?? '';
    final tipo = _datos!['tipo'] as String? ?? '';
    final lat = _datos!['lat'];
    final lng = _datos!['lng'];
    final latNum = lat is num ? lat.toDouble() : double.tryParse('$lat');
    final lngNum = lng is num ? lng.toDouble() : double.tryParse('$lng');
    final direccion = _datos!['direccion_entrega'] as String?;
    final historial =
        (_datos!['historial'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final total = _datos!['total'];

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            _datos!['numero_pedido'] as String? ?? '',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          if (total != null) ...[
            const SizedBox(height: 8),
            Text(
              _formatoMoneda.format(total is num ? total : double.tryParse('$total') ?? 0),
              style: const TextStyle(
                fontSize: 18,
                color: ColoresFoody.primario,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ColoresFoody.secundario.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(
                  _iconoEstado(estado),
                  size: 40,
                  color: ColoresFoody.primario,
                ),
                const SizedBox(height: 8),
                Text(
                  _etiqueta(estado),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                if (!AppBackend.supabaseReady)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Sin Realtime — usa actualizar',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ),
              ],
            ),
          ),
          if (tipo == 'domicilio') ...[
            const SizedBox(height: 20),
            Text('Entrega', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (direccion != null && direccion.isNotEmpty)
              Text(direccion, style: TextStyle(color: Colors.grey.shade700)),
            if (latNum != null && lngNum != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: MapaFoody(
                  altura: 180,
                  centro: LatLng(latNum, lngNum),
                  marcadores: [
                    MarcadorFoody(
                      lat: latNum,
                      lng: lngNum,
                      etiqueta: 'Tu entrega',
                    ),
                  ],
                  mostrarControles: false,
                  interactuable: false,
                ),
              ),
              if (estado == 'en_camino')
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'El repartidor va hacia tu ubicación',
                    style: TextStyle(color: ColoresFoody.secundario, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ],
          const SizedBox(height: 28),
          Text('Historial', style: Theme.of(context).textTheme.titleMedium),
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
            const Text('Aún no hay movimientos registrados'),
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
            ? ColoresFoody.secundario
            : Colors.grey.shade400;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.2),
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
                    fontWeight: activo ? FontWeight.bold : FontWeight.normal,
                    color: activo ? ColoresFoody.texto : Colors.grey.shade700,
                  ),
                ),
                if (subtitulo != null)
                  Text(
                    subtitulo!,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
