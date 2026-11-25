import 'package:flutter/material.dart';
import 'package:reserva_canchas/core/saas_ui/saas_tokens.dart';

/// Aclara que marcar un producto como no disponible no lo descuenta de la cuenta.
class AvisoItemsNoDisponibles extends StatelessWidget {
  const AvisoItemsNoDisponibles({super.key, required this.cantidad});

  final int cantidad;

  @override
  Widget build(BuildContext context) {
    if (cantidad <= 0) return const SizedBox.shrink();
    final color = SaaSTokens.prioridadMedia;
    final productos = cantidad == 1 ? '1 producto' : '$cantidad productos';
    return Semantics(
      container: true,
      liveRegion: true,
      label:
          '$productos marcado${cantidad == 1 ? '' : 's'} como no disponible. Sigue incluido en el total. Confirma el ajuste con el cliente antes de cobrar.',
      child: Container(
        key: const ValueKey('pedido-no-disponible-aviso'),
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          border: Border.all(color: color.withValues(alpha: 0.35)),
          borderRadius: BorderRadius.circular(SaaSTokens.r12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_rounded, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$productos no disponible${cantidad == 1 ? '' : 's'}: '
                'sigue${cantidad == 1 ? '' : 'n'} incluido${cantidad == 1 ? '' : 's'} '
                'en el total. Confirma el ajuste con el cliente antes de cobrar.',
                style: TextStyle(
                  color: SaaSTokens.ink(context),
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
