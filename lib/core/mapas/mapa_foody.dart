import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
import 'package:reserva_canchas/core/mapas/constantes_mapa.dart';
import 'package:reserva_canchas/core/mapas/utilidades_mapa.dart';

/// Marcador simple en el mapa Foody.
class MarcadorFoody {
  const MarcadorFoody({
    required this.lat,
    required this.lng,
    this.etiqueta,
    this.color = ColoresFoody.primario,
    this.icono = Icons.place,
  });

  final double lat;
  final double lng;
  final String? etiqueta;
  final Color color;
  final IconData icono;
}

/// Anillo de cobertura (radio en km desde un centro).
class AnilloZonaFoody {
  const AnilloZonaFoody({
    required this.centroLat,
    required this.centroLng,
    required this.radioKm,
    required this.color,
    this.etiqueta,
  });

  final double centroLat;
  final double centroLng;
  final double radioKm;
  final Color color;
  final String? etiqueta;
}

/// Mapa reutilizable con tiles OpenStreetMap (sin Google Maps).
class MapaFoody extends StatefulWidget {
  const MapaFoody({
    super.key,
    required this.centro,
    this.zoom = ConstantesMapa.zoomInicial,
    this.altura,
    this.marcadores = const [],
    this.anillos = const [],
    this.interactuable = true,
    this.mostrarControles = true,
    this.mostrarAtribucion = true,
    this.onTap,
    this.onCentroCambiado,
  });

  final LatLng centro;
  final double zoom;
  final double? altura;
  final List<MarcadorFoody> marcadores;
  final List<AnilloZonaFoody> anillos;
  final bool interactuable;
  final bool mostrarControles;
  final bool mostrarAtribucion;
  final void Function(double lat, double lng)? onTap;
  final void Function(double lat, double lng)? onCentroCambiado;

  @override
  State<MapaFoody> createState() => _MapaFoodyState();
}

class _MapaFoodyState extends State<MapaFoody> {
  late final MapController _controller;
  late LatLng _centro;

  @override
  void initState() {
    super.initState();
    _controller = MapController();
    _centro = widget.centro;
  }

  @override
  void didUpdateWidget(MapaFoody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.centro != widget.centro) {
      _centro = widget.centro;
      _controller.move(widget.centro, widget.zoom);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mapa = FlutterMap(
      mapController: _controller,
      options: MapOptions(
        initialCenter: _centro,
        initialZoom: widget.zoom,
        interactionOptions: InteractionOptions(
          flags:
              widget.interactuable ? InteractiveFlag.all : InteractiveFlag.none,
        ),
        onTap: widget.onTap == null
            ? null
            : (_, punto) => widget.onTap!(punto.latitude, punto.longitude),
        onPositionChanged: (pos, _) {
          widget.onCentroCambiado?.call(
            pos.center.latitude,
            pos.center.longitude,
          );
        },
      ),
      children: [
        TileLayer(
          urlTemplate: ConstantesMapa.urlTiles,
          userAgentPackageName: 'com.foody.app',
        ),
        if (widget.anillos.isNotEmpty)
          PolygonLayer(
            polygons: widget.anillos
                .map(
                  (a) => Polygon(
                    points: _puntosAnillo(a),
                    color: a.color.withValues(alpha: 0.12),
                    borderColor: a.color.withValues(alpha: 0.85),
                    borderStrokeWidth: 2,
                  ),
                )
                .toList(),
          ),
        if (widget.marcadores.isNotEmpty)
          MarkerLayer(
            markers: widget.marcadores
                .map(
                  (m) => Marker(
                    point: LatLng(m.lat, m.lng),
                    width: 40,
                    height: 40,
                    child: Icon(m.icono, color: m.color, size: 36),
                  ),
                )
                .toList(),
          ),
        if (widget.mostrarAtribucion)
          RichAttributionWidget(
            alignment: AttributionAlignment.bottomLeft,
            attributions: [
              TextSourceAttribution(ConstantesMapa.atribucion),
            ],
          ),
      ],
    );

    Widget contenido = mapa;
    if (widget.altura != null) {
      contenido = SizedBox(height: widget.altura, child: mapa);
    }

    if (!widget.mostrarControles) return contenido;

    return Stack(
      children: [
        contenido,
        Positioned(
          right: 8,
          bottom: widget.mostrarAtribucion ? 28 : 8,
          child: ControlesZoomMapa(
            onAcercar: () {
              _controller.move(
                _controller.camera.center,
                _controller.camera.zoom + 1,
              );
            },
            onAlejar: () {
              _controller.move(
                _controller.camera.center,
                _controller.camera.zoom - 1,
              );
            },
          ),
        ),
      ],
    );
  }

  List<LatLng> _puntosAnillo(AnilloZonaFoody a) {
    return UtilidadesMapa.puntosCirculo(
      a.centroLat,
      a.centroLng,
      a.radioKm,
    );
  }
}

/// Controles de mapa con etiquetas y un área táctil accesible.
class ControlesZoomMapa extends StatelessWidget {
  const ControlesZoomMapa({
    super.key,
    required this.onAcercar,
    required this.onAlejar,
  });

  final VoidCallback onAcercar;
  final VoidCallback onAlejar;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _boton(context, Icons.add, 'Acercar mapa', onAcercar),
        const SizedBox(height: 4),
        _boton(context, Icons.remove, 'Alejar mapa', onAlejar),
      ],
    );
  }

  Widget _boton(
    BuildContext context,
    IconData icono,
    String etiqueta,
    VoidCallback onPressed,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface.withValues(alpha: 0.96),
      elevation: 2,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        tooltip: etiqueta,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: const Size(48, 48),
          fixedSize: const Size(48, 48),
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
        icon: Icon(icono, size: 20),
      ),
    );
  }
}
