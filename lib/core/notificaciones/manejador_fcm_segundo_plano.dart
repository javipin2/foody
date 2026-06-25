import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:reserva_canchas/core/firebase/firebase_inicializador.dart';

/// Handler FCM en segundo plano (archivo top-level obligatorio para el isolate).
@pragma('vm:entry-point')
Future<void> manejadorFcmSegundoPlano(RemoteMessage message) async {
  await Firebase.initializeApp(options: FirebaseInicializador.opcionesActuales());
  debugPrint('FCM background: ${message.messageId} ${message.data}');
}
