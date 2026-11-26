import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reserva_canchas/features/menu/domain/menu_model.dart';
import 'package:reserva_canchas/features/menu/presentation/widgets/detalle_combo_sheet.dart';
import 'package:reserva_canchas/features/menu/presentation/widgets/opcion_upsell_card.dart';
import 'package:reserva_canchas/features/pedidos/domain/linea_carrito.dart';

void main() {
  testWidgets('agrupa toppings por plato y conserva el destino al agregar',
      (tester) async {
    final agregadas = <List<LineaCarrito>>[];
    final combo = ComboMenuModel(
      id: 'combo-1',
      nombre: 'Combo para compartir',
      precioFijo: 30000,
      disponible: true,
      items: const [
        ComboItemMenuModel(
          tipoItem: 'producto',
          itemId: 'plato-1',
          nombreItem: 'Picada',
        ),
        ComboItemMenuModel(
          tipoItem: 'producto',
          itemId: 'plato-2',
          nombreItem: 'Hamburguesa',
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => DetalleComboSheet(
                combo: combo,
                toppingsDisponibles: const [
                  ToppingComboDisponible(
                    productoId: 'plato-1',
                    productoNombre: 'Picada',
                    topping: OpcionMenuModel(
                      id: 'queso',
                      nombre: 'Queso',
                      precio: 1000,
                    ),
                  ),
                  ToppingComboDisponible(
                    productoId: 'plato-2',
                    productoNombre: 'Hamburguesa',
                    topping: OpcionMenuModel(
                      id: 'tocineta',
                      nombre: 'Tocineta',
                      precio: 1500,
                    ),
                  ),
                ],
                onAgregar: agregadas.add,
              ),
            ),
            child: const Text('Abrir combo'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Abrir combo'));
    await tester.pumpAndSettle();
    expect(find.text('Para Picada'), findsOneWidget);
    expect(find.text('Para Hamburguesa'), findsOneWidget);

    final queso = find.ancestor(
      of: find.text('Queso'),
      matching: find.byType(OpcionUpsellCard),
    );
    await tester
        .tap(find.descendant(of: queso, matching: find.byIcon(Icons.add)));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Agregar ·'));
    await tester.pumpAndSettle();

    expect(agregadas, hasLength(1));
    expect(agregadas.single.single.toppings, hasLength(1));
    expect(agregadas.single.single.toppings.single.id, 'queso');
    expect(agregadas.single.single.toppings.single.productoId, 'plato-1');
  });
}
