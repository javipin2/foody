import 'package:flutter/material.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_tokens.dart';

/// Campos / shell visual compartido login + registro (sin lógica).
class AuthFormEstilo {
  AuthFormEstilo._();

  static InputDecoration campo({
    required String label,
    required Widget prefixIcon,
    Widget? suffixIcon,
    bool filledMuted = true,
  }) {
    OutlineInputBorder borde([Color c = AnaliticaTokens.border]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
          borderSide: BorderSide(color: c),
        );
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AnaliticaTokens.inkMuted, fontSize: 13),
      prefixIcon: IconTheme(
        data: const IconThemeData(color: AnaliticaTokens.inkSoft, size: 20),
        child: prefixIcon,
      ),
      suffixIcon: suffixIcon,
      isDense: true,
      filled: true,
      fillColor: filledMuted
          ? AnaliticaTokens.surfaceMuted
          : AnaliticaTokens.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: borde(),
      enabledBorder: borde(),
      focusedBorder: borde(AnaliticaTokens.ink),
      errorBorder: borde(AnaliticaTokens.alertas),
      focusedErrorBorder: borde(AnaliticaTokens.alertas),
      disabledBorder: borde(),
    );
  }
}
