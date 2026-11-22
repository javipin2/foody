import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_tokens.dart';
import 'package:reserva_canchas/services/ciudad_preference_service.dart';
import 'package:reserva_canchas/services/mesa_sesion_service.dart';

/// Bottom nav cliente: Inicio (lugares) · Pedidos · QR. No en selector de ciudad.
class ClienteNavegacionInferior extends StatelessWidget {
  const ClienteNavegacionInferior({super.key});

  static bool rutaMuestraBar(String path) {
    // `/cliente` = elegir ciudad (sin barra).
    return path == '/cliente/mis-pedidos' ||
        path == '/cliente/escanear-qr' ||
        path.startsWith('/ciudades/') ||
        path.startsWith('/restaurantes/');
  }

  static int indiceDesdeRuta(String path) {
    if (path.startsWith('/cliente/mis-pedidos')) return 1;
    if (path.startsWith('/cliente/escanear-qr')) return 2;
    return 0;
  }

  Future<void> _irInicio(BuildContext context) async {
    final ruta = await CiudadPreferenceService.rutaHomeCliente();
    if (context.mounted) context.go(ruta);
  }

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    if (!rutaMuestraBar(path)) return const SizedBox.shrink();

    return FutureBuilder<bool>(
      future: MesaSesionService.tieneActiva(),
      builder: (context, snap) {
        if (snap.data == true) return const SizedBox.shrink();
        final idx = indiceDesdeRuta(path);
        return NavigationBar(
          backgroundColor: AnaliticaTokens.surface,
          surfaceTintColor: Colors.transparent,
          indicatorColor: AnaliticaTokens.ink.withValues(alpha: 0.1),
          selectedIndex: idx,
          onDestinationSelected: (i) {
            switch (i) {
              case 0:
                _irInicio(context);
              case 1:
                context.go('/cliente/mis-pedidos');
              case 2:
                context.go('/cliente/escanear-qr');
            }
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined, color: AnaliticaTokens.inkMuted),
              selectedIcon: Icon(Icons.home, color: AnaliticaTokens.ink),
              label: 'Inicio',
            ),
            NavigationDestination(
              icon: Icon(
                Icons.receipt_long_outlined,
                color: AnaliticaTokens.inkMuted,
              ),
              selectedIcon:
                  Icon(Icons.receipt_long, color: AnaliticaTokens.ink),
              label: 'Pedidos',
            ),
            NavigationDestination(
              icon: Icon(
                Icons.qr_code_scanner_outlined,
                color: AnaliticaTokens.inkMuted,
              ),
              selectedIcon:
                  Icon(Icons.qr_code_scanner, color: AnaliticaTokens.ink),
              label: 'QR mesa',
            ),
          ],
        );
      },
    );
  }
}
