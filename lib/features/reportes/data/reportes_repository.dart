import 'package:dio/dio.dart';
import 'package:reserva_canchas/core/modelos/respuesta_api.dart';
import 'package:reserva_canchas/core/red/cliente_dio.dart';

class ReportesRepository {
  ReportesRepository({Dio? dio})
      : _dio = dio ?? ClienteDio.instancia(conAuthStaff: true);

  final Dio _dio;

  Future<Map<String, dynamic>> financiero({
    required String sucursalId,
    required String desde,
    required String hasta,
  }) async {
    return _get('/reportes/financiero', sucursalId, desde, hasta);
  }

  Future<Map<String, dynamic>> productos({
    required String sucursalId,
    required String desde,
    required String hasta,
  }) async {
    return _get('/reportes/productos', sucursalId, desde, hasta);
  }

  Future<Map<String, dynamic>> pedidos({
    required String sucursalId,
    required String desde,
    required String hasta,
  }) async {
    return _get('/reportes/pedidos', sucursalId, desde, hasta);
  }

  Future<Map<String, dynamic>> _get(
    String path,
    String sucursalId,
    String desde,
    String hasta,
  ) async {
    final r = await _dio.get<Map<String, dynamic>>(
      path,
      queryParameters: {
        'sucursal_id': sucursalId,
        'desde': desde,
        'hasta': hasta,
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
