import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:convert';

import 'ciudad_preference_service.dart';
import 'notification_helper.dart';

/// ID del canal de notificaciones Android para promociones.
const String androidChannelIdPromociones = 'promociones';

/// Canal Android para reservas pendientes (staff del lugar).
const String androidChannelIdStaffReservas = 'reservas_staff_pendientes';

/// VAPID key para FCM web (desde Firebase Console → Cloud Messaging → Web Push certificates).
const String _vapidKeyWeb =
    'BLvpYxLqgXyrlHcfAtaWjXYP7SJn4ws5K3h6e7Mh3X4hJVdbHzYal5SW3jB2jcd8GTgQUKnT9mgjQzaF5cbZrmk';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint(
      'PushNotificationService: background message ${message.messageId}');
}

/// Servicio de notificaciones push por ciudad.
/// Los usuarios (sin login) reciben promociones solo de la ciudad seleccionada (web y móvil).
class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._();
  factory PushNotificationService() => _instance;

  PushNotificationService._();

  /// Si se asigna, se llama cuando el permiso de notificaciones está denegado/bloqueado.
  /// Útil para mostrar un SnackBar o diálogo en la app (ej.: desde un context con navigatorKey).
  static void Function(String message)? onPermissionDenied;

  /// Mensajes de permiso denegado pendientes (p. ej. antes de tener context). La app puede leer y mostrar.
  static final List<String> pendingPermissionDeniedMessages = [];

  static void _notifyPermissionDenied(String message) {
    pendingPermissionDeniedMessages.add(message);
    onPermissionDenied?.call(message);
  }

  /// Si se asigna, se llama cuando falla el registro del token en el backend.
  static void Function(String message)? onRegistrationError;

  /// Mensajes de error de registro pendientes (antes de tener un context disponible).
  static final List<String> pendingRegistrationErrorMessages = [];

  static void _notifyRegistrationError(String message) {
    pendingRegistrationErrorMessages.add(message);
    onRegistrationError?.call(message);
  }

  /// Registrado desde [main]: limpia ciudad y navega a [CiudadScreen] (solo visitantes).
  static Future<void> Function()? guestRepickCiudadForPushCallback;

  /// Registrado desde [main]: abre la pantalla de reservas pendientes al tocar la notificación.
  static void Function()? onNavigateToReservasPendientes;

  static bool _repickCiudadHintAfterPushFailure = false;

  static void markRepickCiudadHintAfterPushFailure() {
    _repickCiudadHintAfterPushFailure = true;
  }

  /// Para mostrar un SnackBar al llegar a ciudades tras un fallo FCM.
  static bool consumeRepickCiudadHintAfterPushFailure() {
    final v = _repickCiudadHintAfterPushFailure;
    _repickCiudadHintAfterPushFailure = false;
    return v;
  }

  Future<void> _onGuestFcmRegistrationFailed() async {
    try {
      if (FirebaseAuth.instance.currentUser != null) {
        const msg =
            'No se pudieron sincronizar las notificaciones. Revisa conexión y permisos.';
        debugPrint(
            'PushNotificationService: fallo FCM con sesión iniciada → aviso');
        _notifyRegistrationError(msg);
        return;
      }
    } catch (e) {
      debugPrint('PushNotificationService: comprobación auth en fallo FCM: $e');
    }

    // En web (incognito, Brave, bloqueo de notificaciones) FCM suele fallar sin token.
    // No forzar re-elegir ciudad: el visitante puede seguir usando la app sin push de promos.
    if (kIsWeb) {
      debugPrint(
          'PushNotificationService: web — fallo FCM visitante; se mantiene ciudad guardada '
          '(no redirigir a selección de ciudad).');
      return;
    }

    debugPrint(
        'PushNotificationService: fallo registro promociones (visitante) → re-elegir ciudad');
    try {
      await guestRepickCiudadForPushCallback?.call();
    } catch (e) {
      debugPrint(
          'PushNotificationService: callback recuperación ciudad error: $e');
    }
  }

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Inicializa FCM y registra el token con la ciudad en caché (si hay).
  Future<void> initialize() async {
    if (_initialized) return;

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    await _requestPermissionIfNeeded();
    await _initLocalNotifications();
    _setupMessageHandlers();
    _messaging.onTokenRefresh.listen((_) async {
      await registerTokenWithCurrentCiudad();
    });
    _initialized = true;
    await registerTokenWithCurrentCiudad();
    debugPrint(
        'PushNotificationService: initialized (notificaciones por ciudad)');
  }

  Future<void> _requestPermissionIfNeeded() async {
    if (kIsWeb) {
      try {
        final settings = await _messaging.getNotificationSettings();
        if (settings.authorizationStatus == AuthorizationStatus.denied) {
          await _messaging.requestPermission(
            alert: true,
            badge: true,
            sound: true,
          );
        }
      } catch (_) {}
      return;
    }
    final settings = await _messaging.getNotificationSettings();
    if (settings.authorizationStatus == AuthorizationStatus.authorized) return;
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await _messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
      }
      if (defaultTargetPlatform == TargetPlatform.android) {
        await Permission.notification.request();
      }
    }
  }

  Future<void> _initLocalNotifications() async {
    if (kIsWeb) return;
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
      macOS: darwinInit,
    );
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationTapped,
    );

    if (defaultTargetPlatform == TargetPlatform.android) {
      const channelPromos = AndroidNotificationChannel(
        androidChannelIdPromociones,
        'Promociones TuCanchaFácil',
        description: 'Nuevas promociones de canchas',
        importance: Importance.high,
        playSound: true,
      );
      const channelStaff = AndroidNotificationChannel(
        androidChannelIdStaffReservas,
        'Reservas pendientes (staff)',
        description: 'Nuevas reservas por confirmar en tu lugar',
        importance: Importance.high,
        playSound: true,
      );
      final androidPlugin =
          _localNotifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(channelPromos);
      await androidPlugin?.createNotificationChannel(channelStaff);
    }
  }

  void _onLocalNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    debugPrint('PushNotificationService: local notification tapped $payload');
    try {
      final map = jsonDecode(payload);
      if (map is Map<String, dynamic> && map['type'] == 'reserva_pendiente') {
        onNavigateToReservasPendientes?.call();
      }
    } catch (_) {}
  }

  /// Plataforma actual para el backend.
  String get _platform {
    if (kIsWeb) return 'web';
    if (defaultTargetPlatform == TargetPlatform.android) return 'android';
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'ios';
    return 'web';
  }

  /// Obtiene el token FCM. En web pide permiso antes si hace falta.
  Future<String?> _getToken() async {
    if (kIsWeb) {
      final settings = await _messaging.getNotificationSettings();
      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        final permission = await _messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        if (permission.authorizationStatus != AuthorizationStatus.authorized &&
            permission.authorizationStatus != AuthorizationStatus.provisional) {
          const msg =
              'Para recibir promociones, permite notificaciones en la configuración del sitio '
              '(icono de candado en la barra de direcciones → Notificaciones → Permitir).';
          debugPrint(
              'PushNotificationService: permiso denegado o bloqueado. $msg');
          _notifyPermissionDenied(msg);
          return null;
        }
      }
    }
    try {
      if (kIsWeb) {
        final vapid = _vapidKeyWeb.isEmpty ? null : _vapidKeyWeb;
        return await _messaging.getToken(vapidKey: vapid);
      }
      return await _messaging.getToken();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-blocked' ||
          e.message?.contains('permission') == true) {
        const msg =
            'Notificaciones bloqueadas. Actívalas en la configuración del sitio para recibir promociones.';
        debugPrint('PushNotificationService: $msg');
        _notifyPermissionDenied(msg);
      } else {
        debugPrint(
            'PushNotificationService: getToken error ${e.code} ${e.message}');
      }
      return null;
    } catch (e) {
      if (e.toString().contains('permission-blocked') ||
          e.toString().contains('permission')) {
        const msg =
            'Notificaciones bloqueadas. Actívalas en la configuración del sitio para recibir promociones.';
        debugPrint('PushNotificationService: $msg');
        _notifyPermissionDenied(msg);
      } else {
        debugPrint('PushNotificationService: getToken error $e');
      }
      return null;
    }
  }

  /// Registra el token con la ciudad actual en caché. Llamar al iniciar la app.
  Future<void> registerTokenWithCurrentCiudad() async {
    final ciudad = await CiudadPreferenceService.getSelectedCiudad();
    if (ciudad == null) {
      debugPrint(
          'PushNotificationService: sin ciudad seleccionada, no se registra token');
      return;
    }
    await updateCiudadForNotifications(ciudad.id);
  }

  /// Actualiza el registro para que las notificaciones lleguen solo de [ciudadId].
  /// Llamar cuando el usuario selecciona o cambia de ciudad.
  Future<void> updateCiudadForNotifications(String ciudadId) async {
    if (ciudadId.isEmpty) return;

    String? token;
    const maxRetries = 3;

    for (var attempt = 0; attempt < maxRetries && token == null; attempt++) {
      token = await _getToken();
      if (token == null && attempt < maxRetries - 1) {
        await Future<void>.delayed(Duration(milliseconds: 500 * (attempt + 1)));
      }
    }

    if (token == null) {
      debugPrint(
          'PushNotificationService: no token tras reintentos, no se puede registrar ciudad');
      await _onGuestFcmRegistrationFailed();
      return;
    }
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('registerFcmToken');
      await callable.call({
        'token': token,
        'ciudadId': ciudadId,
        'platform': _platform,
      }).timeout(const Duration(seconds: 10));
      debugPrint('PushNotificationService: registrado para ciudad $ciudadId');
    } on TimeoutException {
      debugPrint('PushNotificationService: registerFcmToken timeout');
      await _onGuestFcmRegistrationFailed();
    } catch (e) {
      debugPrint('PushNotificationService: registerFcmToken error $e');
      await _onGuestFcmRegistrationFailed();
    }
  }

  /// Registra el token para recibir notificaciones de auditorías de riesgo alto/crítico del [lugarId].
  /// Solo el superadmin recibe estas notificaciones, y solo del lugar donde inició sesión. El backend valida el rol.
  /// Registra el dispositivo para push de **reservas pendientes** del [lugarId] (mismo que la sesión).
  /// Solo tiene efecto si el usuario es admin, encargado o superadmin (valida el backend).
  Future<void> registerTokenForStaffPendingReservas(String lugarId) async {
    if (lugarId.isEmpty) return;
    await initialize();
    String? token = await _getToken();
    if (token == null) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      token = await _getToken();
    }
    if (token == null) {
      debugPrint(
          'PushNotificationService: no token, no se registra reservas pendientes');
      return;
    }
    try {
      final callable = FirebaseFunctions.instance
          .httpsCallable('registerFcmTokenStaffPendingReservas');
      await callable.call({
        'token': token,
        'lugarId': lugarId,
        'platform': _platform,
      });
      debugPrint(
          'PushNotificationService: registrado reservas pendientes, lugar $lugarId');
    } catch (e) {
      debugPrint(
          'PushNotificationService: registerFcmTokenStaffPendingReservas error $e');
    }
  }

  /// Quita el registro de push de reservas pendientes (p. ej. al cerrar sesión).
  Future<void> unregisterTokenStaffPendingReservas() async {
    String? token = await _getToken();
    token ??= await _messaging.getToken();
    if (token == null || token.isEmpty) return;
    try {
      final callable = FirebaseFunctions.instance
          .httpsCallable('unregisterFcmTokenStaffPendingReservas');
      await callable.call({'token': token});
      debugPrint('PushNotificationService: desregistrado reservas pendientes');
    } catch (e) {
      debugPrint('PushNotificationService: unregister staff pending error $e');
    }
  }

  Future<void> registerTokenForAuditAlerts(String lugarId) async {
    if (lugarId.isEmpty) return;
    await initialize();
    String? token = await _getToken();
    if (token == null) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      token = await _getToken();
    }
    if (token == null) {
      debugPrint(
          'PushNotificationService: no token, no se registra alertas de auditoría');
      return;
    }
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('registerFcmTokenAudit');
      await callable.call({
        'token': token,
        'lugarId': lugarId,
        'platform': _platform,
      });
      debugPrint(
          'PushNotificationService: registrado para alertas de auditoría, lugar $lugarId');
    } catch (e) {
      debugPrint('PushNotificationService: registerFcmTokenAudit error $e');
    }
  }

  void _setupMessageHandlers() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint(
          'PushNotificationService: foreground message ${message.messageId}');
      final notification = message.notification;
      if (notification != null) {
        final data = message.data;
        final payloadJson = jsonEncode(data);
        final isReservaPendiente = data['type'] == 'reserva_pendiente';
        if (kIsWeb) {
          showWebNotification(
            notification.title ?? 'TuCanchaFacil',
            notification.body ?? '',
            'https://img.icons8.com/color/512/soccer-ball.png',
          );
        } else {
          _showLocalNotification(
            id: message.hashCode,
            title: notification.title ?? 'TuCanchaFácil',
            body: notification.body ?? '',
            payload: payloadJson,
            androidChannelId: isReservaPendiente
                ? androidChannelIdStaffReservas
                : androidChannelIdPromociones,
          );
        }
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint(
          'PushNotificationService: opened from message ${message.messageId}');
      _handleNotificationTap(message);
    });

    _messaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) _handleNotificationTap(message);
    });
  }

  void _handleNotificationTap(RemoteMessage message) {
    final data = message.data;
    final type = data['type'];
    if (type == 'promocion') {
      debugPrint(
          'PushNotificationService: open promocion ${data['promocionId']}');
    } else if (type == 'auditoria') {
      debugPrint(
          'PushNotificationService: open auditoría ${data['auditId']} lugar ${data['lugarId']}');
    } else if (type == 'reserva_pendiente') {
      debugPrint(
          'PushNotificationService: open reservas pendientes ${data['reservaId']}');
      onNavigateToReservasPendientes?.call();
    }
  }

  Future<void> _showLocalNotification({
    required int id,
    required String title,
    required String body,
    String payload = '',
    String androidChannelId = androidChannelIdPromociones,
  }) async {
    if (kIsWeb) return;
    final androidDetails = AndroidNotificationDetails(
      androidChannelId,
      androidChannelId == androidChannelIdStaffReservas
          ? 'Reservas pendientes (staff)'
          : 'Promociones TuCanchaFácil',
      channelDescription: androidChannelId == androidChannelIdStaffReservas
          ? 'Nuevas reservas por confirmar'
          : 'Nuevas promociones de canchas',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    final details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );
    await _localNotifications.show(id, title, body, details, payload: payload);
  }
}
