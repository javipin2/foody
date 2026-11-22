import 'package:reserva_canchas/core/utilidades/parsear_numero.dart';

class MenuModel {
  const MenuModel({
    required this.sucursal,
    required this.categorias,
    required this.combos,
  });

  final SucursalMenuModel sucursal;
  final List<CategoriaMenuModel> categorias;
  final List<ComboMenuModel> combos;

  List<ProductoMenuModel> get todosLosProductos => [
        for (final c in categorias) ...c.productos,
      ];

  /// Productos de categorías Bebidas/Jugos.
  List<ProductoMenuModel> productosBebidasVendibles({String? excluirId}) {
    return [
      for (final c in categorias)
        if (esNombreCategoriaBebidas(c.nombre))
          for (final p in c.productos)
            if (p.disponible && p.id != excluirId) p.conCategoria(c.id),
    ];
  }

  static bool esNombreCategoriaExtras(String nombre) {
    final n = nombre.trim().toLowerCase();
    return n.contains('extra') ||
        n.contains('topping') ||
        n.contains('adicional') ||
        n == 'extras';
  }

  static bool esNombreCategoriaBebidas(String nombre) {
    final n = nombre.trim().toLowerCase();
    return n.contains('bebida') || n.contains('jugo');
  }

  bool productoEsDeCategoriaBebidas(ProductoMenuModel p) {
    for (final c in categorias) {
      if (c.productos.any((x) => x.id == p.id)) {
        return esNombreCategoriaBebidas(c.nombre);
      }
    }
    return false;
  }

  bool productoEsUpsell(ProductoMenuModel p) {
    for (final c in categorias) {
      if (c.productos.any((x) => x.id == p.id)) {
        return esNombreCategoriaExtras(c.nombre) ||
            esNombreCategoriaBebidas(c.nombre);
      }
    }
    return false;
  }

  factory MenuModel.fromJson(Map<String, dynamic> json) {
    return MenuModel(
      sucursal: SucursalMenuModel.fromJson(
        json['sucursal'] as Map<String, dynamic>,
      ),
      categorias: (json['categorias'] as List<dynamic>)
          .map((e) => CategoriaMenuModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      combos: (json['combos'] as List<dynamic>? ?? [])
          .map((e) => ComboMenuModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class CiudadMenuModel {
  const CiudadMenuModel({
    required this.id,
    required this.nombre,
    required this.slug,
  });

  final String id;
  final String nombre;
  final String slug;

  factory CiudadMenuModel.fromJson(Map<String, dynamic> json) {
    return CiudadMenuModel(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      slug: json['slug'] as String,
    );
  }
}

class RestauranteMenuModel {
  const RestauranteMenuModel({
    required this.id,
    required this.nombre,
  });

  final String id;
  final String nombre;

  factory RestauranteMenuModel.fromJson(Map<String, dynamic> json) {
    return RestauranteMenuModel(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
    );
  }
}

class SucursalMenuModel {
  const SucursalMenuModel({
    required this.id,
    required this.nombre,
    required this.horarioActivo,
    this.ciudad,
    this.restaurante,
  });

  final String id;
  final String nombre;
  final bool horarioActivo;
  final CiudadMenuModel? ciudad;
  final RestauranteMenuModel? restaurante;

  factory SucursalMenuModel.fromJson(Map<String, dynamic> json) {
    return SucursalMenuModel(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      horarioActivo: json['horario_activo'] as bool? ?? false,
      ciudad: json['ciudad'] != null
          ? CiudadMenuModel.fromJson(json['ciudad'] as Map<String, dynamic>)
          : null,
      restaurante: json['restaurante'] != null
          ? RestauranteMenuModel.fromJson(
              json['restaurante'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

class CategoriaMenuModel {
  const CategoriaMenuModel({
    required this.id,
    required this.nombre,
    required this.productos,
  });

  final String id;
  final String nombre;
  final List<ProductoMenuModel> productos;

  factory CategoriaMenuModel.fromJson(Map<String, dynamic> json) {
    return CategoriaMenuModel(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      productos: (json['productos'] as List<dynamic>)
          .map((e) => ProductoMenuModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class OpcionMenuModel {
  const OpcionMenuModel({
    required this.id,
    required this.nombre,
    required this.precio,
  });

  final String id;
  final String nombre;
  final num precio;

  factory OpcionMenuModel.fromJson(Map<String, dynamic> json) {
    return OpcionMenuModel(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      precio: parsearNumero(json['precio']),
    );
  }
}

class ProductoMenuModel {
  const ProductoMenuModel({
    required this.id,
    required this.nombre,
    this.descripcion,
    required this.precio,
    this.precioParaLlevar,
    required this.disponible,
    this.imagenUrl,
    this.toppings = const [],
    this.bebidas = const [],
    this.categoriaId,
    this.esEncargo = false,
  });

  final String id;
  final String nombre;
  final String? descripcion;
  final num precio;
  /// Null = mismo precio que [precio] en llevar/domicilio.
  final num? precioParaLlevar;
  final bool disponible;
  final String? imagenUrl;
  final List<OpcionMenuModel> toppings;
  final List<OpcionMenuModel> bebidas;
  final String? categoriaId;
  final bool esEncargo;

  bool get tienePersonalizacion => toppings.isNotEmpty || bebidas.isNotEmpty;

  factory ProductoMenuModel.fromJson(Map<String, dynamic> json) {
    return ProductoMenuModel(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      descripcion: json['descripcion'] as String?,
      precio: parsearNumero(json['precio']),
      precioParaLlevar: json['precio_para_llevar'] != null
          ? parsearNumero(json['precio_para_llevar'])
          : null,
      disponible: json['disponible'] as bool? ?? true,
      imagenUrl: json['imagen_url'] as String?,
      esEncargo: json['es_encargo'] as bool? ?? false,
      toppings: (json['toppings_disponibles'] as List<dynamic>? ?? [])
          .map((e) => OpcionMenuModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      bebidas: (json['bebidas_disponibles'] as List<dynamic>? ?? [])
          .map((e) => OpcionMenuModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  ProductoMenuModel conCategoria(String categoriaId) {
    return ProductoMenuModel(
      id: id,
      nombre: nombre,
      descripcion: descripcion,
      precio: precio,
      precioParaLlevar: precioParaLlevar,
      disponible: disponible,
      imagenUrl: imagenUrl,
      toppings: toppings,
      bebidas: bebidas,
      categoriaId: categoriaId,
      esEncargo: esEncargo,
    );
  }

  bool get tienePrecioLlevarDistinto {
    final llevar = precioParaLlevar;
    return llevar != null && (llevar - precio).abs() > 0.01;
  }
}

class ComboItemMenuModel {
  const ComboItemMenuModel({
    required this.tipoItem,
    required this.nombreItem,
    this.itemId,
    this.cantidad = 1,
  });

  final String tipoItem;
  final String nombreItem;
  final String? itemId;
  final int cantidad;

  factory ComboItemMenuModel.fromJson(Map<String, dynamic> json) {
    return ComboItemMenuModel(
      tipoItem: json['tipo_item'] as String? ?? 'producto',
      nombreItem: json['nombre_item'] as String? ?? '',
      itemId: json['item_id'] as String?,
      cantidad: (json['cantidad'] as num?)?.toInt() ?? 1,
    );
  }
}

class ComboMenuModel {
  const ComboMenuModel({
    required this.id,
    required this.nombre,
    this.descripcion,
    required this.precioFijo,
    required this.disponible,
    this.imagenUrl,
    this.items = const [],
  });

  final String id;
  final String nombre;
  final String? descripcion;
  final num precioFijo;
  final bool disponible;
  final String? imagenUrl;
  final List<ComboItemMenuModel> items;

  String get resumenItems =>
      items.map((i) => '${i.cantidad}× ${i.nombreItem}').join(' · ');

  factory ComboMenuModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    List<ComboItemMenuModel> parsed = [];
    if (rawItems is List) {
      parsed = rawItems
          .map((e) => ComboItemMenuModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return ComboMenuModel(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      descripcion: json['descripcion'] as String?,
      precioFijo: parsearNumero(json['precio_fijo']),
      disponible: json['disponible'] as bool? ?? true,
      imagenUrl: json['imagen_url'] as String?,
      items: parsed,
    );
  }
}
