import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_tokens.dart';
import 'package:reserva_canchas/features/menu/domain/menu_model.dart';
import 'package:reserva_canchas/features/menu/presentation/widgets/foody_pedido_sheet.dart';
import 'package:reserva_canchas/features/menu/presentation/widgets/opcion_upsell_card.dart';
import 'package:reserva_canchas/features/pedidos/domain/linea_carrito.dart';

/// Combo + toppings (extras de ítems) + bebidas como productos.
class DetalleComboSheet extends StatefulWidget {
  const DetalleComboSheet({
    super.key,
    required this.combo,
    required this.onAgregar,
    this.toppingsDisponibles = const [],
    this.sugerenciasBebidas = const [],
  });

  final ComboMenuModel combo;
  final void Function(List<LineaCarrito> lineas) onAgregar;
  final List<OpcionMenuModel> toppingsDisponibles;
  final List<ProductoMenuModel> sugerenciasBebidas;

  static Future<void> mostrar(
    BuildContext context, {
    required ComboMenuModel combo,
    required void Function(List<LineaCarrito> lineas) onAgregar,
    List<OpcionMenuModel> toppingsDisponibles = const [],
    List<ProductoMenuModel> sugerenciasBebidas = const [],
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DetalleComboSheet(
        combo: combo,
        toppingsDisponibles: toppingsDisponibles,
        sugerenciasBebidas: sugerenciasBebidas,
        onAgregar: (lineas) {
          onAgregar(lineas);
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
  final Map<String, int> _toppingsQty = {};
  final Map<String, int> _bebidasQty = {};
  int _cantidad = 1;

  List<OpcionMenuModel> get _opsBebidas => widget.sugerenciasBebidas
      .map((p) => OpcionMenuModel(id: p.id, nombre: p.nombre, precio: p.precio))
      .toList();

  /// ponytail: UI-only hint en sheet; total autoritativo = POST /pedidos/estimar.
  double get _precioPreview {
    var total = widget.combo.precioFijo.toDouble() * _cantidad;
    for (final t in widget.toppingsDisponibles) {
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
    final tops = widget.toppingsDisponibles
        .where((t) => (_toppingsQty[t.id] ?? 0) > 0)
        .map(
          (t) => ToppingLineaCarrito(
            id: t.id,
            nombre: t.nombre,
            precio: t.precio.toDouble(),
          ),
        )
        .toList();
    final lineas = <LineaCarrito>[
      LineaCarrito(
        clave: LineaCarrito.generarClaveCombo(
          widget.combo.id,
          toppingIds: tops.map((t) => t.id).toList(),
        ),
        comboId: widget.combo.id,
        nombre: widget.combo.nombre,
        precioUnitario: widget.combo.precioFijo.toDouble(),
        cantidad: _cantidad,
        toppings: tops,
        imagenUrl: widget.combo.imagenUrl,
        detalleIncluye: widget.combo.resumenItems.isNotEmpty
            ? widget.combo.resumenItems
            : ((widget.combo.descripcion ?? '').trim().isEmpty
                ? null
                : widget.combo.descripcion!.trim()),
        etiquetaTipo: 'Combo',
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
    final combo = widget.combo;
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
                    if (combo.imagenUrl != null && combo.imagenUrl!.isNotEmpty)
                      ClipRRect(
                        borderRadius:
                            BorderRadius.circular(AnaliticaTokens.r16),
                        child: CachedNetworkImage(
                          imageUrl: combo.imagenUrl!,
                          height: 140,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            height: 140,
                            color: AnaliticaTokens.surfaceMuted,
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: AnaliticaTokens.ink,
                              ),
                            ),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            height: 100,
                            color: AnaliticaTokens.surfaceMuted,
                            child: Icon(
                              Icons.layers_rounded,
                              size: 48,
                              color: AnaliticaTokens.ink.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      ),
                    if (combo.imagenUrl != null && combo.imagenUrl!.isNotEmpty)
                      const SizedBox(height: 16),
                    Text(
                      combo.nombre,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AnaliticaTokens.ink,
                            letterSpacing: -0.4,
                          ),
                    ),
                    if ((combo.descripcion ?? '').isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        combo.descripcion!,
                        style: const TextStyle(
                          color: AnaliticaTokens.inkMuted,
                          height: 1.35,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      _formato.format(combo.precioFijo),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AnaliticaTokens.ink,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Incluye',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AnaliticaTokens.ink,
                          ),
                    ),
                    const SizedBox(height: 8),
                    ...combo.items.map(
                      (item) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          _iconoTipo(item.tipoItem),
                          color: AnaliticaTokens.ink.withValues(alpha: 0.7),
                        ),
                        title: Text(
                          item.nombreItem,
                          style: const TextStyle(color: AnaliticaTokens.ink),
                        ),
                        trailing: Text(
                          '×${item.cantidad}',
                          style: const TextStyle(
                            color: AnaliticaTokens.inkMuted,
                          ),
                        ),
                      ),
                    ),
                    if (combo.items.isEmpty && combo.resumenItems.isNotEmpty)
                      Text(
                        combo.resumenItems,
                        style: const TextStyle(color: AnaliticaTokens.inkMuted),
                      ),
                    SeccionUpsellOpciones(
                      titulo: 'Toppings',
                      subtitulo: 'Extras opcionales',
                      opciones: widget.toppingsDisponibles,
                      cantidades: _toppingsQty,
                      formato: _formato,
                      acento: AnaliticaTokens.ink,
                      maxCantidad: 1,
                      onCambiar: (id, q) => _setQty(_toppingsQty, id, q),
                    ),
                    SeccionUpsellOpciones(
                      titulo: 'Bebidas',
                      subtitulo: 'Productos del menú',
                      opciones: _opsBebidas,
                      cantidades: _bebidasQty,
                      formato: _formato,
                      acento: AnaliticaTokens.ink,
                      maxCantidad: 5,
                      onCambiar: (id, q) => _setQty(_bebidasQty, id, q),
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
