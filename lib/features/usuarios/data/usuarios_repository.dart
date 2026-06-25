import 'package:dio/dio.dart';
import 'package:reserva_canchas/core/modelos/respuesta_api.dart';
import 'package:reserva_canchas/core/red/cliente_dio.dart';

class UsuariosRepository {
  UsuariosRepository({Dio? dio})
      : _dio = dio ?? ClienteDio.instancia(conAuthStaff: true);

  final Dio _dio;

  Future<List<Map<String, dynamic>>> listar(String sucursalId) async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/usuarios',
      queryParameters: {'sucursal_id': sucursalId},
    );
    return _parsearLista(r.data);
  }

  Future<void> crear({
    required String sucursalId,
    required String nombre,
    required String email,
    required String contrasena,
    required String rol,
  }) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/usuarios',
      data: {
        'sucursal_id': sucursalId,
        'nombre': nombre,
        'email': email,
        'contrasena': contrasena,
        'rol': rol,
      },
    );
    _validar(r.data);
  }

  Future<void> cambiarEstado({
    required String usuarioId,
    required String sucursalId,
    required bool activo,
  }) async {
    final r = await _dio.patch<Map<String, dynamic>>(
      '/usuarios/$usuarioId/estado',
      queryParameters: {'sucursal_id': sucursalId},
      data: {'activo': activo},
    );
    _validar(r.data);
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

  void _validar(Map<String, dynamic>? data) {
    if (data == null) throw Exception('Respuesta vacía');
    final env = RespuestaApi<void>.fromJson(data, (_) {});
    if (!env.exito) throw Exception(env.mensaje);
  }
}
