import 'package:dio/dio.dart';
import 'package:reserva_canchas/core/modelos/respuesta_api.dart';
import 'package:reserva_canchas/core/red/cliente_dio.dart';
import 'package:reserva_canchas/features/menu/domain/menu_model.dart';

class MenuRepository {
  MenuRepository({Dio? dio}) : _dio = dio ?? ClienteDio.instancia();

  final Dio _dio;

  Future<MenuModel> obtenerPorSucursal(String sucursalId) async {
    final respuesta =
        await _dio.get<Map<String, dynamic>>('/menu/$sucursalId');
    final data = respuesta.data;
    if (data == null) {
      throw Exception('Respuesta vacía del servidor');
    }

    final envoltura = RespuestaApi<MenuModel>.fromJson(
      data,
      (raw) => MenuModel.fromJson(raw as Map<String, dynamic>),
    );

    if (!envoltura.exito || envoltura.datos == null) {
      throw Exception(envoltura.mensaje);
    }

    return envoltura.datos!;
  }
}
