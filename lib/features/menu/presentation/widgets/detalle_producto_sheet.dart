import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
import 'package:reserva_canchas/features/menu/domain/menu_model.dart';
import 'package:reserva_canchas/features/pedidos/domain/linea_carrito.dart';

/// Modal de personalización (toppings / bebidas) antes de agregar al carrito.
class DetalleProductoSheet extends StatefulWidget {
  const DetalleProductoSheet({
    super.key,
    required this.producto,
    required this.onAgregar,
  });

  final ProductoMenuModel producto;
  final void Function(LineaCarrito linea) onAgregar;

  static Future<void> mostrar(
    BuildContext context, {
    required ProductoMenuModel producto,
    required void Function(LineaCarrito linea) onAgregar,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DetalleProductoSheet(
        producto: producto,
        onAgregar: (linea) {
          onAgregar(linea);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  @override
  State<DetalleProductoSheet> createState() => _DetalleProductoSheetState();
}

class _DetalleProductoSheetState extends State<DetalleProductoSheet> {
  final _formato = NumberFormat.currency(
    locale: 'es_CO',
    symbol: r'$',
    decimalDigits: 0,
  );
  final Set<String> _toppingsSel = {};
  final Set<String> _bebidasSel = {};
  final _observacionesCtrl = TextEditingController();
  int _cantidad = 1;

  @override
  void dispose() {
    _observacionesCtrl.dispose();
    super.dispose();
  }

  double get _precioPreview {
    var total = widget.producto.precio.toDouble() * _cantidad;
    for (final t in widget.producto.toppings) {
      if (_toppingsSel.contains(t.id)) {
        total += t.precio.toDouble() * _cantidad;
      }
    }
    for (final b in widget.producto.bebidas) {
      if (_bebidasSel.contains(b.id)) {
        total += b.precio.toDouble();
      }
    }
    return total;
  }

  void _confirmar() {
    HapticFeedback.lightImpact();
    final tops = widget.producto.toppings
        .where((t) => _toppingsSel.contains(t.id))
        .map(
          (t) => ToppingLineaCarrito(
            id: t.id,
            nombre: t.nombre,
            precio: t.precio.toDouble(),
          ),
        )
        .toList();
    final bebs = widget.producto.bebidas
        .where((b) => _bebidasSel.contains(b.id))
        .map(
          (b) => BebidaLineaCarrito(
            id: b.id,
            nombre: b.nombre,
            precio: b.precio.toDouble(),
          ),
        )
        .toList();

    final clave = LineaCarrito.generarClave(
      productoId: widget.producto.id,
      toppingIds: tops.map((t) => t.id).toList(),
      bebidaIds: bebs.map((b) => b.id).toList(),
      observaciones: _observacionesCtrl.text,
    );

    widget.onAgregar(
      LineaCarrito(
        clave: clave,
        productoId: widget.producto.id,
        nombre: widget.producto.nombre,
        precioUnitario: widget.producto.precio.toDouble(),
        precioUnitarioLlevar: widget.producto.precioParaLlevar?.toDouble(),
        cantidad: _cantidad,
        toppings: tops,
        bebidas: bebs,
        observaciones: _observacionesCtrl.text.trim().isEmpty
            ? null
            : _observacionesCtrl.text.trim(),
        imagenUrl: widget.producto.imagenUrl,
        esEncargo: widget.producto.esEncargo,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.producto;
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.92,
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
                      p.nombre,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    if ((p.descripcion ?? '').isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        p.descripcion!,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      _formato.format(p.precio),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: ColoresFoody.primario,
                      ),
                    ),
                    if (p.toppings.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text('Extras', style: Theme.of(context).textTheme.titleMedium),
                      ...p.toppings.map(
                        (t) => CheckboxListTile(
                          value: _toppingsSel.contains(t.id),
                          onChanged: (v) => setState(() {
                            if (v == true) {
                              _toppingsSel.add(t.id);
                            } else {
                              _toppingsSel.remove(t.id);
                            }
                          }),
                          title: Text(t.nombre),
                          secondary: Text(_formato.format(t.precio)),
                          activeColor: ColoresFoody.primario,
                        ),
                      ),
                    ],
                    if (p.bebidas.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text('Bebidas', style: Theme.of(context).textTheme.titleMedium),
                      ...p.bebidas.map(
                        (b) => CheckboxListTile(
                          value: _bebidasSel.contains(b.id),
                          onChanged: (v) => setState(() {
                            if (v == true) {
                              _bebidasSel.add(b.id);
                            } else {
                              _bebidasSel.remove(b.id);
                            }
                          }),
                          title: Text(b.nombre),
                          secondary: Text(_formato.format(b.precio)),
                          activeColor: ColoresFoody.secundario,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: _observacionesCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Observaciones',
                        hintText: 'Ej. sin cebolla, poco picante',
                        border: OutlineInputBorder(),
                      ),
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
                      'Agregar · ${_formato.format(_precioPreview)}',
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
}
