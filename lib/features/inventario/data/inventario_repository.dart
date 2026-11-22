import 'package:dio/dio.dart';
import 'package:reserva_canchas/core/modelos/respuesta_api.dart';
import 'package:reserva_canchas/core/red/cliente_dio.dart';

class InventarioRepository {
  InventarioRepository({Dio? dio})
      : _dio = dio ?? ClienteDio.instancia(conAuthStaff: true);

  final Dio _dio;

  Future<Map<String, dynamic>> resumenHermanas() async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/inventario/hermanas/resumen',
    );
    return _mapa(r.data);
  }

  Future<List<Map<String, dynamic>>> ingredientes(String sucursalId) async {
    final r = await _dio.get<Map<String, dynamic>>('/inventario/$sucursalId');
    return _lista(r.data);
  }

  Future<List<Map<String, dynamic>>> movimientos(
    String sucursalId, {
    int page = 1,
    int limit = 50,
  }) async {
    final r = await movimientosPaginados(sucursalId, page: page, limit: limit);
    return r.items;
  }

  Future<({List<Map<String, dynamic>> items, int total, bool hayMas})>
      movimientosPaginados(
    String sucursalId, {
    int page = 1,
    int limit = 50,
  }) async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/inventario/movimientos/$sucursalId',
      queryParameters: {'page': page, 'limit': limit},
    );
    final data = r.data;
    if (data == null) throw Exception('Respuesta vacía');
    final env = RespuestaApi<Map<String, dynamic>>.fromJson(
      data,
      (raw) => Map<String, dynamic>.from(raw as Map),
    );
    if (!env.exito || env.datos == null) throw Exception(env.mensaje);
    final d = env.datos!;
    final raw = d['items'];
    final items = raw is List
        ? raw.map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : <Map<String, dynamic>>[];
    final total = (d['total'] as num?)?.toInt() ?? items.length;
    final pagina = (d['page'] as num?)?.toInt() ?? page;
    final lim = (d['limit'] as num?)?.toInt() ?? limit;
    final totalPages = (d['totalPages'] as num?)?.toInt() ??
        (total == 0 ? 0 : (total / lim).ceil());
    return (items: items, total: total, hayMas: pagina < totalPages);
  }

  Future<void> crearIngrediente({
    required String sucursalId,
    required String nombre,
    required String unidadBase,
    String? proveedor,
    String categoriaInsumo = 'alimento',
    String tipoCosteo = 'pieza',
    double? precioCompra,
    double? pesoBruto,
    double? pesoNeto,
    double stockMinimo = 0,
    double stockActual = 0,
    double? costoUnitario,
    bool descontarStock = true,
  }) async {
    final data = <String, dynamic>{
      'sucursal_id': sucursalId,
      'nombre': nombre,
      'unidad_base': unidadBase,
      'tipo_costeo': tipoCosteo,
      'categoria_insumo': categoriaInsumo,
      'stock_minimo': stockMinimo,
      'stock_actual': stockActual,
      'descontar_stock': descontarStock,
      if (proveedor != null && proveedor.isNotEmpty) 'proveedor': proveedor,
      if (precioCompra != null) 'precio_compra': precioCompra,
      if (pesoBruto != null) 'peso_bruto': pesoBruto,
      if (pesoNeto != null) 'peso_neto': pesoNeto,
      if (costoUnitario != null) 'costo_unitario_actual': costoUnitario,
    };
    final r = await _dio.post<Map<String, dynamic>>('/inventario', data: data);
    _validar(r.data);
  }

  Future<void> actualizarIngrediente({
    required String ingredienteId,
    String? nombre,
    String? proveedor,
    String? categoriaInsumo,
    String? unidadBase,
    double? precioCompra,
    double? pesoBruto,
    double? pesoNeto,
    double? stockMinimo,
    double? costoUnitario,
    bool? descontarStock,
  }) async {
    final data = <String, dynamic>{
      if (nombre != null) 'nombre': nombre,
      if (proveedor != null) 'proveedor': proveedor,
      if (categoriaInsumo != null) 'categoria_insumo': categoriaInsumo,
      if (unidadBase != null) 'unidad_base': unidadBase,
      if (precioCompra != null) 'precio_compra': precioCompra,
      if (pesoBruto != null) 'peso_bruto': pesoBruto,
      if (pesoNeto != null) 'peso_neto': pesoNeto,
      if (stockMinimo != null) 'stock_minimo': stockMinimo,
      if (costoUnitario != null) 'costo_unitario_actual': costoUnitario,
      if (descontarStock != null) 'descontar_stock': descontarStock,
    };
    final r = await _dio.patch<Map<String, dynamic>>(
      '/inventario/$ingredienteId',
      data: data,
    );
    _validar(r.data);
  }

  Future<void> ajustarStock({
    required String ingredienteId,
    required double stockNuevo,
    String? motivo,
  }) async {
    final r = await _dio.patch<Map<String, dynamic>>(
      '/inventario/$ingredienteId',
      data: {
        'stock_nuevo': stockNuevo,
        if (motivo != null) 'motivo_ajuste': motivo,
      },
    );
    _validar(r.data);
  }

  Future<Map<String, dynamic>> recetaProducto(
    String productoId, {
    String tipoEntidad = 'producto',
  }) async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/inventario/producto-ingredientes/$productoId',
      queryParameters: {
        if (tipoEntidad != 'producto') 'tipo_entidad': tipoEntidad,
      },
    );
    return _mapa(r.data);
  }

  Future<String> iniciarConteo(String sucursalId) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/inventario/conteos/iniciar/$sucursalId',
    );
    final datos = _mapa(r.data);
    return datos['conteo_id'] as String;
  }

  Future<void> cerrarConteo({
    required String conteoId,
    required List<Map<String, dynamic>> items,
  }) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/inventario/conteos/$conteoId/cerrar',
      data: {
        'items': items
            .map(
              (e) => {
                'ingrediente_id': e['ingrediente_id'],
                'cantidad_real': e['cantidad_real'],
              },
            )
            .toList(),
      },
    );
    _validar(r.data);
  }

  Future<void> configurarReceta({
    required String productoId,
    required List<Map<String, dynamic>> items,
    double? margenError,
    String tipoEntidad = 'producto',
  }) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/inventario/producto-ingredientes',
      data: <String, dynamic>{
        'producto_id': productoId,
        if (tipoEntidad != 'producto') 'tipo_entidad': tipoEntidad,
        if (margenError != null) 'margen_error': margenError,
        'items': items.map((e) {
          final tipo = e['tipo_item'] as String? ?? 'ingrediente';
          final unidad = e['unidad'] as String? ?? 'und';
          return <String, dynamic>{
            'tipo_item': tipo,
            if (tipo == 'subreceta')
              'subreceta_id': '${e['subreceta_id']}',
            if (tipo != 'subreceta')
              'ingrediente_id': '${e['ingrediente_id']}',
            'cantidad': (e['cantidad'] as num?)?.toDouble() ?? 1.0,
            'unidad': unidad,
          };
        }).toList(),
      },
    );
    _validar(r.data);
  }

  Future<void> registrarCompra({
    required String sucursalId,
    required String ingredienteId,
    required double cantidad,
    required double precioTotal,
    String? proveedor,
  }) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/inventario/compras',
      data: {
        'sucursal_id': sucursalId,
        'proveedor': proveedor,
        'items': [
          {
            'ingrediente_id': ingredienteId,
            'cantidad_unidades_base': cantidad,
            'precio_total': precioTotal,
          },
        ],
      },
    );
    _validar(r.data);
  }

  Future<List<Map<String, dynamic>>> listarTraslados({String? sucursalId}) async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/inventario/traslados',
      queryParameters: {
        if (sucursalId != null) 'sucursal_id': sucursalId,
      },
    );
    return _lista(r.data);
  }

  Future<Map<String, dynamic>> crearTraslado({
    required String sucursalOrigenId,
    required String sucursalDestinoId,
    required String ingredienteId,
    required double cantidad,
    String? motivo,
  }) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/inventario/traslados',
      data: {
        'sucursal_origen_id': sucursalOrigenId,
        'sucursal_destino_id': sucursalDestinoId,
        'ingrediente_id': ingredienteId,
        'cantidad': cantidad,
        if (motivo != null) 'motivo': motivo,
      },
    );
    return _mapa(r.data);
  }

  Future<Map<String, dynamic>> recibirTraslado(String trasladoId) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/inventario/traslados/$trasladoId/recibir',
    );
    return _mapa(r.data);
  }

  Future<Map<String, dynamic>> cancelarTraslado(String trasladoId) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/inventario/traslados/$trasladoId/cancelar',
    );
    return _mapa(r.data);
  }

  List<Map<String, dynamic>> _lista(Map<String, dynamic>? data) {
    if (data == null) throw Exception('Respuesta vacía');
    final env = RespuestaApi<List<dynamic>>.fromJson(
      data,
      (raw) => raw as List<dynamic>,
    );
    if (!env.exito || env.datos == null) throw Exception(env.mensaje);
    return env.datos!
        .map((e) => Map<String, dynamic>.from(e as Map<String, dynamic>))
        .toList();
  }

  Map<String, dynamic> _mapa(Map<String, dynamic>? data) {
    if (data == null) throw Exception('Respuesta vacía');
    final env = RespuestaApi<Map<String, dynamic>>.fromJson(
      data,
      (raw) => Map<String, dynamic>.from(raw as Map<String, dynamic>),
    );
    if (!env.exito || env.datos == null) throw Exception(env.mensaje);
    return env.datos!;
  }

  void _validar(Map<String, dynamic>? data) {
    if (data == null) throw Exception('Respuesta vacía');
    final env = RespuestaApi<Map<String, dynamic>>.fromJson(
      data,
      (raw) => Map<String, dynamic>.from(raw as Map<String, dynamic>),
    );
    if (!env.exito) throw Exception(env.mensaje);
  }
}
