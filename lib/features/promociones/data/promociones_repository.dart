import 'package:dio/dio.dart';
import 'package:reserva_canchas/core/dispositivo/dispositivo_service.dart';
import 'package:reserva_canchas/core/modelos/respuesta_api.dart';
import 'package:reserva_canchas/core/red/cliente_dio.dart';

class PromocionesRepository {
  PromocionesRepository({Dio? dioPublico, Dio? dioStaff})
      : _publico = dioPublico ?? ClienteDio.instancia(),
        _staff = dioStaff ?? ClienteDio.instancia(conAuthStaff: true);

  final Dio _publico;
  final Dio _staff;

  Future<List<Map<String, dynamic>>> listarActivas(String sucursalId) async {
    final respuesta = await _publico.get<Map<String, dynamic>>(
      '/promociones',
      queryParameters: {'sucursal_id': sucursalId},
    );
    return _parsearLista(respuesta.data);
  }

  /// Grupos WhatsApp: un restaurante = un anillo, N estados dentro.
  Future<List<Map<String, dynamic>>> listarGruposStoriesCiudad(
    String slugCiudad,
  ) async {
    final respuesta = await _publico.get<Map<String, dynamic>>(
      '/promociones/ciudad/$slugCiudad/stories',
    );
    return _parsearLista(respuesta.data);
  }

  @Deprecated('Usar listarGruposStoriesCiudad')
  Future<List<Map<String, dynamic>>> listarStoriesCiudad(String slugCiudad) async {
    final grupos = await listarGruposStoriesCiudad(slugCiudad);
    final resultado = <Map<String, dynamic>>[];
    for (final grupo in grupos) {
      resultado.addAll(_promosDeGrupo(grupo));
    }
    return resultado;
  }

  /// Aplana un grupo API → lista de promos con campos del restaurante.
  static List<Map<String, dynamic>> promosDeGrupo(Map<String, dynamic> grupo) {
    return _promosDeGrupo(grupo);
  }

  static List<Map<String, dynamic>> _promosDeGrupo(Map<String, dynamic> grupo) {
    final raw = grupo['promociones'];
    if (raw is! List) return const [];
    final resultado = <Map<String, dynamic>>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final promo = Map<String, dynamic>.from(item);
      promo['restaurante_nombre'] = grupo['restaurante_nombre'];
      promo['restaurante_id'] = grupo['restaurante_id'];
      promo['logo_url'] = grupo['logo_url'];
      resultado.add(promo);
    }
    return resultado;
  }

  Future<void> registrarVista(String promocionId) async {
    final deviceId = await DispositivoService.obtenerDeviceId();
    await _publico.post<Map<String, dynamic>>(
      '/promociones/$promocionId/vista',
      data: {'device_id': deviceId},
    );
  }

  Future<List<Map<String, dynamic>>> listarAdmin(String sucursalId) async {
    final respuesta = await _staff.get<Map<String, dynamic>>(
      '/promociones/admin/$sucursalId',
    );
    return _parsearLista(respuesta.data);
  }

  Future<void> crear({
    required String sucursalId,
    String? titulo,
    required String imagenUrl,
    String? descripcion,
    String? expiraAt,
    String? productoId,
    String tipoMedia = 'imagen',
  }) async {
    final respuesta = await _staff.post<Map<String, dynamic>>(
      '/promociones',
      data: {
        'sucursal_id': sucursalId,
        if (titulo != null && titulo.isNotEmpty) 'titulo': titulo,
        'imagen_url': imagenUrl,
        'tipo_media': tipoMedia,
        if (descripcion != null && descripcion.isNotEmpty)
          'descripcion': descripcion,
        if (expiraAt != null && expiraAt.isNotEmpty) 'expira_at': expiraAt,
        if (productoId != null && productoId.isNotEmpty)
          'producto_id': productoId,
      },
    );
    _validarExito(respuesta.data);
  }

  Future<void> actualizar({
    required String id,
    bool? activa,
    String? titulo,
    String? imagenUrl,
    String? descripcion,
  }) async {
    final respuesta = await _staff.patch<Map<String, dynamic>>(
      '/promociones/$id',
      data: {
        if (activa != null) 'activa': activa,
        if (titulo != null) 'titulo': titulo,
        if (imagenUrl != null) 'imagen_url': imagenUrl,
        if (descripcion != null) 'descripcion': descripcion,
      },
    );
    _validarExito(respuesta.data);
  }

  Future<void> eliminar(String id) async {
    final respuesta = await _staff.delete<Map<String, dynamic>>(
      '/promociones/$id',
    );
    _validarExito(respuesta.data);
  }

  void _validarExito(Map<String, dynamic>? data) {
    if (data == null) throw Exception('Respuesta vacía');
    final envoltura = RespuestaApi<void>.fromJson(data, (_) {});
    if (!envoltura.exito) throw Exception(envoltura.mensaje);
  }

  Future<List<Map<String, dynamic>>> _parsearLista(
    Map<String, dynamic>? data,
  ) async {
    if (data == null) throw Exception('Respuesta vacía');
    final envoltura = RespuestaApi<List<Map<String, dynamic>>>.fromJson(
      data,
      (raw) => (raw as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map<String, dynamic>))
          .toList(),
    );
    if (!envoltura.exito || envoltura.datos == null) {
      throw Exception(envoltura.mensaje);
    }
    return envoltura.datos!;
  }
}
