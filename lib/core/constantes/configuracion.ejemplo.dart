import 'package:flutter/foundation.dart';

/// Copiar a `configuracion.dart` y ajustar IP (o ejecutar scripts/sincronizar-ip-movil.ps1).
class Configuracion {
  /// IP Wi-Fi del PC (ipconfig en Windows). NO usar IP WSL ni localhost en APK.
  static const String ipLan = '192.168.1.100';

  static String get urlBackend => kIsWeb
      ? 'http://localhost:3000/api/v1'
      : 'http://$ipLan:3000/api/v1';

  static String get urlSupabase => kIsWeb
      ? 'http://localhost:8000'
      : 'http://$ipLan:8000';

  static const String supabaseAnonKey = 'PEGAR_ANON_KEY';

  static const Duration timeoutConexion = Duration(seconds: 10);
  static const Duration timeoutRespuesta = Duration(seconds: 30);
}
