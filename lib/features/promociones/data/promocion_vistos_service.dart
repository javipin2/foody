import 'package:shared_preferences/shared_preferences.dart';

/// Estados ya vistos en este dispositivo (anillo gris estilo WhatsApp).
/// ponytail: local only; el backend ya cuenta vistas vía POST /vista.
class PromocionVistosService {
  PromocionVistosService._();

  static const _clave = 'foody_estados_vistos_ids';

  static Future<Set<String>> idsVistos() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_clave) ?? const []).toSet();
  }

  static Future<bool> fueVisto(String promocionId) async {
    final set = await idsVistos();
    return set.contains(promocionId);
  }

  static Future<void> marcarVisto(String promocionId) async {
    if (promocionId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final lista = prefs.getStringList(_clave) ?? <String>[];
    if (lista.contains(promocionId)) return;
    lista.add(promocionId);
    // Cap suave: no crecer sin límite
    if (lista.length > 400) {
      lista.removeRange(0, lista.length - 400);
    }
    await prefs.setStringList(_clave, lista);
  }
}
