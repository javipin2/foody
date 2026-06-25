import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../services/storage_service.dart';
import '../services/push_notification_service.dart';
import '../services/app_backend.dart';
import '../services/lugar_helper.dart';

class AuthProvider with ChangeNotifier {
  User? _user;
  Map<String, dynamic>? _userData;
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _currentLugarId; // Lugar actual del usuario
  String? _currentCiudadId; // Ciudad actual del usuario
  
  // ✅ CORRECCIÓN: Variable para guardar la suscripción del stream
  StreamSubscription<User?>? _authSubscription;

  User? get user => _user;
  Map<String, dynamic>? get userData => _userData;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  bool get isAuthenticated => _user != null;
  String? get currentLugarId => _currentLugarId;
  String? get currentCiudadId => _currentCiudadId;


  /// Inicializar el provider y verificar sesión persistente
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    _isLoading = true;
    // No llamar notifyListeners() durante la inicialización para evitar setState during build

    try {
      // Configurar listener de cambios de autenticación
      startAuthStateListener();
      
      // Verificar si hay un usuario autenticado actualmente
      _user = FirebaseAuth.instance.currentUser;
      
      if (_user != null) {
        await _loadUserDataFromSupabase();
      } else {
        // Si no hay usuario, intentar cargar desde SharedPreferences
        await _loadUserFromStorage();
      }
    } catch (e) {
      debugPrint('Error inicializando AuthProvider: $e');
      _clearUserData();
    } finally {
      _isLoading = false;
      _isInitialized = true;
      // Diferir la notificación para evitar setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    }
  }

  /// Perfil de staff en Supabase (`staff_profiles.id` = Firebase Auth UID).
  Future<void> _loadUserDataFromSupabase() async {
    if (_user == null) return;

    if (!AppBackend.supabaseReady) {
      debugPrint('Supabase no inicializado: no se cargan datos de staff');
      return;
    }

    try {
      final row = await Supabase.instance.client
          .from('staff_profiles')
          .select()
          .eq('id', _user!.uid)
          .maybeSingle();

      if (row == null) {
        debugPrint('Usuario no encontrado en staff_profiles');
        await signOut();
        return;
      }

      if (row['activo'] == false) {
        await signOut();
        return;
      }

      _userData = {
        'id': row['id'],
        'email': row['email'],
        'nombre': row['nombre'],
        'rol': row['rol'],
        'lugarId': row['lugar_id'],
        'ciudadId': row['ciudad_id'],
        'activo': row['activo'],
      };

      _currentLugarId = _userData!['lugarId'] as String?;
      _currentCiudadId = _userData!['ciudadId'] as String?;

      debugPrint(
          'Usuario cargado - Lugar: $_currentLugarId, Ciudad: $_currentCiudadId');

      await _saveUserToStorage();
      _registerStaffPendingPushIfNeeded();
    } catch (e) {
      debugPrint('Error cargando datos del usuario: $e');
      await signOut();
    }
  }

  /// Cargar usuario desde almacenamiento local
  Future<void> _loadUserFromStorage() async {
    try {
      _userData = await StorageService.loadUserData();
      
      if (_userData != null) {
        // Intentar reautenticar con Firebase
        if (_userData!['email'] != null) {
          // En web, Firebase mantiene la sesión automáticamente
          // En móvil, necesitamos verificar si el token sigue siendo válido
          _user = FirebaseAuth.instance.currentUser;
          
          if (_user == null) {
            // Si no hay usuario en Firebase, limpiar datos locales
            _clearUserData();
          }
        }
      }
    } catch (e) {
      debugPrint('Error cargando usuario desde almacenamiento: $e');
      _clearUserData();
    }
  }

  /// Guardar datos del usuario en almacenamiento local
  Future<void> _saveUserToStorage() async {
    if (_userData == null) return;

    try {
      await StorageService.saveUserData(_userData!);
    } catch (e) {
      debugPrint('Error guardando usuario en almacenamiento: $e');
    }
  }

  /// Limpiar datos del usuario
  void _clearUserData() {
    _user = null;
    _userData = null;
    _currentLugarId = null;
    _currentCiudadId = null;
  }

  /// Limpiar almacenamiento local
  Future<void> _clearStorage() async {
    try {
      await StorageService.clearUserData();
    } catch (e) {
      debugPrint('Error limpiando almacenamiento: $e');
    }
  }

  /// Iniciar sesión
  Future<bool> signIn(String email, String password, {bool rememberMe = false}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      _user = userCredential.user;
      
      if (_user != null) {
        // Obtener token de autenticación
        final token = await _user!.getIdToken();
        if (token != null) {
          await StorageService.saveAuthToken(token);
        }
        
        // Guardar credenciales si el usuario quiere recordar
        if (rememberMe) {
          await StorageService.saveLoginCredentials(email.trim(), password.trim());
        } else {
          await StorageService.clearLoginCredentials();
        }
        
        // Guardar preferencia de recordar
        await StorageService.saveRememberMe(rememberMe);
        
        await _loadUserDataFromSupabase();
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('Error en signIn: $e');
      _clearUserData();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Validar que el usuario puede acceder a un lugar específico
  /// Solo aplica para usuarios autenticados con roles
  bool canAccessLugar(String lugarId) {
    if (!isAuthenticated || _userData == null) return true; // Visitantes pueden acceder
    
    // Si es programador, puede acceder a cualquier lugar
    if (_userData!['rol'] == 'programador') return true;
    
    // Para otros roles, verificar que el lugarId coincida
    return _currentLugarId == lugarId;
  }

  /// Validar que el usuario puede acceder a una ciudad específica
  /// Solo aplica para usuarios autenticados con roles
  bool canAccessCiudad(String ciudadId) {
    if (!isAuthenticated || _userData == null) return true; // Visitantes pueden acceder
    
    // Si es programador, puede acceder a cualquier ciudad
    if (_userData!['rol'] == 'programador') return true;
    
    // Para otros roles, verificar que la ciudadId coincida
    return _currentCiudadId == ciudadId;
  }

  void _registerStaffPendingPushIfNeeded() {
    if (_user == null || _userData == null) return;
    final rol = userRole;
    if (rol != 'admin' && rol != 'encargado' && rol != 'superadmin') return;
    final lid = _currentLugarId;
    if (lid == null || lid.isEmpty) return;
    PushNotificationService()
        .registerTokenForStaffPendingReservas(lid)
        .catchError((Object _) {});
  }

  /// Cerrar sesión
  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    try {
      await PushNotificationService().unregisterTokenStaffPendingReservas();
      await FirebaseAuth.instance.signOut();
      LugarHelper.clearCache();
      _clearUserData();
      await _clearStorage();
    } catch (e) {
      debugPrint('Error en signOut: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Obtener rol del usuario
  String? get userRole => _userData?['rol'];

  /// Verificar si es admin
  bool get isAdmin => userRole == 'admin' || userRole == 'superadmin';

  /// Verificar si es superadmin
  bool get isSuperAdmin => userRole == 'superadmin';

  /// Verificar si es encargado
  bool get isEncargado => userRole == 'encargado';

  /// Verificar si es staff (admin, superadmin o encargado)
  bool get isStaff => isAdmin || isEncargado;

  /// Obtener nombre del usuario
  String? get userName => _userData?['name'] ?? _userData?['nombre'];

  /// Obtener email del usuario
  String? get userEmail => _user?.email;

  /// Cargar credenciales guardadas
  Future<Map<String, String>?> loadSavedCredentials() async {
    try {
      return await StorageService.loadLoginCredentials();
    } catch (e) {
      debugPrint('Error cargando credenciales guardadas: $e');
      return null;
    }
  }

  /// Cargar preferencia de recordar
  Future<bool> loadRememberMePreference() async {
    try {
      return await StorageService.loadRememberMe();
    } catch (e) {
      debugPrint('Error cargando preferencia de recordar: $e');
      return false;
    }
  }

  /// Verificar si hay credenciales guardadas
  Future<bool> hasSavedCredentials() async {
    try {
      return await StorageService.hasSavedCredentials();
    } catch (e) {
      debugPrint('Error verificando credenciales guardadas: $e');
      return false;
    }
  }

  /// Actualizar el nombre del usuario actual (Supabase + displayName Firebase)
  Future<bool> updateUserName(String newName) async {
    if (_user == null) return false;
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return false;

    try {
      final uid = _user!.uid;
      if (AppBackend.supabaseReady) {
        await Supabase.instance.client.from('staff_profiles').update({
          'nombre': trimmed,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', uid);
      }

      _userData = {
        ...?_userData,
        'nombre': trimmed,
      };

      await _saveUserToStorage();

      await _user!.updateDisplayName(trimmed);

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error actualizando nombre de usuario: $e');
      return false;
    }
  }

  /// Limpiar credenciales guardadas
  Future<void> clearSavedCredentials() async {
    try {
      await StorageService.clearLoginCredentials();
      await StorageService.saveRememberMe(false);
    } catch (e) {
      debugPrint('Error limpiando credenciales guardadas: $e');
    }
  }

  /// Verificar si el usuario tiene permisos para una acción específica
  bool hasPermission(String action) {
    if (!isAuthenticated) return false;
    
    switch (action) {
      case 'read_reservas':
      case 'read_canchas':
      case 'read_sedes':
        return isStaff;
      case 'write_reservas':
      case 'write_canchas':
      case 'write_sedes':
        return isAdmin;
      case 'manage_users':
      case 'system_settings':
        return isSuperAdmin;
      default:
        return false;
    }
  }

  /// Escuchar cambios en el estado de autenticación
  void startAuthStateListener() {
    // ✅ CORRECCIÓN: Cancelar listener anterior si existe para evitar múltiples listeners
    _authSubscription?.cancel();
    
    // ✅ CORRECCIÓN: Guardar la referencia del nuevo listener
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen(
      (User? user) async {
        if (user != _user) {
          _user = user;
          if (user != null) {
            // Usuario autenticado - cargar datos
            await _loadUserDataFromSupabase();
          } else {
            // Usuario no autenticado - limpiar datos
            _clearUserData();
            await _clearStorage();
          }
          notifyListeners();
        }
      },
      onError: (error) {
        // ✅ CORRECCIÓN: Manejar errores del stream
        debugPrint('Error en authStateChanges: $error');
      },
    );
  }

  // ✅ CORRECCIÓN: Método dispose para limpiar recursos cuando el provider se destruye
  @override
  void dispose() {
    // Cancelar el stream cuando el provider se destruye para evitar memory leaks
    _authSubscription?.cancel();
    _authSubscription = null;
    super.dispose();
  }

}
