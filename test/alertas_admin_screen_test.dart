import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:reserva_canchas/features/alertas/data/alertas_repository.dart';
import 'package:reserva_canchas/features/alertas/presentation/alertas_admin_screen.dart';

class _AlertasRepositoryFake extends AlertasRepository {
  bool? ultimoFiltro;
  String? alertaRevisada;

  final List<Map<String, dynamic>> alertas = [
    {
      'id': 'a1',
      'tipo': 'stock_minimo_alcanzado',
      'nivel': 'alto',
      'descripcion':
          'El inventario de harina de trigo está por debajo del mínimo configurado para esta sede.',
      'revisada': false,
      'created_at': '2026-11-22T12:00:00Z',
      'referencia_tipo': 'insumo',
      'referencia_id': 'i1',
    },
  ];

  @override
  Future<List<Map<String, dynamic>>> listar(
    String sucursalId, {
    bool soloPendientes = true,
  }) async {
    ultimoFiltro = soloPendientes;
    return alertas
        .where((a) => !soloPendientes || a['revisada'] != true)
        .toList();
  }

  @override
  Future<void> revisar(String alertaId, {String? sucursalId}) async {
    alertaRevisada = alertaId;
    for (final alerta in alertas) {
      if (alerta['id'] == alertaId) alerta['revisada'] = true;
    }
  }
}

void main() {
  setUpAll(() => initializeDateFormatting('es_CO'));

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(820, 1180),
    const Size(1440, 900),
  ]) {
    testWidgets('alertas se leen sin desbordes a ${size.width}px',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AlertasAdminScreen(
              sucursalId: 's1',
              repository: _AlertasRepositoryFake(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Alertas'), findsOneWidget);
      expect(find.text('Stock bajo'), findsOneWidget);
      expect(find.byTooltip('Marcar revisada'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('alerta conserva contraste y superficie con tema oscuro',
      (tester) async {
    final esquemaOscuro = ColorScheme.fromSeed(
      seedColor: const Color(0xFF6558D3),
      brightness: Brightness.dark,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(colorScheme: esquemaOscuro),
        home: Scaffold(
          body: AlertasAdminScreen(
            sucursalId: 's1',
            repository: _AlertasRepositoryFake(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final alerta = find.textContaining('El inventario de harina');
    final tarjeta = tester.widget<Material>(
      find.ancestor(of: alerta, matching: find.byType(Material)).first,
    );
    expect(tarjeta.color, esquemaOscuro.surfaceContainerLow);
    expect(
      tester.widget<Text>(find.text('Alto')).style?.color,
      const Color(0xFFFCA5A5),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('filtro consulta todas y abrir alerta navega al origen',
      (tester) async {
    final repository = _AlertasRepositoryFake();
    String? referenciaTipo;
    String? referenciaId;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AlertasAdminScreen(
            sucursalId: 's1',
            repository: repository,
            onNavegarReferencia: (tipo, id) {
              referenciaTipo = tipo;
              referenciaId = id;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.ultimoFiltro, isTrue);
    await tester.tap(find.text('Solo pendientes'));
    await tester.pumpAndSettle();
    expect(repository.ultimoFiltro, isFalse);

    await tester.tap(find.textContaining('El inventario de harina'));
    expect(referenciaTipo, 'insumo');
    expect(referenciaId, 'i1');
    expect(tester.takeException(), isNull);
  });

  testWidgets('marcar revisada actualiza el estado y limpia pendientes',
      (tester) async {
    final repository = _AlertasRepositoryFake();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AlertasAdminScreen(
            sucursalId: 's1',
            repository: repository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Marcar revisada'));
    await tester.pumpAndSettle();

    expect(repository.alertaRevisada, 'a1');
    expect(find.text('Sin alertas pendientes'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
