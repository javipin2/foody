import 'package:flutter/foundation.dart';

import 'package:reserva_canchas/models/menu_catalogo.dart';

class CartLine {
  final String productoId;
  final String nombre;
  final double precioUnit;
  final String? imagenUrl;
  int cantidad;

  CartLine({
    required this.productoId,
    required this.nombre,
    required this.precioUnit,
    this.imagenUrl,
    this.cantidad = 1,
  });

  double get subtotal => precioUnit * cantidad;
}

/// Carrito en memoria (el guardado del pedido en Supabase vendrá después).
class MenuCartProvider with ChangeNotifier {
  final Map<String, CartLine> _lines = {};

  Map<String, CartLine> get lines => Map.unmodifiable(_lines);
  int get totalItems =>
      _lines.values.fold(0, (sum, line) => sum + line.cantidad);
  double get totalPrice =>
      _lines.values.fold(0.0, (sum, line) => sum + line.subtotal);

  void addProduct(MenuProducto p) {
    final existing = _lines[p.id];
    if (existing != null) {
      existing.cantidad += 1;
    } else {
      _lines[p.id] = CartLine(
        productoId: p.id,
        nombre: p.nombre,
        precioUnit: p.precio,
        imagenUrl: p.imagenUrl,
      );
    }
    notifyListeners();
  }

  void setQuantity(String productoId, int qty) {
    final line = _lines[productoId];
    if (line == null) return;
    if (qty <= 0) {
      _lines.remove(productoId);
    } else {
      line.cantidad = qty;
    }
    notifyListeners();
  }

  void removeLine(String productoId) {
    _lines.remove(productoId);
    notifyListeners();
  }

  void clear() {
    _lines.clear();
    notifyListeners();
  }
}
