import 'package:flutter/material.dart';
import 'package:reserva_canchas/features/admin/domain/pedido_admin_model.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_tokens.dart';

/// Selector planta / dispatch independiente (extraído de kanban — FL-WIDGET-01).
class AsignarDomiciliarioSlot extends StatefulWidget {
  const AsignarDomiciliarioSlot({
    super.key,
    required this.pedido,
    required this.domiciliarios,
    required this.onAsignar,
    required this.onDispatchIndependiente,
    this.reasignar = false,
  });

  final PedidoAdminModel pedido;
  final List<Map<String, dynamic>> domiciliarios;
  final bool reasignar;
  final Future<void> Function(
    PedidoAdminModel,
    String, {
    bool reasignar,
  }) onAsignar;
  final Future<void> Function(PedidoAdminModel) onDispatchIndependiente;

  @override
  State<AsignarDomiciliarioSlot> createState() => _AsignarDomiciliarioSlotState();
}

class _AsignarDomiciliarioSlotState extends State<AsignarDomiciliarioSlot> {
  String? _seleccion;

  @override
  Widget build(BuildContext context) {
    final libres = widget.domiciliarios
        .where((d) => d['ocupado'] != true)
        .toList();
    final idsLibres = libres.map((d) => d['id'] as String).toList();
    final seleccion = idsLibres.contains(_seleccion)
        ? _seleccion
        : (idsLibres.isEmpty ? null : idsLibres.first);

    if (libres.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.reasignar
                  ? 'Sin otros domiciliarios libres para cambiar'
                  : 'Sin domiciliarios de planta libres',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            if (!widget.reasignar) ...[
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: () =>
                    widget.onDispatchIndependiente(widget.pedido),
                icon: const Icon(Icons.radar, size: 18),
                label: const Text('Buscar independiente'),
              ),
            ],
          ],
        ),
      );
    }

    _seleccion ??= libres.first['id'] as String?;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.reasignar &&
              widget.pedido.domiciliarioNombre?.trim().isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                'Actual: ${widget.pedido.domiciliarioNombre}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ),
          DropdownButtonFormField<String>(
            key: ValueKey(idsLibres.join('|')),
            initialValue: seleccion,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: widget.reasignar ? 'Nuevo domiciliario' : 'Domiciliario',
              isDense: true,
            ),
            items: libres
                .map(
                  (d) => DropdownMenuItem(
                    value: d['id'] as String,
                    child: Text(d['nombre'] as String? ?? '—'),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _seleccion = v),
          ),
          const SizedBox(height: 6),
          FilledButton(
            onPressed: seleccion == null
                ? null
                : () => widget.onAsignar(
                      widget.pedido,
                      seleccion,
                      reasignar: widget.reasignar,
                    ),
            style: FilledButton.styleFrom(backgroundColor: AnaliticaTokens.ink),
            child: Text(widget.reasignar ? 'Cambiar' : 'Asignar'),
          ),
          if (!widget.reasignar) ...[
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: () => widget.onDispatchIndependiente(widget.pedido),
              icon: const Icon(Icons.radar, size: 18),
              label: const Text('Buscar independiente'),
            ),
          ],
        ],
      ),
    );
  }
}
