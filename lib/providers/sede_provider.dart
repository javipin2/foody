import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:reserva_canchas/providers/audit_provider.dart';
import 'package:reserva_canchas/services/app_backend.dart';

class SedeProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _sedes = [];
  String _selectedSede = '';
  String _errorMessage = '';
  String? _lugarId;
  String? _lastLoadedLugarId;
  bool _isFetching = false;

  List<Map<String, dynamic>> get sedes => _sedes;
  List<String> get sedeNames =>
      _sedes.map((sede) => sede['nombre'] as String).toList();
  Map<String, String> get sedeImages => {
        for (var sede in _sedes)
          sede['nombre'] as String: sede['imagen'] as String? ?? ''
      };
  String get selectedSede => _selectedSede;

  /// Id de la fila `sedes` en Supabase (menú, reservas, etc.).
  String? get selectedSedeId => selectedSedeFirestoreId;

  /// Compatibilidad nombre anterior.
  String? get selectedSedeFirestoreId {
    if (_selectedSede.isEmpty) return null;
    for (final s in _sedes) {
      if ((s['nombre'] as String?) == _selectedSede) {
        return s['id'] as String?;
      }
    }
    return null;
  }

  String get errorMessage => _errorMessage;
  String? get lugarId => _lugarId;

  SupabaseClient? get _db =>
      AppBackend.supabaseReady ? Supabase.instance.client : null;

  void setSede(String sede) {
    _selectedSede = sede;
    debugPrint('Sede seleccionada: $sede');
    notifyListeners();
  }

  void setLugar(String lugarId) {
    if (_lugarId == lugarId) return;
    _lugarId = lugarId;
    debugPrint('Lugar establecido: $lugarId');
    notifyListeners();
  }

  void clearLugar() {
    _lugarId = null;
    _sedes = [];
    _selectedSede = '';
    _lastLoadedLugarId = null;
    debugPrint('Lugar limpiado');
    notifyListeners();
  }

  Future<void> fetchSedes({bool force = false}) async {
    if (_isFetching) {
      debugPrint('fetchSedes evitado: ya hay una carga en curso');
      return;
    }
    final db = _db;
    if (db == null) {
      _errorMessage = 'Supabase no configurado';
      notifyListeners();
      return;
    }
    try {
      _errorMessage = '';
      debugPrint('fetchSedes desde Supabase...');
      if (_lugarId == null) {
        _errorMessage = 'No se ha seleccionado un lugar';
        notifyListeners();
        return;
      }

      if (!force && _lastLoadedLugarId == _lugarId && _sedes.isNotEmpty) {
        debugPrint('Sedes ya cargadas para lugar $_lugarId');
        return;
      }

      _isFetching = true;

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          final prof = await db
              .from('staff_profiles')
              .select('rol,lugar_id')
              .eq('id', user.uid)
              .maybeSingle();
          if (prof != null) {
            final userRole = prof['rol'];
            final userLugarId = prof['lugar_id'] as String?;
            if (userRole != null &&
                userRole != 'programador' &&
                userLugarId != null &&
                userLugarId != _lugarId) {
              _errorMessage = 'No tienes permisos para acceder a este lugar';
              notifyListeners();
              return;
            }
          }
        } catch (e) {
          debugPrint('Error verificando permisos staff: $e');
        }
      }

      final snapshot = await db
          .from('sedes')
          .select()
          .eq('lugar_id', _lugarId!)
          .eq('activa', true)
          .order('nombre', ascending: true)
          .limit(100);

      _sedes = (snapshot as List<dynamic>).map((doc) {
        final data = Map<String, dynamic>.from(doc as Map);
        return {
          'id': data['id'] as String,
          'nombre': data['nombre'] ?? '',
          'imagen': data['imagen'] ?? '',
          'descripcion': data['descripcion'] ?? '',
          'activa': data['activa'] ?? true,
          'ubicacion': data['ubicacion'] ?? '',
          'latitud': data['latitud'],
          'longitud': data['longitud'],
          'createdAt': _parseDate(data['created_at']),
        };
      }).toList();

      _lastLoadedLugarId = _lugarId;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error al cargar sedes: $e';
      debugPrint('Error en fetchSedes: $e');
      notifyListeners();
    } finally {
      _isFetching = false;
    }
  }

  DateTime _parseDate(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }

  Future<bool> sedeHasCanchas(String nombreSede) async {
    final db = _db;
    if (db == null) return false;
    try {
      final sede = _sedes.cast<Map<String, dynamic>?>().firstWhere(
            (s) => s != null && s['nombre'] == nombreSede,
            orElse: () => null,
          );
      if (sede == null) return false;
      final sid = sede['id'] as String?;
      if (sid == null || sid.isEmpty) return false;
      final rows = await db
          .from('canchas')
          .select('id')
          .eq('sede_id', sid)
          .limit(1);
      return (rows as List).isNotEmpty;
    } catch (e) {
      debugPrint('Error verificando canchas de la sede: $e');
      return false;
    }
  }

  Future<void> crearSede(String nombreSede,
      {String? imageUrl,
      String? descripcion,
      String? ubicacion,
      double? latitud,
      double? longitud}) async {
    final db = _db;
    if (db == null) return;

    if (nombreSede.isEmpty) {
      _errorMessage = 'El nombre de la sede no puede estar vacío';
      notifyListeners();
      return;
    }

    if (_sedes.any((sede) => sede['nombre'] == nombreSede)) {
      _errorMessage = 'Ya existe una sede con ese nombre';
      notifyListeners();
      return;
    }

    if (_lugarId == null) {
      _errorMessage = 'No hay lugar seleccionado';
      notifyListeners();
      return;
    }

    try {
      _errorMessage = '';
      final defaultImageUrl = imageUrl ??
          'https://images.unsplash.com/photo-1544966503-7cc5ac882d5f?ixlib=rb-4.0.3&auto=format&fit=crop&w=300&h=200';
      final id = const Uuid().v4();

      await db.from('sedes').insert({
        'id': id,
        'lugar_id': _lugarId,
        'nombre': nombreSede,
        'imagen': defaultImageUrl,
        'descripcion': descripcion ?? 'Presione para continuar',
        'ubicacion': ubicacion ?? nombreSede.toLowerCase(),
        'latitud': latitud,
        'longitud': longitud,
        'activa': true,
        'created_at': DateTime.now().toIso8601String(),
      });

      await AuditProvider.registrarAccion(
        accion: 'crear_sede',
        entidad: 'sede',
        entidadId: id,
        datosNuevos: {
          'nombre': nombreSede,
          'imagen': defaultImageUrl,
          'descripcion': descripcion ?? 'Presione para continuar',
          'ubicacion': ubicacion ?? nombreSede.toLowerCase(),
          'latitud': latitud,
          'longitud': longitud,
          'lugarId': _lugarId,
          'activa': true,
        },
        metadatos: {
          'nombre_sede': nombreSede,
          'imagen_url': defaultImageUrl,
        },
        descripcion: 'Nueva sede creada: $nombreSede',
      );

      _sedes.add({
        'id': id,
        'nombre': nombreSede,
        'imagen': defaultImageUrl,
        'descripcion': descripcion ?? 'Presione para continuar',
        'ubicacion': ubicacion ?? nombreSede.toLowerCase(),
        'latitud': latitud,
        'longitud': longitud,
        'activa': true,
        'createdAt': DateTime.now(),
      });

      _sedes.sort(
          (a, b) => (a['nombre'] as String).compareTo(b['nombre'] as String));

      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error al crear la sede: $e';
      debugPrint('Error en crearSede: $e');
      notifyListeners();
    }
  }

  Future<void> renombrarSede(String sedeId, String nuevoNombre) async {
    final db = _db;
    if (db == null) return;

    if (nuevoNombre.isEmpty) {
      _errorMessage = 'El nuevo nombre de la sede no puede estar vacío';
      notifyListeners();
      return;
    }

    if (_sedes.any((sede) => sede['nombre'] == nuevoNombre)) {
      _errorMessage = 'Ya existe una sede con ese nombre';
      notifyListeners();
      return;
    }

    try {
      _errorMessage = '';
      final sedeIndex = _sedes.indexWhere((sede) => sede['id'] == sedeId);
      if (sedeIndex == -1) {
        _errorMessage = 'Sede no encontrada';
        notifyListeners();
        return;
      }

      final oldName = _sedes[sedeIndex]['nombre'] as String;

      await db.from('sedes').update({'nombre': nuevoNombre}).eq('id', sedeId);
      await db
          .from('reservas')
          .update({'sede_nombre': nuevoNombre}).eq('sede_id', sedeId);

      _sedes[sedeIndex]['nombre'] = nuevoNombre;
      _sedes.sort(
          (a, b) => (a['nombre'] as String).compareTo(b['nombre'] as String));

      if (_selectedSede == oldName) {
        _selectedSede = nuevoNombre;
      }

      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error al renombrar la sede: $e';
      debugPrint('Error en renombrarSede: $e');
      notifyListeners();
    }
  }

  Future<void> actualizarUbicacionSede(
      String sedeId, double? latitud, double? longitud) async {
    final db = _db;
    if (db == null) return;
    try {
      final sedeIndex = _sedes.indexWhere((sede) => sede['id'] == sedeId);
      if (sedeIndex == -1) {
        _errorMessage = 'Sede no encontrada';
        notifyListeners();
        return;
      }

      final updateData = <String, dynamic>{};
      if (latitud != null && longitud != null) {
        updateData['latitud'] = latitud;
        updateData['longitud'] = longitud;
      }

      await db.from('sedes').update(updateData).eq('id', sedeId);

      _sedes[sedeIndex]['latitud'] = latitud;
      _sedes[sedeIndex]['longitud'] = longitud;

      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error al actualizar la ubicación: $e';
      debugPrint('Error en actualizarUbicacionSede: $e');
      notifyListeners();
      rethrow;
    }
  }

  Future<void> actualizarImagenSede(String sedeId, String nuevaImagenUrl) async {
    final db = _db;
    if (db == null) return;
    try {
      final sedeIndex = _sedes.indexWhere((sede) => sede['id'] == sedeId);
      if (sedeIndex == -1) {
        _errorMessage = 'Sede no encontrada';
        notifyListeners();
        return;
      }

      await db.from('sedes').update({'imagen': nuevaImagenUrl}).eq('id', sedeId);

      _sedes[sedeIndex]['imagen'] = nuevaImagenUrl;

      notifyListeners();
    } catch (e) {
      debugPrint('Error actualizando imagen de sede: $e');
      _errorMessage = 'Error al actualizar la imagen: $e';
      notifyListeners();
    }
  }

  Future<void> desactivarSede(String sedeId) async {
    final db = _db;
    if (db == null) return;
    try {
      _errorMessage = '';
      final now = DateTime.now();
      final hoy = DateTime(now.year, now.month, now.day);

      final sedeIndex = _sedes.indexWhere((sede) => sede['id'] == sedeId);
      if (sedeIndex == -1) {
        _errorMessage = 'Sede no encontrada';
        notifyListeners();
        return;
      }
      final nombreSede = _sedes[sedeIndex]['nombre'] as String;
      final datosSedeAnterior = Map<String, dynamic>.from(_sedes[sedeIndex]);

      final resRows = await db
          .from('reservas')
          .select('id,fecha')
          .eq('sede_id', sedeId);

      final reservasActivas = (resRows as List<dynamic>).where((row) {
        final m = Map<String, dynamic>.from(row as Map);
        final fechaStr = m['fecha'] as String?;
        if (fechaStr == null) return false;
        try {
          final fechaReserva = DateTime.parse(fechaStr);
          final fechaReservaSinHora =
              DateTime(fechaReserva.year, fechaReserva.month, fechaReserva.day);
          return fechaReservaSinHora.isAtSameMomentAs(hoy) ||
              fechaReservaSinHora.isAfter(hoy);
        } catch (e) {
          return false;
        }
      }).toList();

      if (reservasActivas.isNotEmpty) {
        _errorMessage =
            'No se puede desactivar la sede porque tiene ${reservasActivas.length} reserva(s) activa(s)';
        notifyListeners();
        return;
      }

      await db.from('sedes').update({'activa': false}).eq('id', sedeId);

      await AuditProvider.registrarAccion(
        accion: 'desactivar_sede',
        entidad: 'sede',
        entidadId: sedeId,
        datosAntiguos: datosSedeAnterior,
        datosNuevos: {'activa': false},
        metadatos: {
          'nombre_sede': nombreSede,
          'reservas_verificadas': reservasActivas.length,
        },
        descripcion: 'Sede desactivada: $nombreSede',
      );

      _sedes.removeAt(sedeIndex);

      if (_selectedSede == nombreSede) {
        _selectedSede = '';
      }

      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error al desactivar la sede: $e';
      debugPrint('Error en desactivarSede: $e');
      notifyListeners();
    }
  }

  Future<void> eliminarSedeCompletamente(String sedeId) async {
    final db = _db;
    if (db == null) return;
    try {
      _errorMessage = '';
      final now = DateTime.now();
      final hoy = DateTime(now.year, now.month, now.day);

      final sedeIndex = _sedes.indexWhere((sede) => sede['id'] == sedeId);
      if (sedeIndex == -1) {
        _errorMessage = 'Sede no encontrada';
        notifyListeners();
        return;
      }
      final nombreSede = _sedes[sedeIndex]['nombre'] as String;

      final resRows = await db
          .from('reservas')
          .select('id,fecha')
          .eq('sede_id', sedeId);

      final reservasActivas = (resRows as List<dynamic>).where((row) {
        final m = Map<String, dynamic>.from(row as Map);
        final fechaStr = m['fecha'] as String?;
        if (fechaStr == null) return false;
        try {
          final fechaReserva = DateTime.parse(fechaStr);
          final fechaReservaSinHora =
              DateTime(fechaReserva.year, fechaReserva.month, fechaReserva.day);
          return fechaReservaSinHora.isAtSameMomentAs(hoy) ||
              fechaReservaSinHora.isAfter(hoy);
        } catch (e) {
          return false;
        }
      }).toList();

      if (reservasActivas.isNotEmpty) {
        _errorMessage =
            'No se puede eliminar la sede porque tiene reservas activas';
        notifyListeners();
        return;
      }

      await db.from('reservas').delete().eq('sede_id', sedeId);
      await db.from('canchas').delete().eq('sede_id', sedeId);
      await db.from('sedes').delete().eq('id', sedeId);

      if (sedeIndex != -1) {
        _sedes.removeAt(sedeIndex);
      }

      if (_selectedSede == nombreSede) {
        _selectedSede = '';
      }

      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error al eliminar la sede: $e';
      debugPrint('Error en eliminarSedeCompletamente: $e');
      notifyListeners();
    }
  }

  Future<void> eliminarSede(String sedeId) async {
    final db = _db;
    if (db == null) return;
    try {
      _errorMessage = '';
      await db.from('canchas').delete().eq('sede_id', sedeId);
      await db.from('sedes').delete().eq('id', sedeId);
      await fetchSedes(force: true);
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error al eliminar sede: $e';
      debugPrint('Error en eliminarSede: $e');
      notifyListeners();
      rethrow;
    }
  }

  Future<String?> getDownloadLinkFromFirebase() async {
    return getDownloadLinkFromSupabase();
  }

  Future<String?> getDownloadLinkFromSupabase() async {
    final db = _db;
    if (db == null) return null;
    try {
      final row = await db
          .from('app_download_links')
          .select('apk_url')
          .eq('id', 'descarga')
          .maybeSingle();
      if (row == null) return null;
      return row['apk_url'] as String?;
    } catch (e) {
      debugPrint('Error al obtener enlace de descarga: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getDownloadInfo() async {
    final db = _db;
    if (db == null) return null;
    try {
      final row = await db
          .from('app_download_links')
          .select()
          .eq('id', 'descarga')
          .maybeSingle();
      return row == null ? null : Map<String, dynamic>.from(row);
    } catch (e) {
      debugPrint('Error al obtener información de descarga: $e');
      return null;
    }
  }

  Future<bool> isDownloadLinkActive() async {
    final db = _db;
    if (db == null) return false;
    try {
      final row = await db
          .from('app_download_links')
          .select('active')
          .eq('id', 'descarga')
          .maybeSingle();
      if (row == null) return false;
      return row['active'] as bool? ?? true;
    } catch (e) {
      debugPrint('Error al verificar estado del enlace: $e');
      return false;
    }
  }

  Future<bool> updateDownloadLink(String newLink) async {
    final db = _db;
    if (db == null) return false;
    try {
      await db.from('app_download_links').upsert({
        'id': 'descarga',
        'apk_url': newLink,
        'updated_at': DateTime.now().toIso8601String(),
        'active': true,
      });
      return true;
    } catch (e) {
      debugPrint('Error al actualizar enlace de descarga: $e');
      return false;
    }
  }

  Future<bool> deactivateDownloadLink() async {
    final db = _db;
    if (db == null) return false;
    try {
      await db.from('app_download_links').upsert({
        'id': 'descarga',
        'active': false,
        'deactivated_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint('Error al desactivar enlace: $e');
      return false;
    }
  }
}
