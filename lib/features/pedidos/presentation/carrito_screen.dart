import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
import 'package:reserva_canchas/features/pedidos/providers/carrito_provider.dart';

class CarritoScreen extends ConsumerWidget {
  const CarritoScreen({
    super.key,
    required this.sucursalId,
    required this.sucursalNombre,
    this.mesaId,
    this.mesaNombre,
  });

  final String sucursalId;
  final String sucursalNombre;
  final String? mesaId;
  final String? mesaNombre;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final carrito = ref.watch(carritoProvider);
    final moneda = NumberFormat.currency(
      locale: 'es_CO',
      symbol: r'$',
      decimalDigits: 0,
    );

    return Scaffold(
      appBar: AppBar(title: Text('Carrito · $sucursalNombre')),
      body: carrito.lineas.isEmpty
          ? const Center(child: Text('Tu carrito está vacío'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final linea in carrito.lineas.values)
                  Card(
                    child: ListTile(
                      title: Text(linea.nombre),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${linea.cantidad} × ${moneda.format(linea.precioUnitario)}',
                          ),
                          if (linea.toppings.isNotEmpty)
                            Text(
                              '+ ${linea.toppings.map((t) => t.nombre).join(', ')}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          if (linea.bebidas.isNotEmpty)
                            Text(
                              '+ ${linea.bebidas.map((b) => b.nombre).join(', ')}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () => ref
                                .read(carritoProvider.notifier)
                                .quitarUno(linea.clave),
                          ),
                          Text('${linea.cantidad}'),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
      bottomNavigationBar: carrito.lineas.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: ColoresFoody.primario,
                    minimumSize: const Size.fromHeight(52),
                  ),
                  onPressed: () {
                    var q =
                        'sucursalNombre=${Uri.encodeComponent(sucursalNombre)}';
                    if (mesaId != null) {
                      q += '&mesa_id=$mesaId';
                      if (mesaNombre != null) {
                        q += '&mesa_nombre=${Uri.encodeComponent(mesaNombre!)}';
                      }
                    }
                    context.push('/checkout/$sucursalId?$q');
                  },
                  child: Text(
                    'Confirmar · ${moneda.format(carrito.totalPrecio)}',
                  ),
                ),
              ),
            ),
    );
  }
}
