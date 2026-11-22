import 'package:dio/dio.dart';
import 'package:reserva_canchas/core/constantes/configuracion.dart';

/// Comprueba si el proceso NestJS en marcha expone las rutas nuevas de mesas.
Future<bool> backendMesasActualizado() async {
  final dio = Dio(
    BaseOptions(
      baseUrl: Configuracion.urlBackend,
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
    ),
  );
  try {
    final resp = await dio.get<Map<String, dynamic>>('/salud');
    final datos = resp.data?['datos'] as Map<String, dynamic>?;
    final modulos = datos?['modulos'] as Map<String, dynamic>?;
    final mesas = modulos?['mesas'];
    if (mesas is List) {
      return mesas.contains('POST crear') && mesas.contains('GET qr');
    }
    final texto = mesas?.toString() ?? '';
    return texto.contains('POST crear') && texto.contains('qr');
  } on DioException catch (e) {
    if (e.response?.statusCode == 404) return false;
    return true;
  }
}
