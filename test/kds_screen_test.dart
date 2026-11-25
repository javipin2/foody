import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reserva_canchas/features/cocinas/data/cocinas_repository.dart';
import 'package:reserva_canchas/features/cocinas/presentation/kds_screen.dart';
import 'package:reserva_canchas/services/app_backend.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _CocinasRepositoryFake extends CocinasRepository {
  _CocinasRepositoryFake({
    this.listaTickets = const [],
    this.fallarTickets = false,
    this.itemQueFalla,
  });

  final List<Map<String, dynamic>> listaTickets;
  bool fallarTickets;
  final String? itemQueFalla;
  int fallosPreparacion = 0;
  int reimpresiones = 0;
  int lecturasTickets = 0;
  final List<String> cambiosEstado = [];

  @override
  Future<List<Map<String, dynamic>>> listarCocinas(String sucursalId) async => [
        {'id': 'cocina-1', 'nombre': 'Cocina principal'},
      ];

  @override
  Future<List<Map<String, dynamic>>> cocinasParaKds() async => [
        {'id': 'cocina-1', 'nombre': 'Cocina principal'},
      ];

  @override
  Future<List<Map<String, dynamic>>> tickets(String cocinaId) async {
    lecturasTickets++;
    if (fallarTickets) throw Exception('API no disponible');
    return listaTickets;
  }

  @override
  Future<void> cambiarEstadoItem({
    required String itemId,
    required String estadoCocina,
    String? motivo,
  }) async {
    cambiosEstado.add(itemId);
    if (itemId == itemQueFalla) throw Exception('Fallo de prueba');
    for (final ticket in listaTickets) {
      final items = ticket['items'];
      if (items is! List) continue;
      for (final raw in items) {
        if (raw is Map && raw['item_id'] == itemId) {
          raw['estado_cocina'] = estadoCocina;
        }
      }
    }
  }

  @override
  Future<void> prepararCanalRealtimeCocina({
    required String cocinaId,
    String? sucursalId,
  }) async {}

  @override
  Future<void> falloPreparacion({
    required String itemId,
    required String motivo,
  }) async {
    fallosPreparacion++;
  }

  @override
  Future<void> reimprimirPedido({
    required String pedidoId,
    String? sucursalId,
  }) async {
    reimpresiones++;
  }
}

void main() {
  for (final size in [
    const Size(320, 640),
    const Size(390, 844),
    const Size(820, 900),
    const Size(1440, 900),
  ]) {
    testWidgets('KDS carga con sondeo de respaldo a ${size.width}px',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      AppBackend.supabaseReady = false;
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(() => AppBackend.supabaseReady = false);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: KdsScreen(
              sucursalId: 'sucursal-1',
              repository: _CocinasRepositoryFake(),
            ),
          ),
        ),
      );
      // KDS mantiene un reloj de refresco periódico y un spinner animado;
      // avanzar dos frames permite terminar la carga sin esperar esos timers.
      await tester.pump();
      for (var i = 0;
          i < 60 &&
              find.text('Nada en cocina').evaluate().isEmpty &&
              find.text('Reintentar').evaluate().isEmpty;
          i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Nada en cocina'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final size in [
    const Size(320, 640),
    const Size(390, 844),
    const Size(820, 900),
    const Size(1440, 900),
  ]) {
    testWidgets('tarjeta KDS con acciones cabe en ${size.width}px',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      AppBackend.supabaseReady = false;
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(() => AppBackend.supabaseReady = false);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: KdsScreen(
              sucursalId: 'sucursal-1',
              repository: _CocinasRepositoryFake(
                listaTickets: [
                  {
                    'pedido_id': 'pedido-1',
                    'numero_pedido': 'P-0001',
                    'tipo': 'domicilio',
                    'estado': 'en_cocina',
                    'cocina_desde': DateTime.now().toIso8601String(),
                    'cliente_nombre': 'Cliente con nombre largo de prueba',
                    'observaciones': 'Empacar aparte y llamar al llegar',
                    'items': [
                      {
                        'item_id': 'item-1',
                        'cantidad': 2,
                        'producto':
                            'Hamburguesa especial con queso y tocineta extra',
                        'estado_cocina': 'pendiente',
                        'observaciones': 'Sin cebolla, urgente',
                        'incluidos': [],
                      },
                    ],
                  },
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      for (var i = 0; i < 60 && find.text('P-0001').evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.text('P-0001'), findsOneWidget);
      final listo = find.widgetWithText(FilledButton, 'Marcar listo');
      expect(listo, findsOneWidget);
      expect(tester.getSize(listo).height, greaterThanOrEqualTo(48));
      final preparando = find.byTooltip('Preparando');
      expect(preparando, findsOneWidget);
      expect(tester.getSize(preparando).height, greaterThanOrEqualTo(48));
      expect(find.byTooltip('Nota cocina'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('KDS conserva los estados nulos como pendientes operativos',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    AppBackend.supabaseReady = false;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() => AppBackend.supabaseReady = false);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: KdsScreen(
            sucursalId: 'sucursal-1',
            repository: _CocinasRepositoryFake(
              listaTickets: [
                {
                  'pedido_id': 'pedido-estado-nulo',
                  'numero_pedido': 'P-NULL',
                  'tipo': 'mesa',
                  'estado': 'en_cocina',
                  'cocina_desde': DateTime.now().toIso8601String(),
                  'items': [
                    {
                      'item_id': 'item-estado-nulo',
                      'cantidad': 1,
                      'producto': 'Ítem heredado',
                      'estado_cocina': null,
                      'incluidos': [],
                    },
                  ],
                },
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    for (var i = 0; i < 60 && find.text('P-NULL').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('P-NULL'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Marcar listo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('KDS permite terminar una línea ya cobrada sin ocultarla antes',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    AppBackend.supabaseReady = false;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() => AppBackend.supabaseReady = false);
    final repository = _CocinasRepositoryFake(
      listaTickets: [
        {
          'pedido_id': 'pedido-pagado-cocina-pendiente',
          'numero_pedido': 'P-COBRADO',
          'tipo': 'mesa',
          'estado': 'pagado',
          'cocina_desde': DateTime.now().toIso8601String(),
          'items': [
            {
              'item_id': 'item-cobrado-pendiente',
              'cantidad': 1,
              'producto': 'Plato ya cobrado',
              'estado_cocina': 'preparando',
              'incluidos': [],
            },
          ],
        },
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: KdsScreen(
            sucursalId: 'sucursal-1',
            repository: repository,
          ),
        ),
      ),
    );
    await tester.pump();
    for (var i = 0; i < 60 && find.text('P-COBRADO').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('P-COBRADO'), findsOneWidget);
    expect(find.text('Cobrado'), findsOneWidget);
    final listo = find.widgetWithText(FilledButton, 'Marcar listo');
    expect(listo, findsOneWidget);
    await tester.tap(listo);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(repository.cambiosEstado, ['item-cobrado-pendiente']);
    expect(find.text('P-COBRADO'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('antigüedad extensa de KDS se muestra en días y horas',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    AppBackend.supabaseReady = false;
    addTearDown(() => AppBackend.supabaseReady = false);
    final desde = DateTime.now().subtract(const Duration(days: 112, hours: 3));

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: KdsScreen(
            sucursalId: 'sucursal-1',
            repository: _CocinasRepositoryFake(
              listaTickets: [
                {
                  'pedido_id': 'pedido-antiguo',
                  'numero_pedido': 'P-ANTIGUO',
                  'tipo': 'mesa',
                  'estado': 'en_cocina',
                  'cocina_desde': desde.toIso8601String(),
                  'items': [
                    {
                      'item_id': 'item-antiguo',
                      'cantidad': 1,
                      'producto': 'Pedido de prueba',
                      'estado_cocina': 'pendiente',
                      'incluidos': [],
                    },
                  ],
                },
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    for (var i = 0; i < 60 && find.text('P-ANTIGUO').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('112d 3h'), findsOneWidget);
    expect(find.textContaining('2691h'), findsNothing);
    expect(find.text('Marcar listo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'KDS distingue error inicial de una cocina vacía y permite reintentar',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    AppBackend.supabaseReady = false;
    addTearDown(() => AppBackend.supabaseReady = false);
    final repository = _CocinasRepositoryFake(fallarTickets: true);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: KdsScreen(sucursalId: 'sucursal-1', repository: repository),
        ),
      ),
    );
    for (var i = 0; i < 60 && find.text('Reintentar').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Nada en cocina'), findsNothing);
    expect(find.text('API no disponible'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);

    repository.fallarTickets = false;
    await tester.tap(find.text('Reintentar'));
    for (var i = 0;
        i < 60 && find.text('Nada en cocina').evaluate().isEmpty;
        i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Nada en cocina'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('KDS exige motivo antes de registrar fallo de preparación',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    AppBackend.supabaseReady = false;
    addTearDown(() => AppBackend.supabaseReady = false);
    final repository = _CocinasRepositoryFake(
      listaTickets: [
        {
          'pedido_id': 'pedido-1',
          'numero_pedido': 'P-0001',
          'tipo': 'mesa',
          'estado': 'en_cocina',
          'cocina_desde': DateTime.now().toIso8601String(),
          'items': [
            {
              'item_id': 'item-1',
              'cantidad': 1,
              'producto': 'Plato de prueba',
              'estado_cocina': 'pendiente',
              'incluidos': [],
            },
          ],
        },
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: KdsScreen(sucursalId: 'sucursal-1', repository: repository),
        ),
      ),
    );
    for (var i = 0; i < 60 && find.text('P-0001').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    await tester.tap(find.byTooltip('Fallo / No se pudo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();

    expect(find.text('Escribe el motivo para continuar.'), findsOneWidget);
    expect(repository.fallosPreparacion, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Todo listo refresca y explica un fallo parcial', (tester) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    AppBackend.supabaseReady = false;
    addTearDown(() => AppBackend.supabaseReady = false);
    final repository = _CocinasRepositoryFake(
      itemQueFalla: 'item-2',
      listaTickets: [
        {
          'pedido_id': 'pedido-lote',
          'numero_pedido': 'P-LOTE',
          'tipo': 'mesa',
          'estado': 'en_cocina',
          'cocina_desde': DateTime.now().toIso8601String(),
          'items': [
            {
              'item_id': 'item-1',
              'cantidad': 1,
              'producto': 'Primero',
              'estado_cocina': 'pendiente',
              'incluidos': [],
            },
            {
              'item_id': 'item-2',
              'cantidad': 1,
              'producto': 'Falla al actualizar',
              'estado_cocina': 'pendiente',
              'incluidos': [],
            },
            {
              'item_id': 'item-3',
              'cantidad': 1,
              'producto': 'Tercero',
              'estado_cocina': 'pendiente',
              'incluidos': [],
            },
          ],
        },
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: KdsScreen(sucursalId: 'sucursal-1', repository: repository),
        ),
      ),
    );
    for (var i = 0; i < 60 && find.text('P-LOTE').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    await tester.tap(find.byKey(const ValueKey<String>('kds-mark-all-ready')));
    for (var i = 0;
        i < 60 && find.textContaining('Se confirmaron').evaluate().isEmpty;
        i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(repository.cambiosEstado, ['item-1', 'item-2']);
    expect(repository.lecturasTickets, 2);
    expect(
        repository.listaTickets.single['items'][0]['estado_cocina'], 'listo');
    expect(repository.listaTickets.single['items'][2]['estado_cocina'],
        'pendiente');
    expect(find.textContaining('Se confirmaron 1 de 3 ítems'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('kds-mark-all-ready')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Volver a cocina recupera y explica un fallo parcial',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    AppBackend.supabaseReady = false;
    addTearDown(() => AppBackend.supabaseReady = false);
    final repository = _CocinasRepositoryFake(
      itemQueFalla: 'item-2',
      listaTickets: [
        {
          'pedido_id': 'pedido-reversion',
          'numero_pedido': 'P-REV',
          'tipo': 'mesa',
          'estado': 'en_cocina',
          'cocina_desde': DateTime.now().toIso8601String(),
          'items': [
            {
              'item_id': 'item-1',
              'cantidad': 1,
              'producto': 'Primero',
              'estado_cocina': 'listo',
              'incluidos': [],
            },
            {
              'item_id': 'item-2',
              'cantidad': 1,
              'producto': 'Falla al devolver',
              'estado_cocina': 'listo',
              'incluidos': [],
            },
            {
              'item_id': 'item-3',
              'cantidad': 1,
              'producto': 'Tercero',
              'estado_cocina': 'listo',
              'incluidos': [],
            },
          ],
        },
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: KdsScreen(sucursalId: 'sucursal-1', repository: repository),
        ),
      ),
    );
    for (var i = 0; i < 60 && find.text('P-REV').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.text('Listos').first);
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey<String>('kds-return-to-kitchen')),
    );
    for (var i = 0;
        i < 60 && find.textContaining('Se devolvieron').evaluate().isEmpty;
        i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(repository.cambiosEstado, ['item-1', 'item-2']);
    expect(repository.lecturasTickets, 2);
    expect(repository.listaTickets.single['items'][0]['estado_cocina'],
        'preparando');
    expect(
        repository.listaTickets.single['items'][2]['estado_cocina'], 'listo');
    expect(find.textContaining('Se devolvieron 1 de 3 ítems'), findsOneWidget);
    expect(find.text('P-REV'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('kds-return-to-kitchen')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Listos muestra antigüedad del pedido sin llamarla demora de cocina',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    AppBackend.supabaseReady = false;
    addTearDown(() => AppBackend.supabaseReady = false);
    final repository = _CocinasRepositoryFake(
      listaTickets: [
        {
          'pedido_id': 'pedido-listo-antiguo',
          'numero_pedido': 'P-LISTO-ANTIGUO',
          'tipo': 'para_llevar',
          'estado': 'listo',
          'created_at': DateTime.now()
              .subtract(const Duration(hours: 27))
              .toIso8601String(),
          'cocina_desde': DateTime.now()
              .subtract(const Duration(hours: 26))
              .toIso8601String(),
          'items': [
            {
              'item_id': 'item-listo-antiguo',
              'cantidad': 1,
              'producto': 'Producto listo',
              'estado_cocina': 'listo',
              'incluidos': [],
            },
          ],
        },
        {
          'pedido_id': 'pedido-listo-muy-antiguo',
          'numero_pedido': 'P-LISTO-MUY-ANTIGUO',
          'tipo': 'para_llevar',
          'estado': 'listo',
          'created_at': DateTime.now()
              .subtract(const Duration(days: 113, hours: 9))
              .toIso8601String(),
          'cocina_desde': DateTime.now()
              .subtract(const Duration(days: 113, hours: 8))
              .toIso8601String(),
          'items': [
            {
              'item_id': 'item-listo-muy-antiguo',
              'cantidad': 1,
              'producto': 'Producto listo antiguo',
              'estado_cocina': 'listo',
              'incluidos': [],
            },
          ],
        },
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: KdsScreen(sucursalId: 'sucursal-1', repository: repository),
        ),
      ),
    );
    for (var i = 0;
        i < 60 && find.text('P-LISTO-ANTIGUO').evaluate().isEmpty;
        i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.text('Listos').first);
    await tester.pump();

    expect(find.text('Pedido 1d 3h'), findsOneWidget);
    expect(
        find.byKey(
            const ValueKey<String>('kds-ready-order-age-P-LISTO-ANTIGUO')),
        findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(
            const ValueKey<String>('kds-ready-order-age-P-LISTO-ANTIGUO')),
        matching: find.byIcon(Icons.schedule),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Icon>(
            find.descendant(
              of: find.byKey(const ValueKey<String>(
                  'kds-ready-order-age-P-LISTO-ANTIGUO')),
              matching: find.byIcon(Icons.schedule),
            ),
          )
          .color,
      const Color(0xFFD97706),
    );
    expect(find.text('Pedido 113d 9h'), findsOneWidget);
    expect(
      tester
          .widget<Icon>(
            find.descendant(
              of: find.byKey(const ValueKey<String>(
                  'kds-ready-order-age-P-LISTO-MUY-ANTIGUO')),
              matching: find.byIcon(Icons.schedule),
            ),
          )
          .color,
      const Color(0xFFDC2626),
    );
    expect(find.text('P-LISTO-ANTIGUO'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Reimprimir exige confirmación y permite cancelar sin efecto',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    AppBackend.supabaseReady = false;
    addTearDown(() => AppBackend.supabaseReady = false);
    final repository = _CocinasRepositoryFake(
      listaTickets: [
        {
          'pedido_id': 'pedido-reimpresion',
          'numero_pedido': 'P-REIMP',
          'tipo': 'mesa',
          'estado': 'en_cocina',
          'cocina_desde': DateTime.now().toIso8601String(),
          'items': [
            {
              'item_id': 'item-reimpresion',
              'cantidad': 1,
              'producto': 'Producto de prueba',
              'estado_cocina': 'pendiente',
              'incluidos': [],
            },
          ],
        },
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: KdsScreen(sucursalId: 'sucursal-1', repository: repository),
        ),
      ),
    );
    for (var i = 0; i < 60 && find.text('P-REIMP').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    await tester.tap(find.text('Reimprimir').first);
    await tester.pump();
    expect(find.text('¿Reimprimir esta comanda?'), findsOneWidget);
    expect(repository.reimpresiones, 0);
    await tester.tap(find.text('Cancelar'));
    await tester.pump();
    expect(repository.reimpresiones, 0);

    await tester.tap(find.text('Reimprimir').first);
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Reimprimir'));
    await tester.pump();
    expect(repository.reimpresiones, 1);
    expect(tester.takeException(), isNull);
  });
}
