import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class SesionStaff {
  const SesionStaff({
    required this.token,
    required this.dashboard,
    required this.rol,
    required this.permisos,
    required this.usuario,
    this.plan = 'basico',
    this.modulos = const [],
  });

  final String token;
  final String dashboard;
  final String rol;
  final List<String> permisos;
  final Map<String, dynamic> usuario;
  final String plan;
  final List<String> modulos;

  String? get sucursalId => usuario['sucursal_id'] as String?;
}

class SesionStaffService {
  static const _keyToken = 'foody_staff_token';
  static const _keySesion = 'foody_staff_sesion';

  static Future<void> guardar({
    required String token,
    required String dashboard,
    required String rol,
    required List<String> permisos,
    required Map<String, dynamic> usuario,
    String plan = 'basico',
    List<String> modulos = const [],
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
    await prefs.setString(
      _keySesion,
      jsonEncode({
        'dashboard': dashboard,
        'rol': rol,
        'permisos': permisos,
        'usuario': usuario,
        'plan': plan,
        'modulos': modulos,
      }),
    );
  }

  static Future<SesionStaff?> cargar() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_keyToken);
    final raw = prefs.getString(_keySesion);
    if (token == null || raw == null) return null;

    final map = jsonDecode(raw) as Map<String, dynamic>;
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
    );
  }

  static Future<String?> obtenerToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken);
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

  static Future<void> actualizarToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
  }

  static Future<void> cerrar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keySesion);
  }
}
