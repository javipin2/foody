import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:reserva_canchas/core/config/app_flavor.dart';
import 'package:reserva_canchas/core/modelos/respuesta_api.dart';
import 'package:reserva_canchas/core/red/cliente_dio.dart';
import 'package:reserva_canchas/core/notificaciones/servicio_fcm_foody.dart';
import 'package:reserva_canchas/core/sesion/sesion_staff_service.dart';
import 'package:reserva_canchas/features/auth/domain/login_resultado.dart';
import 'package:reserva_canchas/services/app_backend.dart';

class AuthRepository {
  AuthRepository({Dio? dio}) : _dio = dio ?? ClienteDio.instancia();

  final Dio _dio;

  Future<LoginResultado> login({
    required String email,
    required String contrasena,
  }) async {
    final respuesta = await _dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'email': email, 'contrasena': contrasena},
    );
    final data = respuesta.data;
    if (data == null) throw Exception('Respuesta vacía');

    final envoltura = RespuestaApi<Map<String, dynamic>>.fromJson(
      data,
      (raw) => Map<String, dynamic>.from(raw as Map<String, dynamic>),
    );
    if (!envoltura.exito || envoltura.datos == null) {
      throw Exception(envoltura.mensaje);
    }

    return _guardarSesionDesdeMap(envoltura.datos!);
  }

  Future<LoginResultado> registroRestaurante({
    required String ciudadId,
    required String nombreRestaurante,
    required String adminNombre,
    required String adminEmail,
    String? contrasena,
    String? nombreSucursal,
    String? direccionSucursal,
    String? supabaseAccessToken,
    String proveedorAuth = 'correo',
  }) async {
    final respuesta = await _dio.post<Map<String, dynamic>>(
      '/auth/registro-restaurante',
      data: {
        'ciudad_id': ciudadId,
        'nombre_restaurante': nombreRestaurante,
        'admin_nombre': adminNombre,
        'admin_email': adminEmail,
        if (contrasena != null) 'contrasena': contrasena,
        if (nombreSucursal != null) 'nombre_sucursal': nombreSucursal,
        if (direccionSucursal != null) 'direccion_sucursal': direccionSucursal,
        if (supabaseAccessToken != null)
          'supabase_access_token': supabaseAccessToken,
        'proveedor_auth': proveedorAuth,
      },
    );
    return _guardarSesionDesdeRespuesta(respuesta.data);
  }

  /// Login con token de Supabase (Google OAuth). Si no hay cuenta, devuelve [necesitaRegistro].
  Future<({
    bool necesitaRegistro,
    LoginResultado? sesion,
    String? email,
    String? nombre,
    String? accessToken,
  })> loginGoogle({required String accessToken}) async {
    final respuesta = await _dio.post<Map<String, dynamic>>(
      '/auth/login-google',
      data: {'access_token': accessToken},
    );
    final data = respuesta.data;
    if (data == null) throw Exception('Respuesta vacía');

    final envoltura = RespuestaApi<Map<String, dynamic>>.fromJson(
      data,
      (raw) => Map<String, dynamic>.from(raw as Map<String, dynamic>),
    );
    if (!envoltura.exito || envoltura.datos == null) {
      throw Exception(envoltura.mensaje);
    }

    final d = envoltura.datos!;
    if (d['necesita_registro'] == true) {
      return (
        necesitaRegistro: true,
        sesion: null,
        email: d['email'] as String?,
        nombre: d['nombre'] as String?,
        accessToken: accessToken,
      );
    }

    final sesion = await _guardarSesionDesdeMap(d);
    return (
      necesitaRegistro: false,
      sesion: sesion,
      email: null,
      nombre: null,
      accessToken: null,
    );
  }

  Future<LoginResultado> _guardarSesionDesdeRespuesta(
    Map<String, dynamic>? data,
  ) async {
    if (data == null) throw Exception('Respuesta vacía');

    final envoltura = RespuestaApi<Map<String, dynamic>>.fromJson(
      data,
      (raw) => Map<String, dynamic>.from(raw as Map<String, dynamic>),
    );
    if (!envoltura.exito || envoltura.datos == null) {
      throw Exception(envoltura.mensaje);
    }
    return _guardarSesionDesdeMap(envoltura.datos!);
  }

  Future<LoginResultado> _guardarSesionDesdeMap(Map<String, dynamic> d) async {
    final token = d['token'] as String;
    final dashboard = d['dashboard'] as String? ?? 'restaurante';
    final rol = d['rol'] as String? ?? '';
    final permisos = (d['permisos'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();
    final plan = d['plan'] as String? ?? 'basico';
    final modulos = (d['modulos'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();
    final usuario = Map<String, dynamic>.from(
      d['usuario'] as Map<String, dynamic>? ?? {},
    );

    await SesionStaffService.guardar(
      token: token,
      dashboard: dashboard,
      rol: rol,
      permisos: permisos,
      usuario: usuario,
      plan: plan,
      modulos: modulos,
    );

    await ServicioFcmFoody.instancia.registrarTrasLoginStaff();

    return LoginResultado(
      dashboard: dashboard,
      rol: rol,
      permisos: permisos,
      usuario: usuario,
      plan: plan,
      modulos: modulos,
    );
  }

  /// Sincroniza permisos del JWT con la BD (tras migraciones o cambios de rol).
  Future<List<String>> sincronizarPermisos() async {
    final dio = ClienteDio.instancia(conAuthStaff: true);
    final respuesta = await dio.get<Map<String, dynamic>>('/auth/perfil');
    final data = respuesta.data;
    if (data == null) throw Exception('Respuesta vacía');

    final envoltura = RespuestaApi<Map<String, dynamic>>.fromJson(
      data,
      (raw) => Map<String, dynamic>.from(raw as Map<String, dynamic>),
    );
    if (!envoltura.exito || envoltura.datos == null) {
      throw Exception(envoltura.mensaje);
    }

    final permisos = (envoltura.datos!['permisos'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();
    await _aplicarPerfilDesdeMap(envoltura.datos!);
    return permisos;
  }

  Future<({
    List<String> permisos,
    String plan,
    List<String> modulos,
    Map<String, dynamic>? suscripcion,
  })> sincronizarPerfil() async {
    final dio = ClienteDio.instancia(conAuthStaff: true);
    final respuesta = await dio.get<Map<String, dynamic>>('/auth/perfil');
    final data = respuesta.data;
    if (data == null) throw Exception('Respuesta vacía');

    final envoltura = RespuestaApi<Map<String, dynamic>>.fromJson(
      data,
      (raw) => Map<String, dynamic>.from(raw as Map<String, dynamic>),
    );
    if (!envoltura.exito || envoltura.datos == null) {
      throw Exception(envoltura.mensaje);
    }

    final permisos = (envoltura.datos!['permisos'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();
    final plan = envoltura.datos!['plan'] as String? ?? 'basico';
    final modulos = (envoltura.datos!['modulos'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();
    final suscripcionRaw = envoltura.datos!['suscripcion'];
    final suscripcion = suscripcionRaw is Map<String, dynamic>
        ? suscripcionRaw
        : suscripcionRaw is Map
            ? Map<String, dynamic>.from(suscripcionRaw)
            : null;
    await _aplicarPerfilDesdeMap(envoltura.datos!);
    return (
      permisos: permisos,
      plan: plan,
      modulos: modulos,
      suscripcion: suscripcion,
    );
  }

  Future<void> _aplicarPerfilDesdeMap(Map<String, dynamic> datos) async {
    final permisos = (datos['permisos'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();
    final plan = datos['plan'] as String? ?? 'basico';
    final modulos = (datos['modulos'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();
    final tokenNuevo = datos['token'] as String?;
    if (tokenNuevo != null && tokenNuevo.isNotEmpty) {
      await SesionStaffService.actualizarToken(tokenNuevo);
    }
    await SesionStaffService.actualizarPerfilStaff(
      permisos: permisos,
      plan: plan,
      modulos: modulos,
    );
  }

  Future<void> logout() async {
    if (AppFlavor.actual.esEquipo && AppBackend.firebaseReady) {
      try {
        final token = await FirebaseMessaging.instance.getToken();
        final dio = ClienteDio.instancia(conAuthStaff: true);
        await dio.post<Map<String, dynamic>>(
          '/auth/desactivar-fcm',
          data: {if (token != null) 'fcm_token': token},
        );
      } catch (_) {}
    }
    await SesionStaffService.cerrar();
  }
}
