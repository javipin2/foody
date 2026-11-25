import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reserva_canchas/features/admin/data/dashboard_repository.dart';
import 'package:reserva_canchas/features/admin/data/pedidos_repository.dart';
import 'package:reserva_canchas/features/admin/domain/pedido_admin_model.dart';
import 'package:reserva_canchas/features/admin/presentation/widgets/dashboard_resumen_widget.dart';
import 'package:reserva_canchas/features/alertas/data/alertas_repository.dart';
import 'package:reserva_canchas/features/inventario/data/inventario_repository.dart';
import 'package:reserva_canchas/features/mesa/data/mesas_repository.dart';

class _DashboardRepositoryFake extends DashboardRepository {
  @override
  Future<Map<String, dynamic>> resumen({String? sucursalId}) async => {
        'ventas_hoy': 325000,
        'pedidos_activos': 4,
        'pedidos_completados_hoy': 12,
        'pedidos_pendientes_qr': 2,
        'alertas_pendientes': 0,
      };
}

class _DashboardRepositoryConCambioDeSede extends DashboardRepository {
  @override
  Future<Map<String, dynamic>> resumen({String? sucursalId}) async {
    if (sucursalId == 'sucursal-anterior') {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return {
      'ventas_hoy': sucursalId == 'sucursal-actual' ? 200000 : 100000,
      'pedidos_activos': 1,
      'pedidos_completados_hoy': 0,
      'pedidos_pendientes_qr': 0,
      'alertas_pendientes': 0,
    };
  }
}

class _DashboardRepositoryConDomicilios extends DashboardRepository {
  _DashboardRepositoryConDomicilios({this.minutos = 52});

  final int minutos;

  @override
  Future<Map<String, dynamic>> resumen({String? sucursalId}) async => {
        'ventas_hoy': 0,
        'pedidos_activos': 101,
        'pedidos_pendientes_qr': 0,
        'pedidos_completados_hoy': 0,
        'alertas_pendientes': 0,
        'domicilios_tardios': [
          {
            'numero': 'P-ANTIGUO',
            'detalle': 'En camino · Ana',
            'minutos': minutos,
            'severidad': 0,
          },
        ],
      };
}

class _MesasRepositoryFake extends MesasRepository {
  _MesasRepositoryFake({
    this.falla = false,
    this.fallaTrasPrimeraCarga = false,
    this.filas = const [],
  });

  final bool falla;
  final bool fallaTrasPrimeraCarga;
  final List<Map<String, dynamic>> filas;
  int llamadas = 0;

  @override
  Future<List<Map<String, dynamic>>> listar(String sucursalId) async {
    llamadas++;
    if (falla || (fallaTrasPrimeraCarga && llamadas > 1)) {
      throw Exception('fallo simulado');
    }
    return filas;
  }
}

class _PedidosRepositoryFake extends PedidosRepository {
  int llamadas = 0;

  @override
  Future<List<PedidoAdminModel>> listarActivos({
    String? sucursalId,
    String? meseraId,
    int limit = 100,
  }) async {
    llamadas++;
    return [];
  }
}

class _AlertasRepositoryFake extends AlertasRepository {
  @override
  Future<List<Map<String, dynamic>>> listar(
    String sucursalId, {
    bool soloPendientes = true,
  }) async =>
      [];
}

class _InventarioRepositoryFake extends InventarioRepository {
  @override
  Future<List<Map<String, dynamic>>> ingredientes(String sucursalId) async =>
      [];
}

void main() {
  testWidgets('dashboard usa domicilios tardíos del resumen del servidor', (
    tester,
  ) async {
    final pedidos = _PedidosRepositoryFake();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DashboardResumenWidget(
              sucursalId: 'sucursal-prueba',
              dashboardRepository: _DashboardRepositoryConDomicilios(),
              mesasRepository: _MesasRepositoryFake(),
              pedidosRepository: pedidos,
              alertasRepository: _AlertasRepositoryFake(),
              inventarioRepository: _InventarioRepositoryFake(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('P-ANTIGUO'), findsOneWidget);
    expect(find.text('En camino · Ana'), findsOneWidget);
    expect(pedidos.llamadas, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard muestra demoras extensas en días y horas', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DashboardResumenWidget(
              sucursalId: 'sucursal-prueba',
              dashboardRepository: _DashboardRepositoryConDomicilios(
                minutos: 162243,
              ),
              mesasRepository: _MesasRepositoryFake(),
              pedidosRepository: _PedidosRepositoryFake(),
              alertasRepository: _AlertasRepositoryFake(),
              inventarioRepository: _InventarioRepositoryFake(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('112d 16h'), findsOneWidget);
    expect(find.text('162243m'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(320, 640),
    const Size(390, 844),
    const Size(820, 900),
    const Size(1440, 900),
  ]) {
    testWidgets('centro de operación se adapta a ${size.width}px', (
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
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: DashboardResumenWidget(
                sucursalId: 'sucursal-prueba',
                dashboardRepository: _DashboardRepositoryFake(),
                mesasRepository: _MesasRepositoryFake(),
                pedidosRepository: _PedidosRepositoryFake(),
                alertasRepository: _AlertasRepositoryFake(),
                inventarioRepository: _InventarioRepositoryFake(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Centro de operación'), findsOneWidget);
      expect(find.text('Ventas hoy'), findsOneWidget);
      final alerta = tester.getSize(
        find.byKey(const ValueKey<String>('dashboard-kpi-Alertas')),
      );
      final activa = tester.getSize(
        find.byKey(const ValueKey<String>('dashboard-kpi-Activos')),
      );
      if (size.width <= 390) {
        expect(alerta.width, size.width - 32);
      } else if (size.width == 820) {
        expect(alerta.width, greaterThan(activa.width));
      }
      await tester.scrollUntilVisible(
        find.text('Alertas').last,
        260,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alertas').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Sin alertas pendientes'),
        260,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Sin alertas pendientes'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('un fallo parcial no se presenta como resultado vacío', (
    tester,
  ) async {
    final mesas = _MesasRepositoryFake(falla: true);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DashboardResumenWidget(
              sucursalId: 'sucursal-prueba',
              dashboardRepository: _DashboardRepositoryFake(),
              mesasRepository: mesas,
              pedidosRepository: _PedidosRepositoryFake(),
              alertasRepository: _AlertasRepositoryFake(),
              inventarioRepository: _InventarioRepositoryFake(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
        find.text(
            'No se actualizaron: mesas. Los valores visibles pueden estar desactualizados.'),
        findsOneWidget);
    expect(find.text('No se pudieron consultar las mesas.'), findsOneWidget);
    expect(find.text('Ninguna mesa demorada ahora'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('el refresco fallido conserva la última lista válida', (
    tester,
  ) async {
    final mesas = _MesasRepositoryFake(
      fallaTrasPrimeraCarga: true,
      filas: [
        {
          'id': 'mesa-12',
          'nombre': 'Mesa 12',
          'pedido_estado': 'en_cocina',
          'pedido_creado_at': DateTime.now()
              .subtract(const Duration(minutes: 25))
              .toIso8601String(),
        },
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DashboardResumenWidget(
              sucursalId: 'sucursal-prueba',
              dashboardRepository: _DashboardRepositoryFake(),
              mesasRepository: mesas,
              pedidosRepository: _PedidosRepositoryFake(),
              alertasRepository: _AlertasRepositoryFake(),
              inventarioRepository: _InventarioRepositoryFake(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Mesa 12'), findsOneWidget);

    await tester.tap(find.byTooltip('Actualizar'));
    await tester.pumpAndSettle();

    expect(find.text('Mesa 12'), findsOneWidget);
    expect(find.textContaining('No se actualizaron: mesas.'), findsOneWidget);
    expect(find.text('Ninguna mesa demorada ahora'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('la respuesta tardía de otra sede no reemplaza la actual', (
    tester,
  ) async {
    final sucursalId = ValueNotifier('sucursal-anterior');
    addTearDown(sucursalId.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ValueListenableBuilder<String>(
              valueListenable: sucursalId,
              builder: (context, sid, _) => DashboardResumenWidget(
                sucursalId: sid,
                dashboardRepository: _DashboardRepositoryConCambioDeSede(),
                mesasRepository: _MesasRepositoryFake(),
                pedidosRepository: _PedidosRepositoryFake(),
                alertasRepository: _AlertasRepositoryFake(),
                inventarioRepository: _InventarioRepositoryFake(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    sucursalId.value = 'sucursal-actual';
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();

    expect(find.textContaining('200.000'), findsOneWidget);
    expect(find.textContaining('100.000'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
