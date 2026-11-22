import 'package:dio/dio.dart';
import 'package:reserva_canchas/core/modelos/respuesta_api.dart';
import 'package:reserva_canchas/core/red/cliente_dio.dart';

/// Captura de gastos fijos, nómina y libro de egresos (`/finanzas/*`).
class FinanzasRepository {
  FinanzasRepository({Dio? dio})
      : _dio = dio ?? ClienteDio.instancia(conAuthStaff: true);

  final Dio _dio;

  Future<List<Map<String, dynamic>>> listarCostosFijos(
    String sucursalId, {
    bool incluirInactivos = false,
  }) async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/finanzas/costos-fijos/$sucursalId',
      queryParameters: {
        if (incluirInactivos) 'incluir_inactivos': 'true',
      },
    );
    return _lista(r.data);
  }

  Future<Map<String, dynamic>> crearCostoFijo({
    required String sucursalId,
    required String concepto,
    required double montoMensual,
    String? categoria,
    int? diaPago,
    String? notas,
  }) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/finanzas/costos-fijos',
      data: {
        'sucursal_id': sucursalId,
        'concepto': concepto,
        'monto_mensual': montoMensual,
        if (categoria != null) 'categoria': categoria,
        if (diaPago != null) 'dia_pago': diaPago,
        if (notas != null) 'notas': notas,
      },
    );
    return _mapa(r.data);
  }

  Future<Map<String, dynamic>> actualizarCostoFijo(
    String id, {
    required String sucursalId,
    String? concepto,
    double? montoMensual,
    String? categoria,
    int? diaPago,
    String? notas,
    bool? activo,
  }) async {
    final r = await _dio.patch<Map<String, dynamic>>(
      '/finanzas/costos-fijos/$id',
      queryParameters: {'sucursal_id': sucursalId},
      data: {
        if (concepto != null) 'concepto': concepto,
        if (montoMensual != null) 'monto_mensual': montoMensual,
        if (categoria != null) 'categoria': categoria,
        if (diaPago != null) 'dia_pago': diaPago,
        if (notas != null) 'notas': notas,
        if (activo != null) 'activo': activo,
      },
    );
    return _mapa(r.data);
  }

  Future<void> eliminarCostoFijo(String id, {required String sucursalId}) async {
    final r = await _dio.delete<Map<String, dynamic>>(
      '/finanzas/costos-fijos/$id',
      queryParameters: {'sucursal_id': sucursalId},
    );
    _exigirExito(r.data);
  }

  Future<Map<String, dynamic>> resumen(String sucursalId) async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/finanzas/resumen/$sucursalId',
    );
    return _mapa(r.data);
  }

  Future<Map<String, dynamic>> pagarCostoFijo(
    String id, {
    required String sucursalId,
    double? monto,
    String? fecha,
    String? periodoDesde,
    String? periodoHasta,
  }) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/finanzas/costos-fijos/$id/pagar',
      queryParameters: {'sucursal_id': sucursalId},
      data: {
        if (monto != null) 'monto': monto,
        if (fecha != null) 'fecha': fecha,
        if (periodoDesde != null) 'periodo_desde': periodoDesde,
        if (periodoHasta != null) 'periodo_hasta': periodoHasta,
      },
    );
    return _mapa(r.data);
  }

  Future<List<Map<String, dynamic>>> listarEmpleados(
    String sucursalId, {
    bool incluirInactivos = false,
  }) async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/finanzas/empleados/$sucursalId',
      queryParameters: {
        if (incluirInactivos) 'incluir_inactivos': 'true',
      },
    );
    return _lista(r.data);
  }

  Future<Map<String, dynamic>> crearEmpleado({
    required String sucursalId,
    required String nombre,
    required double sueldoBase,
    String? cargo,
    String frecuenciaPago = 'mensual',
  }) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/finanzas/empleados',
      data: {
        'sucursal_id': sucursalId,
        'nombre': nombre,
        'sueldo_base': sueldoBase,
        'frecuencia_pago': frecuenciaPago,
        if (cargo != null) 'cargo': cargo,
      },
    );
    return _mapa(r.data);
  }

  Future<Map<String, dynamic>> actualizarEmpleado(
    String id, {
    required String sucursalId,
    String? nombre,
    String? cargo,
    double? sueldoBase,
    String? frecuenciaPago,
    bool? activo,
  }) async {
    final r = await _dio.patch<Map<String, dynamic>>(
      '/finanzas/empleados/$id',
      queryParameters: {'sucursal_id': sucursalId},
      data: {
        if (nombre != null) 'nombre': nombre,
        if (cargo != null) 'cargo': cargo,
        if (sueldoBase != null) 'sueldo_base': sueldoBase,
        if (frecuenciaPago != null) 'frecuencia_pago': frecuenciaPago,
        if (activo != null) 'activo': activo,
      },
    );
    return _mapa(r.data);
  }

  Future<Map<String, dynamic>> pagarEmpleado(
    String id, {
    required String sucursalId,
    double? monto,
    String? fecha,
    String? periodoDesde,
    String? periodoHasta,
  }) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/finanzas/empleados/$id/pagar',
      queryParameters: {'sucursal_id': sucursalId},
      data: {
        if (monto != null) 'monto': monto,
        if (fecha != null) 'fecha': fecha,
        if (periodoDesde != null) 'periodo_desde': periodoDesde,
        if (periodoHasta != null) 'periodo_hasta': periodoHasta,
      },
    );
    return _mapa(r.data);
  }

  Future<List<Map<String, dynamic>>> listarGastos(
    String sucursalId, {
    String? desde,
    String? hasta,
  }) async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/finanzas/gastos/$sucursalId',
      queryParameters: {
        if (desde != null) 'desde': desde,
        if (hasta != null) 'hasta': hasta,
      },
    );
    return _lista(r.data);
  }

  Future<Map<String, dynamic>> crearGastoManual({
    required String sucursalId,
    required String concepto,
    required double monto,
    String? categoria,
    String? fecha,
  }) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/finanzas/gastos',
      data: {
        'sucursal_id': sucursalId,
        'concepto': concepto,
        'monto': monto,
        if (categoria != null) 'categoria': categoria,
        if (fecha != null) 'fecha': fecha,
      },
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

  void _exigirExito(Map<String, dynamic>? data) {
    if (data == null) throw Exception('Respuesta vacía');
    final env = RespuestaApi<void>.fromJson(data, (_) {});
    if (!env.exito) throw Exception(env.mensaje);
  }
}
