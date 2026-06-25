import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:reserva_canchas/services/app_backend.dart';

/// Helper para obtener lugarId / rol del usuario autenticado (perfil en Supabase).
class LugarHelper {
  static String? _cachedLugarId;
  static String? _cachedUserId;

  static Future<String?> getLugarId() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      if (_cachedUserId == user.uid && _cachedLugarId != null) {
        return _cachedLugarId;
      }

      if (!AppBackend.supabaseReady) return null;

      final row = await Supabase.instance.client
          .from('staff_profiles')
          .select('lugar_id')
          .eq('id', user.uid)
          .maybeSingle();

      if (row == null) {
        debugPrint('LugarHelper: perfil no encontrado en Supabase');
        return null;
      }

      final lugarId = row['lugar_id'] as String?;
      _cachedLugarId = lugarId;
      _cachedUserId = user.uid;
      debugPrint('LugarHelper: LugarId obtenido: $lugarId');
      return lugarId;
    } catch (e) {
      debugPrint('LugarHelper: Error obteniendo lugarId: $e');
      return null;
    }
  }

  static Future<String?> getUserRole() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      if (!AppBackend.supabaseReady) return null;

      final row = await Supabase.instance.client
          .from('staff_profiles')
          .select('rol')
          .eq('id', user.uid)
          .maybeSingle();

      if (row == null) return null;
      final rol = row['rol'] as String?;
      debugPrint('LugarHelper: Rol obtenido: $rol');
      return rol;
    } catch (e) {
      debugPrint('LugarHelper: Error obteniendo rol: $e');
      return null;
    }
  }

  static Future<bool> isProgramador() async {
    final rol = await getUserRole();
    return rol == 'programador';
  }

  static void clearCache() {
    _cachedLugarId = null;
    _cachedUserId = null;
  }
}
