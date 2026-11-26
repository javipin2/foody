import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reserva_canchas/features/pedidos/data/pedidos_repository.dart';
import 'package:reserva_canchas/features/pedidos/data/pedidos_cliente_repository.dart';
import 'package:reserva_canchas/features/pedidos/domain/linea_carrito.dart';

class _PedidosPaginadosAdapter implements HttpClientAdapter {
  _PedidosPaginadosAdapter(this.cuerpo);

  final Map<String, dynamic> cuerpo;
  RequestOptions? ultimaSolicitud;
  final List<RequestOptions> solicitudes = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    ultimaSolicitud = options;
    solicitudes.add(options);
    return ResponseBody.fromString(
      jsonEncode(cuerpo),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('decisiones de combo consultan, cotizan y registran respuesta',
      () async {
    SharedPreferences.setMockInitialValues({});
    final adapter = _PedidosPaginadosAdapter({
      'exito': true,
      'datos': <String, dynamic>{
        'decision_id': 'decision-1',
        'cotizacion_version': 2,
        'total_propuesto': 42000,
      },
    });
    final dio = Dio(BaseOptions(baseUrl: 'https://foody.test'))
      ..httpClientAdapter = adapter;
    final repository = PedidosRepository(dio: dio);

    adapter.cuerpo['datos'] = <dynamic>[];
    expect(
      await repository.listarDecisionesComboPendientes(
        pedidoId: 'pedido-1',
        sucursalId: 'sucursal-1',
      ),
      isEmpty,
    );
    adapter.cuerpo['datos'] = <String, dynamic>{
      'decision_id': 'decision-1',
      'cotizacion_version': 2,
      'total_propuesto': 42000,
    };
    final cotizacion = await repository.cotizarReemplazoCombo(
      pedidoId: 'pedido-1',
      decisionId: 'decision-1',
      reemplazoId: 'producto-2',
      sucursalId: 'sucursal-1',
    );
    await repository.responderDecisionCombo(
      pedidoId: 'pedido-1',
      decisionId: 'decision-1',
      accion: 'aceptar_sustitucion',
      cotizacionVersion: 2,
      totalAceptado: 42000,
      sucursalId: 'sucursal-1',
    );

    expect(cotizacion['cotizacion_version'], 2);
    expect(adapter.solicitudes.map((r) => r.path), [
      '/pedidos/pedido-1/combo-decisiones-pendientes',
      '/pedidos/pedido-1/combo-decisiones/decision-1/cotizacion',
      '/pedidos/pedido-1/combo-decisiones/decision-1/respuesta',
    ]);
    expect(adapter.solicitudes[1].data, {'reemplazo_id': 'producto-2'});
    expect(adapter.solicitudes[2].data, {
      'accion': 'aceptar_sustitucion',
      'cotizacion_version': 2,
      'total_aceptado': 42000,
    });
    for (final solicitud in adapter.solicitudes) {
      expect(solicitud.queryParameters['sucursal_id'], 'sucursal-1');
    }
  });

  test('cotización POS registra y acredita la capability del dispositivo',
      () async {
    SharedPreferences.setMockInitialValues({
      'foody_device_id': 'device-pos-estimate-regression',
    });
    final adapter = _PedidosPaginadosAdapter({
      'exito': true,
      'datos': {'registrado': true, 'total': 35000},
    });
    final dio = Dio(BaseOptions(baseUrl: 'https://foody.test'))
      ..httpClientAdapter = adapter;
    final repository = PedidosRepository(dio: dio);

    final total = await repository.estimarTotales(
      sucursalId: 'sucursal-1',
      tipo: 'para_llevar',
      lineas: [
        LineaCarrito(
          clave: 'producto-1',
          productoId: 'producto-1',
          nombre: 'Producto demo',
          precioUnitario: 35000,
        ),
      ],
    );

    expect(adapter.solicitudes.map((r) => r.path), [
      '/dispositivos/registrar',
      '/pedidos/estimar',
    ]);
    final registro = adapter.solicitudes.first;
    final estimacion = adapter.solicitudes.last;
    final capability = registro.headers['X-Foody-Device-Capability'];
    expect(capability, isA<String>());
    expect(capability as String, matches(RegExp(r'^[a-f0-9]{64}$')));
    expect(estimacion.headers['X-Foody-Device-Capability'], capability);
    expect((registro.data as Map<String, dynamic>)['device_id'],
        (estimacion.data as Map<String, dynamic>)['device_id']);
    expect(total['total'], 35000);
  });

  test('agregar ítems transmite la clave idempotente al pedido existente',
      () async {
    SharedPreferences.setMockInitialValues({});
    final adapter = _PedidosPaginadosAdapter({
      'exito': true,
      'datos': {'pedido_id': 'pedido-1'},
    });
    final dio = Dio(BaseOptions(baseUrl: 'https://foody.test'))
      ..httpClientAdapter = adapter;
    final repository = PedidosRepository(dio: dio);

    await repository.crearPedidoStaff(
      sucursalId: 'sucursal-1',
      tipo: 'mesa',
      lineas: [],
      pedidoIdAgregar: 'pedido-1',
      idempotencyKey: 'req-123',
    );

    expect(adapter.ultimaSolicitud?.path, '/pedidos/pedido-1/items');
    expect(adapter.ultimaSolicitud?.data, {'idempotency_key': 'req-123'});
  });

  test('crear pedido staff transmite la clave idempotente al endpoint',
      () async {
    SharedPreferences.setMockInitialValues({
      'foody_device_id': 'device-pos-idempotency-regression',
    });
    final adapter = _PedidosPaginadosAdapter({
      'exito': true,
      'datos': {'pedido_id': 'pedido-1'},
    });
    final dio = Dio(BaseOptions(baseUrl: 'https://foody.test'))
      ..httpClientAdapter = adapter;
    final repository = PedidosRepository(dio: dio);

    await repository.crearPedidoStaff(
      sucursalId: 'sucursal-1',
      tipo: 'para_llevar',
      lineas: [
        LineaCarrito(
          clave: 'producto-1',
          productoId: 'producto-1',
          nombre: 'Producto demo',
          precioUnitario: 25000,
        ),
      ],
      idempotencyKey: 'staff-req-123',
      totalEsperado: 25000,
    );

    expect(adapter.ultimaSolicitud?.path, '/pedidos/staff');
    expect(
      (adapter.ultimaSolicitud?.data
          as Map<String, dynamic>)['idempotency_key'],
      'staff-req-123',
    );
    expect(
      (adapter.ultimaSolicitud?.data as Map<String, dynamic>)['total_esperado'],
      25000,
    );
  });

  test('serializa topping de combo ligado al plato seleccionado', () async {
    SharedPreferences.setMockInitialValues({
      'foody_device_id': 'device-combo-topping',
    });
    final adapter = _PedidosPaginadosAdapter({
      'exito': true,
      'datos': {'pedido_id': 'pedido-combo'},
    });
    final dio = Dio(BaseOptions(baseUrl: 'https://foody.test'))
      ..httpClientAdapter = adapter;
    final repository = PedidosRepository(dio: dio);

    await repository.crearPedidoStaff(
      sucursalId: 'sucursal-1',
      tipo: 'mesa',
      lineas: [
        LineaCarrito(
          clave: 'combo:1:producto:1:topping',
          comboId: 'combo-1',
          nombre: 'Combo',
          precioUnitario: 30000,
          toppings: const [
            ToppingLineaCarrito(
              id: 'topping-1',
              nombre: 'Queso',
              precio: 1000,
              productoId: 'producto-1',
            ),
          ],
        ),
      ],
    );

    final body = adapter.ultimaSolicitud!.data as Map<String, dynamic>;
    expect(body['combos'], [
      {
        'combo_id': 'combo-1',
        'cantidad': 1,
        'precio': 30000,
        'toppings': [
          {'topping_id': 'topping-1', 'producto_id': 'producto-1'},
        ],
      },
    ]);
  });

  test('el pedido de cliente QR conserva el plato destino del topping',
      () async {
    SharedPreferences.setMockInitialValues({
      'foody_device_id': 'device-cliente-combo-topping',
    });
    final adapter = _PedidosPaginadosAdapter({
      'exito': true,
      'datos': {'pedido_id': 'pedido-cliente-combo'},
    });
    final dio = Dio(BaseOptions(baseUrl: 'https://foody.test'))
      ..httpClientAdapter = adapter;
    final repository = PedidosClienteRepository(dio: dio);

    await repository.crearPedido(
      sucursalId: 'sucursal-1',
      tipo: 'para_llevar',
      lineas: [
        LineaCarrito(
          clave: 'combo:cliente:plato:topping',
          comboId: 'combo-1',
          nombre: 'Combo',
          precioUnitario: 30000,
          toppings: const [
            ToppingLineaCarrito(
              id: 'topping-1',
              nombre: 'Queso',
              precio: 1000,
              productoId: 'producto-2',
            ),
          ],
        ),
      ],
    );

    final pedido = adapter.solicitudes.last;
    expect(pedido.path, '/pedidos');
    final body = pedido.data as Map<String, dynamic>;
    expect(
      (body['combos'] as List).single['toppings'],
      [
        {'topping_id': 'topping-1', 'producto_id': 'producto-2'},
      ],
    );
  });

  test('alta pública envía la cotización del backend como precondición',
      () async {
    SharedPreferences.setMockInitialValues({
      'foody_device_id': 'device-cliente-cotizacion',
    });
    final adapter = _PedidosPaginadosAdapter({
      'exito': true,
      'datos': {'pedido_id': 'pedido-cotizado'},
    });
    final dio = Dio(BaseOptions(baseUrl: 'https://foody.test'))
      ..httpClientAdapter = adapter;
    final repository = PedidosClienteRepository(dio: dio);

    await repository.crearPedido(
      sucursalId: 'sucursal-1',
      tipo: 'para_llevar',
      lineas: [
        LineaCarrito(
          clave: 'producto-1',
          productoId: 'producto-1',
          nombre: 'Producto demo',
          precioUnitario: 18000,
        ),
      ],
      totalEsperado: 18000,
    );

    expect(
      (adapter.solicitudes.last.data as Map<String, dynamic>)['total_esperado'],
      18000,
    );
  });

  test('reemplazar ítem usa el endpoint atómico con clave y motivo', () async {
    SharedPreferences.setMockInitialValues({});
    final adapter = _PedidosPaginadosAdapter({
      'exito': true,
      'datos': {'pedido_id': 'pedido-1'},
    });
    final dio = Dio(BaseOptions(baseUrl: 'https://foody.test'))
      ..httpClientAdapter = adapter;
    final repository = PedidosRepository(dio: dio);

    await repository.crearPedidoStaff(
      sucursalId: 'sucursal-1',
      tipo: 'mesa',
      lineas: [],
      pedidoIdAgregar: 'pedido-1',
      itemIdReemplazar: 'item-1',
      idempotencyKey: 'replace-req-1',
    );

    expect(
      adapter.ultimaSolicitud?.path,
      '/pedidos/pedido-1/items/item-1/reemplazar',
    );
    expect(adapter.ultimaSolicitud?.data, {
      'idempotency_key': 'replace-req-1',
      'motivo': 'Cambio de producto',
    });
  });

  test('solicita página de activos y conserva el total del servidor', () async {
    final adapter = _PedidosPaginadosAdapter({
      'exito': true,
      'datos': {
        'items': [
          {
            'id': 'pedido-101',
            'numero_pedido': 'P-101',
            'tipo': 'mesa',
            'estado': 'pendiente',
            'total': '25000.00',
            'monto_pagado': '0',
            'created_at': '2026-11-24T10:00:00.000Z',
            'estado_desde': '2026-11-24T10:00:00.000Z',
            'items_resumen': [],
          },
        ],
        'total': 101,
        'page': 2,
        'limit': 100,
        'totalPages': 2,
      },
    });
    final dio = Dio(BaseOptions(baseUrl: 'https://foody.test'))
      ..httpClientAdapter = adapter;
    final repository = PedidosRepository(dio: dio);

    final pagina = await repository.listarActivosPaginado(
      sucursalId: 'sucursal-1',
      meseraId: 'mesera-1',
      page: 2,
      limit: 100,
    );

    expect(adapter.ultimaSolicitud?.path, '/pedidos');
    expect(adapter.ultimaSolicitud?.queryParameters, {
      'solo_activos': 'true',
      'page': 2,
      'limit': 100,
      'sucursal_id': 'sucursal-1',
      'mesera_id': 'mesera-1',
    });
    expect(pagina.items.single.numeroPedido, 'P-101');
    expect(pagina.total, 101);
    expect(pagina.hayMas, isFalse);
  });

  test('busca pedidos activos en servidor con sucursal y consulta', () async {
    final adapter = _PedidosPaginadosAdapter({
      'exito': true,
      'datos': {
        'items': [
          {
            'id': 'pedido-antiguo',
            'numero_pedido': 'P-ANTIGUO',
            'tipo': 'domicilio',
            'estado': 'en_camino',
            'cliente_nombre': 'Ana Pérez',
            'total': '25000.00',
            'monto_pagado': '0',
            'created_at': '2026-11-20T10:00:00.000Z',
            'estado_desde': '2026-11-20T10:00:00.000Z',
            'items_resumen': [],
          },
        ],
        'total': 1,
        'page': 1,
        'limit': 6,
        'totalPages': 1,
      },
    });
    final dio = Dio(BaseOptions(baseUrl: 'https://foody.test'))
      ..httpClientAdapter = adapter;
    final repository = PedidosRepository(dio: dio);

    final resultados = await repository.buscarActivos(
      sucursalId: 'sucursal-1',
      consulta: ' Ana ',
    );

    expect(adapter.ultimaSolicitud?.path, '/pedidos');
    expect(adapter.ultimaSolicitud?.queryParameters, {
      'solo_activos': 'true',
      'page': 1,
      'limit': 6,
      'sucursal_id': 'sucursal-1',
      'q': 'Ana',
    });
    expect(resultados.single.numeroPedido, 'P-ANTIGUO');
    expect(resultados.single.clienteNombre, 'Ana Pérez');
  });
}
