import 'package:dio/dio.dart';
import 'package:reserva_canchas/core/modelos/respuesta_api.dart';
import 'package:reserva_canchas/core/red/cliente_dio.dart';
import 'package:reserva_canchas/core/realtime/foody_realtime.dart';
import 'package:reserva_canchas/core/sesion/sesion_staff_service.dart';

/// Acceso al API de cocinas, impresoras y panel de cocina (KDS).
class CocinasRepository {
  CocinasRepository({Dio? dio})
      : _dio = dio ?? ClienteDio.instancia(conAuthStaff: true);

  final Dio _dio;

  // ----------------------------- Cocinas -----------------------------

  Future<List<Map<String, dynamic>>> listarCocinas(String sucursalId) async {
    final r = await _dio.get<Map<String, dynamic>>('/cocinas/$sucursalId');
    return _lista(r.data);
  }

  /// Cocinas visibles para el rol de cocina (permiso ver_cocina).
  Future<List<Map<String, dynamic>>> cocinasParaKds() async {
    final r = await _dio.get<Map<String, dynamic>>('/cocina/cocinas');
    return _lista(r.data);
  }

  Future<Map<String, dynamic>> crearCocina({
    required String sucursalId,
    required String nombre,
  }) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/cocinas',
      data: {'sucursal_id': sucursalId, 'nombre': nombre},
    );
    return _mapa(r.data);
  }

  Future<void> actualizarCocina({
    required String cocinaId,
    String? nombre,
    bool? activa,
  }) async {
    final r = await _dio.patch<Map<String, dynamic>>(
      '/cocinas/$cocinaId',
      data: {
        if (nombre != null) 'nombre': nombre,
        if (activa != null) 'activa': activa,
      },
    );
    _validar(r.data);
  }

  Future<void> desactivarCocina(String cocinaId) async {
    final r = await _dio.delete<Map<String, dynamic>>('/cocinas/$cocinaId');
    _validar(r.data);
  }

  // ---------------------------- Impresoras ----------------------------

  Future<List<Map<String, dynamic>>> listarImpresoras(
    String sucursalId, {
    String? cocinaId,
  }) async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/impresoras/$sucursalId',
      queryParameters: {if (cocinaId != null) 'cocina_id': cocinaId},
    );
    return _lista(r.data);
  }

  Future<Map<String, dynamic>> crearImpresora({
    required String sucursalId,
    required String cocinaId,
    required String nombre,
    String? ipLocal,
    String tipo = 'termica_red',
  }) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/impresoras',
      data: {
        'sucursal_id': sucursalId,
        'cocina_id': cocinaId,
        'nombre': nombre,
        if (ipLocal != null && ipLocal.isNotEmpty) 'ip_local': ipLocal,
        'tipo': tipo,
      },
    );
    return _mapa(r.data);
  }

  Future<void> actualizarImpresora({
    required String impresoraId,
    String? nombre,
    String? cocinaId,
    String? ipLocal,
    String? tipo,
    bool? activa,
  }) async {
    final r = await _dio.patch<Map<String, dynamic>>(
      '/impresoras/$impresoraId',
      data: {
        if (nombre != null) 'nombre': nombre,
        if (cocinaId != null) 'cocina_id': cocinaId,
        if (ipLocal != null) 'ip_local': ipLocal,
        if (tipo != null) 'tipo': tipo,
        if (activa != null) 'activa': activa,
      },
    );
    _validar(r.data);
  }

  Future<void> desactivarImpresora(String impresoraId) async {
    final r = await _dio.delete<Map<String, dynamic>>(
      '/impresoras/$impresoraId',
    );
    _validar(r.data);
  }

  // ------------------------------- KDS --------------------------------

  /// Pide al backend un topic HMAC para la estación elegida y lo guarda
  /// antes de abrir Realtime. El servidor comprueba permiso y sucursal.
  Future<void> prepararCanalRealtimeCocina({
    required String cocinaId,
    String? sucursalId,
  }) async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/auth/realtime-canales',
      queryParameters: {
        if (sucursalId != null && sucursalId.isNotEmpty)
          'sucursal_id': sucursalId,
        'cocina_id': cocinaId,
      },
    );
    final datos = _mapa(r.data);
    final raw = datos['realtime_canales'];
    if (raw is! Map) throw Exception('Canales Realtime inválidos');
    final canales = <String, String>{};
    raw.forEach((clave, valor) {
      if (valor != null && valor.toString().isNotEmpty) {
        canales[clave.toString()] = valor.toString();
      }
    });
    if (canales['cocina'] == null) {
      throw Exception('El backend no autorizó el canal de cocina');
    }
    await SesionStaffService.actualizarRealtimeCanales(canales);
    FoodyRealtime.aplicarCanalesStaff(canales);
  }

  Future<List<Map<String, dynamic>>> tickets(String cocinaId) async {
    final r = await _dio.get<Map<String, dynamic>>('/cocina/tickets/$cocinaId');
    return _lista(r.data);
  }

  Future<void> cambiarEstadoItem({
    required String itemId,
    required String estadoCocina,
    String? motivo,
  }) async {
    final r = await _dio.patch<Map<String, dynamic>>(
      '/cocina/items/$itemId/estado',
      data: {
        'estado_cocina': estadoCocina,
        if (motivo != null && motivo.isNotEmpty) 'motivo': motivo,
      },
    );
    _validar(r.data);
  }

  Future<void> cambiarEstadoTareaCombo({
    required String tareaId,
    required String estadoCocina,
  }) async {
    final r = await _dio.patch<Map<String, dynamic>>(
      '/cocina/combo-tareas/$tareaId/estado',
      data: {'estado_cocina': estadoCocina},
    );
    _validar(r.data);
  }

  Future<Map<String, dynamic>> marcarTareaComboNoDisponible({
    required String tareaId,
    required String motivo,
  }) async {
    final r = await _dio.patch<Map<String, dynamic>>(
      '/cocina/combo-tareas/$tareaId/no-disponible',
      data: {'motivo': motivo},
    );
    return _mapa(r.data);
  }

  /// VIE-09 C: fallo de preparación (N/D + merma + alerta).
  Future<void> falloPreparacion({
    required String itemId,
    required String motivo,
  }) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/cocina/items/$itemId/fallo-preparacion',
      data: {'motivo': motivo},
    );
    _validar(r.data);
  }

  Future<void> marcarPrioridadItem({
    required String itemId,
    required bool urgente,
  }) async {
    final r = await _dio.patch<Map<String, dynamic>>(
      '/cocina/items/$itemId/prioridad',
      data: {'urgente': urgente},
    );
    _validar(r.data);
  }

  Future<void> actualizarObservacionesItem({
    required String itemId,
    required String observaciones,
  }) async {
    final r = await _dio.patch<Map<String, dynamic>>(
      '/cocina/items/$itemId/observaciones',
      data: {'observaciones': observaciones},
    );
    _validar(r.data);
  }

  Future<void> reimprimirPedido({
    required String pedidoId,
    required String cocinaId,
    String? sucursalId,
  }) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/impresion/reimprimir',
      data: {
        'pedido_id': pedidoId,
        'cocina_id': cocinaId,
        if (sucursalId != null) 'sucursal_id': sucursalId,
      },
    );
    _validar(r.data);
  }

  List<Map<String, dynamic>> _lista(Map<String, dynamic>? data) {
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

  Map<String, dynamic> _mapa(Map<String, dynamic>? data) {
    if (data == null) throw Exception('Respuesta vacía');
    final env = RespuestaApi<Map<String, dynamic>>.fromJson(
      data,
      (raw) => Map<String, dynamic>.from(raw as Map<String, dynamic>),
    );
    if (!env.exito || env.datos == null) throw Exception(env.mensaje);
    return env.datos!;
  }

  void _validar(Map<String, dynamic>? data) {
    if (data == null) throw Exception('Respuesta vacía');
    final env = RespuestaApi<void>.fromJson(data, (_) {});
    if (!env.exito) throw Exception(env.mensaje);
  }
}
