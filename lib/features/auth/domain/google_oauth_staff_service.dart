import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:reserva_canchas/config/app_link_config.dart';
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

  static Future<void> iniciarOAuth(OAuthDestinoStaff destino) async {
    if (!AppBackend.supabaseReady) {
      throw StateError('Supabase no está configurado');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsDestino, destino.name);

    await Supabase.instance.client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: uriRedireccion(destino),
      authScreenLaunchMode: LaunchMode.externalApplication,
    );
  }

  static Future<OAuthDestinoStaff> _consumirDestino() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsDestino);
    await prefs.remove(_prefsDestino);
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

    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return false;

    await _consumirDestino();

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
      return true;
    }

    if (r.sesion != null) {
      irDashboardStaff(context, r.sesion!.dashboard);
      return true;
    }
    return false;
  }

  /// En registro: hidrata el formulario o envía al panel si la cuenta ya existe.
  static Future<DatosGoogleRegistro?> procesarRetornoEnRegistro(
    BuildContext context,
    AuthRepository repo, {
    required bool yaTieneToken,
  }) async {
    if (yaTieneToken || !AppBackend.supabaseReady) return null;

    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return null;

    await _consumirDestino();

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
    }
    return null;
  }
}
