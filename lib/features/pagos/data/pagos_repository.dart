import 'package:dio/dio.dart';
import 'package:reserva_canchas/core/modelos/respuesta_api.dart';
import 'package:reserva_canchas/core/red/cliente_dio.dart';

/// Checkout Wompi y estado de suscripción (F5–F6 self-service).
class PagosRepository {
  PagosRepository({Dio? dio})
      : _dio = dio ?? ClienteDio.instancia(conAuthStaff: true);

  final Dio _dio;

  Future<Map<String, dynamic>> crearCheckout(String plan) async {
    final respuesta = await _dio.post<Map<String, dynamic>>(
      '/pagos/checkout',
      data: {'plan': plan},
    );
    return _extraerDatos(respuesta.data);
  }

  Future<Map<String, dynamic>> estado() async {
    final respuesta = await _dio.get<Map<String, dynamic>>('/pagos/estado');
    return _extraerDatos(respuesta.data);
  }

  Future<Map<String, dynamic>> sincronizar({
    String? pagoId,
    required String transaccionWompiId,
  }) async {
    final respuesta = await _dio.post<Map<String, dynamic>>(
      '/pagos/sincronizar',
      data: {
        if (pagoId != null) 'pago_id': pagoId,
        'transaccion_wompi_id': transaccionWompiId,
      },
    );
    return _extraerDatos(respuesta.data);
  }

  Map<String, dynamic> _extraerDatos(Map<String, dynamic>? data) {
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
