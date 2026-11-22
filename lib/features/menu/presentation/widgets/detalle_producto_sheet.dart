import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_tokens.dart';
import 'package:reserva_canchas/features/menu/domain/menu_model.dart';
import 'package:reserva_canchas/features/menu/presentation/widgets/foody_pedido_sheet.dart';
import 'package:reserva_canchas/features/menu/presentation/widgets/opcion_upsell_card.dart';
import 'package:reserva_canchas/features/pedidos/domain/linea_carrito.dart';

/// Plato + toppings (extras del producto) + bebidas (productos del menú).
class DetalleProductoSheet extends StatefulWidget {
  const DetalleProductoSheet({
    super.key,
    required this.producto,
    required this.onAgregar,
    this.sugerenciasBebidas = const [],
  });

  final ProductoMenuModel producto;
  final void Function(List<LineaCarrito> lineas) onAgregar;
  /// Bebidas vendibles como productos (categoría Bebidas).
  final List<ProductoMenuModel> sugerenciasBebidas;

  static Future<void> mostrar(
    BuildContext context, {
    required ProductoMenuModel producto,
    required void Function(List<LineaCarrito> lineas) onAgregar,
    List<ProductoMenuModel> sugerenciasBebidas = const [],
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DetalleProductoSheet(
        producto: producto,
        sugerenciasBebidas: sugerenciasBebidas,
        onAgregar: (lineas) {
          onAgregar(lineas);
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
  final Map<String, int> _toppingsQty = {};
  final Map<String, int> _bebidasQty = {};
  final _observacionesCtrl = TextEditingController();
  int _cantidad = 1;

  @override
  void dispose() {
    _observacionesCtrl.dispose();
    super.dispose();
  }

  List<OpcionMenuModel> get _opsBebidas => widget.sugerenciasBebidas
      .map((p) => OpcionMenuModel(id: p.id, nombre: p.nombre, precio: p.precio))
      .toList();

  /// ponytail: UI-only hint en sheet; total autoritativo = POST /pedidos/estimar.
  double get _precioPreview {
    var total = widget.producto.precio.toDouble() * _cantidad;
    for (final t in widget.producto.toppings) {
      final q = _toppingsQty[t.id] ?? 0;
      if (q > 0) total += t.precio.toDouble() * _cantidad * q;
    }
    for (final p in widget.sugerenciasBebidas) {
      final q = _bebidasQty[p.id] ?? 0;
      if (q > 0) total += p.precio.toDouble() * q;
    }
    return total;
  }

  void _setQty(Map<String, int> map, String id, int qty) {
    setState(() {
      if (qty <= 0) {
        map.remove(id);
      } else {
        map[id] = qty;
      }
    });
  }

  void _confirmar() {
    HapticFeedback.mediumImpact();
    final tops = widget.producto.toppings
        .where((t) => (_toppingsQty[t.id] ?? 0) > 0)
        .map(
          (t) => ToppingLineaCarrito(
            id: t.id,
            nombre: t.nombre,
            precio: t.precio.toDouble(),
          ),
        )
        .toList();
    final obs = _observacionesCtrl.text.trim();
    final lineas = <LineaCarrito>[
      LineaCarrito(
        clave: LineaCarrito.generarClave(
          productoId: widget.producto.id,
          toppingIds: tops.map((t) => t.id).toList(),
          observaciones: obs,
        ),
        productoId: widget.producto.id,
        nombre: widget.producto.nombre,
        precioUnitario: widget.producto.precio.toDouble(),
        precioUnitarioLlevar: widget.producto.precioParaLlevar?.toDouble(),
        cantidad: _cantidad,
        toppings: tops,
        observaciones: obs.isEmpty ? null : obs,
        imagenUrl: widget.producto.imagenUrl,
        esEncargo: widget.producto.esEncargo,
        detalleIncluye: (widget.producto.descripcion ?? '').trim().isEmpty
            ? null
            : widget.producto.descripcion!.trim(),
        etiquetaTipo: widget.producto.esEncargo ? 'Encargo' : 'Plato',
      ),
    ];
    for (final p in widget.sugerenciasBebidas) {
      final q = _bebidasQty[p.id] ?? 0;
      if (q <= 0) continue;
      lineas.add(
        LineaCarrito(
          clave: LineaCarrito.generarClave(productoId: p.id),
          productoId: p.id,
          nombre: p.nombre,
          precioUnitario: p.precio.toDouble(),
          precioUnitarioLlevar: p.precioParaLlevar?.toDouble(),
          cantidad: q,
          imagenUrl: p.imagenUrl,
          detalleIncluye: (p.descripcion ?? '').trim().isEmpty
              ? null
              : p.descripcion!.trim(),
          etiquetaTipo: 'Bebida',
        ),
      );
    }
    widget.onAgregar(lineas);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.producto;
    return FoodyPedidoSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AnaliticaTokens.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const FoodySheetHandle(),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  children: [
                    Text(
                      p.nombre,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AnaliticaTokens.ink,
                            letterSpacing: -0.4,
                          ),
                    ),
                    if ((p.descripcion ?? '').isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        p.descripcion!,
                        style: const TextStyle(
                          color: AnaliticaTokens.inkMuted,
                          height: 1.35,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      _formato.format(p.precio),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AnaliticaTokens.ink,
                      ),
                    ),
                    if (p.toppings.isNotEmpty || _opsBebidas.isNotEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'Elige extras si quieres; el total se actualiza abajo.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AnaliticaTokens.inkMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    SeccionUpsellOpciones(
                      titulo: 'Toppings',
                      subtitulo: 'Extras de este plato',
                      opciones: p.toppings,
                      cantidades: _toppingsQty,
                      formato: _formato,
                      acento: AnaliticaTokens.ink,
                      maxCantidad: 1,
                      onCambiar: (id, q) => _setQty(_toppingsQty, id, q),
                    ),
                    SeccionUpsellOpciones(
                      titulo: 'Bebidas',
                      subtitulo: 'También en el menú como producto',
                      opciones: _opsBebidas,
                      cantidades: _bebidasQty,
                      formato: _formato,
                      acento: AnaliticaTokens.ink,
                      maxCantidad: 5,
                      onCambiar: (id, q) => _setQty(_bebidasQty, id, q),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _observacionesCtrl,
                      maxLines: 2,
                      style: const TextStyle(color: AnaliticaTokens.ink),
                      decoration: InputDecoration(
                        labelText: 'Observaciones',
                        hintText: 'Ej. sin cebolla, poco picante',
                        labelStyle:
                            const TextStyle(color: AnaliticaTokens.inkMuted),
                        filled: true,
                        fillColor: AnaliticaTokens.surfaceMuted,
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AnaliticaTokens.r12),
                          borderSide:
                              const BorderSide(color: AnaliticaTokens.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AnaliticaTokens.r12),
                          borderSide:
                              const BorderSide(color: AnaliticaTokens.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AnaliticaTokens.r12),
                          borderSide: const BorderSide(
                            color: AnaliticaTokens.ink,
                            width: 1.4,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton.filled(
                          onPressed: _cantidad > 1
                              ? () {
                                  HapticFeedback.selectionClick();
                                  setState(() => _cantidad--);
                                }
                              : null,
                          icon: const Icon(Icons.remove),
                          style: IconButton.styleFrom(
                            backgroundColor: AnaliticaTokens.surfaceMuted,
                            foregroundColor: AnaliticaTokens.ink,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 150),
                            transitionBuilder: (child, anim) => ScaleTransition(
                              scale: anim,
                              child: child,
                            ),
                            child: Text(
                              '$_cantidad',
                              key: ValueKey(_cantidad),
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: AnaliticaTokens.ink,
                                  ),
                            ),
                          ),
                        ),
                        IconButton.filled(
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            setState(() => _cantidad++);
                          },
                          icon: const Icon(Icons.add),
                          style: IconButton.styleFrom(
                            backgroundColor: AnaliticaTokens.ink,
                            foregroundColor: Colors.white,
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
                      backgroundColor: AnaliticaTokens.ink,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AnaliticaTokens.r12),
                      ),
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: Text(
                        'Agregar · ${_formato.format(_precioPreview)}',
                        key: ValueKey(_precioPreview),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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
