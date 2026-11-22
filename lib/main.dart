import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:reserva_canchas/config/supabase_env.dart';
import 'package:reserva_canchas/core/firebase/firebase_inicializador.dart';
import 'package:reserva_canchas/core/config/app_flavor.dart';
import 'package:reserva_canchas/core/rutas/app_router.dart';
import 'package:reserva_canchas/core/tema/tema_foody.dart';
import 'package:reserva_canchas/core/tema/tema_mode_provider.dart';
import 'package:reserva_canchas/core/notificaciones/servicio_fcm_foody.dart';
import 'package:reserva_canchas/features/auth/domain/google_oauth_deep_link_service.dart';
import 'package:reserva_canchas/features/pagos/domain/pagos_deep_link_service.dart';
import 'package:reserva_canchas/services/app_backend.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Navegación global (FCM, deep links — cuando se integren).
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Usado por pantallas legacy que aún no migran a go_router.
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

void main() {
  if (kIsWeb) {
    runZonedGuarded(() async {
      await _iniciarFoody();
    }, (error, stack) {
      if (error.toString().contains('ViewInsets cannot be negative') ||
          error.toString().contains('_viewInsets.isNonNegative')) {
        if (kDebugMode) {
          debugPrint('Web: error al cerrar teclado (ignorado): $error');
        }
        return;
      }
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'main',
      ));
    });
  } else {
    _iniciarFoody();
  }
}

Future<void> _iniciarFoody() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    usePathUrlStrategy();
  }
  initializeDateFormatting('es');

  if (!kIsWeb) {
    try {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          systemNavigationBarContrastEnforced: true,
          systemNavigationBarDividerColor: Colors.transparent,
        ),
      );
    } catch (_) {}
  }

  // Supabase self-hosted: Auth, Storage, Realtime (lectura). Catálogo y pedidos → NestJS.
  if (isSupabaseConfigured) {
    try {
      await Supabase.initialize(
        url: kSupabaseUrl.trim(),
        anonKey: kSupabaseAnonKey.trim(),
        authOptions: FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
          // Web: recupera ?code= en init (evitar llamar getSessionFromUrl dos veces).
          detectSessionInUri: kIsWeb,
        ),
      );
      AppBackend.supabaseReady = true;
      if (!kIsWeb) {
        await GoogleOAuthDeepLinkService.initialize();
      }
    } catch (e, st) {
      AppBackend.supabaseReady = false;
      if (kDebugMode) {
        debugPrint('Supabase.initialize falló: $e\n$st');
        debugPrint(
          'Revisa lib/core/constantes/configuracion.dart (URL y anon key del VPS).',
        );
      }
    }
  } else {
    AppBackend.supabaseReady = false;
  }

  // Wompi → foody://plan (no depende de Supabase).
  if (!kIsWeb) {
    await PagosDeepLinkService.initialize();
  }

  try {
    await FirebaseInicializador.inicializar();
    AppBackend.firebaseReady = true;
    unawaited(ServicioFcmFoody.instancia.inicializar());
  } catch (e, st) {
    AppBackend.firebaseReady = false;
    if (kDebugMode) {
      debugPrint('Firebase.initializeApp falló: $e\n$st');
    }
  }

  runApp(const ProviderScope(child: FoodyApp()));
}

/// App Foody — un entry point; variante con `--dart-define=APP_FLAVOR=...`.
class FoodyApp extends ConsumerWidget {
  const FoodyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(temaModeProvider);
    return MaterialApp.router(
      title: AppFlavor.actual.nombreVisible,
      debugShowCheckedModeBanner: false,
      theme: TemaFoody.claro(),
      darkTheme: TemaFoody.oscuro(),
      themeMode: themeMode,
      routerConfig: AppRouter.router,
    );
  }
}
