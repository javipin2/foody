import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:reserva_canchas/features/auditoria/data/auditoria_repository.dart';
import 'package:reserva_canchas/features/reportes/data/reportes_repository.dart';
import 'package:reserva_canchas/features/reportes/presentation/reportes_admin_screen.dart';

class _ReportesRepositoryFake extends ReportesRepository {
  _ReportesRepositoryFake({
    this.financieroData = const {},
    this.pedidosData = const {},
  });

  final Map<String, dynamic> financieroData;
  final Map<String, dynamic> pedidosData;

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
      pedidosData;
}

class _AuditoriaRepositoryFake extends AuditoriaRepository {
  final requests = <({String desde, String hasta})>[];
  final responses = <Future<Map<String, dynamic>>>[];
  int fallosPendientes = 0;

  @override
  Future<Map<String, dynamic>> timeline({
    required String desde,
    required String hasta,
    String? sucursalId,
  }) async {
    requests.add((desde: desde, hasta: hasta));
    final responseIndex = requests.length - 1;
    if (responseIndex < responses.length) return responses[responseIndex];
    if (fallosPendientes > 0) {
      fallosPendientes--;
      throw Exception('Sin conexión');
    }
    return {};
  }
}

void main() {
  setUpAll(() => initializeDateFormatting('es_CO'));

  for (final caso in [
    (bloqueada: true, etiqueta: 'Análisis · Pro'),
    (bloqueada: false, etiqueta: 'Análisis'),
  ]) {
    testWidgets('puente a Análisis muestra estado del plan ${caso.etiqueta}',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(820, 1180);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReportesAdminScreen(
              sucursalId: 's1',
              repository: _ReportesRepositoryFake(),
              auditoriaRepository: _AuditoriaRepositoryFake(),
              onIrAnalitica: () {},
              analiticaBloqueadaPorPlan: caso.bloqueada,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(caso.etiqueta), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

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

  testWidgets('auditoría vuelve a consultar el timeline al cambiar periodo',
      (tester) async {
    final auditoria = _AuditoriaRepositoryFake();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReportesAdminScreen(
            sucursalId: 's1',
            repository: _ReportesRepositoryFake(),
            auditoriaRepository: auditoria,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Auditoría'));
    await tester.pumpAndSettle();
    expect(auditoria.requests, hasLength(1));

    await tester.tap(find.text('Hoy'));
    await tester.pumpAndSettle();

    expect(auditoria.requests, hasLength(2));
    expect(auditoria.requests.last.desde, auditoria.requests.last.hasta);
  });

  testWidgets('error del timeline permite reintentar sin mostrar vacío falso',
      (tester) async {
    final auditoria = _AuditoriaRepositoryFake()..fallosPendientes = 1;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReportesAdminScreen(
            sucursalId: 's1',
            repository: _ReportesRepositoryFake(),
            auditoriaRepository: auditoria,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Auditoría'));
    await tester.pumpAndSettle();

    expect(auditoria.requests, hasLength(1));
    expect(find.text('Reintentar'), findsOneWidget);
    expect(find.text('Sin eventos en el período'), findsNothing);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.text('Sin eventos en el período'), findsOneWidget);
    expect(auditoria.requests, hasLength(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Reporte financiero identifica domicilio como parte del total',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 720);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReportesAdminScreen(
            sucursalId: 's1',
            repository: _ReportesRepositoryFake(
              financieroData: {
                'resumen': {
                  'ventas_total': 30000,
                  'pedidos': 2,
                  'ticket_promedio': 15000,
                  'costo_domicilio': 5000,
                },
                'por_tipo': [
                  {
                    'tipo': 'domicilio',
                    'pedidos': 2,
                    'ventas': 30000,
                    'costo_domicilio': 5000,
                  },
                ],
              },
            ),
            auditoriaRepository: _AuditoriaRepositoryFake(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Valor total pedidos'), findsOneWidget);
    expect(find.text('Cargo domicilio'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Por tipo de pedido'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.scrollUntilVisible(
      find.textContaining('Incluye'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('pedidos · Valor total'), findsOneWidget);
    expect(find.textContaining('Incluye 5.000'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('detalle diario muestra el cargo incluido sin sumarlo al total',
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
              pedidosData: {
                'por_dia': [
                  {
                    'dia': '2026-11-23',
                    'pedidos': 1,
                    'ventas': 15000,
                    'costo_domicilio': 5000,
                  },
                ],
              },
            ),
            auditoriaRepository: _AuditoriaRepositoryFake(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pedidos').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('pedidos · Valor total'), findsOneWidget);
    expect(find.textContaining('Incluye 5.000'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('respuesta tardía de otro periodo no reemplaza el timeline nuevo',
      (tester) async {
    final respuestaAnterior = Completer<Map<String, dynamic>>();
    final auditoria = _AuditoriaRepositoryFake()
      ..responses.add(respuestaAnterior.future)
      ..responses.add(Future.value({
        'eventos': [
          {
            'tipo': 'Evento del día actual',
            'fuente': 'Pedidos',
            'ocurrido_at': '2026-11-25T12:00:00Z',
          },
        ],
      }));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReportesAdminScreen(
            sucursalId: 's1',
            repository: _ReportesRepositoryFake(),
            auditoriaRepository: auditoria,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Auditoría'));
    // El skeleton anima mientras la primera llamada permanece pendiente.
    await tester.pump(const Duration(milliseconds: 400));
    expect(auditoria.requests, hasLength(1));

    await tester.tap(find.text('Hoy'));
    await tester.pumpAndSettle();
    expect(auditoria.requests, hasLength(2));
    expect(find.text('Evento del día actual'), findsOneWidget);

    respuestaAnterior.complete({
      'eventos': [
        {
          'tipo': 'Evento obsoleto',
          'fuente': 'Pedidos',
          'ocurrido_at': '2026-11-18T12:00:00Z',
        },
      ],
    });
    await tester.pumpAndSettle();

    expect(find.text('Evento del día actual'), findsOneWidget);
    expect(find.text('Evento obsoleto'), findsNothing);
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

    expect(find.text('Pedidos y cobros asociados'), findsOneWidget);
    expect(find.text('Valor total de pedidos'), findsOneWidget);
    expect(find.text('Cobros netos asociados'), findsOneWidget);
    expect(find.text('Valor de pedidos menos cobros'), findsOneWidget);
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
