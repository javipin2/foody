class MenuCategoria {
  final String id;
  final String nombre;
  final int orden;

  const MenuCategoria({
    required this.id,
    required this.nombre,
    required this.orden,
  });

  factory MenuCategoria.fromRow(Map<String, dynamic> row) {
    return MenuCategoria(
      id: row['id'] as String,
      nombre: (row['nombre'] as String?)?.trim() ?? '',
      orden: (row['orden'] as int?) ?? 0,
    );
  }
}

class MenuProducto {
  final String id;
  final String? categoriaId;
  final String nombre;
  final String? descripcion;
  final double precio;
  final String? imagenUrl;
  final int orden;

  const MenuProducto({
    required this.id,
    this.categoriaId,
    required this.nombre,
    this.descripcion,
    required this.precio,
    this.imagenUrl,
    required this.orden,
  });

  factory MenuProducto.fromRow(Map<String, dynamic> row) {
    final precioRaw = row['precio'];
    double precio;
    if (precioRaw is num) {
      precio = precioRaw.toDouble();
    } else {
      precio = double.tryParse('$precioRaw') ?? 0;
    }
    return MenuProducto(
      id: row['id'] as String,
      categoriaId: row['categoria_id'] as String?,
      nombre: (row['nombre'] as String?)?.trim() ?? '',
      descripcion: (row['descripcion'] as String?)?.trim(),
      precio: precio,
      imagenUrl: (row['imagen_url'] as String?)?.trim(),
      orden: (row['orden'] as int?) ?? 0,
    );
  }
}
