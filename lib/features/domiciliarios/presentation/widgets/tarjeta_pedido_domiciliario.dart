import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
import 'package:reserva_canchas/core/mapas/mapa_foody.dart';
import 'package:reserva_canchas/core/mapas/utilidad_navegacion.dart';
import 'package:reserva_canchas/features/domiciliarios/presentation/widgets/acciones_contacto_cliente.dart';

/// Tarjeta de pedido para domiciliario (planta e independiente).
class TarjetaPedidoDomiciliario extends StatelessWidget {
  const TarjetaPedidoDomiciliario({
    super.key,
    required this.pedido,
    this.onSalir,
    this.onEntregar,
    this.mostrarTelefono = true,
    this.mostrarMiniMapa = true,
    this.mostrarIrRestaurante = false,
    this.elevacion = 12,
  });

  final Map<String, dynamic> pedido;
  final VoidCallback? onSalir;
  final VoidCallback? onEntregar;
  final bool mostrarTelefono;
  final bool mostrarMiniMapa;

  /// Indep: botón navegar a sucursal (pickup).
  final bool mostrarIrRestaurante;
  final double elevacion;

  static final _moneda = NumberFormat.currency(
    locale: 'es_CO',
    symbol: r'$',
    decimalDigits: 0,
  );

  double? _coord(String key) {
    final v = pedido[key];
    if (v is num) return v.toDouble();
    return double.tryParse('$v');
  }

  String get _estado {
    final asig = pedido['estado_asignacion'] as String?;
    if (asig != null && asig.isNotEmpty) return asig;
    return '${pedido['estado'] ?? ''}';
  }

  String _etiquetaEstado(String e) {
    switch (e) {
      case 'asignado':
        return 'Por recoger';
      case 'en_camino':
        return 'En camino';
      case 'entregado':
        return 'Entregado';
      default:
        return e.isEmpty ? 'Activo' : e;
    }
  }

  String _etiquetaPago(String? m) {
    switch (m) {
      case 'efectivo':
        return 'Efectivo';
      case 'tarjeta':
        return 'Tarjeta';
      case 'transferencia':
        return 'Transferencia';
      case 'nequi':
        return 'Nequi';
      case 'pendiente':
        return 'Pendiente cobro';
      case 'pendiente_liquidacion':
        return 'A cuenta';
      case null:
      case '':
        return 'Sin método';
      default:
        return m;
    }
  }

  List<String> _etiquetasPagos() {
    final pagos = pedido['pagos_resumen'];
    if (pagos is List && pagos.isNotEmpty) {
      return pagos.whereType<Map>().map((pago) {
        final metodo = _etiquetaPago(pago['metodo_pago'] as String?);
        final monto = num.tryParse('${pago['monto']}') ?? 0;
        return '$metodo ${_moneda.format(monto)}';
      }).toList();
    }
    return [_etiquetaPago(pedido['metodo_pago'] as String?)];
  }

  Future<void> _copiar(BuildContext context, String texto, String ok) async {
    await Clipboard.setData(ClipboardData(text: texto));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok)));
    }
  }

  Future<void> _navegar(
    BuildContext context, {
    required double lat,
    required double lng,
    String? etiqueta,
  }) async {
    final ok = await UtilidadNavegacion.abrir(
      lat: lat,
      lng: lng,
      etiqueta: etiqueta,
    );
    if (!ok && context.mounted) {
      final texto =
          etiqueta?.trim().isNotEmpty == true ? etiqueta!.trim() : '$lat,$lng';
      await _copiar(context, texto, 'Dirección copiada');
    }
  }

  @override
  Widget build(BuildContext context) {
    final lat = _coord('lat');
    final lng = _coord('lng');
    final sLat = _coord('sucursal_lat');
    final sLng = _coord('sucursal_lng');
    final telefono = pedido['cliente_telefono'] as String?;
    final direccion = pedido['direccion_entrega'] as String?;
    final total = num.tryParse('${pedido['total']}') ?? 0;
    final domicilio = num.tryParse('${pedido['costo_domicilio']}') ?? 0;
    final productoNeto = num.tryParse('${pedido['producto_total']}');
    final producto =
        productoNeto ?? (num.tryParse('${pedido['subtotal']}') ?? 0);
    final saldoPendiente = num.tryParse('${pedido['saldo_pendiente']}');
    final pagos = _etiquetasPagos();
    final estado = _estado;
    final latOk = lat;
    final lngOk = lng;
    final tieneGps = latOk != null && lngOk != null;

    return Material(
      elevation: elevacion,
      borderRadius: BorderRadius.circular(20),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Pedido ${pedido['numero_pedido'] ?? ''}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: estado == 'en_camino'
                        ? ColoresFoody.secundario.withValues(alpha: 0.15)
                        : ColoresFoody.primario.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _etiquetaEstado(estado),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: estado == 'en_camino'
                          ? ColoresFoody.secundario
                          : ColoresFoody.primario,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              pedido['cliente_nombre'] as String? ?? 'Cliente',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (pedido['sucursal_nombre'] != null) ...[
              const SizedBox(height: 2),
              Text(
                '${pedido['sucursal_nombre']}',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
            ],
            if (mostrarTelefono &&
                telefono != null &&
                telefono.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => mostrarAccionesContactoCliente(
                  context,
                  telefono: telefono,
                  nombre: pedido['cliente_nombre'] as String?,
                ),
                child: Ink(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: ColoresFoody.grisSuave,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.phone_outlined, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          telefono,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        'Llamar / WhatsApp',
                        style: TextStyle(
                          fontSize: 12,
                          color: ColoresFoody.primario,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (direccion != null && direccion.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  final la = latOk;
                  final ln = lngOk;
                  if (la != null && ln != null) {
                    _navegar(
                      context,
                      lat: la,
                      lng: ln,
                      etiqueta: direccion,
                    );
                  } else {
                    _copiar(context, direccion, 'Dirección copiada');
                  }
                },
                child: Ink(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: ColoresFoody.grisSuave,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 20,
                        color: tieneGps
                            ? ColoresFoody.secundario
                            : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              direccion,
                              style: const TextStyle(height: 1.35),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              tieneGps
                                  ? 'Toca para abrir en mapa'
                                  : 'Sin GPS — toca para copiar',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Copiar dirección',
                        onPressed: () =>
                            _copiar(context, direccion, 'Dirección copiada'),
                        icon: const Icon(Icons.copy_outlined, size: 18),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (mostrarMiniMapa && latOk != null && lngOk != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 110,
                  child: MapaFoody(
                    centro: LatLng(latOk, lngOk),
                    zoom: 15,
                    interactuable: false,
                    mostrarControles: false,
                    marcadores: [
                      MarcadorFoody(
                        lat: latOk,
                        lng: lngOk,
                        color: ColoresFoody.secundario,
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...pagos.map(_chipPago),
                if (mostrarIrRestaurante && sLat != null && sLng != null)
                  ActionChip(
                    avatar: const Icon(Icons.storefront_outlined, size: 16),
                    label: const Text('Ir al restaurante'),
                    onPressed: () => _navegar(
                      context,
                      lat: sLat,
                      lng: sLng,
                      etiqueta: pedido['sucursal_direccion'] as String? ??
                          pedido['sucursal_nombre'] as String?,
                    ),
                  ),
                if (latOk != null && lngOk != null)
                  ActionChip(
                    avatar: const Icon(Icons.navigation_outlined, size: 16),
                    label: const Text('Ir al cliente'),
                    onPressed: () => _navegar(
                      context,
                      lat: latOk,
                      lng: lngOk,
                      etiqueta: direccion,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _filaMonto(
              productoNeto == null ? 'Producto (subtotal)' : 'Producto',
              producto,
            ),
            if (domicilio > 0) _filaMonto('Domicilio', domicilio),
            const Divider(height: 16),
            _filaMonto(
              saldoPendiente == null ? 'Total del pedido' : 'Saldo por cobrar',
              saldoPendiente ?? total,
              fuerte: true,
            ),
            const SizedBox(height: 14),
            if (estado == 'asignado' && onSalir != null)
              FilledButton.icon(
                onPressed: onSalir,
                icon: const Icon(Icons.two_wheeler),
                label: const Text('Salir en camino'),
                style: FilledButton.styleFrom(
                  backgroundColor: ColoresFoody.primario,
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            if (estado == 'en_camino' && onEntregar != null)
              FilledButton.icon(
                onPressed: onEntregar,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Confirmar entrega'),
                style: FilledButton.styleFrom(
                  backgroundColor: ColoresFoody.secundario,
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _chipPago(String texto) {
    return Chip(
      avatar: const Icon(Icons.payments_outlined, size: 16),
      label: Text(texto, style: const TextStyle(fontSize: 12)),
      visualDensity: VisualDensity.compact,
      backgroundColor: ColoresFoody.acento.withValues(alpha: 0.35),
    );
  }

  Widget _filaMonto(String etiqueta, num valor, {bool fuerte = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          Expanded(
            child: Text(
              etiqueta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fuerte ? null : Colors.black54,
                fontWeight: fuerte ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              _moneda.format(valor),
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: fuerte ? FontWeight.w800 : FontWeight.w500,
                fontSize: fuerte ? 16 : 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
