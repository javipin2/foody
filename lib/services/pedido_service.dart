import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:reserva_canchas/providers/menu_cart_provider.dart';
import 'package:reserva_canchas/services/app_backend.dart';

class PedidoService {
  PedidoService._();
  static final PedidoService instance = PedidoService._();

  Future<String> crearPedido({
    required String lugarId,
    required String sedeId,
    required Iterable<CartLine> items,
    String? observaciones,
  }) async {
    if (!AppBackend.supabaseReady) {
      throw Exception('Supabase no configurado');
    }
    final list = items.toList();
    if (list.isEmpty) {
      throw Exception('El carrito esta vacio');
    }

    final total = list.fold<double>(0, (sum, item) => sum + item.subtotal);
    final db = Supabase.instance.client;

    final pedido = await db
        .from('pedidos')
        .insert({
          'lugar_id': lugarId,
          'sede_id': sedeId,
          'estado': 'nuevo',
          'origen': 'app',
          'observaciones': observaciones?.trim().isEmpty ?? true
              ? null
              : observaciones!.trim(),
          'total': total,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        })
        .select('id')
        .single();

    final pedidoId = pedido['id'] as String;

    final payload = list
        .map((line) => {
              'pedido_id': pedidoId,
              'producto_id': line.productoId,
              'producto_nombre': line.nombre,
              'precio_unitario': line.precioUnit,
              'cantidad': line.cantidad,
              'subtotal': line.subtotal,
              'created_at': DateTime.now().toIso8601String(),
            })
        .toList();

    await db.from('pedido_items').insert(payload);
    return pedidoId;
  }
}
