import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:reserva_canchas/features/admin/domain/pedido_admin_model.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_tokens.dart';
import 'package:reserva_canchas/features/pedidos/presentation/widgets/pedido_kanban_card.dart';

/// Columna kanban: título, contador, suma $ y lista de cards.
class PedidoKanbanColumn extends StatelessWidget {
  const PedidoKanbanColumn({
    super.key,
    required this.titulo,
    required this.ancho,
    required this.pedidos,
    required this.formatoMoneda,
    required this.minutosEnEstado,
    required this.textoReloj,
    required this.colorReloj,
    required this.onTapPedido,
    required this.onAccionRapida,
    this.pieBuilder,
  });

  final String titulo;
  final double ancho;
  final List<PedidoAdminModel> pedidos;
  final NumberFormat formatoMoneda;
  final int Function(DateTime) minutosEnEstado;
  final String Function(int) textoReloj;
  final Color Function(int) colorReloj;
  final void Function(PedidoAdminModel) onTapPedido;
  final Future<void> Function(PedidoAdminModel) onAccionRapida;
  final Widget? Function(PedidoAdminModel)? pieBuilder;

  @override
  Widget build(BuildContext context) {
    final suma = pedidos.fold<num>(0, (s, p) => s + p.total);
    return Container(
      width: ancho,
      margin: const EdgeInsets.only(right: 12, bottom: 16),
      decoration: BoxDecoration(
        color: AnaliticaTokens.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AnaliticaTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    titulo,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AnaliticaTokens.ink,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AnaliticaTokens.ink,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${pedidos.length}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Text(
              formatoMoneda.format(suma),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AnaliticaTokens.inkMuted,
              ),
            ),
          ),
          Expanded(
            child: pedidos.isEmpty
                ? const Center(
                    child: Text(
                      'Sin pedidos',
                      style: TextStyle(
                        color: AnaliticaTokens.inkSoft,
                        fontSize: 12,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
                    itemCount: pedidos.length,
                    itemBuilder: (_, i) {
                      final p = pedidos[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: PedidoKanbanCard(
                          pedido: p,
                          formatoMoneda: formatoMoneda,
                          minutos: minutosEnEstado(p.estadoDesde),
                          textoReloj: textoReloj,
                          colorReloj: colorReloj,
                          onTap: () => onTapPedido(p),
                          onAccionRapida: () => onAccionRapida(p),
                          pieExtra: pieBuilder?.call(p),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
