import 'package:reserva_canchas/core/constantes/configuracion.dart';

/// Supabase self-hosted (Auth, Storage, Realtime). Misma fuente que NestJS en [Configuracion].
String get kSupabaseUrl => Configuracion.urlSupabase;

String get kSupabaseAnonKey => Configuracion.supabaseAnonKey;

bool get isSupabaseConfigured =>
    kSupabaseUrl.trim().isNotEmpty && kSupabaseAnonKey.trim().isNotEmpty;
