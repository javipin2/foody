import 'package:go_router/go_router.dart';
import 'package:reserva_canchas/main.dart' show appNavigatorKey;

/// Navegación al abrir una notificación FCM (deep link).
class NavegadorFcmFoody {
  NavegadorFcmFoody._();

  static void manejar(Map<String, dynamic> data) {
    final ctx = appNavigatorKey.currentContext;
    if (ctx == null) return;

    final pedidoId = data['pedido_id']?.toString();
    final ruta = data['ruta']?.toString();
    final tipo = data['tipo']?.toString() ?? '';

    if (ruta != null && ruta.isNotEmpty) {
      if (ruta.startsWith('/pedidos/') && ruta.contains('/seguimiento')) {
        ctx.push(ruta);
        return;
      }
      ctx.go(ruta);
      return;
    }

    if (pedidoId != null && pedidoId.isNotEmpty) {
      if (tipo.contains('cliente') ||
          tipo.contains('seguimiento') ||
          tipo == 'pedido_cliente') {
        ctx.push('/pedidos/$pedidoId/seguimiento');
        return;
      }
      ctx.go('/admin/panel?tab=pedidos&pedido=$pedidoId');
      return;
    }

    if (tipo.contains('cocina') || tipo.contains('kds') || tipo == 'pedido_cocina') {
      ctx.go('/admin/cocina');
      return;
    }
    if (tipo.contains('mesero') || tipo.contains('qr_pendiente')) {
      ctx.go('/admin/mesero');
      return;
    }
    if (tipo.contains('domiciliario') ||
        tipo.contains('oferta') ||
        tipo == 'oferta_domicilio') {
      ctx.go('/domiciliario/independiente');
    }
  }
}
