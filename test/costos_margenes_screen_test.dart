import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reserva_canchas/features/catalogo/data/catalogo_admin_repository.dart';
import 'package:reserva_canchas/features/costeo/presentation/costos_margenes_screen.dart';
import 'package:reserva_canchas/features/inventario/data/costeo_repository.dart';
import 'package:reserva_canchas/features/inventario/data/inventario_repository.dart';

class _CosteoRepositoryFake extends CosteoRepository {
  _CosteoRepositoryFake({this.productos = const []});

  final List<Map<String, dynamic>> productos;

  @override
  Future<Map<String, dynamic>> resumen(String sucursalId) async => {
        'productos': productos,
        'bebidas': <Map<String, dynamic>>[],
        'toppings': <Map<String, dynamic>>[],
        'combos': <Map<String, dynamic>>[],
      };

  @override
  Future<List<Map<String, dynamic>>> subrecetas(String sucursalId) async => [];

  @override
  Future<Map<String, dynamic>> impactoStockProducto({
    required String productoId,
    required String sucursalId,
    int cantidad = 1,
    String tipoEntidad = 'producto',
  }) async =>
      {};
}

class _InventarioRepositoryFake extends InventarioRepository {
  _InventarioRepositoryFake({this.insumos = const []});

  final List<Map<String, dynamic>> insumos;

  @override
  Future<List<Map<String, dynamic>>> ingredientes(String sucursalId) async =>
      insumos;

  @override
  Future<Map<String, dynamic>> recetaProducto(
    String productoId, {
    String tipoEntidad = 'producto',
  }) async => {
    'items': [
      {
        'tipo_item': 'ingrediente',
        'ingrediente_id': 'i1',
        'cantidad': 100,
        'unidad': 'g',
      },
    ],
    'margen_error': 0.05,
  };
}

class _CatalogoRepositoryFake extends CatalogoAdminRepository {
  @override
  Future<List<Map<String, dynamic>>> listarItemsIncluidos(
    String productoId,
  ) async =>
      [];
}

void main() {
  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(820, 1180),
    const Size(1440, 900),
  ]) {
    testWidgets('costos y márgenes se adaptan a ${size.width}px',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CostosMargenesScreen(
              sucursalId: 's1',
              onVolverAlMenu: () {},
              costeoRepository: _CosteoRepositoryFake(),
              inventarioRepository: _InventarioRepositoryFake(),
              catalogoRepository: CatalogoAdminRepository(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sin ítems en el menú'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('busqueda sin coincidencias permite recuperar el listado',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CostosMargenesScreen(
            sucursalId: 's1',
            costeoRepository: _CosteoRepositoryFake(
              productos: [
                {
                  'id': 'p1',
                  'nombre': 'Arepa de choclo',
                  'precio': 7000,
                  'tipo_entidad': 'producto',
                },
              ],
            ),
            inventarioRepository: _InventarioRepositoryFake(),
            catalogoRepository: CatalogoAdminRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Arepa de choclo'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.hintText ==
                'Buscar plato, bebida, combo o adicional…',
      ),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField), 'pizza');
    await tester.pumpAndSettle();
    expect(find.text('No encontramos ítems con esos criterios'), findsOneWidget);

    await tester.tap(find.text('Quitar búsqueda y filtros'));
    await tester.pumpAndSettle();
    expect(find.text('Arepa de choclo'), findsOneWidget);
  });

  testWidgets('detalle integra hero, receta, etapas e incluidos sin red',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CostosMargenesScreen(
            sucursalId: 's1',
            onVolverAlMenu: () {},
            costeoRepository: _CosteoRepositoryFake(
              productos: [
                {
                  'id': 'p1',
                  'nombre': 'Arepa de choclo',
                  'precio': 7000,
                  'tipo_entidad': 'producto',
                },
              ],
            ),
            inventarioRepository: _InventarioRepositoryFake(
              insumos: [
                {
                  'id': 'i1',
                  'nombre': 'Maíz',
                  'categoria_insumo': 'ingrediente',
                  'unidad_base': 'g',
                  'costo_real': 12,
                  'stock_actual': 1000,
                  'stock_minimo': 0,
                },
              ],
            ),
            catalogoRepository: _CatalogoRepositoryFake(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Arepa de choclo').first);
    await tester.pumpAndSettle();

    expect(find.text('Arepa de choclo'), findsWidgets);
    expect(find.byKey(const ValueKey('costeo-flujo-receta')), findsOneWidget);
    expect(find.text('Ingredientes'), findsWidgets);
    expect(find.text('Preparaciones'), findsWidgets);
    expect(find.text('Empaques'), findsWidgets);
    expect(find.text('Acompañamientos incluidos'), findsOneWidget);
    expect(find.text('Maíz'), findsOneWidget);
    expect(find.byKey(const ValueKey('costeo-paso-activo-1')), findsOneWidget);
    await tester.tap(find.text('Incluidos').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('costeo-paso-activo-4')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
