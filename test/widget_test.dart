import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reserva_canchas/main.dart';

void main() {
  testWidgets('Foody inicia con el contenedor de estado requerido',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: FoodyApp()));
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
