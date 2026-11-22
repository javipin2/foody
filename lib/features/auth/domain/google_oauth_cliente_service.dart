import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:reserva_canchas/config/app_link_config.dart';
import 'package:reserva_canchas/core/dispositivo/dispositivo_service.dart';
import 'package:reserva_canchas/features/auth/domain/google_oauth_deep_link_service.dart';
import 'package:reserva_canchas/features/pedidos/data/sesion_cliente_service.dart';
import 'package:reserva_canchas/services/app_backend.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// OAuth Google para el **consumidor** (historial en la nube).
/// No llama a `/auth/login-google` (eso es staff).
class GoogleOAuthClienteService {
  GoogleOAuthClienteService._();

  static const _prefsMarcador = 'foody_oauth_destino_cliente';

  static String uriRedireccion() {
    if (kIsWeb) {
      return '${Uri.base.origin}/cliente/mis-pedidos';
    }
    return AppLinkConfig.oauthRedirectUri;
  }

  static Future<bool> hayRetornoOAuthPendiente() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_prefsMarcador)) return false;
    if (kIsWeb) {
      final tieneCode = Uri.base.queryParameters.containsKey('code');
      if (tieneCode) return true;
      return AppBackend.supabaseReady &&
          Supabase.instance.client.auth.currentSession != null;
    }
    return true;
  }

  static String? errorOAuthEnUrl() {
    if (!kIsWeb) return null;
    final params = Uri.base.queryParameters;
    return params['error_description'] ?? params['error'];
  }

  static void limpiarQueryOAuthEnRuta(BuildContext context) {
    if (!kIsWeb) return;
    final uri = Uri.base;
    if (uri.queryParameters.isEmpty) return;
    final tieneOAuth = uri.queryParameters.containsKey('code') ||
        uri.queryParameters.containsKey('error') ||
        uri.queryParameters.containsKey('error_description');
    if (!tieneOAuth) return;
    context.go('/cliente/mis-pedidos');
  }

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

    for (var i = 0; i < 40; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (auth.currentSession != null) return;
    }

    try {
      await auth.getSessionFromUrl(Uri.base);
    } on AuthException {
      rethrow;
    } catch (_) {
      throw AuthException(
        'No se pudo intercambiar el código de Google. '
        'Comprueba redirect ${uriRedireccion()} en Supabase.',
      );
    }
  }

  static Future<void> limpiarMarcadoresOAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsMarcador);
  }

  static Future<void> iniciarOAuth() async {
    if (!AppBackend.supabaseReady) {
      throw StateError('Supabase no está configurado');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsMarcador, 'mis_pedidos');

    await Supabase.instance.client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: uriRedireccion(),
      authScreenLaunchMode: kIsWeb
          ? LaunchMode.platformDefault
          : LaunchMode.inAppWebView,
    );
  }

  /// Tras volver de Google: vincula device ↔ uid en Nest y guarda perfil local.
  static Future<bool> procesarRetorno(BuildContext context) async {
    if (!AppBackend.supabaseReady) return false;
    if (!await hayRetornoOAuthPendiente()) return false;

    try {
      await asegurarSesionOAuth();
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        throw AuthException('Google no devolvió sesión.');
      }

      await limpiarMarcadoresOAuth();
      if (context.mounted) limpiarQueryOAuthEnRuta(context);

      final perfil = await DispositivoService.vincularAuthCliente(
        accessToken: session.accessToken,
      );
      await SesionClienteService.guardarDesdeVinculo(perfil);

      return true;
    } catch (_) {
      await limpiarMarcadoresOAuth();
      rethrow;
    }
  }

  static Future<void> cerrarSesion() async {
    await SesionClienteService.cerrar();
    if (AppBackend.supabaseReady) {
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (_) {}
    }
  }
}
