import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reserva_canchas/features/admin/presentation/configuracion_admin_screen.dart';

void main() {
  const permisosCompletos = [
    'gestionar_sucursales',
    'editar_productos',
    'gestionar_usuarios',
  ];

  for (final size in const [
    Size(320, 568),
    Size(390, 844),
    Size(820, 900),
    Size(1440, 1000),
  ]) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'configuración ${size.width.toInt()}px ${brightness.name} conserva grupos y opciones',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(
                useMaterial3: true,
                brightness: brightness,
              ),
              home: Scaffold(
                body: ConfiguracionAdminScreen(
                  permisos: permisosCompletos,
                  onAbrir: (_) {},
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Configuración'), findsOneWidget);
          expect(find.text('Negocio'), findsOneWidget);
          expect(find.text('Atención y entrega'), findsOneWidget);
          expect(find.text('Operación'), findsOneWidget);
          expect(find.text('Equipo'), findsOneWidget);
          expect(find.text('Medios de pago del restaurante'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('el centro solo muestra opciones autorizadas y conserva ruta',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    String? ruta;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConfiguracionAdminScreen(
            permisos: const ['gestionar_sucursales'],
            onAbrir: (value) => ruta = value,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Establecimiento y sedes'), findsOneWidget);
    expect(find.text('Cocinas e impresión'), findsNothing);
    await tester.tap(find.text('Establecimiento y sedes'));
    expect(ruta, 'sucursales');
    expect(tester.takeException(), isNull);
  });

  testWidgets('sin permisos muestra estado vacío sin revelar accesos',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConfiguracionAdminScreen(
            permisos: const [],
            onAbrir: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
        find.text('Tu perfil no tiene ajustes disponibles.'), findsOneWidget);
    expect(find.text('Establecimiento y sedes'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
