import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:reserva_canchas/config/app_link_config.dart';
import 'package:reserva_canchas/core/rutas/app_router.dart';

/// Captura `foody://plan?pago_id=…` al volver de Wompi (bridge HTTPS → scheme).
class PagosDeepLinkService {
  PagosDeepLinkService._();

  static StreamSubscription<Uri>? _sub;
  static String? _pagoIdPendiente;

  static bool esUriRetornoPago(Uri uri) =>
      uri.scheme == AppLinkConfig.oauthScheme &&
      uri.host == AppLinkConfig.pagosHostPlan;

  static String? pagoIdDeUri(Uri uri) {
    final id = uri.queryParameters['pago_id']?.trim();
    return (id != null && id.isNotEmpty) ? id : null;
  }

  /// Si el usuario aún no tenía sesión al abrir el link.
  static String? consumirPagoIdPendiente() {
    final id = _pagoIdPendiente;
    _pagoIdPendiente = null;
    return id;
  }

  static void _manejar(Uri uri) {
    if (!esUriRetornoPago(uri)) return;
    final pagoId = pagoIdDeUri(uri);
    _pagoIdPendiente = pagoId;
    final ruta = AppLinkConfig.rutaPanelTrasPago(pagoId: pagoId);
    debugPrint('PagosDeepLinkService → $ruta');
    try {
      AppRouter.router.go(ruta);
    } catch (e) {
      debugPrint('PagosDeepLinkService go: $e');
    }
  }

  static Future<void> initialize() async {
    if (kIsWeb) return;
    try {
      final appLinks = AppLinks();
      final initial = await appLinks.getInitialLink();
      if (initial != null && esUriRetornoPago(initial)) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _manejar(initial));
      }
      await _sub?.cancel();
      _sub = appLinks.uriLinkStream.listen(
        _manejar,
        onError: (Object e) => debugPrint('PagosDeepLinkService: $e'),
      );
    } catch (e) {
      debugPrint('PagosDeepLinkService initialize: $e');
    }
  }

  static Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }
}
