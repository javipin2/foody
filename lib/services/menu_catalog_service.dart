import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:reserva_canchas/models/menu_catalogo.dart';
import 'package:reserva_canchas/services/app_backend.dart';

/// Lectura del catálogo menú en Supabase (`menu_categorias`, `menu_productos`, `sede_id`).
class MenuCatalogService {
  MenuCatalogService._();
  static final MenuCatalogService instance = MenuCatalogService._();

  SupabaseClient? get _client =>
      AppBackend.supabaseReady ? Supabase.instance.client : null;

  Future<List<MenuCategoria>> fetchCategorias(String sedeFirestoreId) async {
    final c = _client;
    if (c == null || sedeFirestoreId.isEmpty) return [];

    try {
      final rows = await c
          .from('menu_categorias')
          .select('id,nombre,orden')
          .eq('sede_id', sedeFirestoreId)
          .order('orden', ascending: true)
          .order('nombre', ascending: true);

      return (rows as List<dynamic>)
          .map((e) => MenuCategoria.fromRow(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e, st) {
      debugPrint('MenuCatalogService.fetchCategorias: $e\n$st');
      rethrow;
    }
  }

  Future<List<MenuProducto>> fetchProductos(String sedeFirestoreId) async {
    final c = _client;
    if (c == null || sedeFirestoreId.isEmpty) return [];

    try {
      final rows = await c
          .from('menu_productos')
          .select('id,categoria_id,nombre,descripcion,precio,imagen_url,orden')
          .eq('sede_id', sedeFirestoreId)
          .order('orden', ascending: true)
          .order('nombre', ascending: true);

      return (rows as List<dynamic>)
          .map((e) => MenuProducto.fromRow(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e, st) {
      debugPrint('MenuCatalogService.fetchProductos: $e\n$st');
      rethrow;
    }
  }
}
