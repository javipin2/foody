import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reserva_canchas/core/widgets/foody_estado_ui.dart';

void main() {
  for (final oscuro in [false, true]) {
    testWidgets(
      'estado de suscripción bloqueada respeta tema ${oscuro ? 'oscuro' : 'claro'}',
      (tester) async {
        final tema = oscuro
            ? ThemeData.dark(useMaterial3: true)
            : ThemeData.light(useMaterial3: true);
        final scheme = tema.colorScheme;

        await tester.pumpWidget(
          MaterialApp(
            theme: tema,
            home: Scaffold(
              body: FoodyEstadoUi.bloqueadoSuscripcion(onReactivarPlan: () {}),
            ),
          ),
        );

        expect(find.text('Plan no activo'), findsOneWidget);
        expect(find.text('Reactivar plan'), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is DecoratedBox &&
                widget.decoration is BoxDecoration &&
                (widget.decoration as BoxDecoration).color ==
                    scheme.surfaceContainerLow,
          ),
          findsOneWidget,
        );
        expect(
          tester.widget<Text>(find.text('Plan no activo')).style?.color,
          scheme.onSurface,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final ancho in [320.0, 1440.0]) {
    testWidgets('estado vacío Foody se adapta a ${ancho}px', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(ancho, 800);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var accionEjecutada = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(useMaterial3: true),
          darkTheme: ThemeData.dark(useMaterial3: true),
          themeMode: ancho == 320 ? ThemeMode.dark : ThemeMode.light,
          home: Scaffold(
            body: FoodyEstadoUi.vacio(
              titulo: 'Todavía no hay productos',
              subtitulo: 'Crea el primer producto para organizar el menú.',
              icono: Icons.restaurant_menu_outlined,
              etiquetaAccion: 'Crear primer producto',
              onAccion: () => accionEjecutada = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Todavía no hay productos'), findsOneWidget);
      expect(find.text('Crea el primer producto para organizar el menú.'),
          findsOneWidget);
      expect(
        tester.getSize(find.byType(FilledButton)).height,
        greaterThanOrEqualTo(48),
      );
      await tester.tap(find.text('Crear primer producto'));
      expect(accionEjecutada, isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  for (final ancho in [320.0, 390.0, 820.0, 1440.0]) {
    testWidgets('estado de error Foody se adapta a ${ancho}px', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(ancho, 640);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var reintentos = 0;
      var accionSecundaria = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(useMaterial3: true),
          darkTheme: ThemeData.dark(useMaterial3: true),
          themeMode: ancho == 320 ? ThemeMode.dark : ThemeMode.light,
          home: Scaffold(
            body: FoodyEstadoUi.errorUi(
              mensaje:
                  'No se pudieron cargar los datos. Comprueba la conexión e inténtalo otra vez.',
              onReintentar: () => reintentos++,
              etiquetaReintentar: 'Reintentar carga',
              onAccionSecundaria: () => accionSecundaria++,
              etiquetaAccionSecundaria: 'Volver al panel',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('No se pudieron cargar los datos'),
          findsOneWidget);
      expect(tester.getSize(find.byType(FilledButton)).height,
          greaterThanOrEqualTo(48));
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Reintentar carga'));
      await tester.tap(find.text('Volver al panel'));
      expect(reintentos, 1);
      expect(accionSecundaria, 1);
      expect(tester.takeException(), isNull);
    });
  }
}
