import 'package:dio/dio.dart';
import 'package:reserva_canchas/core/modelos/respuesta_api.dart';
import 'package:reserva_canchas/core/red/cliente_dio.dart';

class DomiciliariosRepository {
  DomiciliariosRepository({Dio? dio})
      : _dio = dio ?? ClienteDio.instancia(conAuthStaff: true);

  final Dio _dio;

  Future<List<Map<String, dynamic>>> listarDisponibles(
      String sucursalId) async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/domiciliarios-planta/disponibles/$sucursalId',
    );
    return _parsearLista(r.data);
  }

  Future<List<Map<String, dynamic>>> resumenComisionesIndependientes(
    String sucursalId,
  ) async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/domiciliarios-planta/comisiones-independientes/$sucursalId',
    );
    return _parsearLista(r.data).map(_normalizarResumenComision).toList();
  }

  Map<String, dynamic> _normalizarResumenComision(
    Map<String, dynamic> fila,
  ) {
    final normalizada = Map<String, dynamic>.from(fila);
    for (final campo in const [
      'total_domicilios',
      'comision_foody',
      'ganancia_total',
      'por_pagar',
    ]) {
      final valor = normalizada[campo];
      if (valor == null || valor is num) continue;
      if (valor is String) {
        final numero = num.tryParse(valor);
        if (numero != null) {
          normalizada[campo] = numero;
          continue;
        }
      }
      throw FormatException(
          'Importe inválido en el resumen de comisiones: $campo');
    }
    return normalizada;
  }

  Future<Map<String, dynamic>> resumenLiquidacion(String sucursalId) async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/domiciliarios-planta/liquidacion/$sucursalId',
    );
    if (r.data == null) throw Exception('Respuesta vacía');
    final env = RespuestaApi<Map<String, dynamic>>.fromJson(
      r.data!,
      (raw) => Map<String, dynamic>.from(raw as Map<String, dynamic>),
    );
    if (!env.exito || env.datos == null) throw Exception(env.mensaje);
    return env.datos!;
  }

  Future<Map<String, dynamic>> liquidarDomiciliario({
    required String domiciliarioPlantaId,
    required String sucursalId,
  }) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/domiciliarios-planta/liquidar/$domiciliarioPlantaId',
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

  Future<bool> configurarFiadoDomiciliario({
    required String sucursalId,
    required bool permitir,
  }) async {
    final r = await _dio.patch<Map<String, dynamic>>(
      '/domiciliarios-planta/config-fiado/$sucursalId',
      data: {'permitir': permitir},
    );
    if (r.data == null) throw Exception('Respuesta vacía');
    final env = RespuestaApi<Map<String, dynamic>>.fromJson(
      r.data!,
      (raw) => Map<String, dynamic>.from(raw as Map<String, dynamic>),
    );
    if (!env.exito || env.datos == null) throw Exception(env.mensaje);
    return env.datos!['permite_fiado_domiciliario'] == true;
  }

  Future<Map<String, dynamic>> resumenDomicilios(String sucursalId) async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/domiciliarios-planta/domicilios/$sucursalId',
    );
    if (r.data == null) throw Exception('Respuesta vacía');
    final env = RespuestaApi<Map<String, dynamic>>.fromJson(
      r.data!,
      (raw) => Map<String, dynamic>.from(raw as Map<String, dynamic>),
    );
    if (!env.exito || env.datos == null) throw Exception(env.mensaje);
    return env.datos!;
  }

  Future<bool> configurarDomicilioEnCaja({
    required String sucursalId,
    required bool ingresa,
  }) async {
    final r = await _dio.patch<Map<String, dynamic>>(
      '/domiciliarios-planta/config-domicilio-caja/$sucursalId',
      data: {'ingresa': ingresa},
    );
    if (r.data == null) throw Exception('Respuesta vacía');
    final env = RespuestaApi<Map<String, dynamic>>.fromJson(
      r.data!,
      (raw) => Map<String, dynamic>.from(raw as Map<String, dynamic>),
    );
    if (!env.exito || env.datos == null) throw Exception(env.mensaje);
    return env.datos!['domicilio_ingresa_a_caja'] == true;
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

  Future<void> reasignar({
    required String pedidoId,
    required String sucursalId,
    required String domiciliarioPlantaId,
  }) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/domiciliarios-planta/reasignar',
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

  Future<List<Map<String, dynamic>>> historialEntregas({
    String? desde,
    String? hasta,
  }) async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/domiciliario/historial',
      queryParameters: {
        if (desde != null) 'desde': desde,
        if (hasta != null) 'hasta': hasta,
      },
    );
    return _parsearLista(r.data);
  }

  Future<Map<String, dynamic>> estadisticasPlanta({
    String? desde,
    String? hasta,
  }) async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/domiciliario/estadisticas',
      queryParameters: {
        if (desde != null) 'desde': desde,
        if (hasta != null) 'hasta': hasta,
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

  Future<void> marcarEnCamino(String pedidoId) async {
    final r = await _dio.patch<Map<String, dynamic>>(
      '/domiciliario/pedidos/$pedidoId/en-camino',
    );
    _validar(r.data);
  }

  Future<void> confirmarEntrega(
    String pedidoId, {
    String? metodoPago,
    String? metodoPagoDomicilio,
  }) async {
    final r = await _dio.patch<Map<String, dynamic>>(
      '/domiciliario/pedidos/$pedidoId/confirmar-entrega',
      data: {
        if (metodoPago != null) 'metodo_pago': metodoPago,
        if (metodoPagoDomicilio != null)
          'metodo_pago_domicilio': metodoPagoDomicilio,
      },
    );
    _validar(r.data);
  }

  Future<void> registrarUbicacion({
    required double lat,
    required double lng,
    String? pedidoId,
  }) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/domiciliario/ubicacion',
      data: {
        'lat': lat,
        'lng': lng,
        if (pedidoId != null) 'pedido_id': pedidoId,
      },
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
