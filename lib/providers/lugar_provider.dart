import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/lugar.dart';
import '../services/app_backend.dart';

class LugarProvider extends ChangeNotifier {
  List<Lugar> _lugares = [];
  String? _ciudadSeleccionada;
  bool _isLoading = false;
  String? _errorMessage;

  List<Lugar> get lugares => _lugares;
  String? get ciudadSeleccionada => _ciudadSeleccionada;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  SupabaseClient? get _db =>
      AppBackend.supabaseReady ? Supabase.instance.client : null;

  Future<void> fetchLugaresPorCiudad(String ciudadId) async {
    final db = _db;
    if (db == null) {
      _errorMessage = 'Supabase no configurado';
      notifyListeners();
      return;
    }
    try {
      _isLoading = true;
      _errorMessage = null;
      _ciudadSeleccionada = ciudadId;
      notifyListeners();

      final rows = await db
          .from('lugares')
          .select()
          .eq('ciudad_id', ciudadId)
          .eq('activo', true)
          .order('nombre', ascending: true);

      if (_ciudadSeleccionada != ciudadId) return;

      _lugares = (rows as List<dynamic>)
          .map((e) => Lugar.fromSupabase(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      _errorMessage = 'Error al cargar lugares: $e';
      if (kDebugMode) {
        debugPrint('Error en LugarProvider.fetchLugaresPorCiudad: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchTodosLosLugares() async {
    final db = _db;
    if (db == null) {
      _errorMessage = 'Supabase no configurado';
      notifyListeners();
      return;
    }
    try {
      _isLoading = true;
      _errorMessage = null;
      _ciudadSeleccionada = null;
      notifyListeners();

      final rows =
          await db.from('lugares').select().order('nombre', ascending: true).limit(200);

      _lugares = (rows as List<dynamic>)
          .map((e) => Lugar.fromSupabase(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      _errorMessage = 'Error al cargar lugares: $e';
      if (kDebugMode) {
        debugPrint('Error en LugarProvider.fetchTodosLosLugares: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchLugaresDisponibles(
      String ciudadId, DateTime fecha, TimeOfDay hora) async {
    await fetchLugaresPorCiudad(ciudadId);
  }

  Future<void> crearLugar(Lugar lugar) async {
    final db = _db;
    if (db == null) return;
    try {
      final id = lugar.id.isNotEmpty ? lugar.id : const Uuid().v4();
      final row = lugar.toSupabaseInsert();
      row['id'] = id;
      await db.from('lugares').insert(row);
      if (_ciudadSeleccionada != null) {
        await fetchLugaresPorCiudad(_ciudadSeleccionada!);
      } else {
        await fetchTodosLosLugares();
      }
    } catch (e) {
      _errorMessage = 'Error al crear lugar: $e';
      if (kDebugMode) {
        debugPrint('Error en LugarProvider.crearLugar: $e');
      }
      notifyListeners();
    }
  }

  Future<void> actualizarLugar(String id, Map<String, dynamic> datos) async {
    final db = _db;
    if (db == null) return;
    try {
      final patch = _lugarPatchFromMap(datos);
      patch['updated_at'] = DateTime.now().toIso8601String();
      await db.from('lugares').update(patch).eq('id', id);
      if (_ciudadSeleccionada != null) {
        await fetchLugaresPorCiudad(_ciudadSeleccionada!);
      } else {
        await fetchTodosLosLugares();
      }
    } catch (e) {
      _errorMessage = 'Error al actualizar lugar: $e';
      if (kDebugMode) {
        debugPrint('Error en LugarProvider.actualizarLugar: $e');
      }
      notifyListeners();
    }
  }

  Future<void> activarDesactivarLugar(String lugarId, bool activo) async {
    final db = _db;
    if (db == null) return;
    try {
      await db.from('lugares').update({
        'activo': activo,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', lugarId);
      if (_ciudadSeleccionada != null) {
        await fetchLugaresPorCiudad(_ciudadSeleccionada!);
      } else {
        await fetchTodosLosLugares();
      }
    } catch (e) {
      _errorMessage = 'Error al actualizar lugar: $e';
      if (kDebugMode) {
        debugPrint('Error en LugarProvider.activarDesactivarLugar: $e');
      }
      notifyListeners();
    }
  }

  Future<void> eliminarLugar(String id) async {
    final db = _db;
    if (db == null) return;
    try {
      await db.from('lugares').delete().eq('id', id);
      if (_ciudadSeleccionada != null) {
        await fetchLugaresPorCiudad(_ciudadSeleccionada!);
      } else {
        await fetchTodosLosLugares();
      }
    } catch (e) {
      _errorMessage = 'Error al eliminar lugar: $e';
      if (kDebugMode) {
        debugPrint('Error en LugarProvider.eliminarLugar: $e');
      }
      notifyListeners();
    }
  }

  void limpiarError() {
    _errorMessage = null;
    notifyListeners();
  }

  static Map<String, dynamic> _lugarPatchFromMap(Map<String, dynamic> datos) {
    final out = <String, dynamic>{};
    for (final e in datos.entries) {
      switch (e.key) {
        case 'ciudadId':
          out['ciudad_id'] = e.value;
          break;
        case 'fotoUrl':
          out['foto_url'] = e.value;
          break;
        case 'planInicio':
          out['plan_inicio'] = _iso(e.value);
          break;
        case 'planValorMensual':
          out['plan_valor_mensual'] = e.value;
          break;
        case 'planUltimoPago':
          out['plan_ultimo_pago'] = _iso(e.value);
          break;
        case 'maxSedes':
          out['max_sedes'] = e.value;
          break;
        case 'maxCanchas':
          out['max_canchas'] = e.value;
          break;
        case 'createdAt':
        case 'updatedAt':
          break;
        default:
          out[e.key] = e.value;
      }
    }
    return out;
  }

  static String? _iso(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v.toIso8601String();
    try {
      return (v as dynamic).toDate().toIso8601String();
    } catch (_) {
      return null;
    }
  }
}
