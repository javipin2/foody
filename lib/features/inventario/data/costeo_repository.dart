import 'package:dio/dio.dart';
import 'package:reserva_canchas/core/modelos/respuesta_api.dart';
import 'package:reserva_canchas/core/red/cliente_dio.dart';

class CosteoRepository {
  CosteoRepository({Dio? dio})
      : _dio = dio ?? ClienteDio.instancia(conAuthStaff: true);

  final Dio _dio;

  Future<Map<String, dynamic>> resumen(String sucursalId) async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/costeo/resumen/$sucursalId',
    );
    return _mapa(r.data);
  }

  Future<Map<String, dynamic>> recalcular(String sucursalId) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/costeo/recalcular/$sucursalId',
    );
    return _mapa(r.data);
  }

  Future<Map<String, dynamic>> impactoStockProducto({
    required String productoId,
    required String sucursalId,
    int cantidad = 1,
  }) async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/costeo/productos/$productoId/impacto-stock',
      queryParameters: {
        'sucursal_id': sucursalId,
        'cantidad': cantidad,
      },
    );
    return _mapa(r.data);
  }

  Future<Map<String, dynamic>> recalcularProducto(
    String productoId,
    String sucursalId,
  ) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/costeo/productos/$productoId/recalcular',
      queryParameters: {'sucursal_id': sucursalId},
    );
    return _mapa(r.data);
  }

  Future<List<Map<String, dynamic>>> subrecetas(String sucursalId) async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/costeo/subrecetas/$sucursalId',
    );
    return _lista(r.data);
  }

  Future<Map<String, dynamic>> crearSubreceta({
    required String sucursalId,
    required String nombre,
    required double cantidadResultado,
    required String unidadResultado,
    required List<Map<String, dynamic>> items,
    double margenError = 0.05,
  }) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/costeo/subrecetas',
      data: {
        'sucursal_id': sucursalId,
        'nombre': nombre,
        'cantidad_resultado': cantidadResultado,
        'unidad_resultado': unidadResultado,
        'margen_error': margenError,
        'items': items.map(_itemSubrecetaPayload).toList(),
      },
    );
    return _mapa(r.data);
  }

  Future<Map<String, dynamic>> obtenerSubrecetaDetalle({
    required String recetaId,
    required String sucursalId,
  }) async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/costeo/subrecetas/detalle/$recetaId',
      queryParameters: {'sucursal_id': sucursalId},
    );
    return _mapa(r.data);
  }

  Future<Map<String, dynamic>> actualizarSubreceta({
    required String recetaId,
    required String sucursalId,
    required String nombre,
    required double cantidadResultado,
    required String unidadResultado,
    required List<Map<String, dynamic>> items,
    double margenError = 0.05,
  }) async {
    final r = await _dio.patch<Map<String, dynamic>>(
      '/costeo/subrecetas/$recetaId',
      data: {
        'sucursal_id': sucursalId,
        'nombre': nombre,
        'cantidad_resultado': cantidadResultado,
        'unidad_resultado': unidadResultado,
        'margen_error': margenError,
        'items': items.map(_itemSubrecetaPayload).toList(),
      },
    );
    return _mapa(r.data);
  }

  Map<String, dynamic> _itemSubrecetaPayload(Map<String, dynamic> e) {
    final tipo = e['tipo_item'] as String? ?? 'ingrediente';
    return <String, dynamic>{
      'tipo_item': tipo,
      if (tipo == 'subreceta' && e['subreceta_id'] != null)
        'subreceta_id': e['subreceta_id'],
      if (tipo != 'subreceta' && e['ingrediente_id'] != null)
        'ingrediente_id': e['ingrediente_id'],
      'cantidad': e['cantidad'],
      'unidad': e['unidad'],
    };
  }

  Future<Map<String, dynamic>> recalcularSubreceta({
    required String recetaId,
    required String sucursalId,
  }) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/costeo/subrecetas/$recetaId/recalcular',
      queryParameters: {'sucursal_id': sucursalId},
    );
    return _mapa(r.data);
  }

  List<Map<String, dynamic>> _lista(Map<String, dynamic>? data) {
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

  Map<String, dynamic> _mapa(Map<String, dynamic>? data) {
    if (data == null) throw Exception('Respuesta vacía');
    final env = RespuestaApi<Map<String, dynamic>>.fromJson(
      data,
      (raw) => Map<String, dynamic>.from(raw as Map<String, dynamic>),
    );
    if (!env.exito || env.datos == null) throw Exception(env.mensaje);
    return env.datos!;
  }
}
