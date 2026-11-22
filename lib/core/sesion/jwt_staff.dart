import 'dart:convert';

/// Lectura local del claim `exp` de un JWT staff (sin verificar firma).
/// Si la firma cambia en el servidor (JWT_SECRET), el API responde 401 y
/// [ManejoErrorSesion] manda a login.
class JwtStaff {
  JwtStaff._();

  /// `true` si el token está mal formado o ya venció (margen por defecto 30s).
  static bool expirado(
    String token, {
    Duration margen = const Duration(seconds: 30),
  }) {
    final exp = leerExpiracion(token);
    if (exp == null) return true;
    return DateTime.now().toUtc().isAfter(exp.subtract(margen));
  }

  /// `true` si falta menos de [ventana] para el `exp` (renovar con `/auth/refresh`).
  static bool porExpirar(
    String token, {
    Duration ventana = const Duration(minutes: 30),
  }) {
    final exp = leerExpiracion(token);
    if (exp == null) return true;
    final ahora = DateTime.now().toUtc();
    if (!ahora.isBefore(exp)) return true;
    return exp.difference(ahora) <= ventana;
  }

  /// Fecha UTC de `exp`, o `null` si el JWT no es legible.
  static DateTime? leerExpiracion(String token) {
    final partes = token.split('.');
    if (partes.length < 2) return null;
    try {
      final normalized = base64Url.normalize(partes[1]);
      final payload =
          jsonDecode(utf8.decode(base64Url.decode(normalized)))
              as Map<String, dynamic>;
      final exp = payload['exp'];
      if (exp is! num) return null;
      return DateTime.fromMillisecondsSinceEpoch(
        (exp * 1000).round(),
        isUtc: true,
      );
    } catch (_) {
      return null;
    }
  }
}
