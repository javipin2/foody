import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reserva_canchas/features/admin/data/pedidos_repository.dart';
import 'package:reserva_canchas/features/mesa/data/mesas_repository.dart';
import 'package:reserva_canchas/features/mesa/presentation/mesa_pedidos_sheet.dart';
import 'package:reserva_canchas/core/sesion/sesion_staff_service.dart';
import 'package:reserva_canchas/services/app_backend.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _PedidosRepositoryFake extends PedidosRepository {
  _PedidosRepositoryFake({this.noDisponible = false});

  final bool noDisponible;

  @override
  Future<Map<String, dynamic>> obtenerPedidosMesa({
    required String mesaId,
    String? sucursalId,
  }) async =>
      {
        'total_acumulado': 50000,
        'saldo_pendiente': 50000,
        'pagos_abonos': const [
          {
            'id': 'abono-1',
            'monto': 2500,
            'propina': 0,
            'metodo_pago': 'efectivo',
            'numero_pedido': 'P-0002',
            'created_at': '2026-11-25T12:01:00.000Z',
            'responsable_nombre': 'Caja',
          },
        ],
        'pedidos': [
          {
            'id': 'pedido-1',
            'numero_pedido': 'P-0001',
            'estado': 'listo',
            'tipo': 'mesa',
            'total': 50000,
            'saldo_pendiente': 50000,
            'items': [
              {
                'id': 'item-1',
                'cantidad': 2,
                'producto': 'Hamburguesa especial con ingredientes extra',
                'estado_cocina': noDisponible ? 'no_disponible' : 'listo',
                'estado_cobro': 'pendiente',
              },
            ],
          },
        ],
      };
}

void main() {
  for (final brightness in Brightness.values) {
    for (final size in [const Size(320, 568), const Size(390, 844)]) {
      testWidgets(
          'detalle de mesa ${brightness.name} cabe en ${size.width}×${size.height}',
          (tester) async {
        SharedPreferences.setMockInitialValues({});
        FlutterSecureStorage.setMockInitialValues({});
        AppBackend.supabaseReady = false;
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(() => AppBackend.supabaseReady = false);

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(useMaterial3: true, brightness: brightness),
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: FilledButton(
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => MesaPedidosSheet(
                        mesaId: 'mesa-1',
                        mesaNombre: 'Mesa principal con nombre amplio',
                        sucursalId: 'sucursal-1',
                        onActualizado: () {},
                        modoMesero: true,
                        pedidosRepository:
                            _PedidosRepositoryFake(noDisponible: true),
                        mesasRepository: MesasRepository(),
                      ),
                    ),
                    child: const Text('Abrir mesa'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Abrir mesa'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        for (var i = 0; i < 20 && find.text('P-0001').evaluate().isEmpty; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }

        expect(find.text('Mesa principal con nombre amplio'), findsOneWidget);
        expect(find.text('P-0001'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.textContaining('Pedido P-0002'),
          160,
          scrollable: find
              .descendant(
                of: find.byType(MesaPedidosSheet),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(find.textContaining('Pedido P-0002'), findsOneWidget);
        expect(find.text('Listo para cobrar (avisar caja)'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(820, 900),
    const Size(1440, 900),
  ]) {
    testWidgets('diálogo de cobro de mesa se ajusta a ${size.width}px',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      AppBackend.supabaseReady = false;
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      addTearDown(() => AppBackend.supabaseReady = false);
      final exp =
          DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
              1000;
      final payload = base64Url
          .encode(utf8.encode(jsonEncode({'exp': exp})))
          .replaceAll('=', '');
      await SesionStaffService.guardar(
        token: 'header.$payload.signature',
        dashboard: 'restaurante',
        rol: 'cajero',
        permisos: const ['cobrar_pedido'],
        usuario: const {'id': 'user-1', 'sucursal_id': 'sucursal-1'},
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: FilledButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => MesaPedidosSheet(
                      mesaId: 'mesa-1',
                      mesaNombre: 'Mesa 1',
                      sucursalId: 'sucursal-1',
                      onActualizado: () {},
                      modoMesero: false,
                      pedidosRepository:
                          _PedidosRepositoryFake(noDisponible: true),
                      mesasRepository: MesasRepository(),
                    ),
                  ),
                  child: const Text('Abrir mesa'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir mesa'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      for (var i = 0;
          i < 20 && find.text('Cobrar todo').evaluate().isEmpty;
          i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.tap(find.textContaining('Cobrar todo'));
      await tester.pumpAndSettle();
      if (size.width == 320) {
        tester.view.viewInsets = const FakeViewPadding(bottom: 220);
        await tester.pumpAndSettle();
      }

      expect(find.text('Cobrar cuenta'), findsOneWidget);
      expect(find.textContaining('Total pendiente'), findsOneWidget);
      expect(find.text('Propina voluntaria'), findsOneWidget);
      expect(find.text('Aparte del total del pedido'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.textContaining('incluido'),
        ),
        findsOneWidget,
      );
      expect(find.text('Cancelar'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('diálogo de cuenta por cobrar cabe en móvil', (tester) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    AppBackend.supabaseReady = false;
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() => AppBackend.supabaseReady = false);
    final exp =
        DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
            1000;
    final payload = base64Url
        .encode(utf8.encode(jsonEncode({'exp': exp})))
        .replaceAll('=', '');
    await SesionStaffService.guardar(
      token: 'header.$payload.signature',
      dashboard: 'restaurante',
      rol: 'admin',
      permisos: const ['cobrar_pedido'],
      usuario: const {'id': 'user-1', 'sucursal_id': 'sucursal-1'},
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => MesaPedidosSheet(
                    mesaId: 'mesa-1',
                    mesaNombre: 'Mesa 1',
                    sucursalId: 'sucursal-1',
                    onActualizado: () {},
                    modoMesero: false,
                    pedidosRepository: _PedidosRepositoryFake(),
                    mesasRepository: MesasRepository(),
                  ),
                ),
                child: const Text('Abrir mesa'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir mesa'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('Opciones avanzadas'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Salió sin pagar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salió sin pagar'));
    await tester.pumpAndSettle();

    expect(find.text('Cliente salió sin pagar'), findsOneWidget);
    expect(find.text('Registrar CxC'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 250));
  });
}
