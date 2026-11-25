import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reserva_canchas/features/pedidos/domain/pedido_admin_model.dart';
import 'package:reserva_canchas/features/pedidos/presentation/widgets/asignar_domiciliario_slot.dart';

void main() {
  testWidgets('si la disponibilidad cambia, Asignar usa un repartidor libre',
      (tester) async {
    String? asignado;
    final pedido = PedidoAdminModel(
      id: 'pedido-1',
      numeroPedido: 'P-001',
      tipo: 'domicilio',
      estado: 'listo',
      total: 12000,
      creadoEn: DateTime(2026, 11, 23),
      estadoDesde: DateTime(2026, 11, 23),
    );
    final iniciales = [
      {'id': 'repartidor-1', 'nombre': 'Ana', 'ocupado': false},
      {'id': 'repartidor-2', 'nombre': 'Luis', 'ocupado': false},
    ];

    Widget construir(List<Map<String, dynamic>> disponibles) => MaterialApp(
          home: Scaffold(
            body: AsignarDomiciliarioSlot(
              pedido: pedido,
              domiciliarios: disponibles,
              onAsignar: (p, id, {bool reasignar = false}) async {
                asignado = id;
              },
              onDispatchIndependiente: (_) async {},
            ),
          ),
        );

    await tester.pumpWidget(construir(iniciales));
    await tester.pump();
    await tester.pumpWidget(construir([iniciales[1]]));
    await tester.pump();

    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Asignar'));
    expect(asignado, 'repartidor-2');
  });
}
