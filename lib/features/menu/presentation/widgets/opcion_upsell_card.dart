import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_tokens.dart';
import 'package:reserva_canchas/features/menu/domain/menu_model.dart';

/// Card horizontal de upsell (topping / bebida).
class OpcionUpsellCard extends StatelessWidget {
  const OpcionUpsellCard({
    super.key,
    required this.opcion,
    required this.cantidad,
    required this.onCambiar,
    required this.formato,
    this.acento = AnaliticaTokens.ink,
    this.maxCantidad = 1,
  });

  final OpcionMenuModel opcion;
  final int cantidad;
  final ValueChanged<int> onCambiar;
  final NumberFormat formato;
  final Color acento;
  /// Toppings: 1 (API sin qty). Bebidas: puede ser >1.
  final int maxCantidad;

  bool get _seleccionada => cantidad > 0;

  @override
  Widget build(BuildContext context) {
    final precioTxt = opcion.precio <= 0
        ? 'Gratis'
        : '+${formato.format(opcion.precio)}';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: 132,
      padding: const EdgeInsets.fromLTRB(12, 12, 10, 10),
      decoration: BoxDecoration(
        color: _seleccionada
            ? AnaliticaTokens.surfaceMuted
            : AnaliticaTokens.surface,
        borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
        border: Border.all(
          color: _seleccionada ? acento : AnaliticaTokens.border,
          width: _seleccionada ? 1.6 : 1,
        ),
        boxShadow: AnaliticaTokens.shadowSoft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            opcion.nombre,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              height: 1.2,
              color: AnaliticaTokens.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            precioTxt,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AnaliticaTokens.inkMuted,
            ),
          ),
          const Spacer(),
          Align(
            alignment: Alignment.centerRight,
            child: _seleccionada
                ? _stepper()
                : Material(
                    color: acento,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onCambiar(1);
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.add, size: 18, color: Colors.white),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _stepper() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onCambiar(cantidad - 1);
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(
              cantidad <= 1 ? Icons.delete_outline : Icons.remove,
              size: 18,
              color: acento,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            '$cantidad',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: acento,
            ),
          ),
        ),
        InkWell(
          onTap: cantidad >= maxCantidad
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onCambiar(cantidad + 1);
                },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(
              Icons.add,
              size: 18,
              color: cantidad >= maxCantidad
                  ? AnaliticaTokens.inkSoft
                  : acento,
            ),
          ),
        ),
      ],
    );
  }
}

/// Sección con título + lista horizontal de [OpcionUpsellCard].
class SeccionUpsellOpciones extends StatelessWidget {
  const SeccionUpsellOpciones({
    super.key,
    required this.titulo,
    required this.opciones,
    required this.cantidades,
    required this.onCambiar,
    required this.formato,
    this.acento = AnaliticaTokens.ink,
    this.maxCantidad = 1,
    this.subtitulo,
  });

  final String titulo;
  final String? subtitulo;
  final List<OpcionMenuModel> opciones;
  final Map<String, int> cantidades;
  final void Function(String id, int cantidad) onCambiar;
  final NumberFormat formato;
  final Color acento;
  final int maxCantidad;

  @override
  Widget build(BuildContext context) {
    if (opciones.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        Text(
          titulo,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AnaliticaTokens.ink,
              ),
        ),
        if (subtitulo != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitulo!,
            style: const TextStyle(
              fontSize: 12,
              color: AnaliticaTokens.inkMuted,
            ),
          ),
        ],
        const SizedBox(height: 10),
        SizedBox(
          height: 112,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: opciones.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final o = opciones[i];
              return OpcionUpsellCard(
                opcion: o,
                cantidad: cantidades[o.id] ?? 0,
                formato: formato,
                acento: acento,
                maxCantidad: maxCantidad,
                onCambiar: (c) => onCambiar(o.id, c.clamp(0, maxCantidad)),
              );
            },
          ),
        ),
      ],
    );
  }
}
