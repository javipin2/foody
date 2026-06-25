import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
import 'package:reserva_canchas/features/menu/domain/menu_model.dart';
import 'package:reserva_canchas/features/pedidos/domain/linea_carrito.dart';

/// Modal para confirmar combo (ítems incluidos + cantidad).
class DetalleComboSheet extends StatefulWidget {
  const DetalleComboSheet({
    super.key,
    required this.combo,
    required this.onAgregar,
  });

  final ComboMenuModel combo;
  final void Function(LineaCarrito linea) onAgregar;

  static Future<void> mostrar(
    BuildContext context, {
    required ComboMenuModel combo,
    required void Function(LineaCarrito linea) onAgregar,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DetalleComboSheet(
        combo: combo,
        onAgregar: (linea) {
          onAgregar(linea);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  @override
  State<DetalleComboSheet> createState() => _DetalleComboSheetState();
}

class _DetalleComboSheetState extends State<DetalleComboSheet> {
  final _formato = NumberFormat.currency(
    locale: 'es_CO',
    symbol: r'$',
    decimalDigits: 0,
  );
  int _cantidad = 1;

  void _confirmar() {
    HapticFeedback.lightImpact();
    widget.onAgregar(
      LineaCarrito(
        clave: LineaCarrito.generarClaveCombo(widget.combo.id),
        comboId: widget.combo.id,
        nombre: widget.combo.nombre,
        precioUnitario: widget.combo.precioFijo.toDouble(),
        cantidad: _cantidad,
        imagenUrl: widget.combo.imagenUrl,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final combo = widget.combo;
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.85,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  children: [
                    Text(
                      combo.nombre,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    if ((combo.descripcion ?? '').isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        combo.descripcion!,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      _formato.format(combo.precioFijo),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: ColoresFoody.primario,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Incluye',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    ...combo.items.map(
                      (item) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          _iconoTipo(item.tipoItem),
                          color: ColoresFoody.secundario,
                        ),
                        title: Text(item.nombreItem),
                        trailing: Text('×${item.cantidad}'),
                      ),
                    ),
                    if (combo.items.isEmpty && combo.resumenItems.isNotEmpty)
                      Text(
                        combo.resumenItems,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton.filled(
                          onPressed: _cantidad > 1
                              ? () => setState(() => _cantidad--)
                              : null,
                          icon: const Icon(Icons.remove),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            '$_cantidad',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ),
                        IconButton.filled(
                          onPressed: () => setState(() => _cantidad++),
                          icon: const Icon(Icons.add),
                          style: IconButton.styleFrom(
                            backgroundColor: ColoresFoody.primario,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: FilledButton(
                    onPressed: _confirmar,
                    style: FilledButton.styleFrom(
                      backgroundColor: ColoresFoody.primario,
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: Text(
                      'Agregar · ${_formato.format(combo.precioFijo.toDouble() * _cantidad)}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _iconoTipo(String tipo) {
    switch (tipo) {
      case 'bebida':
        return Icons.local_drink_outlined;
      case 'topping':
        return Icons.add_circle_outline;
      default:
        return Icons.restaurant;
    }
  }
}
