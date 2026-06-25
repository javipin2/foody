import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:reserva_canchas/core/config/app_flavor.dart';
import 'package:reserva_canchas/firebase_options_cliente.dart' as opts_cliente;
import 'package:reserva_canchas/firebase_options_equipo.dart' as opts_equipo;

/// Selecciona las [FirebaseOptions] según [AppFlavor.actual] y la plataforma.
class FirebaseInicializador {
  FirebaseInicializador._();

  static FirebaseOptions opcionesActuales() {
    switch (AppFlavor.actual) {
      case AppFlavor.cliente:
        return opts_cliente.DefaultFirebaseOptions.currentPlatform;
      case AppFlavor.equipo:
        if (kIsWeb) {
          // Mismo proyecto; web solo está registrada en flavor cliente por ahora.
          return opts_cliente.DefaultFirebaseOptions.web;
        }
        if (defaultTargetPlatform == TargetPlatform.windows) {
          return opts_cliente.DefaultFirebaseOptions.windows;
        }
        return opts_equipo.DefaultFirebaseOptions.currentPlatform;
    }
  }

  static Future<void> inicializar() async {
    await Firebase.initializeApp(options: opcionesActuales());
  }
}
