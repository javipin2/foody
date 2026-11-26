import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reserva_canchas/features/analitica/presentation/analitica_resumen_dashboard.dart';

void main() {
  testWidgets('aclara pedidos recientes y evita cobertura 100% sin pedidos', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnaliticaResumenDashboard(
            resumen: {
              'periodo': {'label': 'Últimos 7 días'},
              'kpis': {
                'pedidos': 0,
                'recaudo_neto': 5000,
                'cobertura_costo_pct': 100,
                'alertas_abiertas': 0,
                'pedidos_cancelados': 39,
                'pedidos_total_cancelacion': 48,
              },
              'alertas_abiertas_lista': <dynamic>[],
            },
            ventas: const {},
            topProductos: const [],
            pedidosRecientes: const [],
          ),
        ),
      ),
    );

    expect(find.text('Pedidos recientes'), findsOneWidget);
    expect(find.text('Valor de pedidos'), findsOneWidget);
    expect(find.text('Ventas cumplidas'), findsOneWidget);
    expect(find.text('Recaudo neto'), findsOneWidget);
    expect(find.text('Pedidos activos'), findsNothing);
    expect(find.text('Cobertura de costos'), findsOneWidget);
    expect(find.text('Sin pedidos en el periodo'), findsOneWidget);
    expect(find.text('100.0%'), findsNothing);
    expect(find.text('39 de 48 pedidos'), findsOneWidget);
  });

  testWidgets('no inventa el denominador si Nest aún no expone los conteos', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnaliticaResumenDashboard(
            resumen: {
              'periodo': {'label': 'Últimos 7 días'},
              'kpis': {'pedidos': 9, 'pct_cancelacion': 81.3},
            },
            ventas: const {},
            topProductos: const [],
            pedidosRecientes: const [],
          ),
        ),
      ),
    );

    expect(find.text('Sobre pedidos del periodo'), findsOneWidget);
    expect(find.text('0 de 0 pedidos'), findsNothing);
  });
}
