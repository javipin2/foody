import 'package:flutter/material.dart';
import 'package:reserva_canchas/core/widgets/foody_estado_ui.dart';

/// Cuerpo async reutilizable staff/cliente (FL-12).
class FoodyAsyncBody<T> extends StatelessWidget {
  const FoodyAsyncBody({
    super.key,
    required this.cargando,
    this.error,
    required this.datos,
    required this.builder,
    this.mensajeCarga,
    this.onReintentar,
    this.vacio,
  });

  final bool cargando;
  final String? error;
  final T? datos;
  final Widget Function(BuildContext context, T datos) builder;
  final String? mensajeCarga;
  final VoidCallback? onReintentar;
  final Widget? vacio;

  @override
  Widget build(BuildContext context) {
    if (cargando) {
      return FoodyEstadoUi.cargando(mensaje: mensajeCarga);
    }
    if (error != null) {
      return FoodyEstadoUi.desdeMensaje(
        mensaje: error!,
        onReintentar: onReintentar,
      );
    }
    final d = datos;
    if (d == null) {
      return vacio ?? FoodyEstadoUi.vacio(titulo: 'Sin datos');
    }
    return builder(context, d);
  }
}
