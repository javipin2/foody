import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:reserva_canchas/features/auditoria/data/auditoria_repository.dart';
import 'package:reserva_canchas/features/reportes/data/reportes_repository.dart';
import 'package:reserva_canchas/features/reportes/presentation/reportes_admin_screen.dart';

class _ReportesRepositoryFake extends ReportesRepository {
  _ReportesRepositoryFake({this.financieroData = const {}});

  final Map<String, dynamic> financieroData;

  @override
  Future<Map<String, dynamic>> financiero({
    required String sucursalId,
    required String desde,
    required String hasta,
  }) async =>
      financieroData;

  @override
  Future<Map<String, dynamic>> productos({
    required String sucursalId,
    required String desde,
    required String hasta,
  }) async =>
      {};

  @override
  Future<Map<String, dynamic>> pedidos({
    required String sucursalId,
    required String desde,
    required String hasta,
  }) async =>
      {};
}

class _AuditoriaRepositoryFake extends AuditoriaRepository {
  @override
  Future<Map<String, dynamic>> timeline({
    required String desde,
    required String hasta,
    String? sucursalId,
  }) async =>
      {};
}

void main() {
  setUpAll(() => initializeDateFormatting('es_CO'));

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(820, 1180),
    const Size(1440, 900),
  ]) {
    testWidgets('reportes renderiza en ${size.width}px', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReportesAdminScreen(
              sucursalId: 's1',
              repository: _ReportesRepositoryFake(),
              auditoriaRepository: _AuditoriaRepositoryFake(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Reportes'), findsOneWidget);
      expect(find.text('Financiero'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('filtro de periodo seleccionado respeta el tema oscuro',
      (tester) async {
    final esquemaOscuro = ColorScheme.fromSeed(
      seedColor: const Color(0xFF6558D3),
      brightness: Brightness.dark,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(colorScheme: esquemaOscuro),
        home: Scaffold(
          body: ReportesAdminScreen(
            sucursalId: 's1',
            repository: _ReportesRepositoryFake(),
            auditoriaRepository: _AuditoriaRepositoryFake(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final etiqueta = find.text('7d');
    final chip = tester.widget<Material>(
      find.ancestor(of: etiqueta, matching: find.byType(Material)).first,
    );
    expect(chip.color, esquemaOscuro.primaryContainer);
    expect(
      tester.widget<Text>(etiqueta).style?.color,
      esquemaOscuro.onPrimaryContainer,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('cuadre explica la fecha de atribución de movimientos de caja',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReportesAdminScreen(
            sucursalId: 's1',
            repository: _ReportesRepositoryFake(
              financieroData: {
                'resumen': {'ventas_total': 1200, 'pedidos': 1},
                'cuadre_caja': {
                  'ventas_pedidos': 1200,
                  'ventas_movimientos_caja': 900,
                  'diferencia': 300,
                  'etiqueta_ventas_caja': 'Cobrado en caja (neto)',
                  'nota_universos': 'Tickets y caja son universos distintos.',
                },
                'recaudo_periodo': {
                  'total_neto': 1500,
                  'nota':
                      'Suma ventas menos devoluciones registradas dentro del rango; puede incluir pedidos creados antes. Las propinas voluntarias van aparte.',
                },
              },
            ),
            auditoriaRepository: _AuditoriaRepositoryFake(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Recaudo registrado en el rango'),
      400,
      scrollable: find.byType(Scrollable).last,
    );

    expect(find.text('Ventas y cobros asociados'), findsOneWidget);
    expect(find.text('Ventas de pedidos'), findsOneWidget);
    expect(find.text('Cobros netos asociados'), findsOneWidget);
    expect(find.text('Ventas menos cobros'), findsOneWidget);
    expect(find.text('Recaudo registrado en el rango'), findsOneWidget);
    expect(
      find.text('Ventas menos devoluciones por fecha de movimiento'),
      findsOneWidget,
    );
    expect(
      find.textContaining('fecha del pedido'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
