import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reserva_canchas/features/sucursales/data/sucursales_repository.dart';
import 'package:reserva_canchas/features/sucursales/presentation/horarios_admin_screen.dart';

class _SucursalesRepositoryFake extends SucursalesRepository {
  @override
  Future<List<Map<String, dynamic>>> listarHorarios(String sucursalId) async =>
      [
        {
          'id': 'h1',
          'dia_semana': 1,
          'hora_apertura': '08:00:00',
          'hora_cierre': '22:00:00',
          'activo': true,
        },
      ];

  @override
  Future<Map<String, dynamic>> actualizarHorario(
    String horarioId, {
    String? horaApertura,
    String? horaCierre,
    bool? activo,
  }) async =>
      {'id': horarioId};
}

void main() {
  for (final size in [const Size(320, 568), const Size(390, 844)]) {
    testWidgets('diálogos de horarios caben en ${size.width}x${size.height}',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: HorariosAdminScreen(
            sucursalId: 's1',
            repository: _SucursalesRepositoryFake(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Lunes'), findsOneWidget);
      await tester.tap(find.text('Lunes'));
      await tester.pumpAndSettle();
      expect(
          find.text('Toca una hora para elegirla de la lista'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Apertura'));
      await tester.pumpAndSettle();
      expect(find.text('Elige una hora de la lista'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
