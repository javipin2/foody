import 'package:dio/dio.dart';
import 'package:reserva_canchas/core/modelos/respuesta_api.dart';
import 'package:reserva_canchas/core/red/cliente_dio.dart';

class SuperAdminRepository {
  SuperAdminRepository({Dio? dio})
      : _dio = dio ?? ClienteDio.instancia(conAuthStaff: true);

  final Dio _dio;

  Future<Map<String, dynamic>> resumen() async {
    final r = await _dio.get<Map<String, dynamic>>('/super/estadisticas');
    return _parsearMapa(r.data);
  }

  Future<List<Map<String, dynamic>>> ciudades() async {
    final r = await _dio.get<Map<String, dynamic>>('/super/ciudades');
    return _parsearLista(r.data);
  }

  Future<List<Map<String, dynamic>>> restaurantes() async {
    final r = await _dio.get<Map<String, dynamic>>('/super/restaurantes');
    return _parsearLista(r.data);
  }

  Future<Map<String, dynamic>> crearRestaurante({
    required String ciudadId,
    required String nombreRestaurante,
    required String nombreSucursal,
    required String adminNombre,
    required String adminEmail,
    required String adminContrasena,
    String? direccionSucursal,
  }) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/super/restaurantes',
      data: {
        'ciudad_id': ciudadId,
        'nombre_restaurante': nombreRestaurante,
        'nombre_sucursal': nombreSucursal,
        'admin_nombre': adminNombre,
        'admin_email': adminEmail,
        'admin_contrasena': adminContrasena,
        if (direccionSucursal != null && direccionSucursal.isNotEmpty)
          'direccion_sucursal': direccionSucursal,
      },
      options: Options(
        receiveTimeout: const Duration(seconds: 90),
        sendTimeout: const Duration(seconds: 30),
      ),
    );
    return _parsearMapa(r.data);
  }

  Future<List<Map<String, dynamic>>> sucursalesRestaurante(
    String restauranteId,
  ) async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/super/restaurantes/$restauranteId/sucursales',
    );
    return _parsearLista(r.data);
  }

  Future<List<Map<String, dynamic>>> usuarios() async {
    final r = await _dio.get<Map<String, dynamic>>('/super/usuarios');
    return _parsearLista(r.data);
  }

  Future<void> crearUsuario({
    required String nombre,
    required String email,
    required String contrasena,
    required String rol,
    required String sucursalId,
  }) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/super/usuarios',
      data: {
        'nombre': nombre,
        'email': email,
        'contrasena': contrasena,
        'rol': rol,
        'sucursal_id': sucursalId,
      },
      options: Options(receiveTimeout: const Duration(seconds: 60)),
    );
    _validar(r.data);
  }

  Future<void> actualizarUsuario(
    String id, {
    String? nombre,
    String? email,
    String? rol,
  }) async {
    final r = await _dio.patch<Map<String, dynamic>>(
      '/super/usuarios/$id',
      data: {
        if (nombre != null) 'nombre': nombre,
        if (email != null) 'email': email,
        if (rol != null) 'rol': rol,
      },
    );
    _validar(r.data);
  }

  Future<void> cambiarEstadoUsuario(String id, bool activo) async {
    final r = await _dio.patch<Map<String, dynamic>>(
      '/super/usuarios/$id/estado',
      data: {'activo': activo},
    );
    _validar(r.data);
  }

  Future<void> cambiarContrasenaUsuario(String id, String contrasena) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/super/usuarios/$id/cambiar-contrasena',
      data: {'contrasena': contrasena},
    );
    _validar(r.data);
  }

  Future<List<Map<String, dynamic>>> suscripciones() async {
    final r = await _dio.get<Map<String, dynamic>>('/super/suscripciones');
    return _parsearLista(r.data);
  }

  Future<void> actualizarSuscripcion(
    String id, {
    String? estado,
    String? plan,
    String? fechaVencimientoIso,
  }) async {
    final r = await _dio.patch<Map<String, dynamic>>(
      '/super/suscripciones/$id',
      data: {
        if (estado != null) 'estado': estado,
        if (plan != null) 'plan': plan,
        if (fechaVencimientoIso != null) 'fecha_vencimiento': fechaVencimientoIso,
      },
    );
    _validar(r.data);
  }

  /// Tras un error de red, verifica si el restaurante se creó igual.
  Future<bool> existeRestaurantePorNombre(String nombre) async {
    final lista = await restaurantes();
    final q = nombre.trim().toLowerCase();
    return lista.any(
      (r) => (r['nombre'] as String? ?? '').trim().toLowerCase() == q,
    );
  }

  Future<List<Map<String, dynamic>>> domiciliarios() async {
    final r = await _dio.get<Map<String, dynamic>>('/super/domiciliarios');
    return _parsearLista(r.data);
  }

  Future<List<Map<String, dynamic>>> documentosPendientes() async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/super/domiciliarios/documentos-pendientes',
    );
    return _parsearLista(r.data);
  }

  Future<void> aprobarDocumento(String domiciliarioId, String documentoId) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/super/domiciliarios/$domiciliarioId/aprobar-documento',
      data: {'documento_id': documentoId},
    );
    _validar(r.data);
  }

  Future<void> rechazarDocumento(
    String domiciliarioId,
    String documentoId,
    String motivo,
  ) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/super/domiciliarios/$domiciliarioId/rechazar-documento',
      data: {'documento_id': documentoId, 'motivo': motivo},
    );
    _validar(r.data);
  }

  Future<void> domiciliarioEstado(String id, String estadoCuenta) async {
    final r = await _dio.patch<Map<String, dynamic>>(
      '/super/domiciliarios/$id/estado',
      data: {'estado_cuenta': estadoCuenta},
    );
    _validar(r.data);
  }

  Future<void> crearCiudad({required String nombre, String? slug}) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/super/ciudades',
      data: {
        'nombre': nombre,
        if (slug != null && slug.isNotEmpty) 'slug': slug,
      },
    );
    _validar(r.data);
  }

  Future<void> actualizarCiudad(
    String id, {
    String? nombre,
    bool? activa,
  }) async {
    final r = await _dio.patch<Map<String, dynamic>>(
      '/super/ciudades/$id',
      data: {
        if (nombre != null) 'nombre': nombre,
        if (activa != null) 'activa': activa,
      },
    );
    _validar(r.data);
  }

  Future<void> actualizarRestaurante(
    String id, {
    bool? activo,
    String? motivoBloqueo,
  }) async {
    final r = await _dio.patch<Map<String, dynamic>>(
      '/super/restaurantes/$id',
      data: {
        if (activo != null) 'activo': activo,
        if (motivoBloqueo != null) 'motivo_bloqueo': motivoBloqueo,
      },
    );
    _validar(r.data);
  }

  Future<List<Map<String, dynamic>>> configuracion() async {
    final r = await _dio.get<Map<String, dynamic>>('/super/configuracion');
    return _parsearLista(r.data);
  }

  Future<void> actualizarConfiguracion(String clave, String valor) async {
    final r = await _dio.patch<Map<String, dynamic>>(
      '/super/configuracion/$clave',
      data: {'valor': valor},
    );
    _validar(r.data);
  }

  Future<Map<String, dynamic>> _parsearMapa(Map<String, dynamic>? data) async {
    if (data == null) throw Exception('Respuesta vacía');
    final env = RespuestaApi<Map<String, dynamic>>.fromJson(
      data,
      (raw) => Map<String, dynamic>.from(raw as Map<String, dynamic>),
    );
    if (!env.exito || env.datos == null) throw Exception(env.mensaje);
    return env.datos!;
  }

  List<Map<String, dynamic>> _parsearLista(Map<String, dynamic>? data) {
    if (data == null) throw Exception('Respuesta vacía');
    final env = RespuestaApi<List<dynamic>>.fromJson(
      data,
      (raw) => raw as List<dynamic>,
    );
    if (!env.exito || env.datos == null) throw Exception(env.mensaje);
    return env.datos!
        .map((e) => Map<String, dynamic>.from(e as Map<String, dynamic>))
        .toList();
  }

  void _validar(Map<String, dynamic>? data) {
    if (data == null) throw Exception('Respuesta vacía');
    final env = RespuestaApi<void>.fromJson(data, (_) {});
    if (!env.exito) throw Exception(env.mensaje);
  }
}
