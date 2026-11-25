import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:reserva_canchas/features/admin/domain/pedido_admin_model.dart';
import 'package:reserva_canchas/features/pedidos/domain/pedido_item_resumen.dart';
import 'package:reserva_canchas/features/pedidos/presentation/widgets/pedido_kanban_card.dart';

void main() {
  final pedido = PedidoAdminModel(
    id: 'pedido-1',
    numeroPedido: 'FOODY-000001',
    tipo: 'domicilio',
    estado: 'en_cocina',
    clienteNombre: 'Cliente con un nombre muy extenso para probar el recorte',
    direccionEntrega:
        'Carrera 123 #45-67, barrio de prueba, cerca del parque principal',
    domiciliarioNombre: 'Domiciliario de pruebas con nombre extenso',
    total: 125000,
    creadoEn: DateTime(2026, 11, 22),
    estadoDesde: DateTime(2026, 11, 22),
    itemsResumen: const [
      PedidoItemResumen(
        itemId: 'item-1',
        nombre: 'Hamburguesa especial con ingredientes adicionales',
        cantidad: 2,
        tieneToppings: true,
      ),
      PedidoItemResumen(
        itemId: 'item-2',
        nombre: 'Bebida familiar de prueba',
        cantidad: 1,
      ),
      PedidoItemResumen(
        itemId: 'item-3',
        nombre: 'Postre grande para compartir',
        cantidad: 1,
      ),
      PedidoItemResumen(
        itemId: 'item-4',
        nombre: 'Producto adicional',
        cantidad: 1,
      ),
    ],
  );

  for (final width in [280.0, 320.0, 390.0, 820.0, 1440.0]) {
    testWidgets('tarjeta de pedido sin overflow en ${width}px', (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: width - 24,
                child: PedidoKanbanCard(
                  pedido: pedido,
                  formatoMoneda: NumberFormat.currency(
                    locale: 'es_CO',
                    symbol: r'$',
                    decimalDigits: 0,
                  ),
                  minutos: 21,
                  textoReloj: (m) => '$m min',
                  colorReloj: (_) => Colors.red,
                  onTap: () {},
                  onAccionRapida: () async {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
          find.text(
              'Carrera 123 #45-67, barrio de prueba, cerca del parque principal'),
          findsOneWidget);
      expect(find.text('Listo →'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
