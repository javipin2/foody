import 'package:dio/dio.dart';
import 'package:reserva_canchas/core/modelos/respuesta_api.dart';
import 'package:reserva_canchas/core/red/cliente_dio.dart';

class FacturacionRepository {
  FacturacionRepository({Dio? dio})
      : _dio = dio ?? ClienteDio.instancia(conAuthStaff: true);

  final Dio _dio;

  Future<Map<String, dynamic>?> obtenerConfig(String sucursalId) async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/facturacion/config/$sucursalId',
    );
    return _parsearMapaOpcional(r.data);
  }

  Future<Map<String, dynamic>> guardarConfig(Map<String, dynamic> body) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/facturacion/config',
      data: body,
    );
    return _parsearMapa(r.data);
  }

  Future<List<Map<String, dynamic>>> listarFacturas(
    String sucursalId, {
    String? estado,
  }) async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/facturacion/facturas/$sucursalId',
      queryParameters: {
        if (estado != null) 'estado': estado,
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

  Future<Map<String, dynamic>> emitir(String pedidoId, String sucursalId) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/facturacion/emitir/$pedidoId',
      queryParameters: {'sucursal_id': sucursalId},
    );
    return _parsearMapa(r.data);
  }

  Future<Map<String, dynamic>> obtenerPdf(String facturaId, String sucursalId) async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/facturacion/facturas/$facturaId/pdf',
      queryParameters: {'sucursal_id': sucursalId},
    );
    return _parsearMapa(r.data);
  }

  Future<Map<String, dynamic>> anular({
    required String facturaId,
    required String sucursalId,
    required String motivo,
  }) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/facturacion/anular/$facturaId',
      queryParameters: {'sucursal_id': sucursalId},
      data: {'motivo': motivo},
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

  Future<Map<String, dynamic>?> _parsearMapaOpcional(
    Map<String, dynamic>? data,
  ) async {
    if (data == null) throw Exception('Respuesta vacía');
    final env = RespuestaApi<Map<String, dynamic>?>.fromJson(
      data,
      (raw) => raw == null
          ? null
          : Map<String, dynamic>.from(raw as Map<String, dynamic>),
    );
    if (!env.exito) throw Exception(env.mensaje);
    return env.datos;
  }
}
