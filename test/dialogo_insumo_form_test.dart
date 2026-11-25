import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reserva_canchas/features/inventario/presentation/widgets/dialogo_insumo_form.dart';

void main() {
  for (final size in [const Size(320, 568), const Size(390, 844)]) {
    testWidgets('formulario de insumo desplazable en ${size.width}px',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: FilledButton(
                  onPressed: () => mostrarDialogoInsumo(context: context),
                  child: const Text('Abrir formulario'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir formulario'));
      await tester.pumpAndSettle();
      expect(find.text('Nuevo insumo'), findsOneWidget);
      expect(find.text('Precio de compra (COP)'), findsOneWidget);
      expect(tester.takeException(), isNull);

      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Solo costo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Solo costo'));
      await tester.pumpAndSettle();
      expect(find.text('Costo por plato / unidad (COP)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
