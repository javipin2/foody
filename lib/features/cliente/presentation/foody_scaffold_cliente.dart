import 'package:flutter/material.dart';
import 'package:reserva_canchas/features/cliente/presentation/cliente_navegacion_inferior.dart';

/// Scaffold unificado cliente (DS-02): AppBar + body + nav inferior opcional.
class FoodyScaffoldCliente extends StatelessWidget {
  const FoodyScaffoldCliente({
    super.key,
    this.appBar,
    required this.body,
    this.floatingActionButton,
    this.bottomBar,
    this.mostrarNavInferior = true,
    this.extendBody = false,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;
  /// Barra inferior custom (p. ej. botón confirmar carrito). Tiene prioridad sobre nav.
  final Widget? bottomBar;
  final bool mostrarNavInferior;
  final bool extendBody;

  @override
  Widget build(BuildContext context) {
    Widget? inferior;
    if (bottomBar != null) {
      inferior = bottomBar;
    } else if (mostrarNavInferior) {
      inferior = const ClienteNavegacionInferior();
    }

    return Scaffold(
      appBar: appBar,
      body: body,
      extendBody: extendBody,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: inferior,
    );
  }
}
