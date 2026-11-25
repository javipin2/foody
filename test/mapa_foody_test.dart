import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reserva_canchas/core/mapas/mapa_foody.dart';

void main() {
  for (final size in [const Size(320, 568), const Size(820, 900)]) {
    testWidgets('controles de mapa accesibles en ${size.width}px',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var acercamientos = 0;
      var alejamientos = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF14324A),
            ),
          ),
          home: Scaffold(
            body: Align(
              alignment: Alignment.centerRight,
              child: ControlesZoomMapa(
                onAcercar: () => acercamientos++,
                onAlejar: () => alejamientos++,
              ),
            ),
          ),
        ),
      );

      final acercar = find.byTooltip('Acercar mapa');
      final alejar = find.byTooltip('Alejar mapa');
      expect(acercar, findsOneWidget);
      expect(alejar, findsOneWidget);
      expect(tester.getSize(acercar), const Size(48, 48));
      expect(tester.getSize(alejar), const Size(48, 48));
      await tester.tap(acercar);
      await tester.tap(alejar);
      expect(acercamientos, 1);
      expect(alejamientos, 1);
      expect(tester.takeException(), isNull);
    });
  }
}
