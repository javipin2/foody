import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:reserva_canchas/features/pedidos/data/pedidos_repository.dart';
import 'package:reserva_canchas/features/pedidos/domain/pedido_admin_model.dart';
import 'package:reserva_canchas/features/pedidos/domain/pedido_item_resumen.dart';
import 'package:reserva_canchas/features/pedidos/presentation/pedido_detalle_sheet.dart';

class _PedidosFake extends PedidosRepository {
  @override
  Future<PedidoAdminModel> obtenerDetalle({
    required String pedidoId,
    String? sucursalId,
  }) async =>
      PedidoAdminModel(
        id: pedidoId,
        numeroPedido: 'P-0001',
        tipo: 'domicilio',
        estado: 'en_cocina',
        clienteNombre:
            'Cliente con nombre largo para probar el ajuste del detalle',
        clienteTelefono: '+57 300 123 4567',
        direccionEntrega:
            'Calle 123 #45-67, interior 9, barrio de nombre largo, Bogotá',
        domiciliarioNombre: 'Repartidor de prueba',
        total: 58000,
        pagosResumen: const [
          PagoPedidoResumen(metodoPago: 'efectivo', monto: 53000),
          PagoPedidoResumen(metodoPago: 'nequi', monto: 5000),
        ],
        propinaRecibida: 2000,
        creadoEn: DateTime(2026, 11, 22),
        estadoDesde: DateTime(2026, 11, 22),
        itemsResumen: const [
          PedidoItemResumen(
            itemId: 'item-1',
            cantidad: 2,
            nombre: 'Hamburguesa especial con queso extra y tocineta',
            estadoCocina: 'no_disponible',
            observaciones:
                'Sin cebolla, empacar aparte y llamar al llegar a portería',
            toppingsNombres: 'Queso cheddar, tocineta crocante',
          ),
        ],
      );
}

void main() {
  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(820, 700),
    const Size(1440, 700),
  ]) {
    testWidgets('detalle de pedido se ajusta a ${size.width}×${size.height}',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final pedido = PedidoAdminModel(
        id: 'pedido-1',
        numeroPedido: 'P-0001',
        tipo: 'domicilio',
        estado: 'en_cocina',
        total: 58000,
        creadoEn: DateTime(2026, 11, 22),
        estadoDesde: DateTime(2026, 11, 22),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: FilledButton(
                  onPressed: () => mostrarPedidoDetalleSheet(
                    context: context,
                    pedidoInicial: pedido,
                    sucursalId: 'sucursal-1',
                    modoMesero: false,
                    permisos: const ['cobrar_pedido', 'aplicar_descuento'],
                    formatoMoneda: NumberFormat.currency(
                      locale: 'es_CO',
                      symbol: r'$',
                      decimalDigits: 0,
                    ),
                    repository: _PedidosFake(),
                    onIrCaja: (_) {},
                    onCancelar: (_) async {},
                  ),
                  child: const Text('Abrir pedido'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir pedido'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      for (var i = 0;
          i < 20 && find.text('Productos').evaluate().isEmpty;
          i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.text('#P-0001'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Propina registrada · aparte'),
        120,
        scrollable: find
            .descendant(
              of: find.byType(PedidoDetalleSheet),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('Pagos registrados'), findsOneWidget);
      expect(find.text('Propina registrada · aparte'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Productos'),
        200,
        scrollable: find
            .descendant(
              of: find.byType(PedidoDetalleSheet),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('pedido-no-disponible-aviso')),
        200,
        scrollable: find
            .descendant(
              of: find.byType(PedidoDetalleSheet),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.textContaining('incluido'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Acciones'),
        250,
        scrollable: find
            .descendant(
              of: find.byType(PedidoDetalleSheet),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('Acciones'), findsOneWidget);
      expect(find.text('Ir a caja'), findsNothing);
      expect(find.text('Listo →'), findsNothing);
      expect(find.text('Confirmar'), findsNothing);
      expect(find.text('Cancelar pedido'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('muestra Ir a caja solo con el permiso ver_caja', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var cajaAbierta = false;
    String? pedidoCajaId;
    final pedido = PedidoAdminModel(
      id: 'pedido-1',
      numeroPedido: 'P-0001',
      tipo: 'domicilio',
      estado: 'en_cocina',
      total: 58000,
      creadoEn: DateTime(2026, 11, 22),
      estadoDesde: DateTime(2026, 11, 22),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () => mostrarPedidoDetalleSheet(
                  context: context,
                  pedidoInicial: pedido,
                  sucursalId: 'sucursal-1',
                  modoMesero: false,
                  permisos: const ['ver_caja'],
                  formatoMoneda: NumberFormat.currency(
                    locale: 'es_CO',
                    symbol: r'$',
                    decimalDigits: 0,
                  ),
                  repository: _PedidosFake(),
                  onIrCaja: (pedidoId) {
                    cajaAbierta = true;
                    pedidoCajaId = pedidoId;
                  },
                ),
                child: const Text('Abrir pedido'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir pedido'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    for (var i = 0; i < 20 && find.text('Acciones').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.scrollUntilVisible(
      find.text('Acciones'),
      250,
      scrollable: find
          .descendant(
            of: find.byType(PedidoDetalleSheet),
            matching: find.byType(Scrollable),
          )
          .first,
    );

    expect(find.text('Ir a caja'), findsOneWidget);
    await tester.tap(find.text('Ir a caja'));
    await tester.pumpAndSettle();
    expect(cajaAbierta, isTrue);
    expect(pedidoCajaId, pedido.id);
    expect(tester.takeException(), isNull);
  });
}
