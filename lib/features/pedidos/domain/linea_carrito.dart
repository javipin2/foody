class ToppingLineaCarrito {
  const ToppingLineaCarrito({
    required this.id,
    required this.nombre,
    required this.precio,
  });

  final String id;
  final String nombre;
  final double precio;
}

class BebidaLineaCarrito {
  const BebidaLineaCarrito({
    required this.id,
    required this.nombre,
    required this.precio,
    this.cantidad = 1,
  });

  final String id;
  final String nombre;
  final double precio;
  final int cantidad;
}

class LineaCarrito {
  LineaCarrito({
    required this.clave,
    required this.nombre,
    required this.precioUnitario,
    this.precioUnitarioLlevar,
    this.productoId = '',
    this.comboId,
    this.cantidad = 1,
    this.toppings = const [],
    this.bebidas = const [],
    this.observaciones,
    this.imagenUrl,
    this.esEncargo = false,
  }) : assert(productoId.isNotEmpty || comboId != null);

  final String clave;
  final String productoId;
  final String? comboId;
  final String nombre;
  /// Precio en local / mesa.
  final double precioUnitario;
  /// Precio para llevar o domicilio; null = mismo que [precioUnitario].
  final double? precioUnitarioLlevar;
  final int cantidad;
  final List<ToppingLineaCarrito> toppings;
  final List<BebidaLineaCarrito> bebidas;
  final String? observaciones;
  final String? imagenUrl;
  final bool esEncargo;

  bool get esCombo => comboId != null;

  bool get tienePrecioLlevarDistinto {
    final llevar = precioUnitarioLlevar;
    return llevar != null && (llevar - precioUnitario).abs() > 0.01;
  }

  double precioUnitarioPara(String tipoPedido) {
    if (tipoPedido == 'para_llevar' || tipoPedido == 'domicilio') {
      return precioUnitarioLlevar ?? precioUnitario;
    }
    return precioUnitario;
  }

  double get subtotal => subtotalPara('mesa');

  double subtotalPara(String tipoPedido) {
    final unit = precioUnitarioPara(tipoPedido);
    var total = unit * cantidad;
    for (final t in toppings) {
      total += t.precio * cantidad;
    }
    for (final b in bebidas) {
      total += b.precio * b.cantidad;
    }
    return total;
  }

  LineaCarrito copiarCon({int? cantidad}) {
    return LineaCarrito(
      clave: clave,
      productoId: productoId,
      comboId: comboId,
      nombre: nombre,
      precioUnitario: precioUnitario,
      precioUnitarioLlevar: precioUnitarioLlevar,
      cantidad: cantidad ?? this.cantidad,
      toppings: toppings,
      bebidas: bebidas,
      observaciones: observaciones,
      imagenUrl: imagenUrl,
      esEncargo: esEncargo,
    );
  }

  static String generarClaveCombo(String comboId) => 'combo:$comboId';

  static String generarClave({
    required String productoId,
    List<String> toppingIds = const [],
    List<String> bebidaIds = const [],
    String? observaciones,
  }) {
    final tops = [...toppingIds]..sort();
    final bebs = [...bebidaIds]..sort();
    final obs = observaciones?.trim() ?? '';
    return '$productoId|${tops.join(',')}|${bebs.join(',')}|$obs';
  }
}
