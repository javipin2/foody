import 'package:flutter/material.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';

/// Tokens SaaS theme-aware (Insights / Finanzas / panel admin).
class SaaSTokens {
  SaaSTokens._();

  static bool esOscuro(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color canvas(BuildContext context) =>
      esOscuro(context) ? const Color(0xFF0B0C0F) : const Color(0xFFF7F8FA);

  static Color surface(BuildContext context) =>
      esOscuro(context) ? const Color(0xFF16181D) : const Color(0xFFFFFFFF);

  static Color surfaceMuted(BuildContext context) =>
      esOscuro(context) ? const Color(0xFF1C1F26) : const Color(0xFFF3F4F6);

  static Color ink(BuildContext context) =>
      esOscuro(context) ? const Color(0xFFF3F4F6) : const Color(0xFF111827);

  static Color inkMuted(BuildContext context) =>
      esOscuro(context) ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

  static Color inkSoft(BuildContext context) =>
      esOscuro(context) ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF);

  static Color border(BuildContext context) =>
      esOscuro(context) ? const Color(0xFF2A2E36) : const Color(0xFFE5E7EB);

  static Color borderSoft(BuildContext context) =>
      esOscuro(context) ? const Color(0xFF22262E) : const Color(0xFFEEF0F3);

  // Semántica (acentos contenidos).
  static const Color ventas = ColoresFoody.primario;
  static const Color pedidos = Color(0xFF2563EB);
  static const Color inventario = Color(0xFF16A34A);
  static const Color alertas = Color(0xFFDC2626);
  static const Color clientes = Color(0xFF7C3AED);
  static const Color positivo = Color(0xFF16A34A);
  static const Color negativo = Color(0xFFDC2626);
  static const Color prioridadAlta = Color(0xFFDC2626);
  static const Color prioridadMedia = Color(0xFFD97706);
  static const Color prioridadBaja = Color(0xFF6B7280);

  static Color chart(BuildContext context) =>
      esOscuro(context) ? const Color(0xFFD1D5DB) : const Color(0xFF374151);

  static Color chartMuted(BuildContext context) =>
      esOscuro(context) ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF);

  static const double r8 = 8;
  static const double r10 = 10;
  static const double r12 = 12;
  static const double r16 = 16;
  static const double radioPill = 20;

  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;

  // Motion used by shared admin controls; consumers honor reduced motion.
  static const Duration duracionControl = Duration(milliseconds: 140);
  static const Duration duracionTransicion = Duration(milliseconds: 180);

  static List<BoxShadow> shadowSoft(BuildContext context) => [
        BoxShadow(
          color: (esOscuro(context) ? Colors.black : const Color(0xFF111827))
              .withValues(alpha: esOscuro(context) ? 0.35 : 0.04),
          blurRadius: 8,
          offset: const Offset(0, 1),
        ),
      ];

  static List<BoxShadow> shadowLift(BuildContext context) => [
        BoxShadow(
          color: (esOscuro(context) ? Colors.black : const Color(0xFF111827))
              .withValues(alpha: esOscuro(context) ? 0.45 : 0.06),
          blurRadius: 12,
          offset: const Offset(0, 3),
        ),
      ];

  static LinearGradient wash(Color color) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          color.withValues(alpha: 0.04),
          Colors.transparent,
        ],
      );
}
