import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reserva_canchas/features/domiciliarios/presentation/widgets/tarjeta_pedido_domiciliario.dart';

void main() {
  testWidgets('muestra todos los medios e importes pagados', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TarjetaPedidoDomiciliario(
              mostrarTelefono: false,
              mostrarMiniMapa: false,
              pedido: {
                'id': 'pedido-2',
                'numero_pedido': 'P-2',
                'estado': 'en_camino',
                'cliente_nombre': 'Cliente de prueba',
                'subtotal': '13000',
                'costo_domicilio': '0',
                'total': '13000',
                'metodo_pago': 'efectivo',
                'pagos_resumen': [
                  {'metodo_pago': 'transferencia', 'monto': '2000'},
                  {'metodo_pago': 'efectivo', 'monto': '6000'},
                  {'metodo_pago': 'nequi', 'monto': '5000'},
                ],
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Transferencia'), findsOneWidget);
    expect(find.textContaining('Efectivo'), findsOneWidget);
    expect(find.textContaining('Nequi'), findsOneWidget);
    expect(find.textContaining('2.000'), findsOneWidget);
    expect(find.textContaining('6.000'), findsOneWidget);
    expect(find.textContaining('5.000'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('distingue total de productos y saldo restante tras un abono',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TarjetaPedidoDomiciliario(
              mostrarTelefono: false,
              mostrarMiniMapa: false,
              pedido: {
                'id': 'pedido-1',
                'numero_pedido': 'P-1',
                'estado': 'en_camino',
                'estado_asignacion': 'en_camino',
                'cliente_nombre': 'Cliente de prueba',
                'subtotal': '100',
                'producto_total': 90,
                'costo_domicilio': '20',
                'total': '110',
                'monto_pagado': '40',
                'saldo_pendiente': 70,
                'requiere_cobro': true,
                'producto_pendiente': 50,
                'domicilio_pendiente': 20,
                'metodo_pago': 'transferencia',
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Producto'), findsOneWidget);
    expect(find.text('Saldo por cobrar'), findsOneWidget);
    expect(find.textContaining('90'), findsOneWidget);
    expect(find.textContaining('70'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
