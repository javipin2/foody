import 'package:dio/dio.dart';
import 'package:reserva_canchas/core/modelos/respuesta_api.dart';
import 'package:reserva_canchas/core/red/cliente_dio.dart';

class DomiciliariosRepository {
  DomiciliariosRepository({Dio? dio})
      : _dio = dio ?? ClienteDio.instancia(conAuthStaff: true);

  final Dio _dio;

  Future<List<Map<String, dynamic>>> listarDisponibles(String sucursalId) async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/domiciliarios-planta/disponibles/$sucursalId',
    );
    return _parsearLista(r.data);
  }

  Future<void> asignar({
    required String pedidoId,
    required String sucursalId,
    required String domiciliarioPlantaId,
  }) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/domiciliarios-planta/asignar',
      data: {
        'pedido_id': pedidoId,
        'sucursal_id': sucursalId,
        'domiciliario_planta_id': domiciliarioPlantaId,
      },
    );
    _validar(r.data);
  }

  Future<Map<String, dynamic>> dispatchIndependiente({
    required String pedidoId,
    required String sucursalId,
  }) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/domiciliarios-planta/dispatch-independiente/$pedidoId',
      queryParameters: {'sucursal_id': sucursalId},
    );
    if (r.data == null) throw Exception('Respuesta vacía');
    final env = RespuestaApi<Map<String, dynamic>>.fromJson(
      r.data!,
      (raw) => Map<String, dynamic>.from(raw as Map<String, dynamic>),
    );
    if (!env.exito || env.datos == null) throw Exception(env.mensaje);
    return env.datos!;
  }

  Future<List<Map<String, dynamic>>> pedidosAsignados() async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/domiciliario/pedidos-asignados',
    );
    return _parsearLista(r.data);
  }

  Future<List<Map<String, dynamic>>> historialEntregas() async {
    final r = await _dio.get<Map<String, dynamic>>('/domiciliario/historial');
    return _parsearLista(r.data);
  }

  Future<Map<String, dynamic>> estadisticasPlanta() async {
    final r = await _dio.get<Map<String, dynamic>>('/domiciliario/estadisticas');
    if (r.data == null) throw Exception('Respuesta vacía');
    final env = RespuestaApi<Map<String, dynamic>>.fromJson(
      r.data!,
      (raw) => Map<String, dynamic>.from(raw as Map<String, dynamic>),
    );
    if (!env.exito || env.datos == null) throw Exception(env.mensaje);
    return env.datos!;
  }

  Future<void> marcarEnCamino(String pedidoId) async {
    final r = await _dio.patch<Map<String, dynamic>>(
      '/domiciliario/pedidos/$pedidoId/en-camino',
    );
    _validar(r.data);
  }

  Future<void> confirmarEntrega(String pedidoId, {String? metodoPago}) async {
    final r = await _dio.patch<Map<String, dynamic>>(
      '/domiciliario/pedidos/$pedidoId/confirmar-entrega',
      data: {if (metodoPago != null) 'metodo_pago': metodoPago},
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
