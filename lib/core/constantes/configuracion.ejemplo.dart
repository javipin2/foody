import 'package:flutter/foundation.dart';

/// Copiar a `configuracion.dart` o generar con scripts:
/// - Wi‑Fi local: `scripts/sincronizar-ip-movil.ps1`
/// - Fuera de casa: `scripts/sincronizar-url-tunel.ps1` (Cloudflare Tunnel)
class Configuracion {
  /// false = misma Wi‑Fi (ipLan). true = HTTPS público (túnel).
  static const bool usarTunel = false;

  static const String ipLan = '192.168.1.100';

  static const String hostApp = 'https://foody.tu-dominio.com';
  static const String hostApi = 'https://api.foody.tu-dominio.com';
  static const String hostSupabase = 'https://sb.foody.tu-dominio.com';

  static String get urlBackend => usarTunel
      ? '$hostApi/api/v1'
      : (kIsWeb ? 'http://localhost:3000/api/v1' : 'http://$ipLan:3000/api/v1');

  static String get urlSupabase => usarTunel
      ? hostSupabase
      : (kIsWeb ? 'http://localhost:8000' : 'http://$ipLan:8000');

  static const String supabaseAnonKey = 'PEGAR_ANON_KEY';

  static const Duration timeoutConexion = Duration(seconds: 10);
  static const Duration timeoutRespuesta = Duration(seconds: 30);
  static const Duration timeoutEnvio = Duration(seconds: 15);
}
