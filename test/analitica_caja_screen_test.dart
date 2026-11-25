import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reserva_canchas/features/analitica/data/analitica_repository.dart';
import 'package:reserva_canchas/features/analitica/presentation/analitica_screen.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_kpi_card.dart';

class _AnaliticaCajaFake extends AnaliticaRepository {
  _AnaliticaCajaFake({this.incluirDesglose = true});

  final bool incluirDesglose;

  @override
  Future<Map<String, dynamic>> resumen({
    required String sucursalId,
    String preset = 'mes',
    String? desde,
    String? hasta,
    bool comparar = true,
    Map<String, dynamic>? filtros,
  }) async =>
      {
        'periodo': {'label': 'Mes actual'},
        'kpis': {'pedidos': 0},
      };

  @override
  Future<Map<String, dynamic>> productos({
    required String sucursalId,
    String preset = 'mes',
    bool comparar = false,
    Map<String, dynamic>? filtros,
  }) async =>
      {'por_cantidad': <dynamic>[]};

  @override
  Future<Map<String, dynamic>> ventas({
    required String sucursalId,
    String preset = 'mes',
    bool comparar = false,
    Map<String, dynamic>? filtros,
  }) async =>
      {};

  @override
  Future<Map<String, dynamic>> pedidosRecientes({
    required String sucursalId,
    String preset = 'hoy',
    bool comparar = false,
    Map<String, dynamic>? filtros,
    int limite = 15,
  }) async =>
      {'pedidos': <dynamic>[]};

  @override
  Future<Map<String, dynamic>> cocinas({
    required String sucursalId,
    String preset = 'mes',
    bool comparar = false,
    Map<String, dynamic>? filtros,
  }) async =>
      {'cocinas': <dynamic>[]};

  @override
  Future<Map<String, dynamic>> caja({
    required String sucursalId,
    String preset = 'mes',
    bool comparar = false,
    Map<String, dynamic>? filtros,
  }) async {
    final datos = <String, dynamic>{
      'cuadre': {
        'ventas_pedidos': 1000,
        'ventas_movimientos_caja': 900,
        'diferencia': 100,
        'descuadre_relevante': false,
        'nota_periodo_caja':
            'En movimientos ligados a un pedido se usa la fecha de creación del pedido; para movimientos sin pedido, la fecha del movimiento.',
      },
      'gastos_total': 100,
      'gastos_por_categoria': [
        {'categoria': 'Insumos', 'total': 100, 'cantidad': 1},
      ],
    };
    if (incluirDesglose) datos['gastos_movimientos_caja'] = 100;
    return datos;
  }
}

void main() {
  for (final size in [
    const Size(320, 700),
    const Size(390, 844),
    const Size(820, 1180),
    const Size(1440, 900),
  ]) {
    testWidgets('Caja separa libro y egreso a ${size.width}px', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AnaliticaScreen(
            sucursalId: 's1',
            repository: _AnaliticaCajaFake(),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      if (size.width < 600) {
        await tester.tap(find.byType(DropdownButton<int>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Caja').last);
      } else {
        await tester.ensureVisible(find.text('Caja').first);
        await tester.tap(find.text('Caja').first);
      }
      await tester.pumpAndSettle();

      expect(find.text('Gastos registrados'), findsOneWidget);
      expect(find.text('Egresos de caja'), findsOneWidget);
      expect(find.text('Mov. caja netos'), findsOneWidget);
      expect(
        find.byTooltip(
          'En movimientos ligados a un pedido se usa la fecha de creación del pedido; para movimientos sin pedido, la fecha del movimiento.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('API anterior no convierte egresos ausentes en cero',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AnaliticaScreen(
          sucursalId: 's1',
          repository: _AnaliticaCajaFake(incluirDesglose: false),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Caja').last);
    await tester.pumpAndSettle();

    final tarjeta = find.ancestor(
      of: find.text('Egresos de caja'),
      matching: find.byType(AnaliticaKpiCard),
    );
    expect(tarjeta, findsOneWidget);
    expect(
        find.descendant(of: tarjeta, matching: find.text('—')), findsOneWidget);
    expect(
      find.descendant(
        of: tarjeta,
        matching: find.text('Dato no disponible'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
