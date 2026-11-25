import 'dart:convert';
import 'dart:async';

import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:reserva_canchas/core/config/app_flavor.dart';
import 'package:reserva_canchas/core/dispositivo/dispositivo_service.dart';
import 'package:reserva_canchas/core/notificaciones/manejador_fcm_segundo_plano.dart';
import 'package:reserva_canchas/core/notificaciones/navegador_fcm_foody.dart';
import 'package:reserva_canchas/core/notificaciones/notificacion_navegador_web_stub.dart'
    if (dart.library.html) 'package:reserva_canchas/core/notificaciones/notificacion_navegador_web.dart';
import 'package:reserva_canchas/core/notificaciones/fcm_click_web_stub.dart'
    if (dart.library.html) 'package:reserva_canchas/core/notificaciones/fcm_click_web.dart';
import 'package:reserva_canchas/core/red/cliente_dio.dart';
import 'package:reserva_canchas/core/sesion/sesion_staff_service.dart';
import 'package:reserva_canchas/services/app_backend.dart';
import 'package:reserva_canchas/services/ciudad_preference_service.dart';

/// VAPID web — Firebase Console → Cloud Messaging → Web Push certificates.
/// Proyecto foody-pin2. Si está vacío, FCM web no obtiene token.
const String kVapidKeyWebFoody =
    'BLaunARY9xaUqroB4gukrDfQts4tzPByEsIb9_lHyc7QVukMv1Q_Xv4CY2KQ9aFiYYSXjinSp7fJQUenhjKuI0U';

const String _canalAndroidFoody = 'promociones';

/// FCM Foody → NestJS (`/dispositivos/registrar` cliente, `/auth/registrar-fcm` staff).
class ServicioFcmFoody {
  ServicioFcmFoody._();
  static final ServicioFcmFoody instancia = ServicioFcmFoody._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  bool _inicializado = false;

  Future<void> inicializar() async {
    if (_inicializado || !AppBackend.firebaseReady) return;

    FirebaseMessaging.onBackgroundMessage(manejadorFcmSegundoPlano);
    await _pedirPermisos();
    await _initNotificacionesLocales();
    _escucharMensajes();
    if (kIsWeb) {
      escucharClicksFcmWeb(NavegadorFcmFoody.manejar);
    }

    _messaging.onTokenRefresh.listen((token) async {
      await _registrarToken(token);
    });

    _inicializado = true;
    final token = await _obtenerToken();
    if (token != null) {
      await _registrarToken(token);
    }
    // En web, Firebase puede responder HTML (p. ej. fallo del servicio) y su
    // parser JSON arrojar FormatException. Es opcional para renderizar Foody;
    // capturar aquí evita una promesa rechazada fuera del catch del caller.
    unawaited(_manejarAperturaDesdeNotificacion().catchError((Object error) {
      if (kDebugMode) {
        debugPrint('FCM: no se pudo leer el mensaje inicial: $error');
      }
    }));
    debugPrint('ServicioFcmFoody: listo (${AppFlavor.actual.id})');
  }

  /// Llamar tras login staff/domiciliario (app equipo).
  Future<void> registrarTrasLoginStaff({String? tokenSesion}) async {
    if (!AppFlavor.actual.esEquipo || !AppBackend.firebaseReady) return;
    final token = await _obtenerToken();
    if (token != null) {
      await _registrarToken(token, tokenSesion: tokenSesion);
    }
  }

  /// Tras elegir/cambiar ciudad: actualiza device + FCM con `ciudad_id`.
  Future<void> sincronizarTrasCambioCiudad() async {
    if (!AppFlavor.actual.esCliente) return;
    try {
      final ciudad = await CiudadPreferenceService.getSelectedCiudad();
      String? token;
      if (AppBackend.firebaseReady) {
        token = await _obtenerToken();
      }
      await DispositivoService.registrarEnBackend(
        ciudadId: ciudad?.id,
        fcmToken: token,
      );
    } catch (e) {
      debugPrint('ServicioFcmFoody sincronizar ciudad: $e');
    }
  }

  Future<void> _pedirPermisos() async {
    if (kIsWeb) {
      await _messaging.requestPermission(alert: true, badge: true, sound: true);
      return;
    }
    final settings = await _messaging.getNotificationSettings();
    if (settings.authorizationStatus == AuthorizationStatus.authorized) return;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _messaging.requestPermission(alert: true, badge: true, sound: true);
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      await Permission.notification.request();
    }
  }

  Future<void> _initNotificacionesLocales() async {
    if (kIsWeb) return;
    const init = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _local.initialize(
      init,
      onDidReceiveNotificationResponse: (details) {
        final payload = details.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final data = jsonDecode(payload);
          if (data is Map) {
            NavegadorFcmFoody.manejar(Map<String, dynamic>.from(data));
          }
        } catch (_) {}
      },
    );
    if (defaultTargetPlatform == TargetPlatform.android) {
      const canal = AndroidNotificationChannel(
        _canalAndroidFoody,
        'Foody',
        description: 'Pedidos, ofertas y alertas',
        importance: Importance.high,
      );
      await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(canal);
    }
  }

  void _escucharMensajes() {
    FirebaseMessaging.onMessage.listen((message) async {
      final notif = message.notification;
      if (notif == null) return;

      if (kIsWeb) {
        mostrarNotificacionNavegador(
          titulo: notif.title ?? 'Foody',
          cuerpo: notif.body ?? '',
          data: Map<String, dynamic>.from(message.data),
          alTocar: NavegadorFcmFoody.manejar,
        );
        return;
      }

      await _local.show(
        message.hashCode,
        notif.title ?? 'Foody',
        notif.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _canalAndroidFoody,
            'Foody',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        payload: jsonEncode(message.data),
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      NavegadorFcmFoody.manejar(message.data);
    });
  }

  Future<void> _manejarAperturaDesdeNotificacion() async {
    final mensajeInicial = await _messaging.getInitialMessage();
    if (mensajeInicial != null) {
      NavegadorFcmFoody.manejar(mensajeInicial.data);
    }
  }

  String get _plataforma {
    if (kIsWeb) return 'web';
    if (defaultTargetPlatform == TargetPlatform.android) return 'android';
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'ios';
    return 'android';
  }

  Future<String?> _obtenerToken() async {
    try {
      if (kIsWeb) {
        if (kVapidKeyWebFoody.isEmpty) {
          debugPrint('ServicioFcmFoody: falta kVapidKeyWebFoody para web');
          return null;
        }
        return await _messaging.getToken(vapidKey: kVapidKeyWebFoody);
      }
      return await _messaging.getToken();
    } on FirebaseException catch (e) {
      debugPrint('ServicioFcmFoody getToken: ${e.code} ${e.message}');
      return null;
    } catch (e) {
      debugPrint('ServicioFcmFoody getToken: $e');
      return null;
    }
  }

  Future<void> _registrarToken(String token, {String? tokenSesion}) async {
    try {
      if (AppFlavor.actual.esCliente) {
        String? ciudadId;
        final ciudad = await CiudadPreferenceService.getSelectedCiudad();
        ciudadId = ciudad?.id;
        await DispositivoService.registrarEnBackend(
          fcmToken: token,
          ciudadId: ciudadId,
          plataforma: _plataforma,
        );
        debugPrint('ServicioFcmFoody: token cliente → NestJS');
        return;
      }

      final sesion = await SesionStaffService.cargar();
      if (sesion == null) {
        debugPrint(
            'ServicioFcmFoody: equipo sin sesión, token pendiente de login');
        return;
      }
      if (tokenSesion != null && sesion.token != tokenSesion) return;
      final dio = ClienteDio.instancia(conAuthStaff: true);
      await dio.post('/auth/registrar-fcm', data: {
        'fcm_token': token,
        'plataforma': _plataforma,
      });
      debugPrint('ServicioFcmFoody: token staff → NestJS');
    } catch (e) {
      debugPrint('ServicioFcmFoody registrar: $e');
    }
  }
}
