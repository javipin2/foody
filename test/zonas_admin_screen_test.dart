import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reserva_canchas/features/zonas/data/zonas_repository.dart';
import 'package:reserva_canchas/features/zonas/presentation/zonas_admin_screen.dart';

class _ZonasRepositoryFake extends ZonasRepository {
  @override
  Future<Map<String, dynamic>> configuracionMapa(String sucursalId) async => {
        'sucursal': {'nombre': 'Sede demo', 'lat': null, 'lng': null},
        'zonas': <Map<String, dynamic>>[],
      };
}

void main() {
  for (final size in [const Size(320, 568), const Size(390, 844)]) {
    testWidgets('formulario de anillo cabe en ${size.width}x${size.height}',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: ZonasAdminScreen(
            sucursalId: 's1',
            repository: _ZonasRepositoryFake(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Anillo'));
      await tester.pumpAndSettle();
      expect(find.text('Radio (km)'), findsOneWidget);
      expect(find.text('Precio domicilio'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
