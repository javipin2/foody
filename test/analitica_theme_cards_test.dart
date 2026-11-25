import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reserva_canchas/core/saas_ui/saas_tokens.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_charts.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_chart_card.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_kpi_card.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_surface.dart';

void main() {
  test('gráficas de Análisis usan tonos legibles en oscuro', () {
    final barras = AnaliticaCharts.barrasHora(
      [
        <String, dynamic>{'hora': 12, 'ventas': 12000}
      ],
      oscuro: true,
    );
    final pie = AnaliticaCharts.pieMetodo(
      [
        <String, dynamic>{'total': 12000}
      ],
      oscuro: true,
    );
    final linea = AnaliticaCharts.lineaDia(
      [
        <String, dynamic>{'dia': '2026-11-24', 'ventas': 12000}
      ],
      oscuro: true,
    );

    expect(
        barras.barGroups.single.barRods.single.color, const Color(0xFFD1D5DB));
    expect(pie.sections.single.color, const Color(0xFFD1D5DB));
    expect(
      linea.gridData.getDrawingHorizontalLine(0).color,
      const Color(0xFF2A2E36),
    );
  });

  for (final brightness in Brightness.values) {
    testWidgets('tarjetas de Análisis respetan tema $brightness',
        (tester) async {
      final theme = ThemeData(
        useMaterial3: true,
        brightness: brightness,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: ListView(
              children: [
                const SizedBox(
                  height: 112,
                  child: AnaliticaKpiCard(
                    etiqueta: 'Ventas',
                    valor: '\$20.000',
                  ),
                ),
                const AnaliticaSurface(child: Text('Resumen')),
                const AnaliticaChartCard(
                  titulo: 'Ventas por día',
                  child: SizedBox.expand(),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final expectedSurface = SaaSTokens.surface(
        tester.element(find.byType(AnaliticaSurface)),
      );
      final kpiDecoration = tester
          .widget<AnimatedContainer>(
            find.descendant(
              of: find.byType(AnaliticaKpiCard),
              matching: find.byType(AnimatedContainer),
            ),
          )
          .decoration as BoxDecoration;
      final surfaceDecoration = tester
          .widget<AnimatedContainer>(
            find.descendant(
              of: find.byType(AnaliticaSurface),
              matching: find.byType(AnimatedContainer),
            ),
          )
          .decoration as BoxDecoration;
      final chartDecoration = tester
          .widget<Container>(
            find.descendant(
              of: find.byType(AnaliticaChartCard),
              matching: find.byType(Container),
            ),
          )
          .decoration as BoxDecoration;

      expect(kpiDecoration.color, expectedSurface);
      expect(surfaceDecoration.color, expectedSurface);
      expect(chartDecoration.color, expectedSurface);
      expect(
        tester.widget<Text>(find.text('Ventas')).style!.color,
        SaaSTokens.inkMuted(tester.element(find.text('Ventas'))),
      );
      expect(
        tester.widget<Text>(find.text('Ventas por día')).style!.color,
        SaaSTokens.ink(tester.element(find.text('Ventas por día'))),
      );
    });
  }
}
