import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:reserva_canchas/config/app_link_config.dart';
import 'package:reserva_canchas/features/auth/data/auth_repository.dart';
import 'package:reserva_canchas/features/pagos/domain/pagos_deep_link_service.dart';

/// Rutas post-login según `dashboard` del backend (`auth.service.resolverDashboard`).
/// Alineado con `INFRAESTRUCTURA/foody_flujo_completo_pantallas.html`.
void irDashboardStaff(BuildContext context, String dashboard) {
  switch (dashboard) {
    case 'foody_control':
      context.go('/admin/foody-control');
    case 'cajero':
      context.go('/admin/cajero');
    case 'mesero':
      context.go('/admin/mesero');
    case 'domiciliario':
      context.go('/admin/domiciliario');
    case 'domiciliario_independiente':
      context.go('/domiciliario/independiente');
    case 'cocina':
      context.go('/admin/cocina');
    default:
      final pagoId = PagosDeepLinkService.consumirPagoIdPendiente();
      context.go(AppLinkConfig.rutaPanelTrasPago(pagoId: pagoId));
  }
}

/// Cierra JWT + Supabase OAuth y vuelve al login staff (sin pasar por splash).
Future<void> cerrarSesionStaff(BuildContext context) async {
  await AuthRepository().logout();
  if (context.mounted) context.go('/admin/login');
}

/// Etiqueta legible del rol para cabeceras staff.
String etiquetaRolStaff(String? rol) {
  switch (rol) {
    case 'super_admin':
      return 'Super Admin';
    case 'admin':
      return 'Administrador';
    case 'gerente':
      return 'Gerente';
    case 'cajero':
      return 'Cajero / POS';
    case 'mesero':
      return 'Mesero';
    case 'domiciliario_planta':
      return 'Domiciliario planta';
    case 'cocina_principal':
    case 'cocina':
      return 'Cocina';
    default:
      if (rol != null && rol.startsWith('cocina_')) return 'Cocina';
      return rol ?? 'Staff';
  }
}
