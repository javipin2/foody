import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:reserva_canchas/config/app_link_config.dart';
import 'package:reserva_canchas/features/auth/domain/google_oauth_deep_link_service.dart';
import 'package:reserva_canchas/core/rutas/redireccion_staff.dart';
import 'package:reserva_canchas/features/auth/data/auth_repository.dart';
import 'package:reserva_canchas/services/app_backend.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Destino tras OAuth Google (staff / registro restaurante).
enum OAuthDestinoStaff { login, registro }

/// Datos para completar registro tras Google sin pedir contraseña.
class DatosGoogleRegistro {
  const DatosGoogleRegistro({
    required this.accessToken,
    required this.email,
    this.nombre,
  });

  final String accessToken;
  final String email;
  final String? nombre;
}

/// OAuth Google unificado: redirect web/móvil y procesamiento de sesión Supabase.
class GoogleOAuthStaffService {
  GoogleOAuthStaffService._();

  static const _prefsDestino = 'foody_oauth_destino_staff';

  static String uriRedireccion(OAuthDestinoStaff destino) {
    if (kIsWeb) {
      final origin = Uri.base.origin;
      return switch (destino) {
        OAuthDestinoStaff.registro => '$origin/admin/registro',
        OAuthDestinoStaff.login => '$origin/admin/login',
      };
    }
    return AppLinkConfig.oauthRedirectUri;
  }

  /// Solo procesar OAuth si el usuario acaba de volver de Google.
  static Future<bool> hayRetornoOAuthPendiente() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_prefsDestino)) return false;
    if (kIsWeb) {
      final tieneCode = Uri.base.queryParameters.containsKey('code');
      if (tieneCode) return true;
      // Supabase Flutter ya intercambió el code en Supabase.initialize.
      return AppBackend.supabaseReady &&
          Supabase.instance.client.auth.currentSession != null;
    }
    return true;
  }

  /// Error devuelto por Supabase/Google en la URL (`?error=`).
  static String? errorOAuthEnUrl() {
    if (!kIsWeb) return null;
    final params = Uri.base.queryParameters;
    return params['error_description'] ?? params['error'];
  }

  /// Quita `?code=` / `?error=` de la barra para no reintentar al recargar.
  static void limpiarQueryOAuthEnRuta(BuildContext context) {
    if (!kIsWeb) return;
    final uri = Uri.base;
    if (uri.queryParameters.isEmpty) return;
    final tieneOAuth = uri.queryParameters.containsKey('code') ||
        uri.queryParameters.containsKey('error') ||
        uri.queryParameters.containsKey('error_description');
    if (!tieneOAuth) return;
    context.go(uri.path.isEmpty ? '/' : uri.path);
  }

  /// Web: detectSessionInUri / ?code=. Móvil: deep link foody://login.
  static Future<void> asegurarSesionOAuth() async {
    if (!AppBackend.supabaseReady) {
      throw StateError('Supabase no está configurado en este entorno');
    }

    if (!kIsWeb) {
      await GoogleOAuthDeepLinkService.intercambiarSesionPendiente();
      return;
    }

    final errorUrl = errorOAuthEnUrl();
    if (errorUrl != null && errorUrl.isNotEmpty) {
      throw AuthException(errorUrl);
    }

    final auth = Supabase.instance.client.auth;
    if (auth.currentSession != null) return;

    final tieneCode = Uri.base.queryParameters.containsKey('code');
    if (!tieneCode) return;

    // Supabase.initialize ya procesa ?code= (detectSessionInUri). Esperar antes de duplicar.
    for (var i = 0; i < 40; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (auth.currentSession != null) return;
    }

    try {
      await auth.getSessionFromUrl(Uri.base);
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException(
        'No se pudo intercambiar el código de Google. '
        'Comprueba que Supabase (:8000) esté encendido y que el redirect '
        '${Uri.base.origin} esté en ADDITIONAL_REDIRECT_URLS.',
      );
    }
  }

  static Future<void> limpiarMarcadoresOAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsDestino);
  }

  static Future<void> iniciarOAuth(OAuthDestinoStaff destino) async {
    if (!AppBackend.supabaseReady) {
      throw StateError('Supabase no está configurado');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsDestino, destino.name);

    await Supabase.instance.client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: uriRedireccion(destino),
      // Móvil: WebView dentro de la app (mejor UX que Chrome externo).
      authScreenLaunchMode: kIsWeb
          ? LaunchMode.platformDefault
          : LaunchMode.inAppWebView,
    );
  }

  static Future<OAuthDestinoStaff?> _consumirDestino() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsDestino);
    await prefs.remove(_prefsDestino);
    if (raw == null) return null;
    if (raw == OAuthDestinoStaff.registro.name) {
      return OAuthDestinoStaff.registro;
    }
    return OAuthDestinoStaff.login;
  }

  /// Procesa sesión Supabase en login: dashboard o registro con datos precargados.
  static Future<bool> procesarRetornoEnLogin(
    BuildContext context,
    AuthRepository repo,
  ) async {
    if (!AppBackend.supabaseReady) return false;
    if (!await hayRetornoOAuthPendiente()) return false;

    var navegoTrasExito = false;
    try {
      await asegurarSesionOAuth();

      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        throw AuthException(
          'Google no devolvió sesión. Revisa redirect en Supabase '
          '(${uriRedireccion(OAuthDestinoStaff.login)}).',
        );
      }

      final destino = await _consumirDestino();
      if (destino != null && destino != OAuthDestinoStaff.login) {
        return false;
      }

      final r = await repo.loginGoogle(accessToken: session.accessToken);
      if (!context.mounted) return true;

      if (r.necesitaRegistro) {
        context.go(
          '/admin/registro',
          extra: {
            'email': r.email,
            'nombre': r.nombre,
            'access_token': r.accessToken ?? session.accessToken,
          },
        );
        navegoTrasExito = true;
        return true;
      }

      if (r.sesion != null) {
        irDashboardStaff(context, r.sesion!.dashboard);
        navegoTrasExito = true;
        return true;
      }
      return false;
    } finally {
      await limpiarMarcadoresOAuth();
      // No volver a /admin/login si ya redirigimos al panel o registro.
      if (context.mounted && !navegoTrasExito) {
        limpiarQueryOAuthEnRuta(context);
      }
    }
  }

  /// En registro: hidrata el formulario o envía al panel si la cuenta ya existe.
  static Future<DatosGoogleRegistro?> procesarRetornoEnRegistro(
    BuildContext context,
    AuthRepository repo,
  ) async {
    if (!AppBackend.supabaseReady) return null;
    if (!await hayRetornoOAuthPendiente()) return null;

    var navegoTrasExito = false;
    try {
      await asegurarSesionOAuth();

      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        throw AuthException(
          'Google no devolvió sesión. Revisa redirect en Supabase '
          '(${uriRedireccion(OAuthDestinoStaff.registro)}).',
        );
      }

      final destino = await _consumirDestino();
      if (destino != null && destino != OAuthDestinoStaff.registro) {
        return null;
      }

      final r = await repo.loginGoogle(accessToken: session.accessToken);
      if (!context.mounted) return null;

      if (r.necesitaRegistro) {
        return DatosGoogleRegistro(
          accessToken: r.accessToken ?? session.accessToken,
          email: r.email ?? session.user.email ?? '',
          nombre: r.nombre,
        );
      }

      if (r.sesion != null) {
        irDashboardStaff(context, r.sesion!.dashboard);
        navegoTrasExito = true;
      }
      return null;
    } finally {
      await limpiarMarcadoresOAuth();
      if (context.mounted &&
          (!navegoTrasExito || Uri.base.queryParameters.containsKey('code'))) {
        limpiarQueryOAuthEnRuta(context);
      }
    }
  }
}
