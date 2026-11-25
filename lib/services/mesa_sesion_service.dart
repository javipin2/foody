import 'package:shared_preferences/shared_preferences.dart';

/// Contexto fijado al escanear QR de mesa (ciudad + sucursal + mesa).
class MesaSesion {
  const MesaSesion({
    required this.mesaId,
    required this.mesaNombre,
    required this.sucursalId,
    required this.sucursalNombre,
    this.qrToken,
    this.pedidosActivos = 0,
  });

  final String mesaId;
  final String mesaNombre;
  final String sucursalId;
  final String sucursalNombre;
  final String? qrToken;
  final int pedidosActivos;

  String get rutaMenu => '/menu/$sucursalId'
      '?nombre=${Uri.encodeComponent(sucursalNombre)}'
      '&mesa_id=$mesaId'
      '&mesa_nombre=${Uri.encodeComponent(mesaNombre)}'
      '${qrToken == null || qrToken!.isEmpty ? '' : '&qr_token=${Uri.encodeComponent(qrToken!)}'}';
}

/// Persiste la sesión de mesa QR para no pedir ciudad/sucursal de nuevo.
class MesaSesionService {
  MesaSesionService._();

  static const _mesaIdKey = 'mesa_sesion_mesa_id';
  static const _mesaNombreKey = 'mesa_sesion_mesa_nombre';
  static const _sucursalIdKey = 'mesa_sesion_sucursal_id';
  static const _sucursalNombreKey = 'mesa_sesion_sucursal_nombre';
  static const _qrTokenKey = 'mesa_sesion_qr_token';
  static const _pedidosActivosKey = 'mesa_sesion_pedidos_activos';

  static Future<void> activar({
    required String mesaId,
    required String mesaNombre,
    required String sucursalId,
    required String sucursalNombre,
    String? qrToken,
    int pedidosActivos = 0,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_mesaIdKey, mesaId);
    await prefs.setString(_mesaNombreKey, mesaNombre);
    await prefs.setString(_sucursalIdKey, sucursalId);
    await prefs.setString(_sucursalNombreKey, sucursalNombre);
    await prefs.setInt(_pedidosActivosKey, pedidosActivos);
    if (qrToken != null && qrToken.isNotEmpty) {
      await prefs.setString(_qrTokenKey, qrToken);
    } else {
      await prefs.remove(_qrTokenKey);
    }
  }

  static Future<MesaSesion?> obtener() async {
    final prefs = await SharedPreferences.getInstance();
    final mesaId = prefs.getString(_mesaIdKey);
    final mesaNombre = prefs.getString(_mesaNombreKey);
    final sucursalId = prefs.getString(_sucursalIdKey);
    final sucursalNombre = prefs.getString(_sucursalNombreKey);
    if (mesaId == null ||
        mesaNombre == null ||
        sucursalId == null ||
        sucursalNombre == null) {
      return null;
    }
    return MesaSesion(
      mesaId: mesaId,
      mesaNombre: mesaNombre,
      sucursalId: sucursalId,
      sucursalNombre: sucursalNombre,
      qrToken: prefs.getString(_qrTokenKey),
      pedidosActivos: prefs.getInt(_pedidosActivosKey) ?? 0,
    );
  }

  static Future<void> actualizarPedidosActivos(int cantidad) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_pedidosActivosKey, cantidad);
  }

  static Future<bool> tieneActiva() async {
    final s = await obtener();
    return s != null;
  }

  static Future<void> limpiar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_mesaIdKey);
    await prefs.remove(_mesaNombreKey);
    await prefs.remove(_sucursalIdKey);
    await prefs.remove(_sucursalNombreKey);
    await prefs.remove(_qrTokenKey);
    await prefs.remove(_pedidosActivosKey);
  }

  /// Rutas permitidas mientras hay mesa activa (cliente en restaurante).
  static bool rutaPermitidaConMesa(String ubicacion, MesaSesion sesion) {
    final sid = sesion.sucursalId;
    if (ubicacion.startsWith('/mesa/')) return true;
    if (ubicacion.startsWith('/menu/$sid')) return true;
    if (ubicacion.startsWith('/carrito/$sid')) return true;
    if (ubicacion.startsWith('/checkout/$sid')) return true;
    if (ubicacion.startsWith('/pedidos/')) return true;
    return false;
  }
}
