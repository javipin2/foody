import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:reserva_canchas/config/app_link_config.dart';
import 'package:reserva_canchas/services/app_backend.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Captura `foody://login?code=...` al volver de Google en el APK.
class GoogleOAuthDeepLinkService {
  GoogleOAuthDeepLinkService._();

  static StreamSubscription<Uri>? _sub;
  static Uri? _uriPendiente;
  static final StreamController<void> _retorno =
      StreamController<void>.broadcast();

  /// El login staff escucha esto para procesar OAuth al volver de Google.
  static Stream<void> get onRetorno => _retorno.stream;

  static bool esUriOAuthStaff(Uri uri) =>
      uri.scheme == AppLinkConfig.oauthScheme &&
      uri.host == AppLinkConfig.oauthHostLogin;

  static void _marcarRetorno(Uri uri) {
    _uriPendiente = uri;
    if (!_retorno.isClosed) _retorno.add(null);
  }

  static Future<void> initialize() async {
    if (kIsWeb || !AppBackend.supabaseReady) return;

    try {
      final appLinks = AppLinks();
      final initial = await appLinks.getInitialLink();
      if (initial != null && esUriOAuthStaff(initial)) {
        _marcarRetorno(initial);
      }

      await _sub?.cancel();
      _sub = appLinks.uriLinkStream.listen(
        (uri) {
          if (!esUriOAuthStaff(uri)) return;
          _marcarRetorno(uri);
        },
        onError: (Object e) {
          debugPrint('GoogleOAuthDeepLinkService: $e');
        },
      );
    } catch (e) {
      debugPrint('GoogleOAuthDeepLinkService initialize: $e');
    }
  }

  static Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }

  /// Intercambia ?code= de Supabase (móvil; en web usa detectSessionInUri).
  static Future<void> intercambiarSesionPendiente() async {
    if (kIsWeb || !AppBackend.supabaseReady) return;

    final uri = _uriPendiente;
    if (uri == null) return;
    _uriPendiente = null;

    final params = uri.queryParameters;
    if (params.containsKey('error') || params.containsKey('error_description')) {
      throw AuthException(
        params['error_description'] ?? params['error'] ?? 'Error de Google',
      );
    }

    final auth = Supabase.instance.client.auth;
    if (auth.currentSession != null) return;

    if (!params.containsKey('code') &&
        !uri.fragment.contains('access_token')) {
      return;
    }

    try {
      await auth.getSessionFromUrl(uri);
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException(
        'No se pudo completar Google en la app. Revisa foody://login en Supabase.',
      );
    }
  }
}
