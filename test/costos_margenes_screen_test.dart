import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reserva_canchas/features/catalogo/data/catalogo_admin_repository.dart';
import 'package:reserva_canchas/features/costeo/presentation/costos_margenes_screen.dart';
import 'package:reserva_canchas/features/inventario/data/costeo_repository.dart';
import 'package:reserva_canchas/features/inventario/data/inventario_repository.dart';

class _CosteoRepositoryFake extends CosteoRepository {
  @override
  Future<Map<String, dynamic>> resumen(String sucursalId) async => {
        'productos': <Map<String, dynamic>>[],
        'bebidas': <Map<String, dynamic>>[],
        'toppings': <Map<String, dynamic>>[],
        'combos': <Map<String, dynamic>>[],
      };

  @override
  Future<List<Map<String, dynamic>>> subrecetas(String sucursalId) async => [];
}

class _InventarioRepositoryFake extends InventarioRepository {
  @override
  Future<List<Map<String, dynamic>>> ingredientes(String sucursalId) async =>
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
}
