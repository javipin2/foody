import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reserva_canchas/features/inventario/presentation/widgets/inventario_seccion_selector.dart';

void main() {
  for (final width in const [320.0, 390.0]) {
    for (final brightness in Brightness.values) {
      testWidgets(
          'selector compacto ${width.toInt()}px ${brightness.name} permite elegir sección',
          (tester) async {
        tester.view.physicalSize = Size(width, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final controller = TabController(length: 5, vsync: tester);
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(useMaterial3: true, brightness: brightness),
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: InventarioSeccionSelector(
                  controller: controller,
                  compacto: true,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Mercado'), findsOneWidget);
        await tester.tap(find.byTooltip('Cambiar sección de inventario'));
        await tester.pumpAndSettle();
        expect(find.text('Movimientos'), findsOneWidget);
        expect(find.text('Subrecetas'), findsOneWidget);
        expect(find.text('Conteo'), findsOneWidget);
        await tester.tap(find.text('Traslados'));
        await tester.pumpAndSettle();

        expect(controller.index, 4);
        expect(find.text('Traslados'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final width in const [820.0, 1440.0]) {
    testWidgets('selector ${width.toInt()}px muestra las cinco áreas',
        (tester) async {
      tester.view.physicalSize = Size(width, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = TabController(length: 5, vsync: tester);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: InventarioSeccionSelector(
                controller: controller,
                compacto: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final label in const [
        'Mercado',
        'Movimientos',
        'Subrecetas',
        'Conteo',
        'Traslados',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      await tester.tap(find.text('Conteo'));
      await tester.pumpAndSettle();

      expect(controller.index, 3);
      expect(tester.takeException(), isNull);
    });
  }
}
