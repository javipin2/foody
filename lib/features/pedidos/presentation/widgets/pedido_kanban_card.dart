import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:reserva_canchas/features/admin/domain/pedido_admin_model.dart';
import 'package:reserva_canchas/features/admin/presentation/widgets/operacion_ui.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_tokens.dart';
import 'package:reserva_canchas/features/pedidos/presentation/widgets/pedido_estado_pill.dart';

/// Card de pedido — jerarquía: título → ítems → #pedido + tiempo + total.
class PedidoKanbanCard extends StatelessWidget {
  const PedidoKanbanCard({
    super.key,
    required this.pedido,
    required this.formatoMoneda,
    required this.minutos,
    required this.textoReloj,
    required this.colorReloj,
    required this.onTap,
    required this.onAccionRapida,
    this.pieExtra,
  });

  final PedidoAdminModel pedido;
  final NumberFormat formatoMoneda;
  final int minutos;
  final String Function(int) textoReloj;
  final Color Function(int) colorReloj;
  final VoidCallback onTap;
  final Future<void> Function() onAccionRapida;
  final Widget? pieExtra;

  Color? get _franjaUrgencia {
    if (pedido.esTerminal) return null;
    if (minutos >= 15) return AnaliticaTokens.alertas;
    if (minutos >= 8) return const Color(0xFFD97706);
    return null;
  }

  /// Título: mesa / cliente / canal.
  String get _tituloPrincipal {
    if (pedido.tipo == 'mesa') {
      final mesa = pedido.mesaNombre?.trim();
      if (mesa != null && mesa.isNotEmpty) return 'Mesa $mesa';
      final cli = pedido.clienteNombre?.trim();
      if (cli != null && cli.isNotEmpty) return cli;
      return 'Mesa';
    }
    final cli = pedido.clienteNombre?.trim();
    if (cli != null && cli.isNotEmpty) return cli;
    if (pedido.tipo == 'para_llevar') return 'Para llevar';
    if (pedido.tipo == 'domicilio') return 'Domicilio';
    return pedido.etiquetaCliente;
  }

  Color get _colorCta {
    // Verde solo para «Listo» (acción de cocina); resto ink.
    if (pedido.accionRapida == 'listo') return AnaliticaTokens.inventario;
    return AnaliticaTokens.ink;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colorTiempo = colorReloj(minutos);
    final items = pedido.itemsResumen;
    final preview = items.take(3).toList();
    final resto = items.length - preview.length;

    return OperacionTarjeta(
      usarTema: true,
      acentoIzquierdo: _franjaUrgencia,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  _tituloPrincipal,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                    height: 1.2,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              PedidoEstadoPill(estado: pedido.estadoKanban),
            ],
          ),
          if (pedido.tipo == 'mesa' &&
              pedido.clienteNombre?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(
              pedido.clienteNombre!,
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (pedido.meseraNombre?.trim().isNotEmpty == true)
            Text(
              'Mesera: ${pedido.meseraNombre}',
              style: TextStyle(
                fontSize: 11,
                color: scheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          if (pedido.domiciliarioNombre?.trim().isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  const Icon(
                    Icons.delivery_dining,
                    size: 14,
                    color: AnaliticaTokens.pedidos,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      pedido.domiciliarioNombre!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          if (pedido.tipo == 'domicilio' &&
              pedido.direccionEntrega?.trim().isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.place_outlined,
                    size: 14,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      pedido.direccionEntrega!,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: scheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          if (preview.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final it in preview)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        it.lineaPreview,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: scheme.onSurface,
                          height: 1.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (resto > 0)
                    Text(
                      '+$resto más',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                '#${pedido.numeroPedido}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (!pedido.esTerminal) ...[
                const SizedBox(width: 8),
                Icon(Icons.timer_outlined, size: 13, color: colorTiempo),
                const SizedBox(width: 3),
                Text(
                  textoReloj(minutos),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: colorTiempo,
                  ),
                ),
              ],
              const Spacer(),
              Text(
                formatoMoneda.format(pedido.total),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
          if (pedido.accionRapida != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onAccionRapida,
                style: FilledButton.styleFrom(
                  backgroundColor: _colorCta,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  visualDensity: VisualDensity.compact,
                ),
                child: Text(
                  '${pedido.etiquetaAccionRapida} →',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
          if (pieExtra != null) pieExtra!,
        ],
      ),
    );
  }
}
