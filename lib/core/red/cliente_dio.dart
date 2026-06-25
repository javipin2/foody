import 'package:dio/dio.dart';
import 'package:reserva_canchas/core/constantes/configuracion.dart';
import 'package:reserva_canchas/core/sesion/sesion_staff_service.dart';

/// Cliente HTTP hacia el backend NestJS (cerebro de Foody).
class ClienteDio {
  ClienteDio._();

  static Dio? _dio;

  static Dio instancia({bool conAuthStaff = false}) {
    if (_dio != null && !conAuthStaff) return _dio!;

    final dio = Dio(
      BaseOptions(
        baseUrl: Configuracion.urlBackend,
        connectTimeout: Configuracion.timeoutConexion,
        receiveTimeout: Configuracion.timeoutRespuesta,
        headers: {'Content-Type': 'application/json'},
      ),
    );

    if (conAuthStaff) {
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            final token = await SesionStaffService.obtenerToken();
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
            handler.next(options);
          },
        ),
      );
      return dio;
    }

    _dio = dio;
    return dio;
  }
}
