import 'package:shared_preferences/shared_preferences.dart';
import 'package:reserva_canchas/services/app_backend.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Perfil local del comensal tras Google (no JWT staff).
class SesionClientePerfil {
  const SesionClientePerfil({
    required this.authUid,
    this.email,
    this.nombre,
  });

  final String authUid;
  final String? email;
  final String? nombre;
}

class SesionClienteService {
  SesionClienteService._();

  static const _kUid = 'foody_cliente_auth_uid';
  static const _kEmail = 'foody_cliente_email';
  static const _kNombre = 'foody_cliente_nombre';

  static Future<SesionClientePerfil?> obtener() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString(_kUid);
    if (uid == null || uid.isEmpty) return null;
    return SesionClientePerfil(
      authUid: uid,
      email: prefs.getString(_kEmail),
      nombre: prefs.getString(_kNombre),
    );
  }

  static Future<bool> haySesion() async => (await obtener()) != null;

  static Future<String?> accessTokenSupabase() async {
    if (!AppBackend.supabaseReady) return null;
    return Supabase.instance.client.auth.currentSession?.accessToken;
  }

  static Future<void> guardarDesdeVinculo(Map<String, dynamic> datos) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = '${datos['auth_uid'] ?? ''}';
    if (uid.isEmpty) return;
    await prefs.setString(_kUid, uid);
    final email = datos['email'] as String?;
    final nombre = datos['nombre'] as String?;
    if (email != null && email.isNotEmpty) {
      await prefs.setString(_kEmail, email);
    }
    if (nombre != null && nombre.isNotEmpty) {
      await prefs.setString(_kNombre, nombre);
    }
  }

  static Future<void> cerrar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUid);
    await prefs.remove(_kEmail);
    await prefs.remove(_kNombre);
  }
}
