import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';

/// Diálogo de upgrade cuando el plan gratis alcanza un límite numérico.
class PaywallLimitePlanDialog extends StatelessWidget {
  const PaywallLimitePlanDialog({
    super.key,
    required this.mensaje,
    this.limite,
    this.actual,
  });

  final String mensaje;
  final int? limite;
  final int? actual;

  static Future<void> mostrar(
    BuildContext context, {
    required String mensaje,
    int? limite,
    int? actual,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => PaywallLimitePlanDialog(
        mensaje: mensaje,
        limite: limite,
        actual: actual,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.workspace_premium_outlined, color: ColoresFoody.primario, size: 40),
      title: const Text('Límite de tu plan'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(mensaje),
          if (limite != null && actual != null) ...[
            const SizedBox(height: 12),
            Text(
              'Uso actual: $actual de $limite',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade700,
                  ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Mejora tu plan para seguir creciendo sin límites artificiales.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Ahora no'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop();
            context.push('/admin/mejorar-plan');
          },
          child: const Text('Ver planes'),
        ),
      ],
    );
  }
}
