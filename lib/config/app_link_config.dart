class AppLinkConfig {
  const AppLinkConfig._();

  // Dominio web/canónico de la app para compartir lugares.
  static const String shareHost = 'proyecto-20bae.web.app';
  static const String shareScheme = 'https';
  static const String sharePath = '/';

  // Scheme personalizado para enlaces nativos.
  static const String customScheme = 'tucanchafacil';
  static const String customHost = 'lugar';

  /// Ruta/host para abrir **solo** el login del programador (no hay botón en la app).
  ///
  /// Ejemplos (sincronizar dominio con [shareHost]):
  /// - `https://proyecto-20bae.web.app/programador`
  /// - `https://proyecto-20bae.web.app/#/programador`
  /// - `tucanchafacil://programador`
  static const String programadorPathSegment = 'programador';

  /// OAuth Google staff (Equipo). Sincronizar:
  /// - `android/app/src/main/AndroidManifest.xml` (scheme + host)
  /// - `ios/Runner/Info.plist` (CFBundleURLSchemes)
  /// - Supabase `ADDITIONAL_REDIRECT_URLS` (`scripts/configurar-google-oauth-supabase.sh`)
  static const String oauthScheme = 'foody';
  static const String oauthHostLogin = 'login';

  /// Retorno tras Wompi (bridge Nest → app). Sincronizar AndroidManifest host `plan`.
  static const String pagosHostPlan = 'plan';

  static String get oauthRedirectUri => '$oauthScheme://$oauthHostLogin';

  static String uriRetornoPago({String? pagoId}) {
    final base = '$oauthScheme://$pagosHostPlan';
    if (pagoId == null || pagoId.isEmpty) return base;
    return '$base?pago_id=${Uri.encodeComponent(pagoId)}';
  }

  static String rutaPanelTrasPago({String? pagoId}) {
    final q = <String, String>{'seccion': 'mejorar_plan'};
    if (pagoId != null && pagoId.isNotEmpty) q['pago_id'] = pagoId;
    return Uri(path: '/admin/panel', queryParameters: q).toString();
  }
}
