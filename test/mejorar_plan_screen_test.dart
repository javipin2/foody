import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reserva_canchas/features/pagos/data/pagos_repository.dart';
import 'package:reserva_canchas/features/pagos/presentation/mejorar_plan_screen.dart';

class _PagosRepositoryFake extends PagosRepository {
  _PagosRepositoryFake({
    this.plan = 'gratis',
    this.resultadoRenovacion,
  });

  final String plan;
  final Map<String, dynamic>? resultadoRenovacion;
  int renovaciones = 0;

  @override
  Future<Map<String, dynamic>> estado() async => {
        'suscripcion': {'plan': plan, 'estado': 'activa'},
        'precios': {
          'basico': 5000000,
          'pro': 10000000,
          'enterprise': 13000000,
        },
        'historial': <Map<String, dynamic>>[],
      };

  @override
  Future<Map<String, dynamic>> renovar() async {
    renovaciones++;
    return resultadoRenovacion ?? {'modo': 'recurrente'};
  }
}

void main() {
  for (final size in [
    const Size(320, 640),
    const Size(390, 844),
    const Size(820, 900),
    const Size(1440, 900),
  ]) {
    testWidgets('planes se adaptan a ${size.width}px sin iniciar pago', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: MejorarPlanScreen(
              planActual: 'gratis',
              repository: _PagosRepositoryFake(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Plan y pagos'), findsOneWidget);
      expect(find.text('Plan actual: Gratis · Activa'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Pro'),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Pro'), findsOneWidget);
      expect(find.text('Pagar con Wompi'), findsWidgets);
      await tester.scrollUntilVisible(
        find.text('Enterprise'),
        260,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Enterprise'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('renovación ya pendiente informa que no crea otro cobro', (
    tester,
  ) async {
    final repository = _PagosRepositoryFake(
      plan: 'pro',
      resultadoRenovacion: {
        'modo': 'ninguno',
        'motivo': 'pago_reciente_existente',
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MejorarPlanScreen(
            planActual: 'pro',
            repository: repository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Renovar plan ahora'));
    await tester.pumpAndSettle();

    expect(repository.renovaciones, 1);
    expect(
      find.text(
        'Ya hay un pago reciente en proceso. No enviamos otro cobro; espera la confirmación de Wompi.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('cooldown de renovación explica por qué no inicia un cobro', (
    tester,
  ) async {
    final repository = _PagosRepositoryFake(
      plan: 'pro',
      resultadoRenovacion: {
        'modo': 'ninguno',
        'motivo': 'intento_reciente',
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MejorarPlanScreen(
            planActual: 'pro',
            repository: repository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Renovar plan ahora'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Ya se registró un intento reciente. Para evitar un cobro duplicado, espera su conciliación antes de volver a intentarlo.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
