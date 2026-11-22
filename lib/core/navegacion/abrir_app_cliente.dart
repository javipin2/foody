import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:reserva_canchas/core/config/app_flavor.dart';
import 'package:reserva_canchas/core/constantes/configuracion.dart';
import 'package:reserva_canchas/services/ciudad_preference_service.dart';
import 'package:url_launcher/url_launcher.dart';

/// Abre el flujo cliente: navegación interna (flavor cliente) o URL externa (flavor equipo).
class AbrirAppCliente {
  AbrirAppCliente._();

  static Future<void> ejecutar(BuildContext context) async {
    if (AppFlavor.actual.esCliente) {
      final ruta = await CiudadPreferenceService.rutaHomeCliente();
      if (context.mounted) context.go(ruta);
      return;
    }
    final uri = Uri.parse(Configuracion.urlAppCliente);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Abre la app Foody Cliente: ${Configuracion.urlAppCliente}',
          ),
        ),
      );
    }
  }
}
