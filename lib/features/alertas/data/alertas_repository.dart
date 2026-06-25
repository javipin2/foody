import 'package:dio/dio.dart';
import 'package:reserva_canchas/core/modelos/respuesta_api.dart';
import 'package:reserva_canchas/core/red/cliente_dio.dart';

class AlertasRepository {
  AlertasRepository({Dio? dio})
      : _dio = dio ?? ClienteDio.instancia(conAuthStaff: true);

  final Dio _dio;

  Future<List<Map<String, dynamic>>> listar(
    String sucursalId, {
    bool soloPendientes = true,
  }) async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/alertas/$sucursalId',
      queryParameters: {
        if (!soloPendientes) 'solo_pendientes': 'false',
      },
    );
    if (r.data == null) throw Exception('Respuesta vacía');
    final env = RespuestaApi<List<dynamic>>.fromJson(
      r.data!,
      (raw) => raw as List<dynamic>,
    );
    if (!env.exito || env.datos == null) throw Exception(env.mensaje);
    return env.datos!
        .map((e) => Map<String, dynamic>.from(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> revisar(String alertaId, {String? sucursalId}) async {
    final r = await _dio.patch<Map<String, dynamic>>(
      '/alertas/$alertaId/revisar',
      queryParameters: {
        if (sucursalId != null) 'sucursal_id': sucursalId,
      },
    );
    if (r.data == null) throw Exception('Respuesta vacía');
    final env = RespuestaApi<void>.fromJson(r.data!, (_) {});
    if (!env.exito) throw Exception(env.mensaje);
  }

  Future<int> evaluarReglas(String sucursalId) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/alertas/evaluar/$sucursalId',
    );
    if (r.data == null) throw Exception('Respuesta vacía');
    final env = RespuestaApi<Map<String, dynamic>>.fromJson(
      r.data!,
      (raw) => Map<String, dynamic>.from(raw as Map<String, dynamic>),
    );
    if (!env.exito || env.datos == null) throw Exception(env.mensaje);
    return (env.datos!['generadas'] as num?)?.toInt() ?? 0;
  }
}
