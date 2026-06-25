import 'package:dio/dio.dart';
import 'package:reserva_canchas/core/modelos/respuesta_api.dart';
import 'package:reserva_canchas/core/red/cliente_dio.dart';

class MesasRepository {
  MesasRepository({Dio? dio})
      : _dio = dio ?? ClienteDio.instancia(conAuthStaff: true);

  final Dio _dio;

  Future<List<Map<String, dynamic>>> listar(String sucursalId) async {
    final r = await _dio.get<Map<String, dynamic>>('/mesas/$sucursalId');
    return _parsearLista(r.data);
  }

  Future<Map<String, dynamic>> crear({
    required String sucursalId,
    required String nombre,
    String? qrToken,
  }) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/mesas',
      data: {
        'sucursal_id': sucursalId,
        'nombre': nombre,
        if (qrToken != null && qrToken.isNotEmpty) 'qr_token': qrToken,
      },
    );
    return _parsearMapa(r.data);
  }

  Future<Map<String, dynamic>> asignarTurno({
    required String sucursalId,
    required List<Map<String, String?>> asignaciones,
  }) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/mesas/asignar-turno',
      data: {
        'sucursal_id': sucursalId,
        'asignaciones': asignaciones
            .map(
              (a) => {
                'mesa_id': a['mesa_id'],
                if (a['mesera_asignada_id'] != null)
                  'mesera_asignada_id': a['mesera_asignada_id'],
              },
            )
            .toList(),
      },
    );
    return _parsearMapa(r.data);
  }

  Future<Map<String, dynamic>> actualizar({
    required String mesaId,
    required String sucursalId,
    String? nombre,
    bool? activa,
  }) async {
    final r = await _dio.patch<Map<String, dynamic>>(
      '/mesas/$mesaId',
      queryParameters: {'sucursal_id': sucursalId},
      data: {
        if (nombre != null) 'nombre': nombre,
        if (activa != null) 'activa': activa,
      },
    );
    return _parsearMapa(r.data);
  }

  Future<void> desactivar(String mesaId, String sucursalId) async {
    final r = await _dio.delete<Map<String, dynamic>>(
      '/mesas/$mesaId',
      queryParameters: {'sucursal_id': sucursalId},
    );
    _validar(r.data);
  }

  Future<Map<String, dynamic>> transferir({
    required String sucursalId,
    required String pedidoId,
    required String mesaOrigenId,
    required String mesaDestinoId,
    String? motivo,
  }) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/mesas/transferir',
      data: {
        'sucursal_id': sucursalId,
        'pedido_id': pedidoId,
        'mesa_origen_id': mesaOrigenId,
        'mesa_destino_id': mesaDestinoId,
        if (motivo != null && motivo.isNotEmpty) 'motivo': motivo,
      },
    );
    return _parsearMapa(r.data);
  }

  Future<Map<String, dynamic>> obtenerQr({
    required String mesaId,
    required String sucursalId,
    String? baseUrl,
  }) async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/mesas/$mesaId/qr',
      queryParameters: {
        'sucursal_id': sucursalId,
        if (baseUrl != null) 'base_url': baseUrl,
      },
    );
    return _parsearMapa(r.data);
  }

  Future<Map<String, dynamic>> reservar({
    required String mesaId,
    required String sucursalId,
    required String clienteNombre,
    required DateTime reservaHasta,
    String? clienteTelefono,
  }) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/mesas/$mesaId/reservar',
      data: {
        'sucursal_id': sucursalId,
        'cliente_nombre': clienteNombre,
        'reserva_hasta': reservaHasta.toUtc().toIso8601String(),
        if (clienteTelefono != null && clienteTelefono.isNotEmpty)
          'cliente_telefono': clienteTelefono,
      },
    );
    return _parsearMapa(r.data);
  }

  Future<Map<String, dynamic>> cancelarReserva({
    required String mesaId,
    required String sucursalId,
  }) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/mesas/$mesaId/cancelar-reserva',
      data: {'sucursal_id': sucursalId},
    );
    return _parsearMapa(r.data);
  }

  Future<Map<String, dynamic>> unirMesas({
    required String sucursalId,
    required String mesaPrincipalId,
    required List<String> mesasSecundarias,
  }) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/mesas/unir',
      data: {
        'sucursal_id': sucursalId,
        'mesa_principal_id': mesaPrincipalId,
        'mesas_secundarias': mesasSecundarias,
      },
    );
    return _parsearMapa(r.data);
  }

  Future<Map<String, dynamic>> salioSinPagar({
    required String mesaId,
    required String sucursalId,
    required String clienteNombre,
    required String motivo,
    String? clienteTelefono,
  }) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/mesas/$mesaId/salio-sin-pagar',
      data: {
        'sucursal_id': sucursalId,
        'cliente_nombre': clienteNombre,
        'motivo': motivo,
        if (clienteTelefono != null && clienteTelefono.isNotEmpty)
          'cliente_telefono': clienteTelefono,
      },
    );
    return _parsearMapa(r.data);
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

  Map<String, dynamic> _parsearMapa(Map<String, dynamic>? data) {
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
