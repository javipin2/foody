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
}
