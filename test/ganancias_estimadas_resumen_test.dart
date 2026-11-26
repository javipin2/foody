import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reserva_canchas/features/domiciliarios/presentation/widgets/ganancias_estimadas_resumen.dart';

void main() {
  for (final size in const [
    Size(320, 640),
    Size(390, 844),
    Size(820, 1180),
    Size(1440, 1000),
  ]) {
    for (final tema in [
      ('claro', Brightness.light),
      ('oscuro', Brightness.dark),
    ]) {
      testWidgets(
        'resumen de ganancias se adapta a ${size.width}px en tema ${tema.$1}',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(
                colorScheme: ColorScheme.fromSeed(
                  seedColor: const Color(0xFFFF6B35),
                  brightness: tema.$2,
                ),
              ),
              home: const Scaffold(
                body: SingleChildScrollView(
                  child: GananciasEstimadasResumen(total: 27200, registros: 4),
                ),
              ),
            ),
          );

          expect(find.text('Ganancia estimada'), findsOneWidget);
          expect(find.textContaining('27.200'), findsOneWidget);
          expect(
              find.textContaining('4 registros de asignación'), findsOneWidget);
          expect(find.textContaining('Puede incluir pedidos cancelados'),
              findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('explica cuando el resumen supera la lista visible',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GananciasEstimadasResumen(
            total: 27200,
            registros: 145,
            registrosVisibles: 100,
          ),
        ),
      ),
    );

    expect(find.textContaining('145 registros de asignación'), findsOneWidget);
    expect(find.textContaining('Se muestran las 100 asignaciones'),
        findsOneWidget);
  });
}
