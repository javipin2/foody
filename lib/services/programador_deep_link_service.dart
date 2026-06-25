import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_link_config.dart';

/// Enlaces que abren [ProgramadorLoginScreen] sin exponer la pantalla en la UI.
class ProgramadorDeepLinkService {
  ProgramadorDeepLinkService._();

  static const _prefsKey = 'pending_programador_deep_link_v1';

  static bool uriOpensProgramadorLogin(Uri uri) {
    final target = AppLinkConfig.programadorPathSegment.toLowerCase();

    final pathSegs =
        uri.pathSegments.map((e) => e.toLowerCase()).toList(growable: false);
    if (pathSegs.contains(target)) return true;

    if (uri.scheme.toLowerCase() == AppLinkConfig.customScheme &&
        uri.host.toLowerCase() == target) {
      return true;
    }

    final frag = uri.fragment;
    if (frag.isEmpty) return false;
    final head = frag.split('?').first;
    final fragSegs = head
        .split('/')
        .where((s) => s.isNotEmpty)
        .map((s) => s.toLowerCase());
    if (fragSegs.contains(target)) return true;

    return false;
  }

  static Future<void> captureFromUri(Uri uri) async {
    if (!uriOpensProgramadorLogin(uri)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, true);
  }

  /// Lee y borra el flag. Devuelve true si debe abrirse el login del programador.
  static Future<bool> consumePendingOpensProgramador() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getBool(_prefsKey) ?? false;
    if (v) await prefs.remove(_prefsKey);
    return v;
  }
}
