import 'package:dio/dio.dart';
import 'package:reserva_canchas/core/modelos/respuesta_api.dart';
import 'package:reserva_canchas/core/red/cliente_dio.dart';
import 'package:reserva_canchas/features/sucursales/data/sucursales_repository.dart';

class ZonasRepository {
  ZonasRepository({Dio? dio})
      : _dioStaff = dio ?? ClienteDio.instancia(conAuthStaff: true),
        _dioPublico = dio ?? ClienteDio.instancia();

  final Dio _dioStaff;
  final Dio _dioPublico;

  Future<Map<String, dynamic>> cotizarDomicilio({
    required String sucursalId,
    double? lat,
    double? lng,
  }) async {
    final respuesta = await _dioPublico.get<Map<String, dynamic>>(
      '/zonas/cotizar-domicilio',
      queryParameters: {
        'sucursal_id': sucursalId,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
      },
    );
    return _parsearMapa(respuesta.data);
  }

  Future<Map<String, dynamic>> configuracionMapa(String sucursalId) async {
    try {
      final respuesta = await _dioStaff.get<Map<String, dynamic>>(
        '/zonas/sucursal/$sucursalId/configuracion-mapa',
      );
      return _parsearMapa(respuesta.data);
    } on DioException catch (e) {
      if (e.response?.statusCode != 404) rethrow;
      // Backend antiguo sin la ruta nueva: armar respuesta con endpoints existentes.
      return _configuracionMapaLegacy(sucursalId);
    }
  }

  Future<Map<String, dynamic>> _configuracionMapaLegacy(
    String sucursalId,
  ) async {
    final zonas = await listar(sucursalId);
    final sucursales = await SucursalesRepository().listarMiRestaurante();
    Map<String, dynamic>? sucursal;
    for (final s in sucursales) {
      if (s['id'] == sucursalId) {
        sucursal = s;
        break;
      }
    }
    return {
      'sucursal': {
        'id': sucursalId,
        'nombre': sucursal?['nombre'] ?? 'Sucursal',
        'direccion': sucursal?['direccion'],
        'lat': _aDouble(sucursal?['lat']),
        'lng': _aDouble(sucursal?['lng']),
      },
      'zonas': zonas,
    };
  }

  double? _aDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse('$v');
  }

  Future<void> actualizarUbicacionSucursal({
    required String sucursalId,
    required double lat,
    required double lng,
  }) async {
    final respuesta = await _dioStaff.patch<Map<String, dynamic>>(
      '/zonas/sucursal/$sucursalId/ubicacion',
      data: {'lat': lat, 'lng': lng},
    );
    _validarExito(respuesta.data);
  }

  Future<List<Map<String, dynamic>>> listar(String sucursalId) async {
    final respuesta = await _dioStaff.get<Map<String, dynamic>>(
      '/zonas/$sucursalId',
    );
    return _parsearLista(respuesta.data);
  }

  Future<void> crear({
    required String sucursalId,
    required String nombre,
    required num costoDomicilio,
    required num distanciaMaxKm,
  }) async {
    final respuesta = await _dioStaff.post<Map<String, dynamic>>(
      '/zonas',
      data: {
        'sucursal_id': sucursalId,
        'nombre': nombre,
        'costo_domicilio': costoDomicilio,
        'distancia_max_km': distanciaMaxKm,
      },
    );
    _validarExito(respuesta.data);
  }

  Future<void> actualizar({
    required String id,
    String? sucursalId,
    String? nombre,
    num? costoDomicilio,
    num? distanciaMaxKm,
    bool? activa,
  }) async {
    final respuesta = await _dioStaff.patch<Map<String, dynamic>>(
      '/zonas/$id',
      queryParameters: {
        if (sucursalId != null) 'sucursal_id': sucursalId,
      },
      data: {
        if (nombre != null) 'nombre': nombre,
        if (costoDomicilio != null) 'costo_domicilio': costoDomicilio,
        if (distanciaMaxKm != null) 'distancia_max_km': distanciaMaxKm,
        if (activa != null) 'activa': activa,
      },
    );
    _validarExito(respuesta.data);
  }

  Future<void> desactivar(String id, {String? sucursalId}) async {
    final respuesta = await _dioStaff.delete<Map<String, dynamic>>(
      '/zonas/$id',
      queryParameters: {
        if (sucursalId != null) 'sucursal_id': sucursalId,
      },
    );
    _validarExito(respuesta.data);
  }

  void _validarExito(Map<String, dynamic>? data) {
    if (data == null) throw Exception('Respuesta vacía');
    final envoltura = RespuestaApi<void>.fromJson(data, (_) {});
    if (!envoltura.exito) throw Exception(envoltura.mensaje);
  }

  Future<Map<String, dynamic>> _parsearMapa(Map<String, dynamic>? data) async {
    if (data == null) throw Exception('Respuesta vacía');
    final envoltura = RespuestaApi<Map<String, dynamic>>.fromJson(
      data,
      (raw) => Map<String, dynamic>.from(raw as Map<String, dynamic>),
    );
    if (!envoltura.exito || envoltura.datos == null) {
      throw Exception(envoltura.mensaje);
    }
    return envoltura.datos!;
  }

  Future<List<Map<String, dynamic>>> _parsearLista(
    Map<String, dynamic>? data,
  ) async {
    if (data == null) throw Exception('Respuesta vacía');
    final envoltura = RespuestaApi<List<Map<String, dynamic>>>.fromJson(
      data,
      (raw) => (raw as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map<String, dynamic>))
          .toList(),
    );
    if (!envoltura.exito || envoltura.datos == null) {
      throw Exception(envoltura.mensaje);
    }
    return envoltura.datos!;
  }
}
