import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/ciudad.dart';
import '../services/app_backend.dart';

class CiudadProvider extends ChangeNotifier {
  List<Ciudad> _ciudades = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Ciudad> get ciudades => _ciudades;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  SupabaseClient? get _db =>
      AppBackend.supabaseReady ? Supabase.instance.client : null;

  Future<void> fetchCiudades() async {
    final db = _db;
    if (db == null) {
      _errorMessage = 'Supabase no configurado';
      notifyListeners();
      return;
    }
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final rows = await db
          .from('ciudades')
          .select()
          .eq('activa', true)
          .order('nombre', ascending: true);

      _ciudades = (rows as List<dynamic>)
          .map((e) => Ciudad.fromSupabase(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      _errorMessage = 'Error al cargar ciudades: $e';
      if (kDebugMode) {
        debugPrint('Error en CiudadProvider.fetchCiudades: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchTodasLasCiudades() async {
    final db = _db;
    if (db == null) {
      _errorMessage = 'Supabase no configurado';
      notifyListeners();
      return;
    }
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final rows = await db
          .from('ciudades')
          .select()
          .order('nombre', ascending: true)
          .limit(200);

      _ciudades = (rows as List<dynamic>)
          .map((e) => Ciudad.fromSupabase(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      _errorMessage = 'Error al cargar ciudades: $e';
      if (kDebugMode) {
        debugPrint('Error en CiudadProvider.fetchTodasLasCiudades: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> crearCiudad(Ciudad ciudad) async {
    final db = _db;
    if (db == null) return;
    try {
      final id = const Uuid().v4();
      final row = Map<String, dynamic>.from(ciudad.toSupabaseInsert());
      row['id'] = id;
      await db.from('ciudades').insert(row);
      await fetchTodasLasCiudades();
    } catch (e) {
      _errorMessage = 'Error al crear ciudad: $e';
      if (kDebugMode) {
        debugPrint('Error en CiudadProvider.crearCiudad: $e');
      }
      notifyListeners();
    }
  }

  Future<void> actualizarCiudad(String id, Map<String, dynamic> datos) async {
    final db = _db;
    if (db == null) return;
    try {
      final patch = _mapFirestoreKeysToSnake(datos);
      patch['updated_at'] = DateTime.now().toIso8601String();
      await db.from('ciudades').update(patch).eq('id', id);
      await fetchTodasLasCiudades();
    } catch (e) {
      _errorMessage = 'Error al actualizar ciudad: $e';
      if (kDebugMode) {
        debugPrint('Error en CiudadProvider.actualizarCiudad: $e');
      }
      notifyListeners();
    }
  }

  Future<void> eliminarCiudad(String id) async {
    final db = _db;
    if (db == null) return;
    try {
      await db.from('ciudades').delete().eq('id', id);
      await fetchTodasLasCiudades();
    } catch (e) {
      _errorMessage = 'Error al eliminar ciudad: $e';
      if (kDebugMode) {
        debugPrint('Error en CiudadProvider.eliminarCiudad: $e');
      }
      notifyListeners();
    }
  }

  void limpiarError() {
    _errorMessage = null;
    notifyListeners();
  }

  static Map<String, dynamic> _mapFirestoreKeysToSnake(
      Map<String, dynamic> datos) {
    final out = <String, dynamic>{};
    for (final e in datos.entries) {
      switch (e.key) {
        case 'createdAt':
          out['created_at'] = _ts(e.value);
          break;
        case 'updatedAt':
          out['updated_at'] = _ts(e.value);
          break;
        default:
          out[e.key] = e.value;
      }
    }
    return out;
  }

  static dynamic _ts(dynamic v) {
    if (v == null) return DateTime.now().toIso8601String();
    try {
      // cloud_firestore Timestamp en código legado
      return v.toString();
    } catch (_) {
      return DateTime.now().toIso8601String();
    }
  }
}
