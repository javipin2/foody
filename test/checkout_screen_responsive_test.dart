import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reserva_canchas/features/pedidos/presentation/checkout_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('checkout does not overflow at phone, tablet, and desktop widths',
      (tester) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const sizes = <Size>[
      Size(320, 568),
      Size(390, 844),
      Size(820, 1180),
      Size(1440, 900),
    ];

    for (final size in sizes) {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: CheckoutScreen(
              sucursalId: 'c0000000-0000-4000-8000-000000000001',
              sucursalNombre: 'Foody QA',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ListView), findsOneWidget);
      final scroll = tester.state<ScrollableState>(find.byType(Scrollable));
      scroll.position.jumpTo(scroll.position.maxScrollExtent);
      await tester.pumpAndSettle();

      expect(find.text('Confirmar pedido'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'viewport $size');
    }
  });
}
