import 'package:flutter/material.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
import 'package:reserva_canchas/core/saas_ui/saas_tokens.dart';

/// Design tokens compartidos (AQ-DUP-09: viven en `core/tema`, no en feature analitica).
/// Light estáticos (compat charts) + theme-aware via [of].
class AnaliticaTokens {
  AnaliticaTokens._();

  // Light defaults (charts / código legacy sin context).
  static const Color canvas = Color(0xFFF7F8FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF3F4F6);
  static const Color ink = Color(0xFF111827);
  static const Color inkMuted = Color(0xFF6B7280);
  static const Color inkSoft = Color(0xFF9CA3AF);
  static const Color border = Color(0xFFE5E7EB);
  static const Color borderSoft = Color(0xFFEEF0F3);

  static const Color ventas = ColoresFoody.primario;
  static const Color pedidos = Color(0xFF2563EB);
  static const Color inventario = Color(0xFF16A34A);
  static const Color alertas = Color(0xFFDC2626);
  static const Color clientes = Color(0xFF7C3AED);
  static const Color ticket = clientes;
  static const Color margen = inventario;
  static const Color cancelacion = alertas;
  static const Color cocina = pedidos;
  static const Color domicilio = pedidos;
  static const Color pago = inkMuted;
  static const Color insight = inkMuted;
  static const Color chart = Color(0xFF374151);
  static const Color chartMuted = Color(0xFF9CA3AF);

  static const double r8 = SaaSTokens.r8;
  static const double r10 = SaaSTokens.r10;
  static const double r12 = SaaSTokens.r12;
  static const double r16 = SaaSTokens.r16;
  static const double r20 = SaaSTokens.r16;
  static const double s4 = SaaSTokens.s4;
  static const double s8 = SaaSTokens.s8;
  static const double s12 = SaaSTokens.s12;
  static const double s16 = SaaSTokens.s16;
  static const double s20 = SaaSTokens.s20;
  static const double s24 = SaaSTokens.s24;

  static List<BoxShadow> shadowSoft = [
    BoxShadow(
      color: const Color(0xFF111827).withValues(alpha: 0.04),
      blurRadius: 8,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> shadowLift = [
    BoxShadow(
      color: const Color(0xFF111827).withValues(alpha: 0.06),
      blurRadius: 12,
      offset: const Offset(0, 3),
    ),
  ];

  static LinearGradient wash(Color color) => SaaSTokens.wash(color);

  static const LinearGradient heroWash = LinearGradient(
    colors: [surface, surface],
  );

  /// Preferir en UI nueva (dark/light).
  static Color canvasOf(BuildContext c) => SaaSTokens.canvas(c);
  static Color surfaceOf(BuildContext c) => SaaSTokens.surface(c);
  static Color inkOf(BuildContext c) => SaaSTokens.ink(c);
  static Color inkMutedOf(BuildContext c) => SaaSTokens.inkMuted(c);
  static Color borderOf(BuildContext c) => SaaSTokens.border(c);
  static Color chartOf(BuildContext c) => SaaSTokens.chart(c);
}
