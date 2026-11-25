import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reserva_canchas/features/inventario/data/costeo_repository.dart';
import 'package:reserva_canchas/features/inventario/data/inventario_repository.dart';
import 'package:reserva_canchas/features/inventario/presentation/inventario_admin_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _InventarioRepositoryFake extends InventarioRepository {
  @override
  Future<List<Map<String, dynamic>>> ingredientes(String sucursalId) async => [
        {
          'id': 'ingrediente-1',
          'nombre': 'Azúcar morena',
          'categoria_insumo': 'Abarrotes',
          'stock_actual': 12,
          'stock_minimo': 3,
          'unidad_base': 'kg',
          'costo_real': 4500,
          'precio_compra': 4000,
          'descontar_stock': true,
          'bajo_minimo': false,
        },
      ];

  @override
  Future<({List<Map<String, dynamic>> items, int total, bool hayMas})>
      movimientosPaginados(
    String sucursalId, {
    int page = 1,
    int limit = 50,
  }) async =>
          (items: <Map<String, dynamic>>[], total: 0, hayMas: false);
}

class _CosteoRepositoryFake extends CosteoRepository {
  @override
  Future<List<Map<String, dynamic>>> subrecetas(String sucursalId) async => [];
}

void main() {
  testWidgets('búsqueda sin coincidencias permite recuperar inventario',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: InventarioAdminScreen(
            sucursalId: 's1',
            repository: _InventarioRepositoryFake(),
            costeoRepository: _CosteoRepositoryFake(),
          ),
        ),
      ),
    );
    for (var i = 0;
        i < 20 && find.text('Azúcar morena').evaluate().isEmpty;
        i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('Azúcar morena'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.enterText(find.byType(TextField).first, 'insumo inexistente');
    await tester.pump();
    expect(find.text('No encontramos insumos'), findsOneWidget);
    expect(find.text('Limpiar búsqueda y filtros'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.text('Limpiar búsqueda y filtros'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Limpiar búsqueda y filtros'));
    await tester.pump();
    expect(find.text('Azúcar morena'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
