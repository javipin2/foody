import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reserva_canchas/features/caja/data/caja_repository.dart';
import 'package:reserva_canchas/features/admin/presentation/widgets/operacion_ui.dart';
import 'package:reserva_canchas/features/menu/data/menu_repository.dart';
import 'package:reserva_canchas/features/menu/domain/menu_model.dart';
import 'package:reserva_canchas/features/mesa/data/mesas_repository.dart';
import 'package:reserva_canchas/features/pedidos/domain/linea_carrito.dart';
import 'package:reserva_canchas/features/pedidos/presentation/pedido_cajero_screen.dart';
import 'package:reserva_canchas/features/pedidos/data/pedidos_repository.dart';

class _PedidosRepositoryFake extends PedidosRepository {
  _PedidosRepositoryFake({this.total = 12000});

  final num total;
  int estimaciones = 0;
  int creaciones = 0;
  final List<String?> reemplazos = [];
  Object? errorEstimacion;
  int fallosCreacion = 0;
  final List<String?> clavesIdempotencia = [];
  final List<String?> metodosPago = [];
  final List<double?> propinasRecibidas = [];
  final List<List<Map<String, dynamic>>?> pagosRecibidos = [];

  @override
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
  }) async {
    creaciones++;
    reemplazos.add(itemIdReemplazar);
    clavesIdempotencia.add(idempotencyKey);
    metodosPago.add(metodoPago);
    propinasRecibidas.add(propina);
    pagosRecibidos.add(pagos);
    if (fallosCreacion > 0) {
      fallosCreacion--;
      throw Exception('Respuesta perdida');
    }
    return {'id': 'pedido-prueba', 'total': total};
  }

  @override
  Future<Map<String, dynamic>> estimarTotales({
    required String sucursalId,
    required String tipo,
    required List lineas,
    String? mesaId,
    String? direccionEntrega,
  }) async {
    estimaciones++;
    if (errorEstimacion != null) throw errorEstimacion!;
    return {'total': total};
  }
}

class _MenuRepositoryFake extends MenuRepository {
  _MenuRepositoryFake({this.conProductos = false, this.imagenUrl});

  final bool conProductos;
  final String? imagenUrl;

  @override
  Future<MenuModel> obtenerPorSucursal(String sucursalId) async => MenuModel(
        sucursal: SucursalMenuModel(
          id: 'sucursal-prueba',
          nombre: 'Sede de prueba',
          horarioActivo: true,
        ),
        categorias: conProductos
            ? [
                CategoriaMenuModel(
                  id: 'categoria-prueba',
                  nombre: 'Platos',
                  productos: [
                    ProductoMenuModel(
                      id: 'producto-prueba',
                      nombre: 'Arepa',
                      precio: 12000,
                      disponible: true,
                      imagenUrl: imagenUrl,
                    ),
                  ],
                ),
              ]
            : const [],
        combos: [],
      );
}

class _MesasRepositoryFake extends MesasRepository {
  @override
  Future<List<Map<String, dynamic>>> listar(String sucursalId) async => [];
}

class _CajaRepositoryFake extends CajaRepository {
  @override
  Future<Map<String, dynamic>?> cajaActiva(String sucursalId) async =>
      {'id': 'caja-prueba'};
}

class _CajaRepositoryError extends CajaRepository {
  int llamadas = 0;

  @override
  Future<Map<String, dynamic>?> cajaActiva(String sucursalId) async {
    llamadas++;
    throw Exception('API no disponible');
  }
}

class _MenuRepositoryPendiente extends MenuRepository {
  _MenuRepositoryPendiente(this.completer);

  final Completer<MenuModel> completer;
  int llamadas = 0;

  @override
  Future<MenuModel> obtenerPorSucursal(String sucursalId) {
    llamadas++;
    return completer.future;
  }
}

class _MesasRepositoryPendiente extends MesasRepository {
  _MesasRepositoryPendiente(this.completer);

  final Completer<List<Map<String, dynamic>>> completer;
  int llamadas = 0;

  @override
  Future<List<Map<String, dynamic>>> listar(String sucursalId) {
    llamadas++;
    return completer.future;
  }
}

class _CajaRepositoryPendiente extends CajaRepository {
  _CajaRepositoryPendiente(this.completer);

  final Completer<Map<String, dynamic>?> completer;
  int llamadas = 0;

  @override
  Future<Map<String, dynamic>?> cajaActiva(String sucursalId) {
    llamadas++;
    return completer.future;
  }
}

void main() {
  testWidgets('mesero crea el pedido con pago pendiente por defecto', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final pedidos = _PedidosRepositoryFake();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PedidoCajeroScreen(
            sucursalId: 'sucursal-prueba',
            modoMesero: true,
            mesaIdFija: 'mesa-prueba',
            menuRepository: _MenuRepositoryFake(conProductos: true),
            mesasRepository: _MesasRepositoryFake(),
            cajaRepository: _CajaRepositoryFake(),
            pedidosRepository: pedidos,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Arepa').first);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Agregar ·'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Confirmar pedido →'));
    await tester.pumpAndSettle();

    expect(pedidos.creaciones, 1);
    expect(pedidos.metodosPago.single, 'pendiente');
    expect(tester.takeException(), isNull);
  });

  testWidgets('POS no conserva propina al diferir el cobro', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final pedidos = _PedidosRepositoryFake();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PedidoCajeroScreen(
            sucursalId: 'sucursal-prueba',
            menuRepository: _MenuRepositoryFake(conProductos: true),
            mesasRepository: _MesasRepositoryFake(),
            cajaRepository: _CajaRepositoryFake(),
            pedidosRepository: pedidos,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Arepa'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Agregar ·'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    final propina = find.widgetWithText(TextField, 'Propina voluntaria');
    await tester.ensureVisible(propina);
    await tester.enterText(propina, '2500');
    await tester.tap(find.byKey(const ValueKey<String>('pos-metodo-pago')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pendiente').last);
    await tester.pumpAndSettle();

    expect(find.text('Propina voluntaria'), findsNothing);
    final confirmar = find.widgetWithText(
      FilledButton,
      'Confirmar pedido →',
    );
    expect(tester.widget<FilledButton>(confirmar).onPressed, isNotNull);
    await tester.ensureVisible(confirmar);
    await tester.pumpAndSettle();
    await tester.tap(confirmar);
    await tester.pumpAndSettle();

    expect(pedidos.creaciones, 1);
    expect(pedidos.metodosPago.single, 'pendiente');
    expect(pedidos.propinasRecibidas.single, isNull);
    expect(pedidos.pagosRecibidos.single, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('el reintento de POS reutiliza la clave de creación',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final pedidos = _PedidosRepositoryFake()..fallosCreacion = 1;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PedidoCajeroScreen(
            sucursalId: 'sucursal-prueba',
            menuRepository: _MenuRepositoryFake(conProductos: true),
            mesasRepository: _MesasRepositoryFake(),
            cajaRepository: _CajaRepositoryFake(),
            pedidosRepository: pedidos,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Arepa').first);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Agregar ·'));
    await tester.pumpAndSettle();
    final confirmar = find.widgetWithText(FilledButton, 'Confirmar pedido →');
    await tester.tap(confirmar);
    await tester.pumpAndSettle();
    await tester.tap(confirmar);
    await tester.pumpAndSettle();

    expect(pedidos.creaciones, 2);
    expect(pedidos.clavesIdempotencia.first, isNotEmpty);
    expect(pedidos.clavesIdempotencia[1], pedidos.clavesIdempotencia.first);
    expect(tester.takeException(), isNull);
  });

  testWidgets('el reintento al agregar a un pedido conserva la clave',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final pedidos = _PedidosRepositoryFake()..fallosCreacion = 1;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PedidoCajeroScreen(
            sucursalId: 'sucursal-prueba',
            pedidoIdAgregar: 'pedido-existente',
            menuRepository: _MenuRepositoryFake(conProductos: true),
            mesasRepository: _MesasRepositoryFake(),
            cajaRepository: _CajaRepositoryFake(),
            pedidosRepository: pedidos,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Arepa'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Agregar ·'));
    await tester.pumpAndSettle();
    final confirmar = find.widgetWithText(FilledButton, 'Confirmar pedido →');
    await tester.tap(confirmar);
    await tester.pumpAndSettle();
    await tester.tap(confirmar);
    await tester.pumpAndSettle();

    expect(pedidos.creaciones, 2);
    expect(pedidos.clavesIdempotencia.first, isNotEmpty);
    expect(pedidos.clavesIdempotencia[1], pedidos.clavesIdempotencia.first);
    expect(tester.takeException(), isNull);
  });

  testWidgets('si el payload cambia tras fallo, POS rota la clave',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final pedidos = _PedidosRepositoryFake()..fallosCreacion = 1;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PedidoCajeroScreen(
            sucursalId: 'sucursal-prueba',
            menuRepository: _MenuRepositoryFake(conProductos: true),
            mesasRepository: _MesasRepositoryFake(),
            cajaRepository: _CajaRepositoryFake(),
            pedidosRepository: pedidos,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Arepa'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Agregar ·'));
    await tester.pumpAndSettle();
    final confirmar = find.widgetWithText(FilledButton, 'Confirmar pedido →');
    await tester.tap(confirmar);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Arepa').first);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Agregar ·'));
    await tester.pumpAndSettle();
    await tester.tap(confirmar);
    await tester.pumpAndSettle();

    expect(pedidos.creaciones, 2);
    expect(pedidos.clavesIdempotencia.first, isNotEmpty);
    expect(
        pedidos.clavesIdempotencia[1], isNot(pedidos.clavesIdempotencia.first));
    expect(tester.takeException(), isNull);
  });

  testWidgets('POS no cobra con precio local si falla la cotización', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final pedidos = _PedidosRepositoryFake()
      ..errorEstimacion = Exception('Sin conexión');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PedidoCajeroScreen(
            sucursalId: 'sucursal-prueba',
            menuRepository: _MenuRepositoryFake(conProductos: true),
            mesasRepository: _MesasRepositoryFake(),
            cajaRepository: _CajaRepositoryFake(),
            pedidosRepository: pedidos,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Arepa').first);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Agregar ·'));
    await tester.pumpAndSettle();

    final confirmar = find.widgetWithText(FilledButton, 'Confirmar pedido →');
    expect(tester.widget<FilledButton>(confirmar).onPressed, isNull);
    expect(find.text('Reintentar cotización'), findsOneWidget);
    await tester.tap(find.text('Reintentar cotización'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(pedidos.creaciones, 0);
    expect(find.text('Reintentar cotización'), findsOneWidget);

    pedidos.errorEstimacion = null;
    await tester.tap(find.text('Reintentar cotización'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(confirmar).onPressed, isNotNull);
    await tester.tap(confirmar);
    await tester.pumpAndSettle();

    expect(pedidos.creaciones, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reemplazo usa una sola operación atómica desde la UI',
      (tester) async {
    final pedidos = _PedidosRepositoryFake();
    var pedidoModificado = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PedidoCajeroScreen(
            sucursalId: 'sucursal-prueba',
            pedidoIdAgregar: 'pedido-existente',
            itemIdReemplazar: 'item-anterior',
            onPedidoModificado: () => pedidoModificado = true,
            menuRepository: _MenuRepositoryFake(conProductos: true),
            mesasRepository: _MesasRepositoryFake(),
            cajaRepository: _CajaRepositoryFake(),
            pedidosRepository: pedidos,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Arepa'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Agregar ·'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Confirmar pedido →'));
    await tester.pumpAndSettle();

    expect(pedidos.creaciones, 1);
    expect(pedidos.reemplazos, ['item-anterior']);
    expect(pedidoModificado, isTrue);
    expect(find.textContaining('Producto cambiado ·'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(320, 640),
    const Size(390, 844),
    const Size(820, 900),
    const Size(1440, 900),
  ]) {
    testWidgets('POS vacío se adapta a ${size.width}px', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: PedidoCajeroScreen(
              sucursalId: 'sucursal-prueba',
              menuRepository: _MenuRepositoryFake(),
              mesasRepository: _MesasRepositoryFake(),
              cajaRepository: _CajaRepositoryFake(),
              pedidosRepository: _PedidosRepositoryFake(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nuevo pedido'), findsOneWidget);
      expect(find.text('Sin productos en esta categoría'), findsOneWidget);
    });
  }

  testWidgets('POS vacío pide productos y no ofrece reintentar una cotización',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: PedidoCajeroScreen(
            sucursalId: 'sucursal-prueba',
            menuRepository: _MenuRepositoryFake(),
            mesasRepository: _MesasRepositoryFake(),
            cajaRepository: _CajaRepositoryFake(),
            pedidosRepository: _PedidosRepositoryFake(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
        find.text('Agrega productos para cotizar el pedido.'), findsOneWidget);
    expect(find.text('Reintentar cotización'), findsNothing);
  });

  testWidgets('POS aclara cuándo se registra el pago según el canal', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: PedidoCajeroScreen(
            sucursalId: 'sucursal-prueba',
            menuRepository: _MenuRepositoryFake(),
            mesasRepository: _MesasRepositoryFake(),
            cajaRepository: _CajaRepositoryFake(),
            pedidosRepository: _PedidosRepositoryFake(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cobro ahora'), findsOneWidget);
    expect(find.text('Propina voluntaria'), findsOneWidget);
    expect(find.text('Aparte del total del pedido'), findsOneWidget);
    expect(
      find.text('El cobro se registra en Caja al confirmar el pedido.'),
      findsOneWidget,
    );

    final canal = tester.widget<OperacionTipoToggle>(
      find.byType(OperacionTipoToggle),
    );
    canal.onCambio('mesa');
    await tester.pumpAndSettle();
    expect(find.text('Método previsto al cobrar'), findsOneWidget);
    expect(
      find.text(
        'No se cobra al crear el pedido. Confirma el método al cerrar la cuenta.',
      ),
      findsOneWidget,
    );

    final domicilioToggle = tester.widget<OperacionTipoToggle>(
      find.byType(OperacionTipoToggle),
    );
    domicilioToggle.onCambio('domicilio');
    await tester.pumpAndSettle();
    expect(find.text('Método de pago al entregar'), findsOneWidget);
    expect(
      find.text(
        'El repartidor confirma el método al entregar; Admin puede marcar la entrega manual desde Pedidos.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey<String>('pos-metodo-pago')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pendiente').last);
    await tester.pumpAndSettle();
    expect(
      find.text(
        'El repartidor debe indicar el método. Si Admin marca la entrega manualmente, se registra efectivo.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('seleccionar producto lo añade al carrito sin enviarlo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final pedidos = _PedidosRepositoryFake(total: 10000);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: PedidoCajeroScreen(
            sucursalId: 'sucursal-prueba',
            menuRepository: _MenuRepositoryFake(conProductos: true),
            mesasRepository: _MesasRepositoryFake(),
            cajaRepository: _CajaRepositoryFake(),
            pedidosRepository: pedidos,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Arepa'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Agregar ·'), findsOneWidget);

    await tester.tap(find.textContaining('Agregar ·'));
    await tester.pumpAndSettle();
    expect(find.text('Carrito'), findsOneWidget);
    expect(find.text('1 producto'), findsOneWidget);
    final incrementar = find.byKey(
      const ValueKey<String>('pos-qty-increase-0'),
    );
    expect(tester.getSize(incrementar), const Size(44, 44));
    expect(
      find.bySemanticsLabel('Aumentar cantidad de Arepa'),
      findsOneWidget,
    );
    await tester.tap(incrementar);
    await tester.pumpAndSettle();
    expect(find.text('1 producto'), findsOneWidget);
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey<String>('pos-qty-value-0')),
          )
          .data,
      '2',
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(pedidos.estimaciones, 2);
    expect(find.text('Total estimado'), findsOneWidget);
    final total = tester.widget<Text>(
      find.byKey(const ValueKey<String>('pos-total-estimado')),
    );
    expect(total.data, contains('10.000'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('la grilla de productos usa el ancho del panel POS', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PedidoCajeroScreen(
            sucursalId: 'sucursal-prueba',
            menuRepository: _MenuRepositoryFake(
              conProductos: true,
              imagenUrl: 'https://example.test/arepa.jpg',
            ),
            mesasRepository: _MesasRepositoryFake(),
            cajaRepository: _CajaRepositoryFake(),
            pedidosRepository: _PedidosRepositoryFake(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final grid = tester.widget<GridView>(find.byType(GridView).first);
    expect(
      (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
          .crossAxisCount,
      5,
    );
    expect(
      (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
          .childAspectRatio,
      1.35,
    );
    expect(find.byType(CachedNetworkImage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tocar fuera del detalle no activa productos de fondo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PedidoCajeroScreen(
            sucursalId: 'sucursal-prueba',
            menuRepository: _MenuRepositoryFake(conProductos: true),
            mesasRepository: _MesasRepositoryFake(),
            cajaRepository: _CajaRepositoryFake(),
            pedidosRepository: _PedidosRepositoryFake(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Arepa'));
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    expect(find.textContaining('Agregar ·'), findsNothing);
    expect(find.text('0 productos'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pago mixto usa estimación y bloquea montos que no cuadran', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final pedidos = _PedidosRepositoryFake(total: 10000);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PedidoCajeroScreen(
            sucursalId: 'sucursal-prueba',
            menuRepository: _MenuRepositoryFake(conProductos: true),
            mesasRepository: _MesasRepositoryFake(),
            cajaRepository: _CajaRepositoryFake(),
            pedidosRepository: pedidos,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Arepa'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Agregar ·'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    final toggle = find.byKey(const ValueKey<String>('pos-pago-mixto'));
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    final totalFinder =
        find.byKey(const ValueKey<String>('pos-total-estimado'));
    final carritoScrollable =
        find.ancestor(of: toggle, matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(
      totalFinder,
      160,
      scrollable: carritoScrollable,
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(totalFinder).data,
      contains('10.000'),
    );

    final monto1 = find.byKey(const ValueKey<String>('pos-monto-mixto-1'));
    await tester.ensureVisible(monto1);
    await tester.enterText(monto1, '7000');
    await tester.pumpAndSettle();

    final errorFinder =
        find.byKey(const ValueKey<String>('pos-error-pago-mixto'));
    await tester.scrollUntilVisible(
      errorFinder,
      160,
      scrollable: carritoScrollable,
    );
    await tester.pumpAndSettle();
    final error = tester.widget<Text>(
      errorFinder,
    );
    expect(error.data, contains('Los pagos deben sumar'));
    expect(error.data, contains('10.000'));
    final confirmar = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Confirmar pedido →'),
    );
    expect(confirmar.onPressed, isNull);
    expect(tester.takeException(), isNull);

    final monto2 = find.byKey(const ValueKey<String>('pos-monto-mixto-2'));
    await tester.ensureVisible(monto1);
    await tester.enterText(monto1, '6000');
    await tester.ensureVisible(monto2);
    await tester.enterText(monto2, '4000');
    await tester.pumpAndSettle();

    final propina = find.widgetWithText(TextField, 'Propina voluntaria');
    await tester.ensureVisible(propina);
    await tester.enterText(propina, '2500');
    await tester.pumpAndSettle();
    final confirmarValido = find.widgetWithText(
      FilledButton,
      'Confirmar pedido →',
    );
    expect(tester.widget<FilledButton>(confirmarValido).onPressed, isNotNull);
    await tester.ensureVisible(confirmarValido);
    await tester.pumpAndSettle();
    await tester.tap(confirmarValido);
    await tester.pumpAndSettle();

    expect(pedidos.creaciones, 1);
    expect(pedidos.propinasRecibidas.single, 2500);
    expect(pedidos.pagosRecibidos.single, [
      {'metodo_pago': 'efectivo', 'monto': 6000.0},
      {'metodo_pago': 'tarjeta', 'monto': 4000.0},
    ]);
    expect(
      (pedidos.pagosRecibidos.single!).fold<double>(
        0,
        (sum, pago) => sum + (pago['monto'] as num).toDouble(),
      ),
      10000,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('POS inicia menú, mesas y caja en paralelo', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final menuCompleter = Completer<MenuModel>();
    final mesasCompleter = Completer<List<Map<String, dynamic>>>();
    final cajaCompleter = Completer<Map<String, dynamic>?>();
    final menuRepository = _MenuRepositoryPendiente(menuCompleter);
    final mesasRepository = _MesasRepositoryPendiente(mesasCompleter);
    final cajaRepository = _CajaRepositoryPendiente(cajaCompleter);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PedidoCajeroScreen(
            sucursalId: 'sucursal-prueba',
            menuRepository: menuRepository,
            mesasRepository: mesasRepository,
            cajaRepository: cajaRepository,
            pedidosRepository: _PedidosRepositoryFake(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(menuRepository.llamadas, 1);
    expect(mesasRepository.llamadas, 1);
    expect(cajaRepository.llamadas, 1);

    menuCompleter.complete(
      await _MenuRepositoryFake().obtenerPorSucursal('sucursal-prueba'),
    );
    mesasCompleter.complete([]);
    cajaCompleter.complete(null);
    await tester.pumpAndSettle();

    expect(find.text('Nuevo pedido'), findsOneWidget);
    expect(find.text('Sin productos en esta categoría'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('distingue caja no consultable de caja cerrada', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final caja = _CajaRepositoryError();
    final pedidos = _PedidosRepositoryFake();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PedidoCajeroScreen(
            sucursalId: 'sucursal-prueba',
            menuRepository: _MenuRepositoryFake(conProductos: true),
            mesasRepository: _MesasRepositoryFake(),
            cajaRepository: caja,
            pedidosRepository: pedidos,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
        find.textContaining('No pudimos verificar la caja.'), findsOneWidget);
    expect(find.textContaining('No hay caja abierta.'), findsNothing);
    expect(find.text('Reintentar'), findsOneWidget);
    expect(caja.llamadas, 1);

    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(caja.llamadas, 2);

    await tester.tap(find.text('Arepa'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Agregar ·'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    final confirmar = find.widgetWithText(FilledButton, 'Confirmar pedido →');
    expect(find.text('1 producto'), findsOneWidget);
    await tester.drag(find.text('1 producto'), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(confirmar, findsOneWidget);
    await tester.ensureVisible(confirmar);
    await tester.pumpAndSettle();
    await tester.tap(confirmar);
    await tester.pumpAndSettle();
    expect(find.text('No se pudo verificar la caja. Reintenta la consulta.'),
        findsOneWidget);
    expect(pedidos.creaciones, 0);
    expect(tester.takeException(), isNull);
  });
}
