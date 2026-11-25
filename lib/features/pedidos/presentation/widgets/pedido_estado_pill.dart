import 'package:flutter/material.dart';
import 'package:reserva_canchas/core/saas_ui/saas_tokens.dart';
import 'package:reserva_canchas/features/admin/presentation/widgets/operacion_ui.dart';

/// Pill pastel de estado de pedido (semántica neutra + AnaliticaTokens).
class PedidoEstadoPill extends StatelessWidget {
  const PedidoEstadoPill({
    super.key,
    required this.estado,
    this.paraCliente = false,
    this.grande = false,
  });

  final String estado;

  /// Etiquetas más amigables en mis-pedidos / seguimiento consumidor.
  final bool paraCliente;
  final bool grande;

  static String etiqueta(String estado, {bool paraCliente = false}) {
    if (paraCliente) {
      return switch (estado) {
        'pendiente_aprobacion' => 'Esperando mesera',
        'pendiente' => 'Recibido',
        'confirmado' || 'en_cocina' => 'En preparación',
        'listo' => 'Listo',
        'pagando' => 'Por pagar',
        'asignado' => 'Repartidor asignado',
        'en_camino' => 'En camino',
        'entregado' => 'Entregado',
        'pagado' => 'Pagado',
        'cancelado' => 'Cancelado',
        'rechazado' => 'Rechazado',
        _ => estado.replaceAll('_', ' '),
      };
    }
    return switch (estado) {
      'pendiente_aprobacion' => 'Pendiente QR',
      'pendiente' => 'Pendiente',
      'confirmado' || 'en_cocina' => 'En cocina',
      'listo' => 'Listo',
      'pagando' => 'Pagando',
      'asignado' => 'Asignado',
      'en_camino' => 'En camino',
      'entregado' => 'Entregado',
      'pagado' => 'Pagado',
      'cancelado' => 'Cancelado',
      'rechazado' => 'Rechazado',
      _ => estado.replaceAll('_', ' '),
    };
  }

  static (Color, Color) _colores(BuildContext context, String e) {
    switch (e) {
      case 'cancelado':
      case 'rechazado':
        return _coloresSemanticos(
          context,
          SaaSTokens.alertas,
          const Color(0xFFDC2626),
        );
      case 'entregado':
      case 'pagado':
        return _coloresSemanticos(
          context,
          SaaSTokens.positivo,
          const Color(0xFF16794C),
        );
      default:
        final c = OperacionUi.chipEstado(context, e);
        return (c.fondo, c.texto);
    }
  }

  static (Color, Color) _coloresSemanticos(
    BuildContext context,
    Color color,
    Color textoClaro,
  ) {
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    return (
      oscuro ? color.withValues(alpha: 0.2) : color.withValues(alpha: 0.12),
      oscuro ? Color.lerp(color, Colors.white, 0.46)! : textoClaro,
    );
  }

  @override
  Widget build(BuildContext context) {
    final e = estado.toLowerCase();
    final (bg, fg) = _colores(context, e);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: grande ? 14 : 8,
        vertical: grande ? 8 : 3,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        etiqueta(e, paraCliente: paraCliente),
        style: TextStyle(
          fontSize: grande ? 16 : 10,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}
