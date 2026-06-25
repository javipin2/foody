// Bootstrap anterior (Tu Cancha Fácil). Solo para consulta o pruebas puntuales:
// flutter run -t lib/legacy/main_reserva_canchas.dart
//
// La app Foody arranca desde lib/main.dart.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:reserva_canchas/providers/audit_provider.dart';
import 'package:reserva_canchas/providers/sede_provider.dart';
import 'package:reserva_canchas/providers/reserva_provider.dart';
import 'package:reserva_canchas/providers/cancha_provider.dart';
import 'package:reserva_canchas/providers/version_provider.dart';
import 'package:reserva_canchas/providers/auth_provider.dart';
import 'package:reserva_canchas/providers/reserva_recurrente_provider.dart';
import 'package:reserva_canchas/providers/ciudad_provider.dart';
import 'package:reserva_canchas/providers/lugar_provider.dart';
import 'package:reserva_canchas/providers/promocion_provider.dart';
import 'package:reserva_canchas/screens/splash_screen.dart';
import 'package:reserva_canchas/screens/admin/reservas%20a%20confirmar/reservas_pendientes.dart';
import 'package:reserva_canchas/screens/ciudad_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:reserva_canchas/firebase_options.dart';
import 'package:reserva_canchas/config/supabase_env.dart';
import 'package:reserva_canchas/services/app_backend.dart';
import 'package:reserva_canchas/providers/menu_cart_provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:reserva_canchas/services/cleanup_service.dart';
import 'package:reserva_canchas/services/index_error_service.dart';
import 'package:reserva_canchas/services/push_notification_service.dart';
import 'package:reserva_canchas/services/shared_lugar_link_service.dart';
import 'package:reserva_canchas/services/ciudad_preference_service.dart';

final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  if (kIsWeb) {
    runZonedGuarded(() async {
      await _initLegacyApp();
    }, (error, stack) {
      if (error.toString().contains('ViewInsets cannot be negative') ||
          error.toString().contains('_viewInsets.isNonNegative')) {
        return;
      }
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'main_reserva_canchas',
      ));
    });
  } else {
    await _initLegacyApp();
  }
}

Future<void> _initLegacyApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  initializeDateFormatting('es');

  if (!kIsWeb) {
    try {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } catch (_) {}
  }

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (isSupabaseConfigured) {
    try {
      await Supabase.initialize(
        url: kSupabaseUrl.trim(),
        anonKey: kSupabaseAnonKey.trim(),
      );
      AppBackend.supabaseReady = true;
    } catch (_) {
      AppBackend.supabaseReady = false;
    }
  }

  CleanupService.programarLimpiezaAutomatica();
  IndexErrorService.generateIndexReport();
  try {
    await PushNotificationService().initialize();
  } catch (_) {}
  await SharedLugarLinkService.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => MenuCartProvider()),
        ChangeNotifierProvider(create: (_) => VersionProvider()),
        ChangeNotifierProvider(create: (_) => ReservaProvider()),
        ChangeNotifierProvider(create: (_) => SedeProvider()),
        ChangeNotifierProvider(create: (_) => CanchaProvider()),
        ChangeNotifierProvider(create: (_) => AuditProvider()),
        ChangeNotifierProvider(create: (_) => ReservaRecurrenteProvider()),
        ChangeNotifierProvider(create: (_) => CiudadProvider()),
        ChangeNotifierProvider(create: (_) => LugarProvider()),
        ChangeNotifierProvider(create: (_) => PromocionProvider()),
      ],
      child: MaterialApp(
        title: 'Reserva de Canchas (legacy)',
        navigatorKey: appNavigatorKey,
        home: const SplashScreen(),
      ),
    ),
  );
}
