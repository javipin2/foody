import 'package:flutter/material.dart';
import 'package:reserva_canchas/core/saas_ui/saas_tokens.dart';

/// Informa al cliente cuando Cocina reporta líneas que no puede servir.
class AvisoClienteItemsNoDisponibles extends StatelessWidget {
  const AvisoClienteItemsNoDisponibles({
    super.key,
    required this.items,
  });

  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final nombres = items.map((item) {
      final cantidad = item['cantidad'] ?? 1;
      final nombre = item['nombre'] as String? ?? 'Producto';
      return '$cantidad × $nombre';
    }).join(' · ');

    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        key: const ValueKey<String>('aviso-cliente-items-no-disponibles'),
        padding: const EdgeInsets.all(SaaSTokens.s16),
        decoration: BoxDecoration(
          color: SaaSTokens.surface(context),
          borderRadius: BorderRadius.circular(SaaSTokens.r12),
          border: Border.all(color: SaaSTokens.alertas.withValues(alpha: 0.55)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, color: SaaSTokens.alertas),
            const SizedBox(width: SaaSTokens.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Un producto requiere tu atención',
                    style: TextStyle(
                      color: SaaSTokens.ink(context),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: SaaSTokens.s4),
                  Text(
                    nombres,
                    style: TextStyle(color: SaaSTokens.ink(context)),
                  ),
                  const SizedBox(height: SaaSTokens.s8),
                  Text(
                    'El establecimiento debe confirmar contigo una solución antes de completar el pedido. El total aún no refleja ese ajuste.',
                    style: TextStyle(color: SaaSTokens.inkMuted(context)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
