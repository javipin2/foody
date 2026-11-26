import 'package:dio/dio.dart';
import 'package:reserva_canchas/core/modelos/respuesta_api.dart';
import 'package:reserva_canchas/core/red/cliente_dio.dart';

class CatalogoAdminRepository {
  CatalogoAdminRepository({Dio? dio})
      : _dio = dio ?? ClienteDio.instancia(conAuthStaff: true);

  final Dio _dio;

  Future<List<Map<String, dynamic>>> categorias(String sucursalId) async {
    final r = await _dio.get<Map<String, dynamic>>('/categorias/$sucursalId');
    return _lista(r.data);
  }

  Future<List<Map<String, dynamic>>> productos(String sucursalId) async {
    final r =
        await _dio.get<Map<String, dynamic>>('/productos/sucursal/$sucursalId');
    return _lista(r.data);
  }

  Future<void> crearCategoria({
    required String sucursalId,
    required String nombre,
  }) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/categorias',
      data: {'sucursal_id': sucursalId, 'nombre': nombre},
    );
    _validar(r.data);
  }

  Future<void> crearProducto({
    required String sucursalId,
    required String categoriaId,
    required String nombre,
    required double precio,
    String? cocinaId,
  }) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/productos',
      data: {
        'sucursal_id': sucursalId,
        'categoria_id': categoriaId,
        'nombre': nombre,
        'precio': precio,
        if (cocinaId != null) 'cocina_id': cocinaId,
      },
    );
    _validar(r.data);
  }

  Future<void> asignarCocina(String productoId, String cocinaId) async {
    final r = await _dio.patch<Map<String, dynamic>>(
      '/productos/$productoId',
      data: {'cocina_id': cocinaId},
    );
    _validar(r.data);
  }

  Future<void> toggleDisponible(String productoId, bool disponible) async {
    final r = await _dio.patch<Map<String, dynamic>>(
      '/productos/$productoId/disponibilidad',
      data: {'disponible': disponible},
    );
    _validar(r.data);
  }

  Future<List<Map<String, dynamic>>> toppings(String sucursalId) async {
    final r = await _dio.get<Map<String, dynamic>>('/toppings/$sucursalId');
    return _lista(r.data);
  }

  Future<List<Map<String, dynamic>>> bebidas(String sucursalId) async {
    final r = await _dio.get<Map<String, dynamic>>('/bebidas/$sucursalId');
    return _lista(r.data);
  }

  Future<void> crearExtra({
    required String sucursalId,
    required String nombre,
    required double precio,
    required bool esBebida,
    List<String> productoIds = const [],
  }) async {
    final path = esBebida ? '/bebidas' : '/toppings';
    final r = await _dio.post<Map<String, dynamic>>(
      path,
      data: {
        'sucursal_id': sucursalId,
        'nombre': nombre,
        'precio': precio,
        if (!esBebida) 'producto_ids': productoIds,
      },
    );
    _validar(r.data);
  }

  Future<void> toggleExtra({
    required String id,
    required bool disponible,
    required bool esBebida,
  }) async {
    final path = esBebida ? '/bebidas/$id' : '/toppings/$id';
    final r = await _dio.patch<Map<String, dynamic>>(
      path,
      data: {'disponible': disponible},
    );
    _validar(r.data);
  }

  Future<void> vincularExtra({
    required String productoId,
    required String extraId,
    required bool esBebida,
  }) async {
    final path = esBebida
        ? '/productos/$productoId/bebidas'
        : '/productos/$productoId/toppings';
    final r = await _dio.post<Map<String, dynamic>>(
      path,
      data: {esBebida ? 'bebida_id' : 'topping_id': extraId},
    );
    _validar(r.data);
  }

  Future<List<Map<String, dynamic>>> toppingsDeProducto(
      String productoId) async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/productos/$productoId/toppings',
    );
    _validar(r.data);
    final datos = r.data?['datos'];
    if (datos is List) {
      return datos.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  Future<void> configurarToppingsProducto({
    required String productoId,
    required List<String> toppingIds,
  }) async {
    final r = await _dio.put<Map<String, dynamic>>(
      '/productos/$productoId/toppings',
      data: {'topping_ids': toppingIds},
    );
    _validar(r.data);
  }

  Future<void> toggleCombo({
    required String id,
    required bool disponible,
  }) async {
    final r = await _dio.patch<Map<String, dynamic>>(
      '/combos/$id/disponibilidad',
      data: {'disponible': disponible},
    );
    _validar(r.data);
  }

  Future<void> crearCombo({
    required String sucursalId,
    required String nombre,
    required double precioFijo,
    required List<Map<String, dynamic>> items,
  }) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/combos',
      data: {
        'sucursal_id': sucursalId,
        'nombre': nombre,
        'precio_fijo': precioFijo,
        'items': items,
      },
    );
    _validar(r.data);
  }

  Future<List<Map<String, dynamic>>> combos(String sucursalId) async {
    final r = await _dio.get<Map<String, dynamic>>('/combos/$sucursalId');
    return _lista(r.data);
  }

  Future<void> actualizarPrecio(String productoId, double precio) async {
    final r = await _dio.patch<Map<String, dynamic>>(
      '/productos/$productoId',
      data: {'precio': precio},
    );
    _validar(r.data);
  }

  Future<void> actualizarPreciosCanal({
    required String productoId,
    required double precioLocal,
    double? precioParaLlevar,
  }) async {
    final data = <String, dynamic>{'precio': precioLocal};
    if (precioParaLlevar != null &&
        (precioParaLlevar - precioLocal).abs() > 0.01) {
      data['precio_para_llevar'] = precioParaLlevar;
    } else {
      data['precio_para_llevar'] = null;
    }
    final r = await _dio.patch<Map<String, dynamic>>(
      '/productos/$productoId',
      data: data,
    );
    _validar(r.data);
  }

  Future<void> actualizarMargenObjetivo(
    String productoId,
    double margenObjetivo,
  ) async {
    final r = await _dio.patch<Map<String, dynamic>>(
      '/productos/$productoId',
      data: {'margen_objetivo': margenObjetivo},
    );
    _validar(r.data);
  }

  Future<List<Map<String, dynamic>>> listarItemsIncluidos(
    String productoId,
  ) async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/productos/$productoId/items-incluidos',
    );
    return _lista(r.data);
  }

  Future<List<Map<String, dynamic>>> configurarItemsIncluidos({
    required String productoId,
    required List<Map<String, dynamic>> items,
  }) async {
    final r = await _dio.put<Map<String, dynamic>>(
      '/productos/$productoId/items-incluidos',
      data: <String, dynamic>{
        'items': items
            .map(
              (e) => <String, dynamic>{
                'producto_incluido_id': '${e['producto_incluido_id']}',
                'cantidad': (e['cantidad'] as num?)?.toDouble() ?? 1.0,
              },
            )
            .toList(),
      },
    );
    return _lista(r.data);
  }

  List<Map<String, dynamic>> _lista(Map<String, dynamic>? data) {
    if (data == null) return [];
    final env = RespuestaApi<List<dynamic>>.fromJson(
      data,
      (raw) => raw as List<dynamic>,
    );
    if (!env.exito || env.datos == null) throw Exception(env.mensaje);
    return env.datos!
        .map((e) => Map<String, dynamic>.from(e as Map<String, dynamic>))
        .toList();
  }

  void _validar(Map<String, dynamic>? data) {
    if (data == null) throw Exception('Respuesta vacía');
    final env = RespuestaApi<dynamic>.fromJson(data, (raw) => raw);
    if (!env.exito) throw Exception(env.mensaje);
  }

  Future<Map<String, dynamic>> copiarMenuDesde({
    required String sucursalDestinoId,
    required String sucursalOrigenId,
  }) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/categorias/sucursal/$sucursalDestinoId/copiar-desde/$sucursalOrigenId',
    );
    return _mapa(r.data);
  }

  Map<String, dynamic> _mapa(Map<String, dynamic>? data) {
    if (data == null) throw Exception('Respuesta vacía');
    final env = RespuestaApi<Map<String, dynamic>>.fromJson(
      data,
      (raw) => Map<String, dynamic>.from(raw as Map),
    );
    if (!env.exito || env.datos == null) throw Exception(env.mensaje);
    return env.datos!;
  }
}
