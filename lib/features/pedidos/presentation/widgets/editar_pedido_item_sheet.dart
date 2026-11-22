import 'dart:async';

import 'package:flutter/material.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
import 'package:reserva_canchas/core/layout/foody_breakpoints.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';
import 'package:reserva_canchas/features/admin/data/pedidos_repository.dart';
import 'package:reserva_canchas/features/menu/data/menu_repository.dart';
import 'package:reserva_canchas/features/menu/domain/menu_model.dart';
import 'package:reserva_canchas/features/pedidos/domain/pedido_item_resumen.dart';

/// Edita cantidad / toppings / nota de un ítem (totales en backend).
Future<bool> mostrarEditarPedidoItemSheet({
  required BuildContext context,
  required String pedidoId,
  required String sucursalId,
  required PedidoItemResumen item,
}) async {
  final ancho = MediaQuery.sizeOf(context).width;
  final result = FoodyBreakpoints.esExpanded(ancho)
      ? await showDialog<bool>(
          context: context,
          builder: (ctx) => Dialog(
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440, maxHeight: 640),
              child: _EditarItemContenido(
                pedidoId: pedidoId,
                sucursalId: sucursalId,
                item: item,
                onCerrar: () => Navigator.pop(ctx, false),
                onGuardado: () => Navigator.pop(ctx, true),
              ),
            ),
          ),
        )
      : await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (ctx) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(ctx).bottom,
            ),
            child: _EditarItemContenido(
              pedidoId: pedidoId,
              sucursalId: sucursalId,
              item: item,
              onCerrar: () => Navigator.pop(ctx, false),
              onGuardado: () => Navigator.pop(ctx, true),
            ),
          ),
        );
  return result == true;
}

class _EditarItemContenido extends StatefulWidget {
  const _EditarItemContenido({
    required this.pedidoId,
    required this.sucursalId,
    required this.item,
    required this.onCerrar,
    required this.onGuardado,
  });

  final String pedidoId;
  final String sucursalId;
  final PedidoItemResumen item;
  final VoidCallback onCerrar;
  final VoidCallback onGuardado;

  @override
  State<_EditarItemContenido> createState() => _EditarItemContenidoState();
}

class _EditarItemContenidoState extends State<_EditarItemContenido> {
  final _repo = PedidosRepository();
  final _menuRepo = MenuRepository();
  final _notaCtrl = TextEditingController();
  late int _cantidad;
  late Set<String> _toppingIds;
  List<OpcionMenuModel> _toppingsDisponibles = [];
  bool _cargandoMenu = true;
  bool _guardando = false;
  String? _errorMenu;

  @override
  void initState() {
    super.initState();
    _cantidad = widget.item.cantidad;
    _toppingIds = {...widget.item.toppingIds};
    _notaCtrl.text = widget.item.observaciones ?? '';
    unawaited(_cargarToppings());
  }

  @override
  void dispose() {
    _notaCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarToppings() async {
    final productoId = widget.item.productoId;
    if (productoId == null || productoId.isEmpty) {
      setState(() {
        _cargandoMenu = false;
        _toppingsDisponibles = [];
      });
      return;
    }
    try {
      final menu = await _menuRepo.obtenerPorSucursal(widget.sucursalId);
      final prod = menu.todosLosProductos
          .where((p) => p.id == productoId)
          .firstOrNull;
      if (mounted) {
        setState(() {
          _toppingsDisponibles = prod?.toppings ?? [];
          _cargandoMenu = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMenu = mensajeErrorHttp(e, contexto: 'cargar toppings');
          _cargandoMenu = false;
        });
      }
    }
  }

  Future<void> _guardar() async {
    if (widget.item.cantidadInmutableEnCocina &&
        _cantidad < widget.item.cantidad) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se puede bajar la cantidad en cocina. Elimina el ítem con motivo.',
          ),
          backgroundColor: ColoresFoody.error,
        ),
      );
      return;
    }
    setState(() => _guardando = true);
    try {
      await _repo.actualizarItemPedido(
        pedidoId: widget.pedidoId,
        itemId: widget.item.itemId,
        sucursalId: widget.sucursalId,
        cantidad: _cantidad,
        observaciones: _notaCtrl.text.trim().isEmpty
            ? null
            : _notaCtrl.text.trim(),
        toppingIds: _toppingIds.toList(),
      );
      if (mounted) widget.onGuardado();
    } catch (e) {
      if (mounted) {
        setState(() => _guardando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensajeErrorHttp(e, contexto: 'actualizar ítem')),
            backgroundColor: ColoresFoody.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Editar ítem',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.item.nombre,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
          ),
          const SizedBox(height: 16),
          Text('Cantidad', style: TextStyle(color: Colors.grey.shade700)),
          const SizedBox(height: 6),
          Row(
            children: [
              IconButton.filledTonal(
                onPressed: _guardando ||
                        _cantidad <= 1 ||
                        widget.item.cantidadInmutableEnCocina
                    ? null
                    : () {
                        if (widget.item.cantidadInmutableEnCocina) return;
                        setState(() => _cantidad--);
                      },
                icon: const Icon(Icons.remove),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '$_cantidad',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton.filledTonal(
                onPressed:
                    _guardando ? null : () => setState(() => _cantidad++),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          if (widget.item.cantidadInmutableEnCocina) ...[
            const SizedBox(height: 8),
            Text(
              'Este ítem ya está en cocina. Para quitar unidades, elimínalo con motivo (merma).',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ],
          const SizedBox(height: 14),
          TextField(
            controller: _notaCtrl,
            enabled: !_guardando,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Nota / observaciones',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          if (_cargandoMenu)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_errorMenu != null)
            Text(_errorMenu!, style: TextStyle(color: ColoresFoody.error))
          else if (_toppingsDisponibles.isNotEmpty) ...[
            const Text(
              'Toppings',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in _toppingsDisponibles)
                  FilterChip(
                    label: Text(t.nombre),
                    selected: _toppingIds.contains(t.id),
                    onSelected: _guardando
                        ? null
                        : (sel) => setState(() {
                              if (sel) {
                                _toppingIds.add(t.id);
                              } else {
                                _toppingIds.remove(t.id);
                              }
                            }),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              TextButton(
                onPressed: _guardando ? null : widget.onCerrar,
                child: const Text('Cancelar'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _guardando ? null : _guardar,
                style: FilledButton.styleFrom(
                  backgroundColor: ColoresFoody.primario,
                ),
                child: _guardando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Guardar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
