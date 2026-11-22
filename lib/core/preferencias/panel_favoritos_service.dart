import 'package:shared_preferences/shared_preferences.dart';

/// Hasta 3 módulos pinneados en el sidebar admin (AR-29).
class PanelFavoritosService {
  PanelFavoritosService._();

  static const _key = 'panel_admin_favoritos';
  static const maxFavoritos = 3;

  static Future<List<String>> listar() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? [];
  }

  static Future<void> guardar(List<String> rutas) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, rutas.take(maxFavoritos).toList());
  }

  static Future<bool> alternar(String ruta) async {
    final actuales = await listar();
    if (actuales.contains(ruta)) {
      actuales.remove(ruta);
      await guardar(actuales);
      return false;
    }
    if (actuales.length >= maxFavoritos) {
      actuales.removeAt(0);
    }
    actuales.add(ruta);
    await guardar(actuales);
    return true;
  }
}
