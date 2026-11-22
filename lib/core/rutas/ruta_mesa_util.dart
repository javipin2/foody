/// Normaliza deep links QR de mesa (`/mesa/{token}/cliente`, etc.).
class RutaMesaUtil {
  RutaMesaUtil._();

  static final _prefijoMesa = RegExp(r'^/mesa/([^/]+)');

  static bool esEntradaMesa(String path) => _prefijoMesa.hasMatch(path);

  static String? tokenDesdePath(String path) {
    return _prefijoMesa.firstMatch(path)?.group(1);
  }

  /// Devuelve `/mesa/{token}` limpio o null si no es ruta de mesa.
  static String? normalizar(String path) {
    final token = tokenDesdePath(path);
    if (token == null || token.isEmpty) return null;
    return '/mesa/$token';
  }

  /// Ruta inicial en web cuando el navegador abre un QR.
  static String? entradaDesdeNavegador() {
    final path = Uri.base.path;
    return normalizar(path);
  }

  /// Extrae el token de mesa desde texto escaneado (URL, path o token crudo).
  static String? tokenDesdeTextoQr(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.hasScheme) {
      final desdePath = tokenDesdePath(uri.path);
      if (desdePath != null) return desdePath;
      final qp = uri.queryParameters['qr'] ?? uri.queryParameters['token'];
      if (qp != null && qp.isNotEmpty) return qp;
    }

    final path = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    final desdePath = tokenDesdePath(path);
    if (desdePath != null) return desdePath;

    if (RegExp(r'^[a-zA-Z0-9_-]{8,128}$').hasMatch(trimmed)) {
      return trimmed;
    }
    return null;
  }
}
