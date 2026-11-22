import 'dart:async';

import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import 'package:reserva_canchas/core/sesion/sesion_staff_service.dart';
import 'package:reserva_canchas/main.dart' show appNavigatorKey;
import 'package:reserva_canchas/services/app_backend.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 401 en API staff: sesión inválida/expirada → limpiar y volver al login.
class ManejoErrorSesion {
  ManejoErrorSesion._();

  static DateTime? _ultimoRedirect;
  static bool _enCurso = false;

  static bool es401(Object error) {
    if (error is! DioException) return false;
    if (error.response?.statusCode == 401) return true;
    if (error.error == 'SESION_EXPIRADA') return true;
    final msg = error.message ?? '';
    return msg.contains('Sesión expirada') || msg.contains('SESION_EXPIRADA');
  }

  static bool _esRutaLogin(String path) =>
      path.contains('/auth/login') ||
      path.contains('/auth/login-google') ||
      path.contains('/auth/login-domiciliario') ||
      path.contains('/auth/registro') ||
      path.contains('/auth/refresh') ||
      path.contains('/auth/logout');

  /// Interceptor Dio (staff). No depende del BuildContext de la pantalla.
  static void manejarDesdeInterceptor(DioException error) {
    if (!es401(error)) return;
    if (_esRutaLogin(error.requestOptions.path)) return;
    unawaited(solicitarReLogin());
  }

  /// En pantallas / splash: `true` si ya redirigió (no seguir cargando panel).
  static Future<bool> manejarEnPantalla(Object error) async {
    if (!es401(error)) return false;
    await solicitarReLogin();
    return true;
  }

  /// Token vencido en cliente o 401 del API.
  static Future<void> solicitarReLogin() => _forzarReLogin();

  static Future<void> _forzarReLogin() async {
    if (_enCurso) return;
    final ahora = DateTime.now();
    if (_ultimoRedirect != null &&
        ahora.difference(_ultimoRedirect!) < const Duration(seconds: 3)) {
      return;
    }
    _enCurso = true;
    _ultimoRedirect = ahora;
    try {
      // ponytail: no AuthRepository.logout (evitar POST FCM con token ya inválido).
      await SesionStaffService.cerrar();
      if (AppBackend.supabaseReady) {
        try {
          await Supabase.instance.client.auth.signOut();
        } catch (_) {}
      }
      final ctx = appNavigatorKey.currentContext;
      if (ctx != null && ctx.mounted) {
        ctx.go('/admin/login');
      }
    } finally {
      _enCurso = false;
    }
  }
}
