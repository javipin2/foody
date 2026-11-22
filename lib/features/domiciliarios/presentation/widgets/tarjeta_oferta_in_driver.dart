import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
import 'package:reserva_canchas/core/mapas/mapa_foody.dart';
import 'package:reserva_canchas/core/mapas/utilidad_navegacion.dart';

/// Tarjeta oferta estilo app repartidor (countdown + aceptar/rechazar).
class TarjetaOfertaInDriver extends StatefulWidget {
  const TarjetaOfertaInDriver({
    super.key,
    required this.oferta,
    required this.onAceptar,
    required this.onRechazar,
    required this.onVerUbicacion,
    this.onExpirada,
    this.procesando = false,
    this.indice = 1,
    this.total = 1,
  });

  final Map<String, dynamic> oferta;
  final VoidCallback onAceptar;
  final VoidCallback onRechazar;
  final void Function(double lat, double lng) onVerUbicacion;
  final VoidCallback? onExpirada;
  final bool procesando;
  final int indice;
  final int total;

  @override
  State<TarjetaOfertaInDriver> createState() => _TarjetaOfertaInDriverState();
}

class _TarjetaOfertaInDriverState extends State<TarjetaOfertaInDriver> {
  Timer? _tick;
  double _progreso = 1;
  int _segRestantes = 0;
  int _ttlMs = 60000;

  static final _moneda = NumberFormat.currency(
    locale: 'es_CO',
    symbol: r'$',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _calcularTtl();
    _actualizarProgreso();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(_actualizarProgreso);
    });
  }

  @override
  void didUpdateWidget(covariant TarjetaOfertaInDriver oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.oferta['oferta_id'] != widget.oferta['oferta_id'] ||
        oldWidget.oferta['expira_at'] != widget.oferta['expira_at']) {
      _calcularTtl();
      _actualizarProgreso();
    }
  }

  void _calcularTtl() {
    final expira =
        DateTime.tryParse('${widget.oferta['expira_at']}')?.toLocal();
    // TTL = restante al recibir + buffer; usa expira_en_seg si viene del API.
    final segCfg = int.tryParse('${widget.oferta['expira_en_seg'] ?? ''}');
    if (segCfg != null && segCfg > 0) {
      _ttlMs = segCfg * 1000;
      return;
    }
    if (expira != null) {
      final restante = expira.difference(DateTime.now()).inMilliseconds;
      _ttlMs = restante.clamp(10000, 180000);
    } else {
      _ttlMs = 60000;
    }
  }

  void _actualizarProgreso() {
    final expira =
        DateTime.tryParse('${widget.oferta['expira_at']}')?.toLocal();
    if (expira == null) {
      _progreso = 0;
      _segRestantes = 0;
      return;
    }
    final restante = expira.difference(DateTime.now());
    final nuevo = (restante.inMilliseconds / _ttlMs).clamp(0.0, 1.0);
    if (_progreso > 0 && nuevo <= 0) {
      widget.onExpirada?.call();
    }
    _progreso = nuevo;
    _segRestantes = restante.isNegative ? 0 : restante.inSeconds;
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  double? get _lat => _parseCoord(widget.oferta['lat']);
  double? get _lng => _parseCoord(widget.oferta['lng']);

  static double? _parseCoord(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse('$v');
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.oferta;
    final ganancia = num.tryParse('${o['ganancia_estimada']}') ??
        num.tryParse('${o['costo_domicilio']}') ??
        0;
    final radio = o['radio_busqueda_km'];
    final tieneUbicacion = _lat != null && _lng != null;

    return Material(
      elevation: 12,
      borderRadius: BorderRadius.circular(20),
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: LinearProgressIndicator(
              value: _progreso,
              minHeight: 5,
              backgroundColor: Colors.grey.shade200,
              color: _progreso < 0.2
                  ? ColoresFoody.error
                  : ColoresFoody.primario,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: ColoresFoody.primario.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Nuevo · ${_segRestantes}s',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: ColoresFoody.primario,
                        ),
                      ),
                    ),
                    if (radio != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '${radio is num ? radio : radio} km',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                    if (widget.total > 1) ...[
                      const Spacer(),
                      Text(
                        '${widget.indice}/${widget.total}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Pedido ${o['numero_pedido'] ?? ''}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  o['cliente_nombre'] as String? ?? 'Cliente',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  o['sucursal_nombre'] as String? ?? 'Restaurante',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 20,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        o['direccion_entrega'] as String? ?? 'Sin dirección',
                        style: const TextStyle(fontSize: 14, height: 1.35),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ColoresFoody.secundario.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.payments_outlined,
                        color: ColoresFoody.secundario,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Ganas ${_moneda.format(ganancia)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: ColoresFoody.secundario,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: tieneUbicacion && !widget.procesando
                      ? () => widget.onVerUbicacion(_lat!, _lng!)
                      : null,
                  icon: const Icon(Icons.map_outlined, size: 18),
                  label: Text(
                    tieneUbicacion
                        ? 'Ver ubicación / navegar'
                        : 'Sin ubicación GPS del cliente',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            widget.procesando ? null : widget.onRechazar,
                        child: const Text('Rechazar'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed:
                            widget.procesando ? null : widget.onAceptar,
                        style: FilledButton.styleFrom(
                          backgroundColor: ColoresFoody.primario,
                          minimumSize: const Size.fromHeight(48),
                        ),
                        child: widget.procesando
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Aceptar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Mini mapa modal para previsualizar destino de oferta.
Future<void> mostrarMapaOferta(
  BuildContext context, {
  required double lat,
  required double lng,
  String? direccion,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Destino del cliente',
              style: Theme.of(ctx).textTheme.titleMedium,
            ),
            if (direccion != null) ...[
              const SizedBox(height: 4),
              Text(direccion, style: TextStyle(color: Colors.grey.shade700)),
            ],
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 220,
                child: MapaFoody(
                  centro: LatLng(lat, lng),
                  zoom: 15,
                  marcadores: [
                    MarcadorFoody(
                      lat: lat,
                      lng: lng,
                      color: ColoresFoody.secundario,
                      etiqueta: 'Cliente',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => UtilidadNavegacion.abrir(
                lat: lat,
                lng: lng,
                etiqueta: direccion,
              ),
              icon: const Icon(Icons.navigation),
              label: const Text('Abrir en Waze / Maps'),
            ),
          ],
        ),
      ),
    ),
  );
}
