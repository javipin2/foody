import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:reserva_canchas/features/analitica/data/analitica_repository.dart';
import 'package:reserva_canchas/features/finanzas/data/finanzas_repository.dart';
import 'package:reserva_canchas/features/finanzas/presentation/finanzas_admin_screen.dart';
import 'package:reserva_canchas/core/saas_ui/saas_kpi_card.dart';

class _FinanzasRepositoryFake extends FinanzasRepository {
  _FinanzasRepositoryFake({
    this.fijos = const [],
    this.pendientesFijos = const [],
  });

  final List<Map<String, dynamic>> fijos;
  final List<Map<String, dynamic>> pendientesFijos;

  @override
  Future<List<Map<String, dynamic>>> listarCostosFijos(
    String sucursalId, {
    bool incluirInactivos = false,
  }) async =>
      fijos;

  @override
  Future<List<Map<String, dynamic>>> listarEmpleados(
    String sucursalId, {
    bool incluirInactivos = false,
  }) async =>
      [];

  @override
  Future<List<Map<String, dynamic>>> listarGastos(
    String sucursalId, {
    String? desde,
    String? hasta,
  }) async =>
      [];

  @override
  Future<Map<String, dynamic>> resumen(String sucursalId) async => {
        'mes_actual': {
          'ventas_netas': 100000,
          'costo_ventas': 30000,
          'utilidad_bruta': 70000,
          'total_gastos': 20000,
          'utilidad_neta': 50000,
          'margen_neto_pct': 50,
          'cobertura_costo_pct': 100,
        },
        'delta_utilidad_pct': 20,
        'pendientes': {'fijos': pendientesFijos, 'empleados': []},
      };
}

class _AnaliticaRepositoryFake extends AnaliticaRepository {
  @override
  Future<Map<String, dynamic>> rentabilidad({
    required String sucursalId,
    String preset = 'mes',
    bool comparar = false,
    Map<String, dynamic>? filtros,
  }) async =>
      {
        'gastos_por_categoria': [
          {'categoria': 'arriendo', 'total': 15000},
        ],
      };
}

void main() {
  setUpAll(() => initializeDateFormatting('es_CO'));

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(820, 1180),
    const Size(1440, 900),
  ]) {
    testWidgets('hub financiero renderiza en ${size.width}px', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FinanzasAdminScreen(
              sucursalId: 's1',
              repository: _FinanzasRepositoryFake(),
              analiticaRepository: _AnaliticaRepositoryFake(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Finanzas'), findsWidgets);
      expect(
        find.textContaining('Puede incluir pedidos pendientes'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('fijos separa compromiso mensual de saldo y sugiere ese saldo', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 1000);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FinanzasAdminScreen(
            sucursalId: 's1',
            repository: _FinanzasRepositoryFake(
              fijos: [
                {
                  'id': 'fijo-1',
                  'concepto': 'Arriendo',
                  'monto_mensual': 500,
                  'activo': true,
                },
              ],
              pendientesFijos: [
                {'id': 'fijo-1', 'monto': 400},
              ],
            ),
            analiticaRepository: _AnaliticaRepositoryFake(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scroll = find.byKey(const ValueKey('finanzas-scroll'));
    await tester.dragUntilVisible(
      find.text('Pendiente del mes'),
      scroll,
      const Offset(0, -280),
    );
    expect(find.text('Compromiso mensual'), findsOneWidget);
    expect(find.text('Pendiente del mes'), findsOneWidget);
    expect(find.textContaining('500'), findsOneWidget);
    expect(find.textContaining('400'), findsWidgets);

    await tester.ensureVisible(find.text('Pagar').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pagar').first);
    await tester.pumpAndSettle();
    final monto = tester.widget<TextField>(find.byType(TextField).first);
    expect(monto.controller?.text, '400');
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('variación de utilidad no se presenta como variación de ventas',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 1000);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FinanzasAdminScreen(
            sucursalId: 's1',
            repository: _FinanzasRepositoryFake(),
            analiticaRepository: _AnaliticaRepositoryFake(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final ventas = find.ancestor(
      of: find.text('Ventas netas'),
      matching: find.byType(SaaSKpiCard),
    );
    final utilidad = find.ancestor(
      of: find.text('Utilidad neta'),
      matching: find.byType(SaaSKpiCard),
    );
    expect(ventas, findsOneWidget);
    expect(utilidad, findsOneWidget);
    expect(
      find.descendant(of: ventas, matching: find.text('+20.0%')),
      findsNothing,
    );
    expect(
      find.descendant(of: utilidad, matching: find.text('+20.0%')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('gráfico financiero mantiene contraste en modo oscuro', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(
          body: FinanzasAdminScreen(
            sucursalId: 's1',
            repository: _FinanzasRepositoryFake(),
            analiticaRepository: _AnaliticaRepositoryFake(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text('Distribución de gastos'),
      find.byKey(const ValueKey('finanzas-scroll')),
      const Offset(0, -240),
    );
    await tester.pumpAndSettle();

    final chart = tester.widget<PieChart>(find.byType(PieChart));
    expect(chart.data.sections.single.color, const Color(0xFFD1D5DB));
    final leyenda = tester.widget<Text>(find.text('arriendo'));
    expect(leyenda.style?.color, const Color(0xFF9CA3AF));
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(320, 568), const Size(390, 844)]) {
    testWidgets('formularios financieros caben a ${size.width}px',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(size.width, 900);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FinanzasAdminScreen(
              sucursalId: 's1',
              repository: _FinanzasRepositoryFake(),
              analiticaRepository: _AnaliticaRepositoryFake(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final scrollFinanzas = find.byKey(const ValueKey('finanzas-scroll'));
      await tester.dragUntilVisible(
        find.text('Gastos fijos'),
        scrollFinanzas,
        const Offset(0, -240),
      );
      await tester.dragUntilVisible(
        find.text('Gastos fijos'),
        scrollFinanzas,
        const Offset(0, -240),
      );
      await tester.ensureVisible(find.text('Agregar').first);
      await tester.tap(find.text('Agregar').first);
      await tester.pumpAndSettle();
      if (size.width == 320) {
        await tester.tap(find.byType(TextField).first);
        tester.view.viewInsets = const FakeViewPadding(bottom: 220);
        await tester.pumpAndSettle();
      }
      expect(find.text('Nuevo gasto fijo'), findsOneWidget);
      expect(find.text('Guardar'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 250));
      tester.view.viewInsets = FakeViewPadding.zero;

      await tester.dragUntilVisible(
        find.text('Nómina'),
        scrollFinanzas,
        const Offset(0, -280),
      );
      await tester.ensureVisible(find.text('Agregar').last);
      await tester.tap(find.text('Agregar').last);
      await tester.pumpAndSettle();
      expect(find.text('Nuevo empleado'), findsOneWidget);
      expect(find.text('Guardar'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 250));
    });
  }
}
