import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reserva_canchas/core/sesion/jwt_staff.dart';

class SesionStaff {
  const SesionStaff({
    required this.token,
    required this.dashboard,
    required this.rol,
    required this.permisos,
    required this.usuario,
    this.plan = 'basico',
    this.modulos = const [],
    this.realtimeCanales = const {},
  });

  final String token;
  final String dashboard;
  final String rol;
  final List<String> permisos;
  final Map<String, dynamic> usuario;
  final String plan;
  final List<String> modulos;
  /// Topics HMAC staff (RT-SEC-01). Claves: sucursal, cocina, restaurante, domiciliario…
  final Map<String, String> realtimeCanales;

  String? get sucursalId => usuario['sucursal_id'] as String?;
}

/// JWT staff: Keystore/Keychain en móvil; SharedPreferences en web.
/// Web no cifra de verdad (AUTH-STORE-01 residual XSS). En release web el plugin
/// `flutter_secure_storage` puede lanzar MissingPluginException → prefs es la vía.
class SesionStaffService {
  static const _keyToken = 'foody_staff_token';
  static const _keySesion = 'foody_staff_sesion';

  static const FlutterSecureStorage _secure = FlutterSecureStorage();

  static Future<void> guardar({
    required String token,
    required String dashboard,
    required String rol,
    required List<String> permisos,
    required Map<String, dynamic> usuario,
    String plan = 'basico',
    List<String> modulos = const [],
    Map<String, String> realtimeCanales = const {},
  }) async {
    await _escribirToken(token);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keySesion,
      jsonEncode({
        'dashboard': dashboard,
        'rol': rol,
        'permisos': permisos,
        'usuario': usuario,
        'plan': plan,
        'modulos': modulos,
        'realtime_canales': realtimeCanales,
      }),
    );
  }

  static Future<SesionStaff?> cargar() async {
    final token = await obtenerToken();
    if (token == null) return null;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keySesion);
    if (raw == null) {
      await cerrar();
      return null;
    }

    final map = jsonDecode(raw) as Map<String, dynamic>;
    final canalesRaw = map['realtime_canales'];
    final canales = <String, String>{};
    if (canalesRaw is Map) {
      canalesRaw.forEach((k, v) {
        if (v != null && v.toString().isNotEmpty) {
          canales[k.toString()] = v.toString();
        }
      });
    }
    return SesionStaff(
      token: token,
      dashboard: map['dashboard'] as String? ?? 'restaurante',
      rol: map['rol'] as String? ?? '',
      permisos: (map['permisos'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      usuario: Map<String, dynamic>.from(
        map['usuario'] as Map<String, dynamic>? ?? {},
      ),
      plan: map['plan'] as String? ?? 'basico',
      modulos: (map['modulos'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      realtimeCanales: canales,
    );
  }

  static Future<String?> obtenerToken() async {
    final token = await _leerToken();
    if (token == null || token.isEmpty) return null;
    if (JwtStaff.expirado(token)) {
      await cerrar();
      return null;
    }
    return token;
  }

  static Future<void> actualizarPermisos(List<String> permisos) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keySesion);
    if (raw == null) return;
    final map = jsonDecode(raw) as Map<String, dynamic>;
    map['permisos'] = permisos;
    await prefs.setString(_keySesion, jsonEncode(map));
  }

  static Future<void> actualizarPlanYModulos({
    required String plan,
    required List<String> modulos,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keySesion);
    if (raw == null) return;
    final map = jsonDecode(raw) as Map<String, dynamic>;
    map['plan'] = plan;
    map['modulos'] = modulos;
    await prefs.setString(_keySesion, jsonEncode(map));
  }

  static Future<void> actualizarPerfilStaff({
    required List<String> permisos,
    required String plan,
    required List<String> modulos,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keySesion);
    if (raw == null) return;
    final map = jsonDecode(raw) as Map<String, dynamic>;
    map['permisos'] = permisos;
    map['plan'] = plan;
    map['modulos'] = modulos;
    await prefs.setString(_keySesion, jsonEncode(map));
  }

  static Future<void> actualizarSucursalId(String sucursalId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keySesion);
    if (raw == null) return;
    final map = jsonDecode(raw) as Map<String, dynamic>;
    final usuario = Map<String, dynamic>.from(
      map['usuario'] as Map<String, dynamic>? ?? {},
    );
    usuario['sucursal_id'] = sucursalId;
    map['usuario'] = usuario;
    await prefs.setString(_keySesion, jsonEncode(map));
  }

  /// RT-SEC-01: guarda topics firmados del login/refresh/cambio de sede.
  static Future<void> actualizarRealtimeCanales(
    Map<String, String> canales,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keySesion);
    if (raw == null) return;
    final map = jsonDecode(raw) as Map<String, dynamic>;
    map['realtime_canales'] = canales;
    await prefs.setString(_keySesion, jsonEncode(map));
  }

  static Future<Map<String, String>> obtenerRealtimeCanales() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keySesion);
    if (raw == null) return {};
    final map = jsonDecode(raw) as Map<String, dynamic>;
    final canalesRaw = map['realtime_canales'];
    final out = <String, String>{};
    if (canalesRaw is Map) {
      canalesRaw.forEach((k, v) {
        if (v != null && v.toString().isNotEmpty) {
          out[k.toString()] = v.toString();
        }
      });
    }
    return out;
  }

  static Future<void> actualizarToken(String token) async {
    await _escribirToken(token);
  }

  static Future<void> cerrar() async {
    await _borrarToken();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keySesion);
  }

  /// ponytail: web → prefs (plugin release suele fallar MissingPluginException).
  /// Móvil → secure storage; si el plugin falla, prefs + migración one-shot.
  static Future<String?> _leerToken() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final t = prefs.getString(_keyToken);
      return (t == null || t.isEmpty) ? null : t;
    }

    try {
      final t = await _secure.read(key: _keyToken);
      if (t != null && t.isNotEmpty) return t;
    } catch (_) {
      // MissingPluginException u otro fallo de plataforma.
    }

    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(_keyToken);
    if (legacy == null || legacy.isEmpty) return null;
    await _escribirToken(legacy);
    await prefs.remove(_keyToken);
    return legacy;
  }

  static Future<void> _escribirToken(String token) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyToken, token);
      return;
    }

    try {
      await _secure.write(key: _keyToken, value: token);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyToken);
    } catch (_) {
      // Fallback: no bloquear login si Keystore/plugin falla.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyToken, token);
    }
  }

  static Future<void> _borrarToken() async {
    if (kIsWeb) return;
    try {
      await _secure.delete(key: _keyToken);
    } catch (_) {}
  }
}
