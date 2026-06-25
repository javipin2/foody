import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Cache local de pedidos del dispositivo (complementa GET /pedidos/mios).
class HistorialPedidosService {
  HistorialPedidosService._();

  static const _key = 'foody_historial_pedidos';
  static const _maxEntradas = 30;

  static Future<void> registrar({
    required String pedidoId,
    required String numeroPedido,
    required String sucursalNombre,
    num? total,
    String? estado,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final lista = _leerLista(prefs);
    lista.removeWhere((e) => e['pedido_id'] == pedidoId);
    lista.insert(0, {
      'pedido_id': pedidoId,
      'numero_pedido': numeroPedido,
      'sucursal_nombre': sucursalNombre,
      if (total != null) 'total': total,
      if (estado != null) 'estado': estado,
      'created_at': DateTime.now().toIso8601String(),
    });
    if (lista.length > _maxEntradas) {
      lista.removeRange(_maxEntradas, lista.length);
    }
    await prefs.setString(_key, jsonEncode(lista));
  }

  static Future<List<Map<String, dynamic>>> listarLocal() async {
    final prefs = await SharedPreferences.getInstance();
    return _leerLista(prefs);
  }

  static List<Map<String, dynamic>> _leerLista(SharedPreferences prefs) {
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
