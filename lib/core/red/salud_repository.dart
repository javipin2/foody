import 'package:dio/dio.dart';
import 'package:reserva_canchas/core/red/cliente_dio.dart';
import 'package:reserva_canchas/core/modelos/respuesta_api.dart';

/// Consultas de salud del backend (sin auth).
class SaludRepository {
  SaludRepository({Dio? dio}) : _dio = dio ?? ClienteDio.instancia();

  final Dio _dio;

  Future<({bool configurado, bool conectado, String? detalle})>
      verificarRealtime() async {
    final resp = await _dio.get<Map<String, dynamic>>('/health/realtime');
    final api = RespuestaApi<Map<String, dynamic>>.fromJson(
      resp.data ?? {},
      (d) => Map<String, dynamic>.from(d as Map),
    );
    if (!api.exito || api.datos == null) {
      return (
        configurado: false,
        conectado: false,
        detalle: api.mensaje,
      );
    }
    final d = api.datos!;
    return (
      configurado: d['configurado'] as bool? ?? false,
      conectado: d['conectado'] as bool? ?? false,
      detalle: d['detalle'] as String?,
    );
  }
}
