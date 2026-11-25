import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reserva_canchas/features/admin/data/dashboard_repository.dart';
import 'package:reserva_canchas/features/admin/presentation/widgets/dashboard_graficos_widget.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_chart_card.dart';

class _DashboardRepositoryFake extends DashboardRepository {
  @override
  Future<Map<String, dynamic>> graficos({String? sucursalId}) async => {
        'ventas_7_dias': [
          for (var dia = 19; dia <= 25; dia++)
            {
              'dia': '2026-11-$dia',
              'pedidos': 0,
              'ventas': 0,
            },
        ],
        'pedidos_por_tipo_hoy': <dynamic>[],
        'top_productos_7d': <dynamic>[],
      };
}

void main() {
  for (final size in [
    const Size(320, 640),
    const Size(390, 844),
    const Size(820, 900),
    const Size(1440, 900),
  ]) {
    testWidgets('gráficas vacías usan estados compactos a ${size.width}px',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DashboardGraficosWidget(
                sucursalId: 'sucursal-1',
                repository: _DashboardRepositoryFake(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Sin ventas en la semana'), findsOneWidget);
      expect(find.text('Sin pedidos hoy'), findsOneWidget);
      final cards = find.byType(AnaliticaChartCard);
      expect(cards, findsNWidgets(3));
      for (var i = 0; i < 3; i++) {
        expect(tester.getSize(cards.at(i)).height, lessThan(180));
      }
      expect(tester.takeException(), isNull);
    });
  }
}
