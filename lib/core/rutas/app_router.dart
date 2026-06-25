import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:go_router/go_router.dart';
import 'package:reserva_canchas/features/admin/presentation/panel_cajero_screen.dart';
import 'package:reserva_canchas/features/admin/presentation/panel_mesero_screen.dart';
import 'package:reserva_canchas/features/admin/presentation/panel_foody_control_screen.dart';
import 'package:reserva_canchas/features/admin/presentation/panel_restaurante_screen.dart';
import 'package:reserva_canchas/features/domiciliarios/presentation/dashboard_domiciliario_screen.dart';
import 'package:reserva_canchas/features/domiciliarios/presentation/domiciliario_registro_screen.dart';
import 'package:reserva_canchas/features/domiciliarios/presentation/domiciliario_independiente_login_screen.dart';
import 'package:reserva_canchas/features/domiciliarios/presentation/dashboard_domiciliario_independiente_screen.dart';
import 'package:reserva_canchas/features/auth/presentation/staff_login_screen.dart';
import 'package:reserva_canchas/features/auth/presentation/restaurante_registro_screen.dart';
import 'package:reserva_canchas/features/ciudades/presentation/ciudades_screen_foody.dart';
import 'package:reserva_canchas/features/cocinas/presentation/kds_screen.dart';
import 'package:reserva_canchas/features/mesa/presentation/mesa_qr_entrada_screen.dart';
import 'package:reserva_canchas/features/menu/presentation/menu_screen_foody.dart';
import 'package:reserva_canchas/features/pedidos/presentation/carrito_screen.dart';
import 'package:reserva_canchas/features/pedidos/presentation/checkout_screen.dart';
import 'package:reserva_canchas/features/pedidos/presentation/mis_pedidos_screen.dart';
import 'package:reserva_canchas/features/pedidos/presentation/seguimiento_pedido_screen.dart';
import 'package:reserva_canchas/features/restaurantes/presentation/restaurantes_screen_foody.dart';
import 'package:reserva_canchas/features/restaurantes/presentation/sucursales_screen_foody.dart';
import 'package:reserva_canchas/features/splash/presentation/foody_splash_screen.dart';
import 'package:reserva_canchas/core/config/app_flavor.dart';
import 'package:reserva_canchas/core/rutas/ruta_mesa_util.dart';
import 'package:reserva_canchas/main.dart' show appNavigatorKey;
import 'package:reserva_canchas/services/mesa_sesion_service.dart';

class AppRouter {
  static String _ubicacionInicial() {
    if (kIsWeb) {
      final mesa = RutaMesaUtil.entradaDesdeNavegador();
      if (mesa != null) return mesa;
    }
    return AppFlavor.actual.rutaInicial;
  }

  static final GoRouter router = GoRouter(
    navigatorKey: appNavigatorKey,
    initialLocation: _ubicacionInicial(),
    redirect: (context, state) async {
      final path = state.uri.path;

      final bloqueoFlavor = AppFlavor.actual.redirigirSiRutaProhibida(path);
      if (bloqueoFlavor != null) return bloqueoFlavor;

      // Deep link QR: /mesa/{token}/cliente u otra basura → /mesa/{token}
      final mesaLimpia = RutaMesaUtil.normalizar(path);
      if (mesaLimpia != null && path != mesaLimpia) {
        return mesaLimpia;
      }

      // Entrada mesa: no redirigir a ciudad/menú viejo; lo resuelve MesaQrEntradaScreen.
      if (RutaMesaUtil.esEntradaMesa(path)) {
        return null;
      }

      final sesion = await MesaSesionService.obtener();
      if (sesion == null) return null;

      final ubicacion = state.matchedLocation;
      if (MesaSesionService.rutaPermitidaConMesa(ubicacion, sesion)) {
        return null;
      }

      // Bloquear selector ciudad/restaurante/sucursal mientras hay mesa QR activa.
      if (ubicacion == '/cliente' ||
          ubicacion.startsWith('/ciudades/') ||
          ubicacion.startsWith('/restaurantes/') ||
          ubicacion.startsWith('/menu/') ||
          ubicacion.startsWith('/carrito/') ||
          ubicacion.startsWith('/checkout/')) {
        return sesion.rutaMenu;
      }

      return null;
    },
    errorBuilder: (context, state) {
      final mesaRuta = RutaMesaUtil.normalizar(state.uri.path);
      if (mesaRuta != null) {
        final token = RutaMesaUtil.tokenDesdePath(state.uri.path)!;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) context.go(mesaRuta);
        });
        return MesaQrEntradaScreen(qrToken: token);
      }
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Ruta no encontrada: ${state.uri.path}',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const FoodySplashScreen(),
      ),
      GoRoute(
        path: '/cliente/mis-pedidos',
        builder: (context, state) => const MisPedidosScreen(),
      ),
      GoRoute(
        path: '/cliente',
        builder: (context, state) => const CiudadesScreenFoody(),
      ),
      GoRoute(
        path: '/admin/login',
        builder: (context, state) => const StaffLoginScreen(),
      ),
      GoRoute(
        path: '/admin/registro',
        builder: (context, state) {
          final extra = state.extra;
          Map<String, dynamic>? datos;
          if (extra is Map<String, dynamic>) {
            datos = extra;
          }
          return RestauranteRegistroScreen(
            emailPrecargado: datos?['email'] as String?,
            nombrePrecargado: datos?['nombre'] as String?,
            supabaseAccessToken: datos?['access_token'] as String?,
          );
        },
      ),
      GoRoute(
        path: '/admin/panel',
        builder: (context, state) {
          final seccion = state.uri.queryParameters['seccion'];
          final pagoId = state.uri.queryParameters['pago_id'];
          return PanelRestauranteScreen(
            seccionInicial: seccion,
            pagoIdInicial: pagoId,
          );
        },
      ),
      GoRoute(
        path: '/admin/mejorar-plan',
        redirect: (_, __) => '/admin/panel?seccion=mejorar_plan',
      ),
      GoRoute(
        path: '/admin/cajero',
        builder: (context, state) => const PanelCajeroScreen(),
      ),
      GoRoute(
        path: '/admin/mesero',
        builder: (context, state) => const PanelMeseroScreen(),
      ),
      GoRoute(
        path: '/admin/foody-control',
        builder: (context, state) => const PanelFoodyControlScreen(),
      ),
      GoRoute(
        path: '/admin/domiciliario',
        builder: (context, state) => const DashboardDomiciliarioScreen(),
      ),
      GoRoute(
        path: '/admin/cocina',
        builder: (context, state) => const KdsScreen(standalone: true),
      ),
      GoRoute(
        path: '/domiciliario/login',
        builder: (context, state) => const DomiciliarioIndependienteLoginScreen(),
      ),
      GoRoute(
        path: '/domiciliario/registro',
        builder: (context, state) => const DomiciliarioRegistroScreen(),
      ),
      GoRoute(
        path: '/domiciliario/espera',
        builder: (context, state) => const DomiciliarioEsperaScreen(),
      ),
      GoRoute(
        path: '/domiciliario/independiente',
        builder: (context, state) =>
            const DashboardDomiciliarioIndependienteScreen(),
      ),
      GoRoute(
        path: '/ciudades/:slug/restaurantes',
        builder: (context, state) {
          final slug = state.pathParameters['slug']!;
          final nombre = state.uri.queryParameters['nombre'] ?? slug;
          return RestaurantesScreenFoody(ciudadSlug: slug, ciudadNombre: nombre);
        },
      ),
      GoRoute(
        path: '/restaurantes/:id/sucursales',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final nombre =
              state.uri.queryParameters['nombre'] ?? 'Restaurante';
          return SucursalesScreenFoody(
            restauranteId: id,
            restauranteNombre: nombre,
          );
        },
      ),
      GoRoute(
        path: '/mesa/:qrToken',
        builder: (context, state) {
          final qrToken = state.pathParameters['qrToken']!;
          return MesaQrEntradaScreen(qrToken: qrToken);
        },
      ),
      GoRoute(
        path: '/menu/:sucursalId',
        builder: (context, state) {
          final sucursalId = state.pathParameters['sucursalId']!;
          final nombre = state.uri.queryParameters['nombre'] ?? 'Menú';
          final mesaId = state.uri.queryParameters['mesa_id'];
          final mesaNombre = state.uri.queryParameters['mesa_nombre'];
          return MenuScreenFoody(
            sucursalId: sucursalId,
            sucursalNombre: nombre,
            mesaId: mesaId,
            mesaNombre: mesaNombre,
          );
        },
      ),
      GoRoute(
        path: '/carrito/:sucursalId',
        builder: (context, state) {
          final sucursalId = state.pathParameters['sucursalId']!;
          final nombre = state.uri.queryParameters['sucursalNombre'] ?? 'Menú';
          return CarritoScreen(
            sucursalId: sucursalId,
            sucursalNombre: nombre,
            mesaId: state.uri.queryParameters['mesa_id'],
            mesaNombre: state.uri.queryParameters['mesa_nombre'],
          );
        },
      ),
      GoRoute(
        path: '/checkout/:sucursalId',
        builder: (context, state) {
          final sucursalId = state.pathParameters['sucursalId']!;
          final nombre = state.uri.queryParameters['sucursalNombre'] ?? 'Menú';
          return CheckoutScreen(
            sucursalId: sucursalId,
            sucursalNombre: nombre,
            mesaId: state.uri.queryParameters['mesa_id'],
            mesaNombre: state.uri.queryParameters['mesa_nombre'],
          );
        },
      ),
      GoRoute(
        path: '/pedidos/:pedidoId/seguimiento',
        builder: (context, state) {
          final pedidoId = state.pathParameters['pedidoId']!;
          return SeguimientoPedidoScreen(pedidoId: pedidoId);
        },
      ),
    ],
  );
}
