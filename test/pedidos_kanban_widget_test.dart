import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reserva_canchas/features/admin/data/pedidos_repository.dart';
import 'package:reserva_canchas/features/admin/presentation/widgets/pedidos_kanban_widget.dart';
import 'package:reserva_canchas/features/domiciliarios/data/domiciliarios_repository.dart';
import 'package:reserva_canchas/features/pedidos/domain/pedido_admin_model.dart';
import 'package:reserva_canchas/features/pedidos/domain/pedido_item_resumen.dart';
import 'package:reserva_canchas/features/pedidos/presentation/pedido_detalle_sheet.dart';
import 'package:reserva_canchas/features/pedidos/presentation/widgets/pedido_kanban_card.dart';
import 'package:reserva_canchas/core/sesion/sesion_staff_service.dart';
import 'package:reserva_canchas/services/app_backend.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _guardarSesionStaff(List<String> permisos) async {
  final exp =
      DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
          1000;
  final payload = base64Url
      .encode(utf8.encode(jsonEncode({'exp': exp})))
      .replaceAll('=', '');
  await SesionStaffService.guardar(
    token: 'header.$payload.signature',
    dashboard: 'restaurante',
    rol: 'cajero',
    permisos: permisos,
    usuario: const {'id': 'user-1', 'sucursal_id': 'sucursal-1'},
  );
}

class _PedidosRepositoryFake extends PedidosRepository {
  _PedidosRepositoryFake({
    this.pedidos = const [],
    this.pedidosPaginaDos = const [],
    this.totalActivos,
    this.fallarCerrados = false,
  });

  final List<PedidoAdminModel> pedidos;
  final List<PedidoAdminModel> pedidosPaginaDos;
  final int? totalActivos;
  bool fallarCerrados;
  int llamadasCerrados = 0;
  int llamadasCambiarEstado = 0;
  String? ultimoEstadoActualizado;

  @override
  Future<List<PedidoAdminModel>> listarActivos({
    String? sucursalId,
    String? meseraId,
    int limit = 100,
  }) async =>
      pedidos;

  @override
  Future<({List<PedidoAdminModel> items, int total, bool hayMas})>
      listarActivosPaginado({
    String? sucursalId,
    String? meseraId,
    int page = 1,
    int limit = 100,
  }) async =>
          (
            items: page == 1 ? pedidos : pedidosPaginaDos,
            total: totalActivos ?? pedidos.length + pedidosPaginaDos.length,
            hayMas: page == 1 && pedidosPaginaDos.isNotEmpty,
          );

  @override
  Future<({List<PedidoAdminModel> items, int total, bool hayMas})>
      listarCerradosHoy({
    String? sucursalId,
    String? meseraId,
    int page = 1,
    int limit = 30,
  }) async {
    llamadasCerrados++;
    if (fallarCerrados) throw Exception('sin conexión');
    return (items: <PedidoAdminModel>[], total: 0, hayMas: false);
  }

  @override
  Future<Map<String, dynamic>?> cambiarEstado({
    required String pedidoId,
    required String estado,
    String? sucursalId,
    String? motivo,
  }) async {
    llamadasCambiarEstado++;
    ultimoEstadoActualizado = estado;
    return null;
  }

  @override
  Future<PedidoAdminModel> obtenerDetalle({
    required String pedidoId,
    String? sucursalId,
  }) async =>
      pedidos.firstWhere((pedido) => pedido.id == pedidoId);
}

class _DomiciliariosRepositoryFake extends DomiciliariosRepository {
  @override
  Future<List<Map<String, dynamic>>> listarDisponibles(
    String sucursalId,
  ) async =>
      [];
}

void main() {
  for (final width in [320.0, 390.0, 820.0, 1440.0]) {
    testWidgets('pedidos se adaptan a ${width}px', (tester) async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      AppBackend.supabaseReady = false;
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(() => AppBackend.supabaseReady = false);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData(useMaterial3: true),
            home: Scaffold(
              body: PedidosKanbanWidget(
                sucursalId: 'sucursal-1',
                repository: _PedidosRepositoryFake(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      for (var i = 0;
          i < 20 &&
              find.textContaining('No hay pedidos en ').evaluate().isEmpty;
          i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.text('Pedidos'), findsOneWidget);
      expect(find.textContaining('No hay pedidos en '), findsOneWidget);
      final filtroCanal = find.byKey(
        const ValueKey<String>('pedidos-channel-filter'),
      );
      if (width < 720) {
        expect(
          find.descendant(
            of: filtroCanal,
            matching: find.byType(SingleChildScrollView),
          ),
          findsOneWidget,
        );
        expect(
          tester.getTopLeft(find.text('Todos')).dy,
          tester.getTopLeft(find.text('Para llevar')).dy,
        );
      }
      if (width >= 720) {
        await tester.tap(find.byTooltip('Vista columnas'));
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('tablero de pedidos muestra tarjeta y acción primaria',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await _guardarSesionStaff(const ['ver_pedidos', 'crear_pedido']);
    AppBackend.supabaseReady = false;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() => AppBackend.supabaseReady = false);
    final ahora = DateTime.now();

    final repo = _PedidosRepositoryFake(
      pedidos: [
        PedidoAdminModel(
          id: 'pedido-1',
          numeroPedido: 'P-001',
          tipo: 'mesa',
          estado: 'pendiente',
          mesaNombre: 'Mesa 4',
          total: 42000,
          creadoEn: ahora,
          estadoDesde: ahora,
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: PedidosKanbanWidget(
              sucursalId: 'sucursal-1',
              repository: repo,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    for (var i = 0; i < 20 && find.text('#P-001').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.text('Mesa 4'), findsOneWidget);
    expect(find.text('#P-001'), findsOneWidget);
    expect(find.text('A cocina →'), findsOneWidget);
    expect(find.text('Valor en pedidos'), findsOneWidget);
    final kpiValor = find.byTooltip(
      'Suma del valor total de pedidos activos; no equivale a dinero cobrado.',
    );
    expect(kpiValor, findsOneWidget);
    expect(
      find.descendant(
        of: kpiValor,
        matching: find.textContaining('42.000'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('A cocina →'));
    await tester.pumpAndSettle();
    expect(repo.ultimoEstadoActualizado, 'en_cocina');
    expect(find.text('P-001 actualizado: En cocina'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('perfil de solo lectura no ve acciones mutables del pedido',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await _guardarSesionStaff(const ['ver_pedidos']);
    AppBackend.supabaseReady = false;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() => AppBackend.supabaseReady = false);
    final ahora = DateTime.now();

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: PedidosKanbanWidget(
              sucursalId: 'sucursal-1',
              repository: _PedidosRepositoryFake(
                pedidos: [
                  PedidoAdminModel(
                    id: 'pedido-lectura',
                    numeroPedido: 'P-LECTURA',
                    tipo: 'mesa',
                    estado: 'pendiente',
                    mesaNombre: 'Mesa 9',
                    total: 18000,
                    creadoEn: ahora,
                    estadoDesde: ahora,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    for (var i = 0; i < 20 && find.text('#P-LECTURA').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.text('#P-LECTURA'), findsOneWidget);
    expect(find.text('A cocina →'), findsNothing);
    await tester.tap(find.byType(PedidoKanbanCard));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    for (var i = 0; i < 20 && find.text('Productos').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final detalle = find.byType(PedidoDetalleSheet);
    expect(detalle, findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Acciones'),
      200,
      scrollable: find
          .descendant(
            of: detalle,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Cancelar pedido'), findsNothing);
    expect(find.text('A cocina'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cajero no ve cancelar en un pedido pendiente de más de 2 min',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await _guardarSesionStaff(const ['ver_pedidos', 'crear_pedido']);
    AppBackend.supabaseReady = false;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() => AppBackend.supabaseReady = false);
    final ahora = DateTime.now();
    final creadoHaceTresMinutos = ahora.subtract(const Duration(minutes: 3));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: PedidosKanbanWidget(
              sucursalId: 'sucursal-1',
              repository: _PedidosRepositoryFake(
                pedidos: [
                  PedidoAdminModel(
                    id: 'pedido-antiguo',
                    numeroPedido: 'P-ANTIGUO',
                    tipo: 'mesa',
                    estado: 'pendiente',
                    mesaNombre: 'Mesa 10',
                    total: 18000,
                    creadoEn: creadoHaceTresMinutos,
                    estadoDesde: creadoHaceTresMinutos,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    for (var i = 0; i < 20 && find.text('#P-ANTIGUO').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('A cocina →'), findsOneWidget);

    await tester.tap(find.byType(PedidoKanbanCard));
    await tester.pump();
    for (var i = 0; i < 20 && find.text('Productos').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final detalle = find.byType(PedidoDetalleSheet);
    await tester.scrollUntilVisible(
      find.text('Acciones'),
      200,
      scrollable: find
          .descendant(
            of: detalle,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Cancelar pedido'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no ofrece asignar domicilio con cocina incompleta',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await _guardarSesionStaff(
      const ['ver_pedidos', 'gestionar_domiciliarios'],
    );
    AppBackend.supabaseReady = false;
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() => AppBackend.supabaseReady = false);
    final ahora = DateTime.now();
    final pedido = PedidoAdminModel(
      id: 'pedido-dom-cocina',
      numeroPedido: 'P-DOM-COCINA',
      tipo: 'domicilio',
      estado: 'listo',
      total: 24000,
      creadoEn: ahora,
      estadoDesde: ahora,
      itemsResumen: const [
        PedidoItemResumen(
          itemId: 'item-pendiente',
          nombre: 'Producto en preparación',
          cantidad: 1,
          estadoCocina: 'preparando',
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: PedidosKanbanWidget(
              sucursalId: 'sucursal-1',
              repository: _PedidosRepositoryFake(pedidos: [pedido]),
              domiciliariosRepository: _DomiciliariosRepositoryFake(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    if (find.text('Listos').evaluate().isNotEmpty) {
      await tester.tap(find.text('Listos').first);
      await tester.pump();
    }
    for (var i = 0;
        i < 20 && find.text('#P-DOM-COCINA').evaluate().isEmpty;
        i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.tap(find.byType(PedidoKanbanCard));
    await tester.pump();
    for (var i = 0; i < 20 && find.text('Productos').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final aviso = find.byKey(
      const ValueKey('pedido-domicilio-bloqueado-cocina'),
    );
    await tester.scrollUntilVisible(
      aviso,
      200,
      scrollable: find
          .descendant(
            of: find.byType(PedidoDetalleSheet),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(aviso, findsOneWidget);
    expect(
      find.textContaining('pendientes en Cocina'),
      findsOneWidget,
    );
    expect(find.text('Asignar domiciliario'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('entrega manual pendiente exige confirmar efectivo recibido',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await _guardarSesionStaff(const ['ver_pedidos', 'crear_pedido']);
    AppBackend.supabaseReady = false;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() => AppBackend.supabaseReady = false);
    final ahora = DateTime.now();
    final repo = _PedidosRepositoryFake(
      pedidos: [
        PedidoAdminModel(
          id: 'pedido-domicilio',
          numeroPedido: 'P-DOM-1',
          tipo: 'domicilio',
          estado: 'en_camino',
          direccionEntrega: 'Calle 10',
          metodoPago: 'pendiente',
          total: 25000,
          creadoEn: ahora,
          estadoDesde: ahora,
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: PedidosKanbanWidget(
              sucursalId: 'sucursal-1',
              repository: repo,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    for (var i = 0; i < 20 && find.text('#P-DOM-1').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    await tester.ensureVisible(find.text('Cobro / Ruta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cobro / Ruta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Entregado →'));
    await tester.pumpAndSettle();
    expect(find.text('Confirmar cobro en efectivo'), findsOneWidget);
    expect(repo.llamadasCambiarEstado, 0);
    await tester.tap(find.text('Volver'));
    await tester.pumpAndSettle();
    expect(repo.llamadasCambiarEstado, 0);

    await tester.tap(find.text('Cobro / Ruta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Entregado →'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sí, recibí el efectivo'));
    await tester.pumpAndSettle();
    expect(repo.llamadasCambiarEstado, 1);
    expect(repo.ultimoEstadoActualizado, 'entregado');
    expect(tester.takeException(), isNull);
  });

  testWidgets('pedidos activos cargan páginas y muestran total global',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    AppBackend.supabaseReady = false;
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() => AppBackend.supabaseReady = false);
    final ahora = DateTime.now();
    final repo = _PedidosRepositoryFake(
      pedidos: [
        PedidoAdminModel(
          id: 'pedido-reciente',
          numeroPedido: 'P-REC',
          tipo: 'mesa',
          estado: 'pendiente',
          mesaNombre: 'Mesa 1',
          total: 10000,
          creadoEn: ahora,
          estadoDesde: ahora,
        ),
      ],
      pedidosPaginaDos: [
        PedidoAdminModel(
          id: 'pedido-antiguo',
          numeroPedido: 'P-ANT',
          tipo: 'mesa',
          estado: 'pendiente',
          mesaNombre: 'Mesa 2',
          total: 20000,
          creadoEn: ahora.subtract(const Duration(days: 1)),
          estadoDesde: ahora.subtract(const Duration(days: 1)),
        ),
      ],
      totalActivos: 101,
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: PedidosKanbanWidget(
              sucursalId: 'sucursal-1',
              repository: repo,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    for (var i = 0; i < 20 && find.text('#P-REC').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.text('101'), findsOneWidget);
    expect(find.text('Mostrando 1 de 101 pedidos activos'), findsOneWidget);
    expect(find.text('#P-ANT'), findsNothing);

    await tester.tap(find.text('Cargar más'));
    await tester.pumpAndSettle();
    expect(find.text('#P-ANT'), findsOneWidget);
    expect(find.text('Mostrando 2 de 101 pedidos activos'), findsOneWidget);
    expect(find.text('Valor cargado'), findsNothing);
    await tester.tap(find.byTooltip('Vista columnas'));
    await tester.pumpAndSettle();
    expect(find.text('Mostrando 2 de 101 pedidos activos'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('vacío por filtro permite recuperar la lista en móvil',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    AppBackend.supabaseReady = false;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() => AppBackend.supabaseReady = false);
    final ahora = DateTime.now();

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: PedidosKanbanWidget(
              sucursalId: 'sucursal-1',
              repository: _PedidosRepositoryFake(
                pedidos: [
                  PedidoAdminModel(
                    id: 'pedido-1',
                    numeroPedido: 'P-001',
                    tipo: 'mesa',
                    estado: 'pendiente',
                    mesaNombre: 'Mesa 4',
                    total: 42000,
                    creadoEn: ahora,
                    estadoDesde: ahora,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    for (var i = 0; i < 20 && find.text('Mesa 4').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    await tester.tap(find.text('Domicilio'));
    await tester.pump();
    expect(find.text('No encontramos pedidos'), findsOneWidget);
    expect(find.text('Limpiar filtros'), findsOneWidget);

    await tester.tap(find.text('Limpiar filtros'));
    await tester.pump();
    expect(find.text('Mesa 4'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cerrados distingue fallo de carga de una lista vacía', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    AppBackend.supabaseReady = false;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() => AppBackend.supabaseReady = false);
    final repo = _PedidosRepositoryFake(fallarCerrados: true);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: PedidosKanbanWidget(
              sucursalId: 'sucursal-1',
              repository: repo,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    for (var i = 0;
        i < 20 && find.textContaining('No hay pedidos en ').evaluate().isEmpty;
        i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    await tester.ensureVisible(find.text('Cerrados'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cerrados'));
    await tester.pumpAndSettle();
    expect(find.text('Reintentar'), findsOneWidget);
    expect(find.text('No hay pedidos en Cerrados'), findsNothing);
    expect(repo.llamadasCerrados, 1);

    repo.fallarCerrados = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(repo.llamadasCerrados, 2);
    expect(find.text('No hay pedidos en Cerrados'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
