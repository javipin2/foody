import 'package:dio/dio.dart';
import 'package:reserva_canchas/core/modelos/respuesta_api.dart';
import 'package:reserva_canchas/core/red/cliente_dio.dart';

class AuditoriaRepository {
  AuditoriaRepository({Dio? dio})
      : _dio = dio ?? ClienteDio.instancia(conAuthStaff: true);

  final Dio _dio;

  Future<Map<String, dynamic>> timeline({
    required String desde,
    required String hasta,
    String? sucursalId,
  }) async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/auditoria/timeline',
      queryParameters: {
        'desde': desde,
        'hasta': hasta,
        if (sucursalId != null) 'sucursal_id': sucursalId,
      },
    );
    if (r.data == null) throw Exception('Respuesta vacía');
    final env = RespuestaApi<Map<String, dynamic>>.fromJson(
      r.data!,
      (raw) => Map<String, dynamic>.from(raw as Map<String, dynamic>),
    );
    if (!env.exito || env.datos == null) throw Exception(env.mensaje);
    return env.datos!;
  }
}
