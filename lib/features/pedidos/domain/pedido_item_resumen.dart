/// Línea compacta para preview en kanban / detalle (viene del API).
class PedidoItemResumen {
  const PedidoItemResumen({
    required this.itemId,
    required this.nombre,
    required this.cantidad,
    this.productoId,
    this.tieneToppings = false,
    this.tieneBebidas = false,
    this.observaciones,
    this.toppingsNombres,
    this.bebidasNombres,
    this.toppingIds = const [],
    this.estadoCocina,
  });

  final String itemId;
  final String nombre;
  final int cantidad;
  final String? productoId;
  final bool tieneToppings;
  final bool tieneBebidas;
  final String? observaciones;
  final String? toppingsNombres;
  final String? bebidasNombres;
  final List<String> toppingIds;
  /// VIE-QTY-01: preparando/listo → no bajar cantidad en UI.
  final String? estadoCocina;

  bool get cantidadInmutableEnCocina =>
      estadoCocina == 'preparando' || estadoCocina == 'listo';

  factory PedidoItemResumen.fromJson(Map<String, dynamic> json) {
    final rawTops = json['topping_ids'];
    return PedidoItemResumen(
      itemId: '${json['item_id'] ?? json['id'] ?? ''}',
      nombre: json['nombre'] as String? ?? 'Ítem',
      cantidad: json['cantidad'] is int
          ? json['cantidad'] as int
          : int.tryParse('${json['cantidad']}') ?? 1,
      productoId: json['producto_id'] as String?,
      tieneToppings: json['tiene_toppings'] == true,
      tieneBebidas: json['tiene_bebidas'] == true,
      observaciones: json['observaciones'] as String?,
      toppingsNombres: json['toppings_nombres'] as String?,
      bebidasNombres: json['bebidas_nombres'] as String?,
      toppingIds: rawTops is List
          ? rawTops.map((e) => '$e').where((e) => e.isNotEmpty).toList()
          : const [],
      estadoCocina: json['estado_cocina'] as String?,
    );
  }

  String get lineaPreview {
    final extras = <String>[];
    if (tieneToppings) extras.add('toppings');
    if (tieneBebidas) extras.add('bebidas');
    final suf = extras.isEmpty ? '' : ' · ${extras.join('+')}';
    return '$cantidad× $nombre$suf';
  }
}
