import 'package:dio/dio.dart';
import 'package:reserva_canchas/core/modelos/respuesta_api.dart';
import 'package:reserva_canchas/core/red/cliente_dio.dart';
import 'package:reserva_canchas/features/ciudades/domain/ciudad_model.dart';

class CiudadesRepository {
  CiudadesRepository({Dio? dio}) : _dio = dio ?? ClienteDio.instancia();

  final Dio _dio;

  Future<List<CiudadModel>> listarActivas() async {
    final respuesta = await _dio.get<Map<String, dynamic>>('/ciudades');
    final data = respuesta.data;
    if (data == null) {
      throw Exception('Respuesta vacía del servidor');
    }

    final envoltura = RespuestaApi<List<CiudadModel>>.fromJson(
      data,
      (raw) => (raw as List<dynamic>)
          .map((e) => CiudadModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

    if (!envoltura.exito || envoltura.datos == null) {
      throw Exception(envoltura.mensaje);
    }

    return envoltura.datos!;
  }
}
