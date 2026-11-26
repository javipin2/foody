import 'package:dio/dio.dart';
import 'package:reserva_canchas/core/dispositivo/dispositivo_service.dart';
import 'package:reserva_canchas/core/modelos/respuesta_api.dart';
import 'package:reserva_canchas/core/red/cliente_dio.dart';
import 'package:reserva_canchas/features/pedidos/domain/pedido_admin_model.dart';
import 'package:reserva_canchas/features/pedidos/domain/linea_carrito.dart';

class PedidosRepository {
  PedidosRepository({Dio? dio})
      : _dio = dio ?? ClienteDio.instancia(conAuthStaff: true);

  final Dio _dio;

  Future<List<PedidoAdminModel>> listarActivos({
    String? sucursalId,
    String? meseraId,
    int limit = 100,
  }) async {
    final respuesta = await _dio.get<Map<String, dynamic>>(
      '/pedidos',
      queryParameters: {
        'solo_activos': 'true',
        'limit': limit,
        if (sucursalId != null) 'sucursal_id': sucursalId,
        if (meseraId != null) 'mesera_id': meseraId,
      },
    );
    return _parsearLista(respuesta.data);
  }

  /// Busca pedidos activos en el servidor, con scope por sucursal y límite.
  Future<List<PedidoAdminModel>> buscarActivos({
    required String sucursalId,
    required String consulta,
    int limit = 6,
  }) async {
    final respuesta = await _dio.get<Map<String, dynamic>>(
      '/pedidos',
      queryParameters: {
        'solo_activos': 'true',
        'page': 1,
        'limit': limit,
        'sucursal_id': sucursalId,
        'q': consulta.trim(),
      },
    );
    final data = respuesta.data;
    if (data == null) throw Exception('Respuesta vacía');
    final envoltura = RespuestaApi<Map<String, dynamic>>.fromJson(
      data,
      (raw) => Map<String, dynamic>.from(raw as Map),
    );
    if (!envoltura.exito || envoltura.datos == null) {
      throw Exception(envoltura.mensaje);
    }
    final rawItems = envoltura.datos!['items'];
    if (rawItems is! List) return <PedidoAdminModel>[];
    return rawItems
        .map((item) => PedidoAdminModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Pedidos activos paginados para tableros de alto volumen.
  Future<({List<PedidoAdminModel> items, int total, bool hayMas})>
      listarActivosPaginado({
    String? sucursalId,
    String? meseraId,
    int page = 1,
    int limit = 100,
  }) async {
    final respuesta = await _dio.get<Map<String, dynamic>>(
      '/pedidos',
      queryParameters: {
        'solo_activos': 'true',
        'page': page,
        'limit': limit,
        if (sucursalId != null) 'sucursal_id': sucursalId,
        if (meseraId != null) 'mesera_id': meseraId,
      },
    );
    final data = respuesta.data;
    if (data == null) throw Exception('Respuesta vacía');
    final envoltura = RespuestaApi<Map<String, dynamic>>.fromJson(
      data,
      (raw) => Map<String, dynamic>.from(raw as Map),
    );
    if (!envoltura.exito || envoltura.datos == null) {
      throw Exception(envoltura.mensaje);
    }
    final d = envoltura.datos!;
    final rawItems = d['items'];
    final lista = rawItems is List
        ? rawItems
            .map((e) => PedidoAdminModel.fromJson(e as Map<String, dynamic>))
            .toList()
        : <PedidoAdminModel>[];
    final total = (d['total'] as num?)?.toInt() ?? lista.length;
    final pagina = (d['page'] as num?)?.toInt() ?? page;
    final lim = (d['limit'] as num?)?.toInt() ?? limit;
    final totalPages = (d['totalPages'] as num?)?.toInt() ??
        (total == 0 ? 0 : (total / lim).ceil());
    return (items: lista, total: total, hayMas: pagina < totalPages);
  }

  /// Cerrados de hoy. Con [page] el API devuelve `{ items, total, page, limit }`.
  Future<({List<PedidoAdminModel> items, int total, bool hayMas})>
      listarCerradosHoy({
    String? sucursalId,
    String? meseraId,
    int page = 1,
    int limit = 30,
  }) async {
    final respuesta = await _dio.get<Map<String, dynamic>>(
      '/pedidos/cerrados-hoy',
      queryParameters: {
        'page': page,
        'limit': limit,
        if (sucursalId != null) 'sucursal_id': sucursalId,
        if (meseraId != null) 'mesera_id': meseraId,
      },
    );
    final data = respuesta.data;
    if (data == null) throw Exception('Respuesta vacía');
    final envoltura = RespuestaApi<Map<String, dynamic>>.fromJson(
      data,
      (raw) => Map<String, dynamic>.from(raw as Map),
    );
    if (!envoltura.exito || envoltura.datos == null) {
      throw Exception(envoltura.mensaje);
    }
    final d = envoltura.datos!;
    final rawItems = d['items'];
    final lista = rawItems is List
        ? rawItems
            .map((e) => PedidoAdminModel.fromJson(e as Map<String, dynamic>))
            .toList()
        : <PedidoAdminModel>[];
    final total = (d['total'] as num?)?.toInt() ?? lista.length;
    final pagina = (d['page'] as num?)?.toInt() ?? page;
    final lim = (d['limit'] as num?)?.toInt() ?? limit;
    final totalPages = (d['totalPages'] as num?)?.toInt() ??
        (total == 0 ? 0 : (total / lim).ceil());
    return (items: lista, total: total, hayMas: pagina < totalPages);
  }

  Future<PedidoAdminModel> obtenerDetalle({
    required String pedidoId,
    String? sucursalId,
  }) async {
    final respuesta = await _dio.get<Map<String, dynamic>>(
      '/pedidos/$pedidoId/detalle',
      queryParameters: {
        if (sucursalId != null) 'sucursal_id': sucursalId,
      },
    );
    final data = respuesta.data;
    if (data == null) throw Exception('Respuesta vacía');
    final envoltura = RespuestaApi<Map<String, dynamic>>.fromJson(
      data,
      (raw) => Map<String, dynamic>.from(raw as Map),
    );
    if (!envoltura.exito || envoltura.datos == null) {
      throw Exception(envoltura.mensaje);
    }
    return PedidoAdminModel.fromJson(envoltura.datos!);
  }

  Future<List<Map<String, dynamic>>> listarDecisionesComboPendientes({
    required String pedidoId,
    String? sucursalId,
  }) async {
    final respuesta = await _dio.get<Map<String, dynamic>>(
      '/pedidos/$pedidoId/combo-decisiones-pendientes',
      queryParameters: {
        if (sucursalId != null) 'sucursal_id': sucursalId,
      },
    );
    final data = respuesta.data;
    if (data == null) throw Exception('Respuesta vacía');
    final envoltura = RespuestaApi<List<dynamic>>.fromJson(
      data,
      (raw) => raw as List<dynamic>,
    );
    if (!envoltura.exito || envoltura.datos == null) {
      throw Exception(envoltura.mensaje);
    }
    return envoltura.datos!
        .map((raw) => Map<String, dynamic>.from(raw as Map))
        .toList();
  }

  Future<Map<String, dynamic>> cotizarReemplazoCombo({
    required String pedidoId,
    required String decisionId,
    required String reemplazoId,
    String? sucursalId,
  }) async {
    final respuesta = await _dio.post<Map<String, dynamic>>(
      '/pedidos/$pedidoId/combo-decisiones/$decisionId/cotizacion',
      data: {'reemplazo_id': reemplazoId},
      queryParameters: {
        if (sucursalId != null) 'sucursal_id': sucursalId,
      },
    );
    return _parsearMapa(respuesta.data);
  }

  Future<Map<String, dynamic>> responderDecisionCombo({
    required String pedidoId,
    required String decisionId,
    required String accion,
    String? motivo,
    int? cotizacionVersion,
    num? totalAceptado,
    String? sucursalId,
  }) async {
    final respuesta = await _dio.patch<Map<String, dynamic>>(
      '/pedidos/$pedidoId/combo-decisiones/$decisionId/respuesta',
      data: {
        'accion': accion,
        if (motivo != null) 'motivo': motivo,
        if (cotizacionVersion != null)
          'cotizacion_version': cotizacionVersion,
        if (totalAceptado != null) 'total_aceptado': totalAceptado,
      },
      queryParameters: {
        if (sucursalId != null) 'sucursal_id': sucursalId,
      },
    );
    return _parsearMapa(respuesta.data);
  }

  Future<Map<String, dynamic>> obtenerPedidosMesa({
    required String mesaId,
    String? sucursalId,
  }) async {
    final respuesta = await _dio.get<Map<String, dynamic>>(
      '/pedidos/mesa/$mesaId',
      queryParameters: {
        if (sucursalId != null) 'sucursal_id': sucursalId,
      },
    );
    return _parsearMapa(respuesta.data);
  }

  Future<void> aprobarMesa(
    String pedidoId, {
    String? sucursalId,
    String? meseraId,
  }) async {
    final respuesta = await _dio.patch<Map<String, dynamic>>(
      '/pedidos/$pedidoId/aprobar',
      data: {
        if (meseraId != null) 'mesera_id': meseraId,
      },
      queryParameters: {
        if (sucursalId != null) 'sucursal_id': sucursalId,
      },
    );
    _validarExito(respuesta.data);
  }

  Future<void> rechazarMesa(
    String pedidoId, {
    required String motivo,
    String? sucursalId,
  }) async {
    final respuesta = await _dio.patch<Map<String, dynamic>>(
      '/pedidos/$pedidoId/rechazar',
      data: {'motivo': motivo},
      queryParameters: {
        if (sucursalId != null) 'sucursal_id': sucursalId,
      },
    );
    _validarExito(respuesta.data);
  }

  void _validarExito(Map<String, dynamic>? data) {
    if (data == null) throw Exception('Respuesta vacía');
    final envoltura = RespuestaApi<void>.fromJson(data, (_) {});
    if (!envoltura.exito) throw Exception(envoltura.mensaje);
  }

  Future<Map<String, dynamic>?> cambiarEstado({
    required String pedidoId,
    required String estado,
    String? sucursalId,
    String? motivo,
  }) async {
    final respuesta = await _dio.patch<Map<String, dynamic>>(
      '/pedidos/$pedidoId/estado',
      data: {
        'estado': estado,
        if (motivo != null) 'motivo': motivo,
      },
      queryParameters: {
        if (sucursalId != null) 'sucursal_id': sucursalId,
      },
    );
    final data = respuesta.data;
    if (data == null) throw Exception('Respuesta vacía');
    final envoltura = RespuestaApi<Map<String, dynamic>>.fromJson(
      data,
      (raw) =>
          raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{},
    );
    if (!envoltura.exito) throw Exception(envoltura.mensaje);
    return envoltura.datos;
  }

  Future<Map<String, dynamic>> aplicarDescuento({
    required String pedidoId,
    required String motivo,
    String? sucursalId,
    num? monto,
    num? porcentaje,
  }) async {
    final respuesta = await _dio.post<Map<String, dynamic>>(
      '/pedidos/$pedidoId/descuento',
      data: {
        'motivo': motivo,
        if (monto != null) 'monto': monto,
        if (porcentaje != null) 'porcentaje': porcentaje,
      },
      queryParameters: {
        if (sucursalId != null) 'sucursal_id': sucursalId,
      },
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
    return envoltura.datos!;
  }

  Future<Map<String, dynamic>> crearPedidoStaff({
    required String sucursalId,
    required String tipo,
    required List<LineaCarrito> lineas,
    String? clienteNombre,
    String? clienteTelefono,
    String? direccionEntrega,
    double? lat,
    double? lng,
    String? metodoPago,
    String? mesaId,
    String? pedidoIdAgregar,
    String? itemIdReemplazar,
    List<Map<String, dynamic>>? pagos,
    double? propina,
    String? observaciones,
    String? idempotencyKey,
    double? totalEsperado,
  }) async {
    final deviceId = await DispositivoService.obtenerDeviceId();
    final lineasProducto = lineas.where((l) => !l.esCombo).toList();
    final lineasCombo = lineas.where((l) => l.esCombo).toList();
    final body = {
      if (lineasProducto.isNotEmpty)
        'items': lineasProducto.map((l) => _itemJson(l, tipo)).toList(),
      if (lineasCombo.isNotEmpty)
        'combos': lineasCombo.map(_comboJson).toList(),
    };

    if (pedidoIdAgregar != null && pedidoIdAgregar.isNotEmpty) {
      final reemplaza = itemIdReemplazar != null && itemIdReemplazar.isNotEmpty;
      final respuesta = await _dio.post<Map<String, dynamic>>(
        reemplaza
            ? '/pedidos/$pedidoIdAgregar/items/$itemIdReemplazar/reemplazar'
            : '/pedidos/$pedidoIdAgregar/items',
        data: {
          ...body,
          if (idempotencyKey != null && idempotencyKey.isNotEmpty)
            'idempotency_key': idempotencyKey,
          if (reemplaza) 'motivo': 'Cambio de producto',
        },
        queryParameters: {
          if (sucursalId.isNotEmpty) 'sucursal_id': sucursalId,
        },
      );
      return _parsearMapa(respuesta.data);
    }

    final respuesta = await _dio.post<Map<String, dynamic>>(
      '/pedidos/staff',
      data: {
        'sucursal_id': sucursalId,
        'device_id': deviceId,
        'tipo': tipo,
        'mesa_id': mesaId,
        'cliente_nombre': clienteNombre,
        'cliente_telefono': clienteTelefono,
        'direccion_entrega': direccionEntrega,
        'lat': lat,
        'lng': lng,
        'metodo_pago': pagos != null ? null : (metodoPago ?? 'pendiente'),
        if (pagos != null) 'pagos': pagos,
        if (propina != null) 'propina': propina,
        if (observaciones != null && observaciones.trim().isNotEmpty)
          'observaciones': observaciones.trim(),
        if (idempotencyKey != null && idempotencyKey.isNotEmpty)
          'idempotency_key': idempotencyKey,
        if (totalEsperado != null) 'total_esperado': totalEsperado,
        ...body,
      },
    );
    return _parsearMapa(respuesta.data);
  }

  /// Cotización del servidor para el POS. Solo estima; nunca crea el pedido.
  Future<Map<String, dynamic>> estimarTotales({
    required String sucursalId,
    required String tipo,
    required List<LineaCarrito> lineas,
    String? mesaId,
    String? direccionEntrega,
  }) async {
    await DispositivoService.registrarEnBackend(dio: _dio);
    final deviceId = await DispositivoService.obtenerDeviceId();
    final capabilityHeaders = await DispositivoService.capabilityHeaders();
    final productos = lineas.where((linea) => !linea.esCombo).toList();
    final combos = lineas.where((linea) => linea.esCombo).toList();
    final respuesta = await _dio.post<Map<String, dynamic>>(
      '/pedidos/estimar',
      options: Options(headers: capabilityHeaders),
      data: {
        'sucursal_id': sucursalId,
        'device_id': deviceId,
        'tipo': tipo,
        'metodo_pago': 'pendiente',
        if (mesaId != null) 'mesa_id': mesaId,
        if (direccionEntrega != null) 'direccion_entrega': direccionEntrega,
        if (productos.isNotEmpty)
          'items': productos.map((linea) => _itemJson(linea, tipo)).toList(),
        if (combos.isNotEmpty) 'combos': combos.map(_comboJson).toList(),
      },
    );
    return _parsearMapa(respuesta.data);
  }

  Future<Map<String, dynamic>> cobrarCuentaMesa({
    required String mesaId,
    String? sucursalId,
    String? metodoPago,
    double? montoParcial,
    double? propina,
    List<Map<String, dynamic>>? pagos,
    List<String>? itemIds,
    String? idempotencyKey,
    String? motivo,
  }) async {
    final respuesta = await _dio.post<Map<String, dynamic>>(
      '/pedidos/mesa/$mesaId/cobrar',
      data: {
        if (metodoPago != null) 'metodo_pago': metodoPago,
        if (montoParcial != null) 'monto_parcial': montoParcial,
        if (propina != null) 'propina': propina,
        if (pagos != null) 'pagos': pagos,
        if (itemIds != null) 'item_ids': itemIds,
        if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
        if (motivo != null && motivo.trim().isNotEmpty) 'motivo': motivo.trim(),
      },
      queryParameters: {
        if (sucursalId != null) 'sucursal_id': sucursalId,
      },
    );
    return _parsearMapa(respuesta.data);
  }

  Future<Map<String, dynamic>> cobrarPedidoCaja({
    required String pedidoId,
    String? sucursalId,
    String? metodoPago,
    double? montoParcial,
    double? propina,
    List<Map<String, dynamic>>? pagos,
    String? idempotencyKey,
    String? motivo,
  }) async {
    final respuesta = await _dio.post<Map<String, dynamic>>(
      '/pedidos/$pedidoId/cobrar',
      data: {
        if (metodoPago != null) 'metodo_pago': metodoPago,
        if (montoParcial != null) 'monto_parcial': montoParcial,
        if (propina != null) 'propina': propina,
        if (pagos != null) 'pagos': pagos,
        if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
        if (motivo != null && motivo.trim().isNotEmpty) 'motivo': motivo.trim(),
      },
      queryParameters: {
        if (sucursalId != null) 'sucursal_id': sucursalId,
      },
    );
    return _parsearMapa(respuesta.data);
  }

  Future<void> actualizarComensalItem({
    required String pedidoId,
    required String itemId,
    String? sucursalId,
    String? comensalEtiqueta,
  }) async {
    final respuesta = await _dio.patch<Map<String, dynamic>>(
      '/pedidos/$pedidoId/items/$itemId/comensal',
      data: {'comensal_etiqueta': comensalEtiqueta},
      queryParameters: {
        if (sucursalId != null) 'sucursal_id': sucursalId,
      },
    );
    _validarExito(respuesta.data);
  }

  Future<Map<String, dynamic>> eliminarItemPedido({
    required String pedidoId,
    required String itemId,
    String? sucursalId,
    String? motivo,
  }) async {
    final respuesta = await _dio.delete<Map<String, dynamic>>(
      '/pedidos/$pedidoId/items/$itemId',
      data: {if (motivo != null) 'motivo': motivo},
      queryParameters: {
        if (sucursalId != null) 'sucursal_id': sucursalId,
      },
    );
    return _parsearMapa(respuesta.data);
  }

  Future<Map<String, dynamic>> actualizarItemPedido({
    required String pedidoId,
    required String itemId,
    String? sucursalId,
    required int cantidad,
    required String? observaciones,
    required List<String> toppingIds,
  }) async {
    final respuesta = await _dio.patch<Map<String, dynamic>>(
      '/pedidos/$pedidoId/items/$itemId',
      data: {
        'cantidad': cantidad,
        'observaciones': observaciones,
        'toppings': [
          for (final id in toppingIds) {'topping_id': id},
        ],
      },
      queryParameters: {
        if (sucursalId != null) 'sucursal_id': sucursalId,
      },
    );
    return _parsearMapa(respuesta.data);
  }

  Map<String, dynamic> _comboJson(LineaCarrito l) {
    return {
      'combo_id': l.comboId,
      'cantidad': l.cantidad,
      'precio': l.precioUnitario,
      if (l.toppings.isNotEmpty)
        'toppings': l.toppings
            .map((t) => {
                  'topping_id': t.id,
                  if (t.productoId != null) 'producto_id': t.productoId,
                })
            .toList(),
      if (l.bebidas.isNotEmpty)
        'bebidas': l.bebidas
            .map(
              (b) => {
                'bebida_id': b.id,
                'cantidad': b.cantidad,
              },
            )
            .toList(),
    };
  }

  Map<String, dynamic> _itemJson(LineaCarrito l, String tipoPedido) {
    return {
      'producto_id': l.productoId,
      'cantidad': l.cantidad,
      'precio': l.precioUnitarioPara(tipoPedido),
      'observaciones': l.observaciones,
      'toppings': l.toppings.map((t) => {'topping_id': t.id}).toList(),
      'bebidas': l.bebidas
          .map(
            (b) => {
              'bebida_id': b.id,
              'cantidad': b.cantidad,
            },
          )
          .toList(),
    };
  }

  Future<Map<String, dynamic>> _parsearMapa(Map<String, dynamic>? data) async {
    if (data == null) throw Exception('Respuesta vacía');
    final envoltura = RespuestaApi<Map<String, dynamic>>.fromJson(
      data,
      (raw) => Map<String, dynamic>.from(raw as Map<String, dynamic>),
    );
    if (!envoltura.exito || envoltura.datos == null) {
      throw Exception(envoltura.mensaje);
    }
    return envoltura.datos!;
  }

  Future<List<PedidoAdminModel>> _parsearLista(
      Map<String, dynamic>? data) async {
    if (data == null) throw Exception('Respuesta vacía');
    final envoltura = RespuestaApi<List<PedidoAdminModel>>.fromJson(
      data,
      (raw) => (raw as List<dynamic>)
          .map((e) => PedidoAdminModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
    if (!envoltura.exito || envoltura.datos == null) {
      throw Exception(envoltura.mensaje);
    }
    return envoltura.datos!;
  }
}
