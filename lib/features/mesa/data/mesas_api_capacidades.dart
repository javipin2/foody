import 'package:dio/dio.dart';
import 'package:reserva_canchas/core/constantes/configuracion.dart';

/// Comprueba si el proceso NestJS en marcha expone las rutas nuevas de mesas.
Future<bool> backendMesasActualizado() async {
  final dio = Dio(
    BaseOptions(
      baseUrl: Configuracion.urlBackend,
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
      headers: {'Content-Type': 'application/json'},
    ),
  );
  try {
    await dio.post<Map<String, dynamic>>('/mesas', data: {});
    return true;
  } on DioException catch (e) {
    final codigo = e.response?.statusCode;
    // Ruta existe: guard JWT (401) o validación body (400)
    if (codigo == 401 || codigo == 400) return true;
    if (codigo == 404) return false;
    return true;
  }
}
