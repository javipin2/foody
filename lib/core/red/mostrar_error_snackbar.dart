import 'package:flutter/material.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';

/// Muestra un SnackBar con el mensaje legible del API (validaciones de negocio).
void mostrarErrorSnackBar(
  BuildContext context,
  Object error, {
  String contexto = 'operación',
  Duration duracion = const Duration(seconds: 6),
}) {
  final texto = mensajeErrorHttp(error, contexto: contexto);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(texto),
      duration: duracion,
      behavior: SnackBarBehavior.floating,
      width: MediaQuery.sizeOf(context).width > 600 ? 520 : null,
    ),
  );
}
