import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reserva_canchas/features/catalogo/data/catalogo_admin_repository.dart';
import 'package:reserva_canchas/features/catalogo/presentation/menu_admin_screen.dart';
import 'package:reserva_canchas/features/cocinas/data/cocinas_repository.dart';
import 'package:reserva_canchas/features/inventario/data/costeo_repository.dart';

class _CatalogoRepositoryFake extends CatalogoAdminRepository {
  _CatalogoRepositoryFake({this.conProducto = false});

  final bool conProducto;
  bool disponibilidadActual = true;
  int cambiosDisponibilidad = 0;
  bool? ultimaDisponibilidad;
  Object? errorDisponibilidad;
  Completer<void>? disponibilidadPendiente;

  @override
  Future<List<Map<String, dynamic>>> categorias(String sucursalId) async => [
        {
          'id': 'cat1',
          'nombre': 'Hamburguesas artesanales de la casa',
        },
      ];

  @override
  Future<List<Map<String, dynamic>>> productos(String sucursalId) async =>
      conProducto
          ? [
              {
                'id': 'producto-1',
                'nombre': 'Hamburguesa de prueba',
                'precio': 18000,
                'precio_para_llevar': 17000,
                'categoria_id': 'cat1',
                'disponible': disponibilidadActual,
                'cocina_id': 'c1',
              },
            ]
          : [];

  @override
  Future<void> toggleDisponible(String productoId, bool disponible) async {
    cambiosDisponibilidad++;
    ultimaDisponibilidad = disponible;
    if (errorDisponibilidad != null) throw errorDisponibilidad!;
    final pendiente = disponibilidadPendiente;
    if (pendiente != null) await pendiente.future;
    disponibilidadActual = disponible;
  }

  @override
  Future<List<Map<String, dynamic>>> toppings(String sucursalId) async => [];

  @override
  Future<List<Map<String, dynamic>>> bebidas(String sucursalId) async => [];

  @override
  Future<List<Map<String, dynamic>>> combos(String sucursalId) async => [];
}

class _CocinasRepositoryFake extends CocinasRepository {
  @override
  Future<List<Map<String, dynamic>>> listarCocinas(String sucursalId) async => [
        {
          'id': 'c1',
          'nombre': 'Cocina caliente de platos principales',
          'activa': true,
        },
      ];
}

class _CosteoRepositoryFake extends CosteoRepository {
  @override
  Future<Map<String, dynamic>> resumen(String sucursalId) async => {};
}

class _CatalogoConcurrenteFake extends CatalogoAdminRepository {
  final iniciadas = <String>[];
  final categoriasPendientes = Completer<List<Map<String, dynamic>>>();
  final productosPendientes = Completer<List<Map<String, dynamic>>>();
  final toppingsPendientes = Completer<List<Map<String, dynamic>>>();
  final bebidasPendientes = Completer<List<Map<String, dynamic>>>();
  final combosPendientes = Completer<List<Map<String, dynamic>>>();

  @override
  Future<List<Map<String, dynamic>>> categorias(String sucursalId) {
    iniciadas.add('categorias');
    return categoriasPendientes.future;
  }

  @override
  Future<List<Map<String, dynamic>>> productos(String sucursalId) {
    iniciadas.add('productos');
    return productosPendientes.future;
  }

  @override
  Future<List<Map<String, dynamic>>> toppings(String sucursalId) {
    iniciadas.add('toppings');
    return toppingsPendientes.future;
  }

  @override
  Future<List<Map<String, dynamic>>> bebidas(String sucursalId) {
    iniciadas.add('bebidas');
    return bebidasPendientes.future;
  }

  @override
  Future<List<Map<String, dynamic>>> combos(String sucursalId) {
    iniciadas.add('combos');
    return combosPendientes.future;
  }
}

class _CocinasPendientesFake extends CocinasRepository {
  final iniciadas = <String>[];
  final pendientes = Completer<List<Map<String, dynamic>>>();

  @override
  Future<List<Map<String, dynamic>>> listarCocinas(String sucursalId) {
    iniciadas.add('cocinas');
    return pendientes.future;
  }
}

class _CosteoPendienteFake extends CosteoRepository {
  final iniciadas = <String>[];
  final pendiente = Completer<Map<String, dynamic>>();

  @override
  Future<Map<String, dynamic>> resumen(String sucursalId) {
    iniciadas.add('costeo');
    return pendiente.future;
  }
}

void main() {
  testWidgets('carga colecciones en paralelo y no espera el resumen de costeo',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final catalogo = _CatalogoConcurrenteFake();
    final cocinas = _CocinasPendientesFake();
    final costeo = _CosteoPendienteFake();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MenuAdminScreen(
            sucursalId: 's1',
            repository: catalogo,
            cocinasRepository: cocinas,
            costeoRepository: costeo,
          ),
        ),
      ),
    );

    expect(
        catalogo.iniciadas,
        unorderedEquals([
          'categorias',
          'productos',
          'toppings',
          'bebidas',
          'combos',
        ]));
    expect(cocinas.iniciadas, ['cocinas']);
    expect(costeo.iniciadas, ['costeo']);

    catalogo.categoriasPendientes.complete([]);
    catalogo.productosPendientes.complete([]);
    catalogo.toppingsPendientes.complete([]);
    catalogo.bebidasPendientes.complete([]);
    catalogo.combosPendientes.complete([]);
    cocinas.pendientes.complete([]);
    await tester.pumpAndSettle();

    expect(find.textContaining('Productos ('), findsOneWidget);
    expect(find.text('Menú'), findsOneWidget);
    expect(tester.takeException(), isNull);

    costeo.pendiente.complete({});
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('menú de acciones ofrece acceso explícito a editar precios',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MenuAdminScreen(
            sucursalId: 's1',
            repository: _CatalogoRepositoryFake(conProducto: true),
            cocinasRepository: _CocinasRepositoryFake(),
            costeoRepository: _CosteoRepositoryFake(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Editar precios de Hamburguesa de prueba'));
    await tester.pumpAndSettle();

    expect(find.text('Precios'), findsOneWidget);
    expect(find.text('Canales de venta'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(820, 1180),
    const Size(1440, 900),
  ]) {
    testWidgets('menú se adapta a ${size.width}px', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MenuAdminScreen(
              sucursalId: 's1',
              repository: _CatalogoRepositoryFake(),
              cocinasRepository: _CocinasRepositoryFake(),
              costeoRepository: _CosteoRepositoryFake(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Productos ('), findsOneWidget);
      expect(find.textContaining('Toppings ('), findsOneWidget);
      expect(tester.takeException(), isNull);

      if (size.width < 600) {
        await tester.tap(find.byTooltip('Acciones del menú'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Nuevo producto'));
        await tester.pumpAndSettle();
        expect(find.text('Nuevo producto'), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(
          find.text('Hamburguesas artesanales de la casa'),
          findsOneWidget,
        );
        expect(
          find.text('Cocina caliente de platos principales'),
          findsOneWidget,
        );
      }
    });
  }

  for (final size in [
    const Size(390, 844),
    const Size(1440, 900),
  ]) {
    testWidgets(
      'disponibilidad de producto muestra progreso en ${size.width}px',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final catalogo = _CatalogoRepositoryFake(conProducto: true)
          ..disponibilidadPendiente = Completer<void>();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MenuAdminScreen(
                sucursalId: 's1',
                repository: catalogo,
                cocinasRepository: _CocinasRepositoryFake(),
                costeoRepository: _CosteoRepositoryFake(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final switchFinder = find.byKey(
          const ValueKey<String>('producto-disponibilidad-producto-1'),
        );
        expect(switchFinder, findsOneWidget);
        await tester.tap(switchFinder);
        await tester.pump();
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(switchFinder, findsNothing);
        expect(catalogo.cambiosDisponibilidad, 1);

        catalogo.disponibilidadPendiente!.complete();
        await tester.pumpAndSettle();
        expect(catalogo.disponibilidadActual, isFalse);
        expect(catalogo.ultimaDisponibilidad, isFalse);
        expect(switchFinder, findsOneWidget);
        expect(tester.widget<Switch>(switchFinder).value, isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('fallo al cambiar disponibilidad informa y permite reintentar',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final catalogo = _CatalogoRepositoryFake(conProducto: true)
      ..errorDisponibilidad = Exception('API no disponible');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MenuAdminScreen(
            sucursalId: 's1',
            repository: catalogo,
            cocinasRepository: _CocinasRepositoryFake(),
            costeoRepository: _CosteoRepositoryFake(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        const ValueKey<String>('producto-disponibilidad-producto-1'),
      ),
    );
    await tester.pumpAndSettle();

    expect(catalogo.cambiosDisponibilidad, 1);
    expect(catalogo.disponibilidadActual, isTrue);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
    expect(
        tester
            .widget<Switch>(find.byKey(
              const ValueKey<String>('producto-disponibilidad-producto-1'),
            ))
            .value,
        isTrue);

    catalogo.errorDisponibilidad = null;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(catalogo.cambiosDisponibilidad, 2);
    expect(catalogo.disponibilidadActual, isFalse);
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(820, 1180),
    const Size(1440, 900),
  ]) {
    testWidgets('edición de precios cabe en ${size.width}px', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MenuAdminScreen(
              sucursalId: 's1',
              repository: _CatalogoRepositoryFake(conProducto: true),
              cocinasRepository: _CocinasRepositoryFake(),
              costeoRepository: _CosteoRepositoryFake(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hamburguesa de prueba'));
      await tester.pumpAndSettle();

      expect(find.text('Precios'), findsOneWidget);
      expect(find.text('Canales de venta'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('búsqueda sin coincidencias permite volver al catálogo',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: MenuAdminScreen(
            sucursalId: 's1',
            repository: _CatalogoRepositoryFake(conProducto: true),
            cocinasRepository: _CocinasRepositoryFake(),
            costeoRepository: _CosteoRepositoryFake(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Hamburguesa de prueba'), findsOneWidget);

    await tester.enterText(
        find.byType(TextField).first, 'producto inexistente');
    await tester.pump();
    expect(find.text('No encontramos productos'), findsOneWidget);
    expect(find.text('Limpiar búsqueda y filtros'), findsOneWidget);

    await tester.tap(find.text('Limpiar búsqueda y filtros'));
    await tester.pump();
    expect(find.text('Hamburguesa de prueba'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
