import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reserva_canchas/features/sucursales/data/sucursales_repository.dart';
import 'package:reserva_canchas/features/sucursales/presentation/sucursales_admin_screen.dart';

class _SucursalesRepositoryFake extends SucursalesRepository {
  @override
  Future<List<Map<String, dynamic>>> listarMiRestaurante() async => [];

  @override
  Future<Map<String, dynamic>> obtenerMarca() async => {};
}

void main() {
  for (final size in [const Size(320, 568), const Size(390, 844)]) {
    testWidgets('crear sucursal se adapta a ${size.width}x${size.height}',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: SucursalesAdminScreen(
            repository: _SucursalesRepositoryFake(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Nueva'));
      await tester.pumpAndSettle();
      expect(find.text('Dirección (opcional)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
