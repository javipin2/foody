import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:reserva_canchas/core/layout/foody_breakpoints.dart';
import 'package:reserva_canchas/core/mapas/constantes_mapa.dart';
import 'package:reserva_canchas/core/mapas/mapa_foody.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';
import 'package:reserva_canchas/core/saas_ui/saas_ui.dart';
import 'package:reserva_canchas/core/utilidades/parsear_numero.dart';
import 'package:reserva_canchas/core/widgets/foody_dialogo.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_skeleton.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_tokens.dart';
import 'package:reserva_canchas/features/zonas/data/zonas_repository.dart';
import 'package:reserva_canchas/widgets/mapa_seleccion_ubicacion.dart';

/// Zonas de cobertura por radio (km) y precio de domicilio — admin.
///
/// UX: mapa + lista en paralelo en escritorio; edición con presets (km/precio);
/// ubicación sobre el mapa; anillos ordenados por distancia.
class ZonasAdminScreen extends StatefulWidget {
  const ZonasAdminScreen({super.key, required this.sucursalId});

  final String? sucursalId;

  @override
  State<ZonasAdminScreen> createState() => _ZonasAdminScreenState();
}

class _ZonasAdminScreenState extends State<ZonasAdminScreen> {
  ColorScheme get _scheme => Theme.of(context).colorScheme;

  final _repo = ZonasRepository();
  List<Map<String, dynamic>> _zonas = [];
  double? _sucursalLat;
  double? _sucursalLng;
  String _sucursalNombre = 'Sucursal';
  bool _cargando = true;
  String? _error;
  bool _mostrarAyuda = false;

  static const _coloresAnillos = [
    Color(0xFF16A34A),
    Color(0xFFD97706),
    Color(0xFF2563EB),
    Color(0xFF7C3AED),
    Color(0xFFDC2626),
  ];

  static const _presetsKm = [1.0, 2.0, 3.0, 5.0, 8.0, 10.0, 15.0];
  static const _presetsPrecio = [3000, 4000, 5000, 7000, 10000, 12000];

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

  /// Anillos activos ordenados de más cercano a más lejano (como cobra el API).
  List<Map<String, dynamic>> get _zonasOrdenadas {
    final lista = List<Map<String, dynamic>>.from(_zonas);
    lista.sort(
      (a, b) => parsearDouble(a['distancia_max_km'])
          .compareTo(parsearDouble(b['distancia_max_km'])),
    );
    return lista;
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
        backgroundColor: error ? AnaliticaTokens.alertas : _scheme.onSurface,
      ),
    );
  }

  Future<void> _ubicarSucursal() async {
    final sucursalId = widget.sucursalId;
    if (sucursalId == null) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _scheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
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

    final resultado = await FoodyDialogo.mostrar<_ResultadoAnillo>(
      context: context,
      builder: (ctx) => _DialogoAnillo(
        zona: zona,
        formato: _formato,
        presetsKm: _presetsKm,
        presetsPrecio: _presetsPrecio,
      ),
    );
    if (resultado == null) return;

    final nombre = resultado.nombre;
    final costo = resultado.costo;
    final dist = resultado.dist;

    if (nombre.isEmpty || dist <= 0) {
      _avisar('Completa nombre, precio y un radio mayor a 0', error: true);
      return;
    }

    // Aviso UX (no bloquea): dos anillos con el mismo radio confunden el cobro.
    final duplicado = _zonas.any(
      (z) =>
          z['id'] != zona?['id'] &&
          z['activa'] != false &&
          (parsearDouble(z['distancia_max_km']) - dist).abs() < 0.01,
    );
    if (duplicado) {
      _avisar(
        'Ya hay un anillo con ese radio. El cobro puede quedar ambiguo.',
        error: true,
      );
    }

    try {
      if (zona != null) {
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
      _avisar(zona != null ? 'Zona actualizada' : 'Zona creada');
      _cargar();
    } catch (e) {
      _avisar(mensajeErrorHttp(e, contexto: 'guardar zona'), error: true);
    }
  }

  Future<void> _desactivar(Map<String, dynamic> zona) async {
    final confirmar = await FoodyDialogo.mostrar<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desactivar zona'),
        content: Text(
          '¿Desactivar «${zona['nombre']}»? Dejará de usarse para calcular el domicilio.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Desactivar'),
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
    final activas = _zonasOrdenadas.where((z) => z['activa'] != false).toList();
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

  int get _activas => _zonas.where((z) => z['activa'] != false).length;

  @override
  Widget build(BuildContext context) {
    final ancho = FoodyBreakpoints.widthOf(context);
    final compacto = FoodyBreakpoints.esCompact(ancho);
    final dual = ancho >= 980;
    final tieneUbicacion = _sucursalLat != null && _sucursalLng != null;

    return ColoredBox(
      color: _scheme.surface,
      child: SaasScrollableShell(
        header: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              compacto ? 12 : 20,
              8,
              compacto ? 12 : 20,
              8,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Admin / Domicilio',
                  style: TextStyle(
                    fontSize: 11,
                    color: _scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Zonas de domicilio',
                            style: TextStyle(
                              fontSize: compacto ? 18 : 20,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.4,
                              color: _scheme.onSurface,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _cargando
                                ? 'Cargando…'
                                : '$_activas anillos · cobro por distancia desde $_sucursalNombre',
                            style: TextStyle(
                              color: _scheme.onSurfaceVariant,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cómo funciona',
                      onPressed: () =>
                          setState(() => _mostrarAyuda = !_mostrarAyuda),
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        _mostrarAyuda ? Icons.help : Icons.help_outline,
                        color: _scheme.onSurfaceVariant,
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () => _dialogoZona(),
                      style: FilledButton.styleFrom(
                        backgroundColor: _scheme.primary,
                        foregroundColor: _scheme.onPrimary,
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(compacto ? 'Anillo' : 'Nuevo anillo'),
                    ),
                  ],
                ),
                if (_mostrarAyuda) ...[
                  const SizedBox(height: 10),
                  _bloqueAyuda(),
                ],
              ],
            ),
          ),
        ],
        body: _cargando
            ? AnaliticaSkeleton.tab()
            : _error != null
                ? _estadoError()
                : RefreshIndicator(
                    onRefresh: _cargar,
                    color: _scheme.onSurface,
                    child: dual
                        ? _layoutDual(tieneUbicacion)
                        : _layoutApilado(tieneUbicacion, compacto),
                  ),
      ),
    );
  }

  Widget _bloqueAyuda() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cómo cobra Foody',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _scheme.onSurface,
            ),
          ),
          SizedBox(height: 6),
          Text(
            '1. Ubica la sede en el mapa (punto central).\n'
            '2. Crea anillos de cerca → lejos (cada uno con km y precio).\n'
            '3. Al pedir, se usa el anillo más cercano que cubra la distancia del cliente.\n'
            'Ejemplo: 1,5 km cae en «hasta 2 km»; 2,5 km cae en «hasta 3 km».',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: _scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _layoutDual(bool tieneUbicacion) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 5,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 10, 32),
            children: [
              if (!tieneUbicacion) _avisoSinUbicacion() else _mapa(altura: 420),
            ],
          ),
        ),
        Expanded(
          flex: 4,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(10, 4, 20, 32),
            children: [
              _encabezadoLista(),
              const SizedBox(height: 10),
              if (_zonas.isEmpty) _vacio() else ..._listaAnillos(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _layoutApilado(bool tieneUbicacion, bool compacto) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        compacto ? 12 : 20,
        4,
        compacto ? 12 : 20,
        32,
      ),
      children: [
        if (!tieneUbicacion)
          _avisoSinUbicacion()
        else
          _mapa(altura: compacto ? 200 : 260),
        const SizedBox(height: 16),
        _encabezadoLista(),
        const SizedBox(height: 10),
        if (_zonas.isEmpty) _vacio() else ..._listaAnillos(),
      ],
    );
  }

  Widget _encabezadoLista() {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Anillos (cerca → lejos)',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: _scheme.onSurface,
            ),
          ),
        ),
        Text(
          '$_activas activos',
          style: TextStyle(
            fontSize: 12,
            color: _scheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  List<Widget> _listaAnillos() {
    final ordenadas = _zonasOrdenadas;
    final activasIdx = <String, int>{};
    var iActiva = 0;
    for (final z in ordenadas) {
      if (z['activa'] != false) {
        activasIdx[z['id'] as String] = iActiva++;
      }
    }

    return [
      for (var i = 0; i < ordenadas.length; i++)
        _tarjetaZona(
          ordenadas[i],
          colorIndex: activasIdx[ordenadas[i]['id']] ?? i,
          esPrimera: i == 0,
          esUltima: i == ordenadas.length - 1,
        ),
    ];
  }

  Widget _estadoError() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 48, 20, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
            border: Border.all(color: _scheme.outlineVariant),
            boxShadow: AnaliticaTokens.shadowSoft,
          ),
          child: Column(
            children: [
              const Icon(
                Icons.error_outline,
                size: 36,
                color: AnaliticaTokens.alertas,
              ),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  color: _scheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: _cargar,
                style: FilledButton.styleFrom(
                  backgroundColor: _scheme.primary,
                  foregroundColor: _scheme.onPrimary,
                ),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _avisoSinUbicacion() {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
        border: Border.all(color: _scheme.outlineVariant),
        boxShadow: AnaliticaTokens.shadowSoft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.place_outlined, color: Color(0xFFD97706)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Paso 1 · Ubica la sede',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Sin coordenadas no se pueden dibujar los anillos ni calcular '
            'distancia al cliente. Marca el punto en el mapa.',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: _scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _ubicarSucursal,
            style: FilledButton.styleFrom(
              backgroundColor: _scheme.primary,
              foregroundColor: _scheme.onPrimary,
            ),
            icon: const Icon(Icons.my_location, size: 18),
            label: const Text('Marcar ubicación en el mapa'),
          ),
        ],
      ),
    );
  }

  Widget _mapa({required double altura}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
        border: Border.all(color: _scheme.outlineVariant),
        boxShadow: AnaliticaTokens.shadowSoft,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          MapaFoody(
            altura: altura,
            centro: LatLng(_sucursalLat!, _sucursalLng!),
            zoom: _zoomParaAnillos(),
            anillos: _anillosMapa(),
            marcadores: [
              MarcadorFoody(
                lat: _sucursalLat!,
                lng: _sucursalLng!,
                etiqueta: _sucursalNombre,
                color: _scheme.onSurface,
                icono: Icons.store,
              ),
            ],
            interactuable: true,
          ),
          Positioned(
            left: 10,
            top: 10,
            child: _leyendaMapa(),
          ),
          Positioned(
            right: 10,
            top: 10,
            child: Material(
              color: _scheme.surfaceContainerLow.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(8),
              elevation: 2,
              child: InkWell(
                onTap: _ubicarSucursal,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.edit_location_alt_outlined,
                        size: 16,
                        color: _scheme.onSurface,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Ubicación',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _scheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _leyendaMapa() {
    final activas = _zonasOrdenadas.where((z) => z['activa'] != false).toList();
    if (activas.isEmpty) return const SizedBox.shrink();

    return Material(
      color: _scheme.surfaceContainerLow.withValues(alpha: 0.95),
      borderRadius: BorderRadius.circular(8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < activas.length && i < 5; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _coloresAnillos[i % _coloresAnillos.length],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${activas[i]['nombre']} · '
                      '${parsearDouble(activas[i]['distancia_max_km']).toString().replaceAll(RegExp(r'\.0$'), '')} km',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _scheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _vacio() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: _scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
        border: Border.all(color: _scheme.outlineVariant),
        boxShadow: AnaliticaTokens.shadowSoft,
      ),
      child: Column(
        children: [
          Text(
            'Paso 2 · Crea tus anillos',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _scheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sin anillos se cobra ${_formato.format(5000)} fijo. '
            'Empieza con 2–3 zonas (cerca / medio / lejos).',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: _scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              OutlinedButton(
                onPressed: () => _crearRapido('Cerca', 2, 4000),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _scheme.onSurface,
                  side: BorderSide(color: _scheme.outlineVariant),
                ),
                child: const Text('Cerca 2 km'),
              ),
              OutlinedButton(
                onPressed: () => _crearRapido('Medio', 4, 6000),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _scheme.onSurface,
                  side: BorderSide(color: _scheme.outlineVariant),
                ),
                child: const Text('Medio 4 km'),
              ),
              FilledButton(
                onPressed: () => _dialogoZona(),
                style: FilledButton.styleFrom(
                  backgroundColor: _scheme.primary,
                  foregroundColor: _scheme.onPrimary,
                ),
                child: const Text('Personalizar'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _crearRapido(String nombre, num km, num precio) async {
    final sid = widget.sucursalId;
    if (sid == null) return;
    try {
      await _repo.crear(
        sucursalId: sid,
        nombre: nombre,
        costoDomicilio: precio,
        distanciaMaxKm: km,
      );
      _avisar('Anillo «$nombre» creado');
      _cargar();
    } catch (e) {
      _avisar(mensajeErrorHttp(e, contexto: 'crear zona'), error: true);
    }
  }

  Widget _tarjetaZona(
    Map<String, dynamic> z, {
    required int colorIndex,
    required bool esPrimera,
    required bool esUltima,
  }) {
    final activa = z['activa'] != false;
    final color = _coloresAnillos[colorIndex % _coloresAnillos.length];
    final nombre = z['nombre'] as String? ?? 'Zona';
    final costo = parsearNumero(z['costo_domicilio']);
    final km = parsearDouble(z['distancia_max_km']);
    final kmLabel = km == km.roundToDouble() ? '${km.toInt()}' : '$km';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: _scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
        child: InkWell(
          onTap: () => _dialogoZona(zona: z),
          borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
              border: Border.all(color: _scheme.outlineVariant),
              boxShadow: AnaliticaTokens.shadowSoft,
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: activa ? color : _scheme.outlineVariant,
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(12),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
                      child: Row(
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color:
                                      activa ? color : _scheme.onSurfaceVariant,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              if (!esUltima)
                                Expanded(
                                  child: Container(
                                    width: 2,
                                    margin: const EdgeInsets.only(top: 4),
                                    color: _scheme.outlineVariant,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        nombre,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                          color: activa
                                              ? _scheme.onSurface
                                              : _scheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                    if (esPrimera && activa)
                                      Container(
                                        margin: const EdgeInsets.only(left: 6),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: color.withValues(alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(5),
                                        ),
                                        child: Text(
                                          'Más cercano',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: color,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Text(
                                      _formato.format(costo),
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.4,
                                        color: _scheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'hasta $kmLabel km',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: _scheme.onSurfaceVariant,
                                      ),
                                    ),
                                    if (!activa) ...[
                                      const SizedBox(width: 8),
                                      Text(
                                        'Inactiva',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: _scheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Editar',
                            onPressed: () => _dialogoZona(zona: z),
                            icon: Icon(
                              Icons.edit_outlined,
                              size: 18,
                              color: _scheme.onSurfaceVariant,
                            ),
                          ),
                          PopupMenuButton<String>(
                            tooltip: 'Más',
                            icon: Icon(
                              Icons.more_vert,
                              color: _scheme.onSurfaceVariant,
                            ),
                            onSelected: (v) {
                              if (v == 'editar') _dialogoZona(zona: z);
                              if (v == 'desactivar' && activa) _desactivar(z);
                            },
                            itemBuilder: (_) => [
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
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultadoAnillo {
  const _ResultadoAnillo({
    required this.nombre,
    required this.costo,
    required this.dist,
  });

  final String nombre;
  final num costo;
  final num dist;
}

/// Diálogo con controllers propios (dispose al cerrar el route, no antes).
class _DialogoAnillo extends StatefulWidget {
  const _DialogoAnillo({
    required this.zona,
    required this.formato,
    required this.presetsKm,
    required this.presetsPrecio,
  });

  final Map<String, dynamic>? zona;
  final NumberFormat formato;
  final List<double> presetsKm;
  final List<int> presetsPrecio;

  @override
  State<_DialogoAnillo> createState() => _DialogoAnilloState();
}

class _DialogoAnilloState extends State<_DialogoAnillo> {
  ColorScheme get _scheme => Theme.of(context).colorScheme;

  late final TextEditingController _nombreCtrl;
  late final TextEditingController _costoCtrl;
  late final TextEditingController _distCtrl;

  bool get _esEdicion => widget.zona != null;

  @override
  void initState() {
    super.initState();
    final z = widget.zona;
    _nombreCtrl = TextEditingController(text: z?['nombre'] as String? ?? '');
    _costoCtrl = TextEditingController(
      text:
          z != null ? '${parsearNumero(z['costo_domicilio']).round()}' : '5000',
    );
    final km = z != null ? parsearDouble(z['distancia_max_km']) : 3.0;
    _distCtrl = TextEditingController(
      text: km == km.roundToDouble() ? '${km.toInt()}' : '$km',
    );
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _costoCtrl.dispose();
    _distCtrl.dispose();
    super.dispose();
  }

  void _guardar() {
    final nombre = _nombreCtrl.text.trim();
    final costo = num.tryParse(_costoCtrl.text.trim());
    final dist = num.tryParse(_distCtrl.text.trim());
    if (nombre.isEmpty || costo == null || dist == null || dist <= 0) {
      return;
    }
    Navigator.pop(
      context,
      _ResultadoAnillo(nombre: nombre, costo: costo, dist: dist),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kmPreview = double.tryParse(_distCtrl.text.trim()) ?? 0;
    final precioPreview = int.tryParse(_costoCtrl.text.trim()) ?? 0;

    return AlertDialog(
      title: Text(_esEdicion ? 'Editar anillo' : 'Nuevo anillo'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _scheme.outlineVariant),
                ),
                child: Text(
                  kmPreview > 0 && precioPreview > 0
                      ? 'Si el cliente está a ≤ ${kmPreview == kmPreview.roundToDouble() ? kmPreview.toInt() : kmPreview} km, '
                          'paga ${widget.formato.format(precioPreview)} de domicilio '
                          '(salvo que un anillo más cercano lo cubra).'
                      : 'Elige radio y precio. El anillo más cercano que '
                          'cubra la distancia del cliente es el que cobra.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: _scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _nombreCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  hintText: 'ej. Cerca, Medio, Lejos',
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 14),
              Text(
                'Radio (km)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final km in widget.presetsKm)
                    ChoiceChip(
                      label: Text(
                        '${km == km.roundToDouble() ? km.toInt() : km} km',
                      ),
                      selected:
                          (double.tryParse(_distCtrl.text.trim()) ?? -1) == km,
                      onSelected: (_) => setState(() {
                        _distCtrl.text =
                            km == km.roundToDouble() ? '${km.toInt()}' : '$km';
                      }),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _distCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'O escribe el km',
                  suffixText: 'km',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
              Text(
                'Precio domicilio',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final p in widget.presetsPrecio)
                    ChoiceChip(
                      label: Text(widget.formato.format(p)),
                      selected:
                          (int.tryParse(_costoCtrl.text.trim()) ?? -1) == p,
                      onSelected: (_) => setState(() {
                        _costoCtrl.text = '$p';
                      }),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _costoCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'O escribe el valor',
                  suffixText: 'COP',
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _guardar,
          child: Text(_esEdicion ? 'Guardar' : 'Crear anillo'),
        ),
      ],
    );
  }
}
