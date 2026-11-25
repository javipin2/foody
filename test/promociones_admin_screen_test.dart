import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reserva_canchas/features/menu/data/menu_repository.dart';
import 'package:reserva_canchas/features/menu/domain/menu_model.dart';
import 'package:reserva_canchas/features/promociones/data/promociones_repository.dart';
import 'package:reserva_canchas/features/promociones/presentation/promociones_admin_screen.dart';

class _PromocionesRepositoryFake extends PromocionesRepository {
  @override
  Future<List<Map<String, dynamic>>> listarAdmin(String sucursalId) async => [];
}

class _MenuRepositoryFake extends MenuRepository {
  @override
  Future<MenuModel> obtenerPorSucursal(String sucursalId) async =>
      const MenuModel(
        sucursal: SucursalMenuModel(
          id: 's1',
          nombre: 'Sede demo',
          horarioActivo: true,
        ),
        categorias: [],
        combos: [],
      );
}

void main() {
  for (final size in [const Size(320, 568), const Size(390, 844)]) {
    testWidgets('crear promoción se adapta a ${size.width}px', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: PromocionesAdminScreen(
            sucursalId: 's1',
            repository: _PromocionesRepositoryFake(),
            menuRepository: _MenuRepositoryFake(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Nuevo'));
      await tester.pumpAndSettle();
      expect(find.text('Nuevo estado (24 h)'), findsOneWidget);
      expect(find.text('Producto vinculado (opcional)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
