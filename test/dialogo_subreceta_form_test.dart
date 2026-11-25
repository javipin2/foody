import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reserva_canchas/features/inventario/presentation/widgets/dialogo_subreceta_form.dart';

void main() {
  for (final size in [const Size(320, 568), const Size(390, 844)]) {
    testWidgets('formulario de subreceta cabe en ${size.width}px',
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
                  onPressed: () => mostrarDialogoSubreceta(
                    context: context,
                    ingredientes: const [],
                    subrecetas: const [],
                  ),
                  child: const Text('Abrir subreceta'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir subreceta'));
      await tester.pumpAndSettle();
      expect(find.text('Nueva subreceta'), findsOneWidget);
      expect(find.text('Cantidad obtenida'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
