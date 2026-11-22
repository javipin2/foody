import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:reserva_canchas/core/config/app_flavor.dart';
import 'package:reserva_canchas/core/dispositivo/dispositivo_service.dart';
import 'package:reserva_canchas/core/red/manejo_error_sesion.dart';
import 'package:reserva_canchas/core/rutas/ruta_mesa_util.dart';
import 'package:reserva_canchas/core/sesion/sesion_staff_service.dart';
import 'package:reserva_canchas/core/realtime/foody_realtime.dart';
import 'package:reserva_canchas/core/rutas/redireccion_staff.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_tokens.dart';
import 'package:reserva_canchas/features/auth/data/auth_repository.dart';
import 'package:reserva_canchas/services/ciudad_preference_service.dart';
import 'package:reserva_canchas/services/mesa_sesion_service.dart';

/// Splash Foody — marca densa Analítica (sin gradiente arcoíris); carga en segundo plano.
class FoodySplashScreen extends StatefulWidget {
  const FoodySplashScreen({super.key});

  @override
  State<FoodySplashScreen> createState() => _FoodySplashScreenState();
}

class _FoodySplashScreenState extends State<FoodySplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  String _estado = 'Iniciando Foody…';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
      ),
    );
    _controller.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _inicializar());
  }

  Future<void> _inicializar() async {
    // QR mesa en la barra del navegador: ir directo (splash no debe mandar a ciudades).
    final pathEntrada =
        kIsWeb ? Uri.base.path : GoRouterState.of(context).uri.path;
    final mesaRuta = RutaMesaUtil.normalizar(pathEntrada);
    if (mesaRuta != null && mounted) {
      context.go(mesaRuta);
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    setState(() => _estado = 'Preparando dispositivo…');
    try {
      await DispositivoService.registrarEnBackend()
          .timeout(const Duration(seconds: 8));
    } catch (_) {}

    // ponytail: en flavor cliente ignorar JWT staff (mismo origen web que equipo → bucle /splash)
    if (AppFlavor.actual.esEquipo) {
      setState(() => _estado = 'Verificando sesión…');
      final sesion = await SesionStaffService.cargar();
      if (!mounted) return;
      if (sesion != null) {
        FoodyRealtime.aplicarCanalesStaff(sesion.realtimeCanales);
        try {
          await AuthRepository()
              .sincronizarPermisos()
              .timeout(const Duration(seconds: 8));
        } catch (e) {
          // 401 → login; timeout/offline → no entrar al panel (INFRA-EXT-DOWN-02).
          if (await ManejoErrorSesion.manejarEnPantalla(e)) return;
          if (!mounted) return;
          setState(() => _estado = 'Sin conexión al servidor…');
          final accion = await showDialog<String>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: const Text('Servidor no disponible'),
              content: const Text(
                'No se pudo contactar la API de Foody. '
                'Comprueba que Docker y el backend estén en marcha.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, 'login'),
                  child: const Text('Ir a login'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, 'retry'),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          );
          if (!mounted) return;
          if (accion == 'retry') {
            await _inicializar();
            return;
          }
          if (mounted) context.go('/admin/login');
          return;
        }
        if (!mounted) return;
        irDashboardStaff(context, sesion.dashboard);
        return;
      }
    }

    setState(() => _estado = 'Preparando experiencia…');
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    final mesaSesion = await MesaSesionService.obtener();
    if (mesaSesion != null && mounted) {
      context.go(mesaSesion.rutaMenu);
      return;
    }

    if (AppFlavor.actual.esEquipo) {
      if (mounted) context.go('/admin/login');
      return;
    }

    final tieneCiudad = await CiudadPreferenceService.hasSelectedCiudad();
    if (tieneCiudad && mounted) {
      context.go(await CiudadPreferenceService.rutaHomeCliente());
      return;
    }

    if (mounted) context.go('/cliente');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AnaliticaTokens.canvas,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Ambiente monocromo (no naranja+teal).
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AnaliticaTokens.surface,
                  AnaliticaTokens.canvas,
                  AnaliticaTokens.surfaceMuted.withValues(alpha: 0.95),
                ],
              ),
            ),
          ),
          Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Opacity(
                  opacity: _opacityAnimation.value,
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: child,
                  ),
                );
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    padding: const EdgeInsets.all(14),
                    child: Image.asset(
                      'assets/foody.png',
                      width: 130,
                      height: 130,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.restaurant_rounded,
                        size: 48,
                        color: AnaliticaTokens.ink,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Foody',
                    style: TextStyle(
                      color: AnaliticaTokens.ink,
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Pedidos para tu restaurante',
                    style: TextStyle(
                      color: AnaliticaTokens.inkMuted,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 40),
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: AnaliticaTokens.ink,
                      strokeWidth: 2.2,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _estado,
                    style: const TextStyle(
                      color: AnaliticaTokens.inkSoft,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
