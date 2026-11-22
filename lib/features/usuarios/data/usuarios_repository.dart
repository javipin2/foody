import 'package:dio/dio.dart';
import 'package:reserva_canchas/core/modelos/respuesta_api.dart';
import 'package:reserva_canchas/core/red/cliente_dio.dart';

class CatalogoRolesResultado {
  const CatalogoRolesResultado({
    required this.roles,
    required this.permisosDisponibles,
  });

  final List<Map<String, dynamic>> roles;
  final List<String> permisosDisponibles;
}

class UsuariosRepository {
  UsuariosRepository({Dio? dio})
      : _dio = dio ?? ClienteDio.instancia(conAuthStaff: true);

  final Dio _dio;

  Future<List<Map<String, dynamic>>> listar(String sucursalId) async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/usuarios',
      queryParameters: {'sucursal_id': sucursalId},
    );
    return _parsearLista(r.data);
  }

  Future<List<Map<String, dynamic>>> listarMeserosActivos(
    String sucursalId,
  ) async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/usuarios/meseros-activos',
      queryParameters: {'sucursal_id': sucursalId},
    );
    return _parsearLista(r.data);
  }

  Future<void> crear({
    required String sucursalId,
    required String nombre,
    required String email,
    required String contrasena,
    required String rol,
    String? cocinaId,
    List<String>? permisos,
  }) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/usuarios',
      data: {
        'sucursal_id': sucursalId,
        'nombre': nombre,
        'email': email,
        'contrasena': contrasena,
        'rol': rol,
        if (cocinaId != null) 'cocina_id': cocinaId,
        if (permisos != null) 'permisos': permisos,
      },
    );
    _validar(r.data);
  }

  Future<void> cambiarEstado({
    required String usuarioId,
    required String sucursalId,
    required bool activo,
  }) async {
    final r = await _dio.patch<Map<String, dynamic>>(
      '/usuarios/$usuarioId/estado',
      queryParameters: {'sucursal_id': sucursalId},
      data: {'activo': activo},
    );
    _validar(r.data);
  }

  Future<CatalogoRolesResultado> catalogoRoles() async {
    final r = await _dio.get<Map<String, dynamic>>('/usuarios/catalogo-roles');
    if (r.data == null) throw Exception('Respuesta vacía');
    final env = RespuestaApi<Map<String, dynamic>>.fromJson(
      r.data!,
      (raw) => Map<String, dynamic>.from(raw as Map),
    );
    if (!env.exito || env.datos == null) throw Exception(env.mensaje);
    final rolesRaw = env.datos!['roles'];
    final dispRaw = env.datos!['permisos_disponibles'];
    final roles = rolesRaw is List
        ? rolesRaw
            .map((e) => Map<String, dynamic>.from(e as Map<String, dynamic>))
            .toList()
        : <Map<String, dynamic>>[];
    final disponibles = dispRaw is List
        ? dispRaw.map((e) => e.toString()).toList()
        : <String>[];
    return CatalogoRolesResultado(
      roles: roles,
      permisosDisponibles: disponibles,
    );
  }

  Future<Map<String, dynamic>> permisosUsuario({
    required String usuarioId,
    required String sucursalId,
  }) async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/usuarios/$usuarioId/permisos',
      queryParameters: {'sucursal_id': sucursalId},
    );
    if (r.data == null) throw Exception('Respuesta vacía');
    final env = RespuestaApi<Map<String, dynamic>>.fromJson(
      r.data!,
      (raw) => Map<String, dynamic>.from(raw as Map),
    );
    if (!env.exito || env.datos == null) throw Exception(env.mensaje);
    return env.datos!;
  }

  Future<Map<String, dynamic>> actualizar({
    required String usuarioId,
    required String sucursalId,
    String? nombre,
    String? rol,
    String? sucursalDestinoId,
    String? cocinaId,
    List<String>? permisos,
  }) async {
    final data = <String, dynamic>{};
    if (nombre != null) data['nombre'] = nombre;
    if (rol != null) data['rol'] = rol;
    if (sucursalDestinoId != null) data['sucursal_id'] = sucursalDestinoId;
    if (cocinaId != null) data['cocina_id'] = cocinaId;
    if (permisos != null) data['permisos'] = permisos;
    final r = await _dio.patch<Map<String, dynamic>>(
      '/usuarios/$usuarioId',
      queryParameters: {'sucursal_id': sucursalId},
      data: data,
    );
    if (r.data == null) throw Exception('Respuesta vacía');
    final env = RespuestaApi<Map<String, dynamic>>.fromJson(
      r.data!,
      (raw) => Map<String, dynamic>.from(raw as Map),
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
