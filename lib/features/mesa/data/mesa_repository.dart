import 'package:dio/dio.dart';
import 'package:reserva_canchas/core/modelos/respuesta_api.dart';
import 'package:reserva_canchas/core/red/cliente_dio.dart';
import 'package:reserva_canchas/features/menu/domain/menu_model.dart';

class MesaRepository {
  MesaRepository({Dio? dio}) : _dio = dio ?? ClienteDio.instancia();

  final Dio _dio;

  Future<({MenuModel menu, String mesaId, String mesaNombre})> menuPorQr(
    String qrToken,
  ) async {
    final respuesta =
        await _dio.get<Map<String, dynamic>>('/menu/mesa/$qrToken');
    final data = respuesta.data;
    if (data == null) throw Exception('Respuesta vacía');
    final env = RespuestaApi<Map<String, dynamic>>.fromJson(
      data,
      (raw) => Map<String, dynamic>.from(raw as Map<String, dynamic>),
    );
    if (!env.exito || env.datos == null) {
      throw Exception(env.mensaje);
    }
    final json = env.datos!;
    final mesa = json['mesa'] as Map<String, dynamic>;
    return (
      menu: MenuModel.fromJson(json),
      mesaId: mesa['id'] as String,
      mesaNombre: mesa['nombre'] as String,
    );
  }
}
