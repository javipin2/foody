import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:reserva_canchas/core/red/cliente_dio.dart';

class DispositivoService {
  static const _keyDeviceId = 'foody_device_id';
  static const _keyCapability = 'foody_device_capability';
  static const FlutterSecureStorage _secure = FlutterSecureStorage();
  static String? _capabilityRegistrada;
  static Future<void>? _registroEnCurso;

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

  static Future<String> obtenerCapability() async {
    String? valor;
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      valor = prefs.getString(_keyCapability);
    } else {
      try {
        valor = await _secure.read(key: _keyCapability);
      } catch (_) {
        // Keystore/Keychain puede no estar disponible; revisar la copia fallback.
      }
      if (valor == null || !RegExp(r'^[a-f0-9]{64}$').hasMatch(valor)) {
        final prefs = await SharedPreferences.getInstance();
        final fallback = prefs.getString(_keyCapability);
        if (fallback != null && RegExp(r'^[a-f0-9]{64}$').hasMatch(fallback)) {
          valor = fallback;
          try {
            await _secure.write(key: _keyCapability, value: fallback);
            await prefs.remove(_keyCapability);
          } catch (_) {
            // Conservar fallback si el almacenamiento seguro sigue fallando.
          }
        }
      }
    }
    if (valor != null && RegExp(r'^[a-f0-9]{64}$').hasMatch(valor)) {
      return valor;
    }

    const uuid = Uuid();
    valor = '${uuid.v4().replaceAll('-', '')}${uuid.v4().replaceAll('-', '')}';
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyCapability, valor);
    } else {
      try {
        await _secure.write(key: _keyCapability, value: valor);
      } catch (_) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyCapability, valor);
      }
    }
    return valor;
  }

  static Future<Map<String, String>> capabilityHeaders() async => {
        'X-Foody-Device-Capability': await obtenerCapability(),
      };

  static Future<void> registrarEnBackend({
    String? ciudadId,
    String? fcmToken,
    String? plataforma,
    Dio? dio,
  }) async {
    final esSoloCapability =
        ciudadId == null && fcmToken == null && plataforma == null;
    final deviceId = await obtenerDeviceId();
    final capability = await obtenerCapability();
    final claveRegistro = '$deviceId:$capability';
    if (esSoloCapability && _capabilityRegistrada == claveRegistro) return;
    final enCurso = _registroEnCurso;
    if (enCurso != null) return enCurso;
    final registro = _registrar(
      dio: dio,
      deviceId: deviceId,
      capability: capability,
      ciudadId: ciudadId,
      fcmToken: fcmToken,
      plataforma: plataforma,
    );
    _registroEnCurso = registro;
    try {
      await registro;
    } finally {
      _registroEnCurso = null;
    }
  }

  static Future<void> _registrar({
    Dio? dio,
    required String deviceId,
    required String capability,
    String? ciudadId,
    String? fcmToken,
    String? plataforma,
  }) async {
    final cliente = dio ?? ClienteDio.instancia();
    final respuesta = await cliente.post<Map<String, dynamic>>(
      '/dispositivos/registrar',
      options: Options(headers: {'X-Foody-Device-Capability': capability}),
      data: {
        'device_id': deviceId,
        if (ciudadId != null) 'ciudad_id': ciudadId,
        if (fcmToken != null) 'fcm_token': fcmToken,
        'plataforma': plataforma ?? _plataformaPorDefecto(),
      },
    );
    final datos = respuesta.data?['datos'];
    if (datos is Map && datos['registrado'] == false) {
      throw StateError('No se pudo registrar la capability del dispositivo');
    }
    _capabilityRegistrada = '$deviceId:$capability';
  }

  /// Vincula Google (Supabase access token) al device_id local.
  static Future<Map<String, dynamic>> vincularAuthCliente({
    required String accessToken,
  }) async {
    await registrarEnBackend();
    final deviceId = await obtenerDeviceId();
    final capability = await obtenerCapability();
    final dio = ClienteDio.instancia();
    final respuesta = await dio.post<Map<String, dynamic>>(
      '/dispositivos/vincular-auth',
      options: Options(headers: {'X-Foody-Device-Capability': capability}),
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
    throw Exception(
        data['mensaje']?.toString() ?? 'No se pudo vincular Google');
  }
}
