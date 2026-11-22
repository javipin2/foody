import 'package:dio/dio.dart';
import 'package:reserva_canchas/core/modelos/respuesta_api.dart';
import 'package:reserva_canchas/core/red/cliente_dio.dart';

class CajaRepository {
  CajaRepository({Dio? dio}) : _dio = dio ?? ClienteDio.instancia(conAuthStaff: true);

  final Dio _dio;

  Future<Map<String, dynamic>?> cajaActiva(String sucursalId) async {
    final r = await _dio.get<Map<String, dynamic>>('/caja/activa/$sucursalId');
    return _parsearNullable(r.data);
  }

  Future<Map<String, dynamic>> abrir({
    required String sucursalId,
    required double montoInicial,
    bool arqueoCiego = false,
  }) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/caja/abrir',
      data: {
        'sucursal_id': sucursalId,
        'monto_inicial': montoInicial,
        'arqueo_ciego': arqueoCiego,
      },
    );
    return _parsear(r.data)!;
  }

  Future<Map<String, dynamic>> cerrar({
    required String cajaId,
    required double montoContado,
    String? observaciones,
  }) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/caja/cerrar',
      data: {
        'caja_id': cajaId,
        'monto_final_contado': montoContado,
        if (observaciones != null) 'observaciones_cierre': observaciones,
      },
    );
    return _parsear(r.data)!;
  }

  Future<List<Map<String, dynamic>>> movimientos(String cajaId) async {
    final all = <Map<String, dynamic>>[];
    var page = 1;
    const limit = 100;
    while (page <= 50) {
      final r = await _dio.get<Map<String, dynamic>>(
        '/caja/$cajaId/movimientos',
        queryParameters: {'page': page, 'limit': limit},
      );
      if (r.data == null) throw Exception('Respuesta vacía');
      final env = RespuestaApi<Map<String, dynamic>>.fromJson(
        r.data!,
        (raw) => Map<String, dynamic>.from(raw as Map<String, dynamic>),
      );
      if (!env.exito || env.datos == null) throw Exception(env.mensaje);
      final d = env.datos!;
      final items = (d['items'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map<String, dynamic>))
          .toList();
      all.addAll(items);
      final totalPages = (d['totalPages'] as num?)?.toInt() ?? 1;
      if (page >= totalPages) break;
      page++;
    }
    return all;
  }

  Future<void> registrarGasto({
    required String cajaId,
    required String concepto,
    required double monto,
  }) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/caja/gastos',
      data: {'caja_id': cajaId, 'concepto': concepto, 'monto': monto},
    );
    _validar(r.data);
  }

  Future<List<Map<String, dynamic>>> cuentasPorCobrar(
    String sucursalId, {
    bool incluirPagadas = false,
  }) async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/caja/cuentas-por-cobrar/$sucursalId',
      queryParameters:
          incluirPagadas ? {'incluir_pagadas': 'true'} : null,
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

  Future<Map<String, dynamic>> resumenCuentasPorCobrar(String sucursalId) async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/caja/cuentas-por-cobrar/$sucursalId/resumen',
    );
    return _parsear(r.data)!;
  }

  Future<void> crearCuentaPorCobrar({
    required String sucursalId,
    required String clienteNombre,
    required double monto,
    String? clienteTelefono,
    String? pedidoId,
  }) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/caja/cuentas-por-cobrar',
      data: {
        'sucursal_id': sucursalId,
        'cliente_nombre': clienteNombre,
        'monto': monto,
        if (clienteTelefono != null) 'cliente_telefono': clienteTelefono,
        if (pedidoId != null) 'pedido_id': pedidoId,
      },
    );
    _validar(r.data);
  }

  Future<void> pagarCuenta(String cuentaId, {String metodoPago = 'efectivo'}) async {
    final r = await _dio.patch<Map<String, dynamic>>(
      '/caja/cuentas-por-cobrar/$cuentaId/pagar',
      data: {'metodo_pago': metodoPago},
    );
    _validar(r.data);
  }

  Future<void> retiro({
    required String cajaId,
    required double monto,
    String? descripcion,
  }) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/caja/retiro-parcial',
      data: {
        'caja_id': cajaId,
        'monto': monto,
        if (descripcion != null) 'descripcion': descripcion,
      },
    );
    _validar(r.data);
  }

  Future<void> registrarDevolucion({
    required String cajaId,
    required String sucursalId,
    required double monto,
    required String motivo,
    String? pedidoId,
    String? metodoPago,
  }) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/caja/devolucion',
      data: {
        'caja_id': cajaId,
        'sucursal_id': sucursalId,
        'monto': monto,
        'motivo': motivo,
        if (pedidoId != null) 'pedido_id': pedidoId,
        if (metodoPago != null) 'metodo_pago': metodoPago,
      },
    );
    _validar(r.data);
  }

  Map<String, dynamic>? _parsearNullable(Map<String, dynamic>? data) {
    if (data == null) return null;
    final env = RespuestaApi<dynamic>.fromJson(data, (raw) => raw);
    if (!env.exito) throw Exception(env.mensaje);
    if (env.datos == null) return null;
    if (env.datos is Map) {
      return Map<String, dynamic>.from(env.datos as Map);
    }
    return null;
  }

  Map<String, dynamic>? _parsear(Map<String, dynamic>? data) {
    if (data == null) throw Exception('Respuesta vacía');
    final env = RespuestaApi<Map<String, dynamic>>.fromJson(
      data,
      (raw) => Map<String, dynamic>.from(raw as Map<String, dynamic>),
    );
    if (!env.exito) throw Exception(env.mensaje);
    return env.datos;
  }

  void _validar(Map<String, dynamic>? data) {
    if (data == null) throw Exception('Respuesta vacía');
    final env = RespuestaApi<dynamic>.fromJson(data, (raw) => raw);
    if (!env.exito) throw Exception(env.mensaje);
  }
}
