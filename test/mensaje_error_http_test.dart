import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';

void main() {
  test('el mensaje de demostración se conserva en modo debug', () {
    expect(kDebugMode, isTrue);

    final request = RequestOptions(path: '/auth/login');
    final error = DioException(
      requestOptions: request,
      response: Response<void>(
        requestOptions: request,
        statusCode: 401,
      ),
    );

    expect(
      mensajeErrorHttp(error),
      contains('admin@foody.demo / 123456'),
    );
  });

  test('conserva la instrucción de Cocina del API al bloquear estado listo',
      () {
    const mensaje =
        'No se puede marcar el pedido como listo hasta resolver todos sus ítems en Cocina.';
    final request = RequestOptions(path: '/api/v1/pedidos/pedido-1/estado');
    final error = DioException(
      requestOptions: request,
      response: Response<Map<String, dynamic>>(
        requestOptions: request,
        statusCode: 400,
        data: {
          'statusCode': 400,
          'error': 'COCINA_INCOMPLETA_PARA_LISTO',
          'message': mensaje,
        },
      ),
    );

    expect(mensajeErrorHttp(error, contexto: 'cambiar el estado'), mensaje);
  });
}
