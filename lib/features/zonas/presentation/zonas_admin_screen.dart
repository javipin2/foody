import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
import 'package:reserva_canchas/core/mapas/constantes_mapa.dart';
import 'package:reserva_canchas/core/mapas/mapa_foody.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';
import 'package:reserva_canchas/core/utilidades/parsear_numero.dart';
import 'package:reserva_canchas/features/zonas/data/zonas_repository.dart';
import 'package:reserva_canchas/widgets/mapa_seleccion_ubicacion.dart';

/// Zonas de cobertura por radio (km) y precio de domicilio — admin.
class ZonasAdminScreen extends StatefulWidget {
  const ZonasAdminScreen({super.key, required this.sucursalId});

  final String? sucursalId;

  @override
  State<ZonasAdminScreen> createState() => _ZonasAdminScreenState();
}

class _ZonasAdminScreenState extends State<ZonasAdminScreen> {
  final _repo = ZonasRepository();
  List<Map<String, dynamic>> _zonas = [];
  double? _sucursalLat;
  double? _sucursalLng;
  String _sucursalNombre = 'Sucursal';
  bool _cargando = true;
  String? _error;

  static const _coloresAnillos = [
    Color(0xFF2EC4B6),
    Color(0xFFFF6B35),
    Color(0xFFFFE66D),
    Color(0xFF534AB7),
    Color(0xFFE71D36),
  ];

  final _formato = NumberFormat.currency(
    locale: 'es_CO',
    symbol: r'$',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final sucursalId = widget.sucursalId;
    if (sucursalId == null) {
      setState(() {
        _cargando = false;
        _error = 'Sin sucursal asignada';
      });
      return;
    }
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final cfg = await _repo.configuracionMapa(sucursalId);
      final sucursal = Map<String, dynamic>.from(
        cfg['sucursal'] as Map<String, dynamic>,
      );
      final zonas = (cfg['zonas'] as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map<String, dynamic>))
          .toList();
      if (!mounted) return;
      setState(() {
        _sucursalNombre = sucursal['nombre'] as String? ?? 'Sucursal';
        _sucursalLat = _aDouble(sucursal['lat']);
        _sucursalLng = _aDouble(sucursal['lng']);
        _zonas = zonas;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = mensajeErrorHttp(e, contexto: 'cargar zonas');
      });
    }
  }

  double? _aDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse('$v');
  }

  void _avisar(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? ColoresFoody.error : ColoresFoody.exito,
      ),
    );
  }

  Future<void> _ubicarSucursal() async {
    final sucursalId = widget.sucursalId;
    if (sucursalId == null) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: MapaSeleccionUbicacion(
              titulo: 'Ubicación de la sucursal',
              latitudInicial: _sucursalLat,
              longitudInicial: _sucursalLng,
              onUbicacionSeleccionada: (lat, lng) async {
                try {
                  await _repo.actualizarUbicacionSucursal(
                    sucursalId: sucursalId,
                    lat: lat,
                    lng: lng,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  _avisar('Ubicación de sucursal guardada');
                  _cargar();
                } catch (e) {
                  _avisar(
                    mensajeErrorHttp(e, contexto: 'guardar ubicación'),
                    error: true,
                  );
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _dialogoZona({Map<String, dynamic>? zona}) async {
    final sucursalId = widget.sucursalId;
    if (sucursalId == null) return;

    final nombreCtrl =
        TextEditingController(text: zona?['nombre'] as String? ?? '');
    final costoCtrl = TextEditingController(
      text: zona != null ? '${zona['costo_domicilio']}' : '4000',
    );
    final distCtrl = TextEditingController(
      text: zona != null ? '${zona['distancia_max_km']}' : '3',
    );
    final esEdicion = zona != null;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(esEdicion ? 'Editar anillo' : 'Nuevo anillo de cobertura'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Define hasta cuántos km desde la sucursal aplica este precio. '
                'Ejemplo: 3 km → \$4.000, 8 km → \$7.000.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nombreCtrl,
                decoration: const InputDecoration(labelText: 'Nombre de la zona'),
              ),
              TextField(
                controller: costoCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Precio domicilio (COP)',
                ),
              ),
              TextField(
                controller: distCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Radio máximo desde sucursal (km)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (ok != true) {
      nombreCtrl.dispose();
      costoCtrl.dispose();
      distCtrl.dispose();
      return;
    }

    final nombre = nombreCtrl.text.trim();
    final costo = num.tryParse(costoCtrl.text.trim());
    final dist = num.tryParse(distCtrl.text.trim());
    nombreCtrl.dispose();
    costoCtrl.dispose();
    distCtrl.dispose();

    if (nombre.isEmpty || costo == null || dist == null) {
      _avisar('Completa todos los campos', error: true);
      return;
    }

    try {
      if (esEdicion) {
        await _repo.actualizar(
          id: zona['id'] as String,
          sucursalId: sucursalId,
          nombre: nombre,
          costoDomicilio: costo,
          distanciaMaxKm: dist,
        );
      } else {
        await _repo.crear(
          sucursalId: sucursalId,
          nombre: nombre,
          costoDomicilio: costo,
          distanciaMaxKm: dist,
        );
      }
      _avisar(esEdicion ? 'Zona actualizada' : 'Zona creada');
      _cargar();
    } catch (e) {
      _avisar(mensajeErrorHttp(e, contexto: 'guardar zona'), error: true);
    }
  }

  Future<void> _desactivar(Map<String, dynamic> zona) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desactivar zona'),
        content: Text('¿Desactivar «${zona['nombre']}»?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sí'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      await _repo.desactivar(
        zona['id'] as String,
        sucursalId: widget.sucursalId,
      );
      _avisar('Zona desactivada');
      _cargar();
    } catch (e) {
      _avisar(mensajeErrorHttp(e, contexto: 'desactivar zona'), error: true);
    }
  }

  List<AnilloZonaFoody> _anillosMapa() {
    if (_sucursalLat == null || _sucursalLng == null) return [];
    final activas = _zonas.where((z) => z['activa'] != false).toList()
      ..sort(
        (a, b) => parsearDouble(a['distancia_max_km'])
            .compareTo(parsearDouble(b['distancia_max_km'])),
      );
    return activas.asMap().entries.map((entry) {
      final z = entry.value;
      final color = _coloresAnillos[entry.key % _coloresAnillos.length];
      return AnilloZonaFoody(
        centroLat: _sucursalLat!,
        centroLng: _sucursalLng!,
        radioKm: parsearDouble(z['distancia_max_km']),
        color: color,
        etiqueta: z['nombre'] as String?,
      );
    }).toList();
  }

  double _zoomParaAnillos() {
    if (_zonas.isEmpty) return ConstantesMapa.zoomInicial;
    final maxKm = _zonas
        .map((z) => parsearDouble(z['distancia_max_km']))
        .fold<double>(3, (a, b) => b > a ? b : a);
    if (maxKm <= 3) return 14;
    if (maxKm <= 6) return 13;
    if (maxKm <= 12) return 12;
    return 11;
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: TextStyle(color: ColoresFoody.error)),
            const SizedBox(height: 12),
            FilledButton(onPressed: _cargar, child: const Text('Reintentar')),
          ],
        ),
      );
    }

    final tieneUbicacion = _sucursalLat != null && _sucursalLng != null;

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Zonas de domicilio',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              FilledButton.icon(
                onPressed: () => _dialogoZona(),
                icon: const Icon(Icons.add),
                label: const Text('Anillo'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Cada anillo define el precio hasta X km desde $_sucursalNombre. '
            'Al pedir, el cliente paga el costo del primer anillo que alcance su distancia.',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          ),
          const SizedBox(height: 12),
          if (!tieneUbicacion)
            Card(
              color: ColoresFoody.acento.withValues(alpha: 0.25),
              child: ListTile(
                leading: const Icon(Icons.warning_amber_rounded),
                title: const Text('Falta ubicar la sucursal'),
                subtitle: const Text(
                  'Los anillos de radio se dibujan desde el punto de la sede.',
                ),
                trailing: FilledButton(
                  onPressed: _ubicarSucursal,
                  child: const Text('Ubicar'),
                ),
              ),
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: MapaFoody(
                altura: 260,
                centro: LatLng(_sucursalLat!, _sucursalLng!),
                zoom: _zoomParaAnillos(),
                anillos: _anillosMapa(),
                marcadores: [
                  MarcadorFoody(
                    lat: _sucursalLat!,
                    lng: _sucursalLng!,
                    etiqueta: _sucursalNombre,
                    color: ColoresFoody.primario,
                    icono: Icons.store,
                  ),
                ],
                interactuable: true,
              ),
            ),
          if (tieneUbicacion) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _ubicarSucursal,
                icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
                label: const Text('Cambiar ubicación sucursal'),
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (_zonas.isEmpty)
            Card(
              child: ListTile(
                title: const Text('Sin anillos configurados'),
                subtitle: Text(
                  'Se usará costo por defecto (${_formato.format(5000)})',
                ),
              ),
            )
          else
            ..._zonas.asMap().entries.map((entry) {
              final z = entry.value;
              final activa = z['activa'] != false;
              final color = _coloresAnillos[entry.key % _coloresAnillos.length];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: color.withValues(alpha: 0.2),
                    child: Icon(Icons.radio_button_unchecked, color: color),
                  ),
                  title: Text(z['nombre'] as String? ?? 'Zona'),
                  subtitle: Text(
                    '${_formato.format(parsearNumero(z['costo_domicilio']))} · '
                    'hasta ${parsearDouble(z['distancia_max_km'])} km'
                    '${activa ? '' : ' · inactiva'}',
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'editar') _dialogoZona(zona: z);
                      if (v == 'desactivar' && activa) _desactivar(z);
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'editar',
                        child: Text('Editar'),
                      ),
                      if (activa)
                        const PopupMenuItem(
                          value: 'desactivar',
                          child: Text('Desactivar'),
                        ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
