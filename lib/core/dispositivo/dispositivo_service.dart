import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:reserva_canchas/core/red/cliente_dio.dart';

class DispositivoService {
  static const _keyDeviceId = 'foody_device_id';

  static Future<String> obtenerDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_keyDeviceId);
    if (id == null || id.isEmpty) {
      id = const Uuid().v4();
      await prefs.setString(_keyDeviceId, id);
    }
    return id;
  }

  static String _plataformaPorDefecto() {
    if (kIsWeb) return 'web';
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'ios';
    return 'android';
  }

  static Future<void> registrarEnBackend({
    String? ciudadId,
    String? fcmToken,
    String? plataforma,
  }) async {
    final deviceId = await obtenerDeviceId();
    final dio = ClienteDio.instancia();
    await dio.post('/dispositivos/registrar', data: {
      'device_id': deviceId,
      if (ciudadId != null) 'ciudad_id': ciudadId,
      if (fcmToken != null) 'fcm_token': fcmToken,
      'plataforma': plataforma ?? _plataformaPorDefecto(),
    });
  }

  /// Vincula Google (Supabase access token) al device_id local.
  static Future<Map<String, dynamic>> vincularAuthCliente({
    required String accessToken,
  }) async {
    final deviceId = await obtenerDeviceId();
    final dio = ClienteDio.instancia();
    final respuesta = await dio.post<Map<String, dynamic>>(
      '/dispositivos/vincular-auth',
      data: {
        'device_id': deviceId,
        'access_token': accessToken,
      },
    );
    final data = respuesta.data;
    if (data == null) throw Exception('Respuesta vacía al vincular sesión');
    // Envoltura { exito, datos } o mapa plano.
    final datos = data['datos'];
    if (datos is Map<String, dynamic>) return datos;
    if (data['auth_uid'] != null) return data;
    throw Exception(data['mensaje']?.toString() ?? 'No se pudo vincular Google');
  }
}
