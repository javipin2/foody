import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reserva_canchas/features/pedidos/presentation/widgets/aviso_cliente_items_no_disponibles.dart';

void main() {
  for (final width in [320.0, 390.0, 820.0, 1440.0]) {
    testWidgets('aviso al cliente se adapta a ${width.toInt()} px',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: width - 32,
                child: const AvisoClienteItemsNoDisponibles(
                  items: [
                    {'nombre': 'Hamburguesa vegetariana', 'cantidad': 2},
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('aviso-cliente-items-no-disponibles')),
        findsOneWidget,
      );
      expect(
          find.textContaining('2 × Hamburguesa vegetariana'), findsOneWidget);
      expect(find.textContaining('total aún no refleja ese ajuste'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('no muestra aviso si no hay líneas no disponibles',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AvisoClienteItemsNoDisponibles(items: []),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('aviso-cliente-items-no-disponibles')),
      findsNothing,
    );
  });
}
