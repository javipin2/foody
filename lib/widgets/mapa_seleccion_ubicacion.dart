import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
import 'package:reserva_canchas/core/mapas/constantes_mapa.dart';
import 'package:reserva_canchas/core/mapas/geografia_repository.dart';
import 'package:reserva_canchas/core/mapas/mapa_foody.dart';

/// Selector de ubicación con OpenStreetMap (sin Google Maps).
class MapaSeleccionUbicacion extends StatefulWidget {
  const MapaSeleccionUbicacion({
    super.key,
    this.latitudInicial,
    this.longitudInicial,
    this.titulo = 'Ubicación',
    required this.onUbicacionSeleccionada,
  });

  final double? latitudInicial;
  final double? longitudInicial;
  final String titulo;
  final void Function(double latitud, double longitud) onUbicacionSeleccionada;

  @override
  State<MapaSeleccionUbicacion> createState() => _MapaSeleccionUbicacionState();
}

class _MapaSeleccionUbicacionState extends State<MapaSeleccionUbicacion> {
  final _busquedaCtrl = TextEditingController();
  final _geografia = GeografiaRepository();
  LatLng? _ubicacion;
  bool _cargandoGps = false;
  bool _buscando = false;
  List<ResultadoGeografia> _resultados = [];
  bool _mostrarResultados = false;
  Timer? _debounceUbicacion;
  Timer? _debounceBusqueda;
  bool _cerrado = false;

  @override
  void initState() {
    super.initState();
    if (widget.latitudInicial != null && widget.longitudInicial != null) {
      _ubicacion = LatLng(widget.latitudInicial!, widget.longitudInicial!);
    } else {
      _ubicacion = ConstantesMapa.ubicacionDefault;
    }
    if (!kIsWeb) {
      Geolocator.checkPermission();
    }
  }

  @override
  void dispose() {
    _cerrado = true;
    _debounceUbicacion?.cancel();
    _debounceBusqueda?.cancel();
    _busquedaCtrl.dispose();
    super.dispose();
  }

  void _notificarUbicacion(LatLng punto) {
    _debounceUbicacion?.cancel();
    _debounceUbicacion = Timer(const Duration(milliseconds: 300), () {
      if (!_cerrado && mounted) {
        widget.onUbicacionSeleccionada(punto.latitude, punto.longitude);
      }
    });
  }

  void _fijarUbicacion(LatLng punto) {
    setState(() => _ubicacion = punto);
    _notificarUbicacion(punto);
  }

  Future<void> _irAMiUbicacion() async {
    if (_cerrado || !mounted) return;
    setState(() => _cargandoGps = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _mensaje('Activa los servicios de ubicación', Colors.orange);
        return;
      }
      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
      }
      if (permiso == LocationPermission.denied ||
          permiso == LocationPermission.deniedForever) {
        _mensaje('Se necesitan permisos de ubicación', ColoresFoody.error);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 10));
      final punto = LatLng(pos.latitude, pos.longitude);
      _fijarUbicacion(punto);
      _mensaje('Ubicación actual obtenida', ColoresFoody.exito);
    } catch (_) {
      _mensaje('No se pudo obtener la ubicación', ColoresFoody.error);
    } finally {
      if (mounted) setState(() => _cargandoGps = false);
    }
  }

  void _mensaje(String texto, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texto), backgroundColor: color),
    );
  }

  Future<void> _buscar(String consulta) async {
    if (consulta.length < 3 || _cerrado) {
      setState(() {
        _resultados = [];
        _mostrarResultados = false;
      });
      return;
    }
    setState(() => _buscando = true);
    try {
      final res = await _geografia.buscar(
        consulta,
        lat: _ubicacion?.latitude,
        lng: _ubicacion?.longitude,
      );
      if (!_cerrado && mounted) {
        setState(() {
          _resultados = res;
          _mostrarResultados = res.isNotEmpty;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _resultados = [];
          _mostrarResultados = false;
        });
      }
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

  void _elegirResultado(ResultadoGeografia r) {
    _busquedaCtrl.text = r.etiqueta;
    setState(() => _mostrarResultados = false);
    _fijarUbicacion(LatLng(r.lat, r.lng));
  }

  @override
  Widget build(BuildContext context) {
    final punto = _ubicacion ?? ConstantesMapa.ubicacionDefault;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.titulo,
          style: GoogleFonts.montserrat(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 300,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: ColoresFoody.secundario.withValues(alpha: 0.5),
              width: 2,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              children: [
                MapaFoody(
                  centro: punto,
                  zoom: ConstantesMapa.zoomDetalle,
                  marcadores: [
                    MarcadorFoody(
                      lat: punto.latitude,
                      lng: punto.longitude,
                      color: ColoresFoody.primario,
                    ),
                  ],
                  onTap: (lat, lng) => _fijarUbicacion(LatLng(lat, lng)),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: Column(
                    children: [
                      Material(
                        elevation: 2,
                        borderRadius: BorderRadius.circular(12),
                        child: TextField(
                          controller: _busquedaCtrl,
                          decoration: InputDecoration(
                            hintText: 'Buscar dirección…',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _buscando
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  )
                                : _busquedaCtrl.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 20),
                                        onPressed: () {
                                          _busquedaCtrl.clear();
                                          setState(() {
                                            _resultados = [];
                                            _mostrarResultados = false;
                                          });
                                        },
                                      )
                                    : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          onChanged: (v) {
                            _debounceBusqueda?.cancel();
                            if (v.length >= 3) {
                              _debounceBusqueda = Timer(
                                const Duration(milliseconds: 450),
                                () => _buscar(v),
                              );
                            } else {
                              setState(() {
                                _resultados = [];
                                _mostrarResultados = false;
                              });
                            }
                          },
                        ),
                      ),
                      if (_mostrarResultados)
                        Container(
                          margin: const EdgeInsets.only(top: 6),
                          constraints: const BoxConstraints(maxHeight: 160),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _resultados.length,
                            itemBuilder: (_, i) {
                              final r = _resultados[i];
                              return ListTile(
                                dense: true,
                                leading: const Icon(
                                  Icons.location_on_outlined,
                                  color: ColoresFoody.secundario,
                                ),
                                title: Text(
                                  r.etiqueta,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13),
                                ),
                                onTap: () => _elegirResultado(r),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: FloatingActionButton.small(
                    heroTag: 'gps_mapa',
                    backgroundColor: Colors.white,
                    onPressed: _cargandoGps ? null : _irAMiUbicacion,
                    child: _cargandoGps
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(
                            Icons.my_location,
                            color: ColoresFoody.primario,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (_ubicacion != null)
          Text(
            'Coordenadas: ${_ubicacion!.latitude.toStringAsFixed(6)}, '
            '${_ubicacion!.longitude.toStringAsFixed(6)}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
      ],
    );
  }
}
