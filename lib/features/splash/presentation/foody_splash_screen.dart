import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:reserva_canchas/core/dispositivo/dispositivo_service.dart';
import 'package:reserva_canchas/core/rutas/ruta_mesa_util.dart';
import 'package:reserva_canchas/core/sesion/sesion_staff_service.dart';
import 'package:reserva_canchas/core/rutas/redireccion_staff.dart';
import 'package:reserva_canchas/features/auth/data/auth_repository.dart';
import 'package:reserva_canchas/services/ciudad_preference_service.dart';
import 'package:reserva_canchas/services/mesa_sesion_service.dart';

/// Splash Foody — animación + carga en segundo plano (sesión staff, ciudad guardada).
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
  String _estado = 'Iniciando Foody...';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
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

    setState(() => _estado = 'Preparando dispositivo...');
    try {
      await DispositivoService.registrarEnBackend();
    } catch (_) {}

    setState(() => _estado = 'Verificando sesión...');
    final sesion = await SesionStaffService.cargar();

    if (!mounted) return;
    if (sesion != null) {
      try {
        await AuthRepository().sincronizarPermisos();
      } catch (_) {}
      if (!mounted) return;
      irDashboardStaff(context, sesion.dashboard);
      return;
    }

    setState(() => _estado = 'Preparando experiencia...');
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    final mesaSesion = await MesaSesionService.obtener();
    if (mesaSesion != null && mounted) {
      context.go(mesaSesion.rutaMenu);
      return;
    }

    final tieneCiudad = await CiudadPreferenceService.hasSelectedCiudad();
    if (tieneCiudad) {
      final ciudad = await CiudadPreferenceService.getSelectedCiudad();
      if (ciudad != null && mounted) {
        final slug = ciudad.codigo.isNotEmpty ? ciudad.codigo : 'valledupar';
        context.go(
          '/ciudades/$slug/restaurantes'
          '?nombre=${Uri.encodeComponent(ciudad.nombre)}',
        );
        return;
      }
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
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/fondo2.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.35),
                  Colors.black.withValues(alpha: 0.55),
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
                  Image.asset(
                    'assets/tucanchafacil.png',
                    width: 120,
                    height: 120,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.restaurant,
                      size: 96,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Foody',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _estado,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 14,
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
