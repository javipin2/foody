import 'package:dio/dio.dart';
import 'package:reserva_canchas/core/modelos/respuesta_api.dart';
import 'package:reserva_canchas/core/red/cliente_dio.dart';

class SucursalesRepository {
  SucursalesRepository({Dio? dio})
      : _dio = dio ?? ClienteDio.instancia(conAuthStaff: true);

  final Dio _dio;

  Future<List<Map<String, dynamic>>> listarMiRestaurante() async {
    final r = await _dio.get<Map<String, dynamic>>('/sucursales/mi-restaurante');
    return _parsearLista(r.data);
  }

  Future<List<Map<String, dynamic>>> listarHorarios(String sucursalId) async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/sucursales/$sucursalId/horarios',
    );
    return _parsearLista(r.data);
  }

  Future<Map<String, dynamic>> actualizarHorario(
    String horarioId, {
    String? horaApertura,
    String? horaCierre,
    bool? activo,
  }) async {
    final r = await _dio.patch<Map<String, dynamic>>(
      '/sucursales/horarios/$horarioId',
      data: {
        if (horaApertura != null) 'hora_apertura': horaApertura,
        if (horaCierre != null) 'hora_cierre': horaCierre,
        if (activo != null) 'activo': activo,
      },
    );
    return _parsearMapa(r.data);
  }

  Future<Map<String, dynamic>> crear({
    required String nombre,
    String? direccion,
    String? telefono,
  }) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/sucursales',
      data: {
        'nombre': nombre,
        if (direccion != null && direccion.isNotEmpty) 'direccion': direccion,
        if (telefono != null && telefono.isNotEmpty) 'telefono': telefono,
      },
    );
    return _parsearMapa(r.data);
  }

  Future<Map<String, dynamic>> _parsearMapa(Map<String, dynamic>? data) async {
    if (data == null) throw Exception('Respuesta vacía');
    final env = RespuestaApi<Map<String, dynamic>>.fromJson(
      data,
      (raw) => Map<String, dynamic>.from(raw as Map<String, dynamic>),
    );
    if (!env.exito || env.datos == null) throw Exception(env.mensaje);
    return env.datos!;
  }

  List<Map<String, dynamic>> _parsearLista(Map<String, dynamic>? data) {
    if (data == null) throw Exception('Respuesta vacía');
    final env = RespuestaApi<List<dynamic>>.fromJson(
      data,
      (raw) => raw as List<dynamic>,
    );
    if (!env.exito || env.datos == null) throw Exception(env.mensaje);
    return env.datos!
        .map((e) => Map<String, dynamic>.from(e as Map<String, dynamic>))
        .toList();
  }
}
