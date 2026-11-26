import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reserva_canchas/features/caja/data/caja_repository.dart';
import 'package:reserva_canchas/features/caja/presentation/caja_admin_screen.dart';

class _CajaRepositoryFake extends CajaRepository {
  _CajaRepositoryFake({
    this.turnoAbierto = false,
    this.horasAbierta = '2',
    this.movimientosDelPedido = const [],
    this.cuentas = const [],
  });

  final bool turnoAbierto;
  final String horasAbierta;
  final List<Map<String, dynamic>> movimientosDelPedido;
  final List<Map<String, dynamic>> cuentas;

  @override
  Future<Map<String, dynamic>?> cajaActiva(String sucursalId) async =>
      turnoAbierto
          ? {
              'id': 'caja-prueba',
              'total_ventas': '1250000',
              'total_gastos': '125000',
              'saldo_sistema': '1125000',
              'arqueo_ciego': false,
              'horas_abierta': horasAbierta,
            }
          : null;

  @override
  Future<List<Map<String, dynamic>>> movimientos(String cajaId) async => [];

  @override
  Future<List<Map<String, dynamic>>> movimientosPedido(
    String pedidoId, {
    required String sucursalId,
  }) async =>
      movimientosDelPedido;

  @override
  Future<Map<String, dynamic>> resumenCuentasPorCobrar(
    String sucursalId,
  ) async =>
      {
        'total_pendiente': 0,
        'cantidad_pendiente': cuentas.length,
        'antiguas_7d': 0,
      };

  @override
  Future<List<Map<String, dynamic>>> cuentasPorCobrar(
    String sucursalId, {
    bool incluirPagadas = false,
  }) async =>
      cuentas;
}

void main() {
  for (final size in [
    const Size(320, 640),
    const Size(390, 844),
    const Size(820, 900),
    const Size(1440, 900),
  ]) {
    testWidgets('apertura de caja se adapta a ${size.width}px', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData(useMaterial3: true),
            home: Scaffold(
              body: CajaAdminScreen(
                sucursalId: 'sucursal-1',
                permisos: const ['abrir_caja'],
                repository: _CajaRepositoryFake(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Abrir turno de caja'), findsOneWidget);
      expect(find.text('Monto inicial'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final size in [
    const Size(320, 640),
    const Size(390, 844),
    const Size(820, 900),
    const Size(1440, 900),
  ]) {
    testWidgets('turno activo y saldos caben a ${size.width}px', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData(useMaterial3: true),
            home: Scaffold(
              body: CajaAdminScreen(
                sucursalId: 'sucursal-1',
                repository: _CajaRepositoryFake(turnoAbierto: true),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Turno activo'), findsOneWidget);
      expect(find.text('Efectivo esperado'), findsOneWidget);
      expect(find.text('Ventas'), findsOneWidget);
      expect(find.text('Gastos'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Sin movimientos aún'),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Sin movimientos aún'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final caso in [
    (horas: '14', duracion: '14 h'),
    (horas: '2635', duracion: '109 días y 19 h'),
  ]) {
    testWidgets('turno largo se expresa en formato legible (${caso.horas} h)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData(useMaterial3: true),
            home: Scaffold(
              body: CajaAdminScreen(
                sucursalId: 'sucursal-1',
                repository: _CajaRepositoryFake(
                  turnoAbierto: true,
                  horasAbierta: caso.horas,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Turno abierto hace ${caso.duracion}. Revisa pedidos, mesas y domicilios pendientes antes de cerrar.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final size in [const Size(320, 640), const Size(820, 900)]) {
    testWidgets('aviso de turno largo navega a su acción en ${size.width}px', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var revisoOperaciones = false;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData(useMaterial3: true),
            home: Scaffold(
              body: CajaAdminScreen(
                sucursalId: 'sucursal-1',
                repository: _CajaRepositoryFake(
                  turnoAbierto: true,
                  horasAbierta: '14',
                ),
                onRevisarOperaciones: () => revisoOperaciones = true,
                etiquetaAccionTurnoLargo: 'Ver pedidos',
                textoAvisoTurnoLargo:
                    'Revisa los pedidos pendientes antes de cerrar.',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final accion = find.byKey(const ValueKey('caja.revisarOperaciones'));
      expect(find.text('Ver pedidos'), findsOneWidget);
      expect(tester.getSize(accion).height, greaterThanOrEqualTo(48));
      await tester.tap(accion);
      expect(revisoOperaciones, isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  for (final size in [
    const Size(320, 640),
    const Size(390, 844),
    const Size(820, 900),
    const Size(1440, 900),
  ]) {
    testWidgets(
      'muestra movimientos ligados al pedido sin turno abierto a ${size.width}px',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        var consumido = false;
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: ThemeData(useMaterial3: true),
              home: Scaffold(
                body: CajaAdminScreen(
                  sucursalId: 'sucursal-1',
                  permisos: const ['abrir_caja'],
                  pedidoIdInicial: 'pedido-1',
                  onPedidoInicialUsado: () => consumido = true,
                  repository: _CajaRepositoryFake(
                    movimientosDelPedido: [
                      {
                        'id': 'mov-1',
                        'numero_pedido': '42',
                        'tipo': 'venta',
                        'monto': 25000,
                        'metodo_pago': 'efectivo',
                        'descripcion': 'Pago de pedido',
                        'pedido_id': 'pedido-1',
                        'caja_estado': 'cerrada',
                      },
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Movimientos del pedido #42'), findsOneWidget);
        expect(find.text('venta'), findsOneWidget);
        expect(find.text('Abrir turno de caja'), findsOneWidget);
        expect(consumido, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('modo lectura oculta acciones que escriben en Caja', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: CajaAdminScreen(
              sucursalId: 'sucursal-1',
              permisos: const ['ver_caja'],
              repository: _CajaRepositoryFake(turnoAbierto: true),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Registrar fiado'), findsNothing);
    expect(find.text('Guardar gasto'), findsNothing);
    expect(find.text('Registrar retiro'), findsNothing);
    expect(find.text('Registrar devolución'), findsNothing);
    expect(find.text('Cerrar caja'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('las cuentas de domiciliario se liquidan desde Domiciliarios', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: CajaAdminScreen(
              sucursalId: 'sucursal-1',
              permisos: const ['gestionar_caja'],
              repository: _CajaRepositoryFake(
                turnoAbierto: true,
                cuentas: const [
                  {
                    'id': 'cuenta-domi',
                    'cliente_nombre': 'Domiciliario: Alex',
                    'monto': 8000,
                    'estado': 'pendiente',
                    'domiciliario_planta_id': 'domi-1',
                  },
                  {
                    'id': 'cuenta-cliente',
                    'cliente_nombre': 'Cliente fiado',
                    'monto': 5000,
                    'estado': 'pendiente',
                  },
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Domiciliario: Alex'),
      220,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Liquidar desde Domiciliarios'), findsOneWidget);
    expect(find.text('Cobrar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
