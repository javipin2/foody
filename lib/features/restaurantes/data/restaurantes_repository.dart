import 'package:dio/dio.dart';
import 'package:reserva_canchas/core/modelos/respuesta_api.dart';
import 'package:reserva_canchas/core/red/cliente_dio.dart';
import 'package:reserva_canchas/features/restaurantes/domain/restaurante_model.dart';
import 'package:reserva_canchas/features/restaurantes/domain/sucursal_model.dart';

class RestaurantesRepository {
  RestaurantesRepository({Dio? dio}) : _dio = dio ?? ClienteDio.instancia();

  final Dio _dio;

  Future<List<RestauranteModel>> listarPorCiudad(String slug) async {
    final respuesta =
        await _dio.get<Map<String, dynamic>>('/ciudades/$slug/restaurantes');
    return _parsearLista(respuesta.data, RestauranteModel.fromJson);
  }

  Future<List<SucursalModel>> listarSucursales(String restauranteId) async {
    final respuesta = await _dio.get<Map<String, dynamic>>(
      '/restaurantes/$restauranteId/sucursales',
    );
    return _parsearLista(respuesta.data, SucursalModel.fromJson);
  }

  Future<List<T>> _parsearLista<T>(
    Map<String, dynamic>? data,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    if (data == null) {
      throw Exception('Respuesta vacía del servidor');
    }

    final envoltura = RespuestaApi<List<T>>.fromJson(
      data,
      (raw) => (raw as List<dynamic>)
          .map((e) => fromJson(e as Map<String, dynamic>))
          .toList(),
    );

    if (!envoltura.exito || envoltura.datos == null) {
      throw Exception(envoltura.mensaje);
    }

    return envoltura.datos!;
  }
}
