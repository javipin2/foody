import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:reserva_canchas/core/modelos/respuesta_api.dart';
import 'package:reserva_canchas/core/red/cliente_dio.dart';

/// Lectura del módulo Centro de Análisis (`/analitica/*`).
class AnaliticaRepository {
  AnaliticaRepository({Dio? dio})
      : _dio = dio ?? ClienteDio.instancia(conAuthStaff: true);

  final Dio _dio;

  /// Construye queryParameters para endpoints de analítica.
  static Map<String, dynamic> buildQuery({
    required String sucursalId,
    String? preset,
    String? desde,
    String? hasta,
    bool? comparar,
    Map<String, dynamic>? filtros,
  }) {
    final query = <String, dynamic>{'sucursal_id': sucursalId};
    if (preset != null) query['preset'] = preset;
    if (desde != null) query['desde'] = desde;
    if (hasta != null) query['hasta'] = hasta;
    if (comparar != null) query['comparar'] = comparar ? 'true' : 'false';
    if (filtros != null) {
      for (final e in filtros.entries) {
        final v = e.value;
        if (v != null && v != '') query[e.key] = v;
      }
    }
    return query;
  }

  Future<Map<String, dynamic>> resumen({
    required String sucursalId,
    String preset = 'mes',
    String? desde,
    String? hasta,
    bool comparar = true,
    Map<String, dynamic>? filtros,
  }) =>
      _get(
        '/analitica/resumen',
        sucursalId: sucursalId,
        preset: preset,
        desde: desde,
        hasta: hasta,
        comparar: comparar,
        filtros: filtros,
      );

  Future<Map<String, dynamic>> ventas({
    required String sucursalId,
    String preset = 'mes',
    bool comparar = false,
    Map<String, dynamic>? filtros,
  }) =>
      _get(
        '/analitica/ventas',
        sucursalId: sucursalId,
        preset: preset,
        comparar: comparar,
        filtros: filtros,
      );

  Future<Map<String, dynamic>> productos({
    required String sucursalId,
    String preset = 'mes',
    bool comparar = false,
    Map<String, dynamic>? filtros,
  }) =>
      _get(
        '/analitica/productos',
        sucursalId: sucursalId,
        preset: preset,
        comparar: comparar,
        filtros: filtros,
      );

  Future<Map<String, dynamic>> cocinas({
    required String sucursalId,
    String preset = 'mes',
    bool comparar = false,
    Map<String, dynamic>? filtros,
  }) =>
      _get(
        '/analitica/cocinas',
        sucursalId: sucursalId,
        preset: preset,
        comparar: comparar,
        filtros: filtros,
      );

  Future<Map<String, dynamic>> inventario({
    required String sucursalId,
    String preset = 'mes',
    bool comparar = false,
    Map<String, dynamic>? filtros,
  }) =>
      _get(
        '/analitica/inventario',
        sucursalId: sucursalId,
        preset: preset,
        comparar: comparar,
        filtros: filtros,
      );

  Future<Map<String, dynamic>> domiciliarios({
    required String sucursalId,
    String preset = 'mes',
    bool comparar = false,
    Map<String, dynamic>? filtros,
  }) =>
      _get(
        '/analitica/domiciliarios',
        sucursalId: sucursalId,
        preset: preset,
        comparar: comparar,
        filtros: filtros,
      );

  Future<Map<String, dynamic>> caja({
    required String sucursalId,
    String preset = 'mes',
    bool comparar = false,
    Map<String, dynamic>? filtros,
  }) =>
      _get(
        '/analitica/caja',
        sucursalId: sucursalId,
        preset: preset,
        comparar: comparar,
        filtros: filtros,
      );

  Future<Map<String, dynamic>> rentabilidad({
    required String sucursalId,
    String preset = 'mes',
    bool comparar = false,
    Map<String, dynamic>? filtros,
  }) =>
      _get(
        '/analitica/rentabilidad',
        sucursalId: sucursalId,
        preset: preset,
        comparar: comparar,
        filtros: filtros,
      );

  Future<Map<String, dynamic>> riesgo({
    required String sucursalId,
    String preset = 'mes',
    bool comparar = false,
    Map<String, dynamic>? filtros,
  }) =>
      _get(
        '/analitica/riesgo',
        sucursalId: sucursalId,
        preset: preset,
        comparar: comparar,
        filtros: filtros,
      );

  Future<Uint8List> exportarCsv({
    required String sucursalId,
    String preset = 'mes',
    bool comparar = false,
    Map<String, dynamic>? filtros,
  }) async {
    final query = buildQuery(
      sucursalId: sucursalId,
      preset: preset,
      comparar: comparar,
      filtros: filtros,
    )..['formato'] = 'csv';

    final r = await _dio.get<List<int>>(
      '/analitica/export',
      queryParameters: query,
      options: Options(responseType: ResponseType.bytes),
    );
    if (r.data == null || r.data!.isEmpty) {
      throw Exception('Exportación vacía');
    }
    return Uint8List.fromList(r.data!);
  }

  Future<Map<String, dynamic>> pedidosRecientes({
    required String sucursalId,
    String preset = 'hoy',
    bool comparar = false,
    Map<String, dynamic>? filtros,
    int limite = 15,
  }) =>
      _get(
        '/analitica/pedidos-recientes',
        sucursalId: sucursalId,
        preset: preset,
        comparar: comparar,
        filtros: {
          ...?filtros,
          'limite': limite,
        },
      );

  Future<Map<String, dynamic>> comparativaSedes({
    String preset = '7d',
    Map<String, dynamic>? filtros,
  }) async {
    final query = buildQuery(
      sucursalId: '',
      preset: preset,
      filtros: filtros,
    )..remove('sucursal_id');

    final r = await _dio.get<Map<String, dynamic>>(
      '/analitica/comparativa-sedes',
      queryParameters: query,
    );
    if (r.data == null) throw Exception('Respuesta vacía');
    final env = RespuestaApi<Map<String, dynamic>>.fromJson(
      r.data!,
      (raw) => Map<String, dynamic>.from(raw as Map<String, dynamic>),
    );
    if (!env.exito || env.datos == null) throw Exception(env.mensaje);
    return env.datos!;
  }

  Future<Map<String, dynamic>> _get(
    String path, {
    required String sucursalId,
    String? preset,
    String? desde,
    String? hasta,
    bool? comparar,
    Map<String, dynamic>? filtros,
  }) async {
    final query = buildQuery(
      sucursalId: sucursalId,
      preset: preset,
      desde: desde,
      hasta: hasta,
      comparar: comparar,
      filtros: filtros,
    );

    final r = await _dio.get<Map<String, dynamic>>(path, queryParameters: query);
    if (r.data == null) throw Exception('Respuesta vacía');
    final env = RespuestaApi<Map<String, dynamic>>.fromJson(
      r.data!,
      (raw) => Map<String, dynamic>.from(raw as Map<String, dynamic>),
    );
    if (!env.exito || env.datos == null) throw Exception(env.mensaje);
    return env.datos!;
  }
}
