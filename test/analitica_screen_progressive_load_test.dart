import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reserva_canchas/features/analitica/data/analitica_repository.dart';
import 'package:reserva_canchas/features/analitica/presentation/analitica_screen.dart';

class _AnaliticaRepositoryControlado extends AnaliticaRepository {
  _AnaliticaRepositoryControlado() : super(dio: Dio());

  final resumenCompleter = Completer<Map<String, dynamic>>();
  final ventasCompleter = Completer<Map<String, dynamic>>();
  final productosCompleter = Completer<Map<String, dynamic>>();
  final recientesCompleter = Completer<Map<String, dynamic>>();
  final cocinasCompleter = Completer<Map<String, dynamic>>();
  final inventarioCompleter = Completer<Map<String, dynamic>>();
  var llamadasVentas = 0;
  var llamadasInventario = 0;

  @override
  Future<Map<String, dynamic>> resumen({
    required String sucursalId,
    String preset = 'mes',
    String? desde,
    String? hasta,
    bool comparar = true,
    Map<String, dynamic>? filtros,
  }) =>
      resumenCompleter.future;

  @override
  Future<Map<String, dynamic>> ventas({
    required String sucursalId,
    String preset = 'mes',
    bool comparar = false,
    Map<String, dynamic>? filtros,
  }) {
    llamadasVentas++;
    return ventasCompleter.future;
  }

  @override
  Future<Map<String, dynamic>> productos({
    required String sucursalId,
    String preset = 'mes',
    bool comparar = false,
    Map<String, dynamic>? filtros,
  }) =>
      productosCompleter.future;

  @override
  Future<Map<String, dynamic>> pedidosRecientes({
    required String sucursalId,
    String preset = 'hoy',
    bool comparar = false,
    Map<String, dynamic>? filtros,
    int limite = 15,
  }) =>
      recientesCompleter.future;

  @override
  Future<Map<String, dynamic>> cocinas({
    required String sucursalId,
    String preset = 'mes',
    bool comparar = false,
    Map<String, dynamic>? filtros,
  }) =>
      cocinasCompleter.future;

  @override
  Future<Map<String, dynamic>> inventario({
    required String sucursalId,
    String preset = 'mes',
    bool comparar = false,
    Map<String, dynamic>? filtros,
  }) {
    llamadasInventario++;
    return inventarioCompleter.future;
  }
}

void main() {
  testWidgets('Análisis usa selector de secciones en ancho compacto', (
    tester,
  ) async {
    final repository = _AnaliticaRepositoryControlado();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnaliticaScreen(
            sucursalId: 'sede-1',
            repository: repository,
          ),
        ),
      ),
    );
    repository.resumenCompleter.complete(_resumenFixture);
    _completarDetalles(repository);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.byWidgetPredicate((w) => w is DropdownButton<int>),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Análisis conserva tabs amplios en escritorio', (tester) async {
    final repository = _AnaliticaRepositoryControlado();
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnaliticaScreen(
            sucursalId: 'sede-1',
            repository: repository,
          ),
        ),
      ),
    );
    repository.resumenCompleter.complete(_resumenFixture);
    _completarDetalles(repository);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.byType(TabBar), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('muestra KPIs antes de terminar los endpoints complementarios', (
    tester,
  ) async {
    final repository = _AnaliticaRepositoryControlado();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnaliticaScreen(
            sucursalId: 'sede-1',
            repository: repository,
          ),
        ),
      ),
    );

    repository.resumenCompleter.complete(_resumenFixture);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Indicadores clave'), findsOneWidget);
    expect(find.textContaining('Cargando gráficos y listados'), findsOneWidget);
    expect(repository.llamadasVentas, 1);
    expect(repository.llamadasInventario, 0);
    expect(tester.takeException(), isNull);

    _completarDetalles(repository);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.textContaining('Cargando gráficos y listados'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('un fallo secundario conserva KPIs y ofrece reintentar', (
    tester,
  ) async {
    final repository = _AnaliticaRepositoryControlado();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnaliticaScreen(
            sucursalId: 'sede-1',
            repository: repository,
          ),
        ),
      ),
    );

    repository.resumenCompleter.complete(_resumenFixture);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    repository.productosCompleter.completeError(Exception('red caída'));
    repository.ventasCompleter.complete(<String, dynamic>{});
    repository.recientesCompleter.complete(<String, dynamic>{'pedidos': []});
    repository.cocinasCompleter.complete(<String, dynamic>{'cocinas': []});
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Indicadores clave'), findsOneWidget);
    expect(find.textContaining('No cargaron: productos'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
    expect(find.textContaining('Cargando gráficos y listados'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

const _resumenFixture = <String, dynamic>{
  'periodo': {'label': 'Últimos 7 días'},
  'kpis': {
    'ventas_netas': 12000,
    'pedidos': 2,
    'ticket_promedio': 6000,
    'margen_bruto_estimado': 9000,
    'margen_bruto_pct': 75,
    'pct_cancelacion': 0,
    'pedidos_cancelados': 0,
    'pedidos_total_cancelacion': 2,
    'alertas_abiertas': 0,
    'cobertura_costo_pct': 100,
  },
  'alertas_abiertas_lista': <dynamic>[],
};

void _completarDetalles(_AnaliticaRepositoryControlado repository) {
  repository.ventasCompleter.complete(<String, dynamic>{});
  repository.productosCompleter.complete(<String, dynamic>{});
  repository.recientesCompleter.complete(<String, dynamic>{'pedidos': []});
  repository.cocinasCompleter.complete(<String, dynamic>{'cocinas': []});
}
