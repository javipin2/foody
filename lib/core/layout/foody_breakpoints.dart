import 'package:flutter/widgets.dart';

/// Breakpoints unificados Foody (RS-20 / FRONTEND_RESPONSIVE_STRATEGY).
///
/// ponytail: un solo archivo, sin paquete responsive externo.
class FoodyBreakpoints {
  FoodyBreakpoints._();

  /// Móvil portrait.
  static const compact = 600.0;

  /// Tablet / phablet landscape — alinea shell cajero/mesero y panel admin.
  static const expanded = 720.0;

  /// Desktop / tablet landscape ancha (sidebar completa).
  static const large = 1100.0;

  /// Monitor ancho.
  static const extraLarge = 1440.0;

  static const maxContentCliente = 1200.0;
  static const maxContentAdmin = 1280.0;

  /// Ancho de ventana / MediaQuery.
  static double widthOf(BuildContext context) =>
      MediaQuery.sizeOf(context).width;

  static bool esCompact(double ancho) => ancho < expanded;

  /// Nav superior (cajero/mesero), split POS/caja, tabs top.
  static bool esExpanded(double ancho) => ancho >= expanded;

  static bool esLarge(double ancho) => ancho >= large;

  /// Master-detail operación (POS, caja, costeo). Antes: 900 (RS-20).
  static bool splitOperacion(double ancho) => ancho >= expanded;

  /// Diálogos densos / SegmentedButton estrecho.
  static bool dialogoEstrecho(double ancho) => ancho < compact;
}
