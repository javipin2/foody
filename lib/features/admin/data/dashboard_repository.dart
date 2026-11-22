import 'package:dio/dio.dart';
import 'package:reserva_canchas/core/modelos/respuesta_api.dart';
import 'package:reserva_canchas/core/red/cliente_dio.dart';

class DashboardRepository {
  DashboardRepository({Dio? dio})
      : _dio = dio ?? ClienteDio.instancia(conAuthStaff: true);

  final Dio _dio;

  Future<Map<String, dynamic>> resumen({String? sucursalId}) async {
    final respuesta = await _dio.get<Map<String, dynamic>>(
      '/dashboard/resumen',
      queryParameters: {
        if (sucursalId != null) 'sucursal_id': sucursalId,
      },
    );
    final data = respuesta.data;
    if (data == null) throw Exception('Respuesta vacía');

    final envoltura = RespuestaApi<Map<String, dynamic>>.fromJson(
      data,
      (raw) => Map<String, dynamic>.from(raw as Map<String, dynamic>),
    );
    if (!envoltura.exito || envoltura.datos == null) {
      throw Exception(envoltura.mensaje);
    }
    return envoltura.datos!;
  }

  Future<Map<String, dynamic>> graficos({String? sucursalId}) async {
    final respuesta = await _dio.get<Map<String, dynamic>>(
      '/dashboard/graficos',
      queryParameters: {
        if (sucursalId != null) 'sucursal_id': sucursalId,
      },
    );
    final data = respuesta.data;
    if (data == null) throw Exception('Respuesta vacía');

    final envoltura = RespuestaApi<Map<String, dynamic>>.fromJson(
      data,
      (raw) => Map<String, dynamic>.from(raw as Map<String, dynamic>),
    );
    if (!envoltura.exito || envoltura.datos == null) {
      throw Exception(envoltura.mensaje);
    }
    return envoltura.datos!;
  }

  Future<Map<String, dynamic>> consolidado() async {
    final respuesta = await _dio.get<Map<String, dynamic>>(
      '/dashboard/consolidado',
    );
    final data = respuesta.data;
    if (data == null) throw Exception('Respuesta vacía');

    final envoltura = RespuestaApi<Map<String, dynamic>>.fromJson(
      data,
      (raw) => Map<String, dynamic>.from(raw as Map<String, dynamic>),
    );
    if (!envoltura.exito || envoltura.datos == null) {
      throw Exception(envoltura.mensaje);
    }
    return envoltura.datos!;
  }
}
