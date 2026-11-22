import 'package:dio/dio.dart';
import 'package:reserva_canchas/core/dispositivo/dispositivo_service.dart';
import 'package:reserva_canchas/core/modelos/respuesta_api.dart';
import 'package:reserva_canchas/core/red/cliente_dio.dart';
import 'package:reserva_canchas/features/pedidos/domain/linea_carrito.dart';
import 'package:reserva_canchas/features/pedidos/data/sesion_cliente_service.dart';

class PedidosClienteRepository {
  PedidosClienteRepository({Dio? dio}) : _dio = dio ?? ClienteDio.instancia();

  final Dio _dio;

  Future<Map<String, dynamic>> crearPedido({
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
    bool requiereFactura = false,
    String? nitCliente,
    String? nombreFiscalCliente,
    String? emailCliente,
    String? codigoPromocion,
    double? propina,
    String? idempotencyKey,
    String? fechaEntregaDeseada,
  }) async {
    final deviceId = await DispositivoService.obtenerDeviceId();
    final lineasProducto = lineas.where((l) => !l.esCombo).toList();
    final lineasCombo = lineas.where((l) => l.esCombo).toList();
    final payload = <String, dynamic>{
      'sucursal_id': sucursalId,
      'device_id': deviceId,
      'tipo': tipo,
      'metodo_pago': metodoPago ?? 'pendiente',
      'requiere_factura': requiereFactura,
      if (mesaId != null) 'mesa_id': mesaId,
      if (clienteNombre != null) 'cliente_nombre': clienteNombre,
      if (clienteTelefono != null) 'cliente_telefono': clienteTelefono,
      if (direccionEntrega != null) 'direccion_entrega': direccionEntrega,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      if (requiereFactura) ...{
        'nit_cliente': nitCliente,
        'nombre_fiscal_cliente': nombreFiscalCliente,
        'email_cliente': emailCliente,
      },
      if (lineasProducto.isNotEmpty)
        'items': lineasProducto.map((l) => _itemJson(l, tipo)).toList(),
      if (lineasCombo.isNotEmpty)
        'combos': lineasCombo.map(_comboJson).toList(),
      if (codigoPromocion != null && codigoPromocion.trim().isNotEmpty)
        'codigo_promocion': codigoPromocion.trim(),
      if (propina != null && propina > 0) 'propina': propina,
      if (idempotencyKey != null && idempotencyKey.isNotEmpty)
        'idempotency_key': idempotencyKey,
      if (fechaEntregaDeseada != null && fechaEntregaDeseada.isNotEmpty)
        'fecha_entrega_deseada': fechaEntregaDeseada,
    };

    final respuesta = await _dio.post<Map<String, dynamic>>(
      '/pedidos',
      data: payload,
    );
    return _parsearMapa(respuesta.data);
  }

  /// Totales autoritativos del backend (AQ-SOLID-06). No crea pedido.
  Future<Map<String, dynamic>> estimarTotales({
    required String sucursalId,
    required String tipo,
    required List<LineaCarrito> lineas,
    String? mesaId,
    double? lat,
    double? lng,
    String? codigoPromocion,
  }) async {
    final deviceId = await DispositivoService.obtenerDeviceId();
    final lineasProducto = lineas.where((l) => !l.esCombo).toList();
    final lineasCombo = lineas.where((l) => l.esCombo).toList();
    final payload = <String, dynamic>{
      'sucursal_id': sucursalId,
      'device_id': deviceId,
      'tipo': tipo,
      'metodo_pago': 'pendiente',
      if (mesaId != null) 'mesa_id': mesaId,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      if (lineasProducto.isNotEmpty)
        'items': lineasProducto.map((l) => _itemJson(l, tipo)).toList(),
      if (lineasCombo.isNotEmpty)
        'combos': lineasCombo.map(_comboJson).toList(),
      if (codigoPromocion != null && codigoPromocion.trim().isNotEmpty)
        'codigo_promocion': codigoPromocion.trim(),
    };
    final respuesta = await _dio.post<Map<String, dynamic>>(
      '/pedidos/estimar',
      data: payload,
    );
    return _parsearMapa(respuesta.data);
  }

  Map<String, dynamic> _comboJson(LineaCarrito l) {
    return {
      'combo_id': l.comboId,
      'cantidad': l.cantidad,
      'precio': l.precioUnitario,
      if (l.toppings.isNotEmpty)
        'toppings': l.toppings.map((t) => {'topping_id': t.id}).toList(),
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
      if (l.observaciones != null && l.observaciones!.isNotEmpty)
        'observaciones': l.observaciones,
      if (l.toppings.isNotEmpty)
        'toppings': l.toppings.map((t) => {'topping_id': t.id}).toList(),
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

  Future<Map<String, dynamic>> estadoPedido(
    String pedidoId, {
    String? seguimientoToken,
  }) async {
    final deviceId = await DispositivoService.obtenerDeviceId();
    final respuesta = await _dio.get<Map<String, dynamic>>(
      '/pedidos/$pedidoId/estado',
      queryParameters: {
        'device_id': deviceId,
        if (seguimientoToken != null && seguimientoToken.isNotEmpty)
          'token': seguimientoToken,
      },
    );
    return _parsearMapa(respuesta.data);
  }

  Future<Map<String, dynamic>> calificarDomicilio({
    required String pedidoId,
    required int estrellas,
    String? comentario,
  }) async {
    final deviceId = await DispositivoService.obtenerDeviceId();
    final respuesta = await _dio.post<Map<String, dynamic>>(
      '/pedidos/$pedidoId/calificar',
      data: {
        'device_id': deviceId,
        'calificacion': estrellas,
        if (comentario != null && comentario.trim().isNotEmpty)
          'comentario': comentario.trim(),
      },
    );
    return _parsearMapa(respuesta.data);
  }

  Future<Map<String, dynamic>> cancelarPedido({
    required String pedidoId,
    required String motivo,
  }) async {
    final deviceId = await DispositivoService.obtenerDeviceId();
    final respuesta = await _dio.post<Map<String, dynamic>>(
      '/pedidos/$pedidoId/cancelar',
      data: {
        'device_id': deviceId,
        'motivo': motivo,
      },
    );
    return _parsearMapa(respuesta.data);
  }

  Future<Map<String, dynamic>> llamarMesera({
    required String pedidoId,
    String? mensaje,
  }) async {
    final deviceId = await DispositivoService.obtenerDeviceId();
    final respuesta = await _dio.post<Map<String, dynamic>>(
      '/pedidos/$pedidoId/llamar-mesera',
      data: {
        'device_id': deviceId,
        if (mensaje != null && mensaje.trim().isNotEmpty)
          'mensaje': mensaje.trim(),
      },
    );
    return _parsearMapa(respuesta.data);
  }

  Future<List<Map<String, dynamic>>> listarMios() async {
    final deviceId = await DispositivoService.obtenerDeviceId();
    final bearer = await SesionClienteService.accessTokenSupabase();
    final respuesta = await _dio.get<Map<String, dynamic>>(
      '/pedidos/mios',
      queryParameters: {'device_id': deviceId},
      options: bearer != null && bearer.isNotEmpty
          ? Options(headers: {'Authorization': 'Bearer $bearer'})
          : null,
    );
    if (respuesta.data == null) throw Exception('Respuesta vacía');
    final envoltura = RespuestaApi<List<Map<String, dynamic>>>.fromJson(
      respuesta.data!,
      (raw) => (raw as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map<String, dynamic>))
          .toList(),
    );
    if (!envoltura.exito || envoltura.datos == null) {
      throw Exception(envoltura.mensaje);
    }
    return envoltura.datos!;
  }

  Future<Map<String, dynamic>> validarCodigoPromocion({
    required String sucursalId,
    required String codigo,
    required num subtotal,
  }) async {
    final respuesta = await _dio.get<Map<String, dynamic>>(
      '/promociones/validar-codigo',
      queryParameters: {
        'sucursal_id': sucursalId,
        'codigo': codigo,
        'subtotal': subtotal,
      },
    );
    return _parsearMapa(respuesta.data);
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
}
