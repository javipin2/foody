import 'package:flutter/material.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_tokens.dart';

/// Diálogos Foody — superficie blanca, tipografía densa, CTA ink (sin naranja Material).
class FoodyDialogo {
  FoodyDialogo._();

  static ThemeData tema(BuildContext context) {
    final base = Theme.of(context);
    return base.copyWith(
      dialogTheme: DialogThemeData(
        backgroundColor: AnaliticaTokens.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: const Color(0xFF111827).withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AnaliticaTokens.border),
        ),
        titleTextStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          color: AnaliticaTokens.ink,
        ),
        contentTextStyle: const TextStyle(
          fontSize: 13.5,
          height: 1.35,
          color: AnaliticaTokens.inkMuted,
        ),
      ),
      colorScheme: base.colorScheme.copyWith(
        primary: AnaliticaTokens.ink,
        onPrimary: Colors.white,
        secondary: AnaliticaTokens.ink,
        onSecondary: Colors.white,
        surface: AnaliticaTokens.surface,
        onSurface: AnaliticaTokens.ink,
        error: AnaliticaTokens.alertas,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AnaliticaTokens.ink,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AnaliticaTokens.border,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AnaliticaTokens.inkMuted,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AnaliticaTokens.ink,
          side: const BorderSide(color: AnaliticaTokens.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AnaliticaTokens.surfaceMuted,
        labelStyle: const TextStyle(
          color: AnaliticaTokens.inkMuted,
          fontSize: 13,
        ),
        hintStyle: const TextStyle(
          color: AnaliticaTokens.inkSoft,
          fontSize: 13,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AnaliticaTokens.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AnaliticaTokens.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AnaliticaTokens.ink, width: 1.2),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        selectedColor: AnaliticaTokens.ink,
        backgroundColor: AnaliticaTokens.surfaceMuted,
        side: const BorderSide(color: AnaliticaTokens.border),
        labelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AnaliticaTokens.inkMuted,
        ),
        secondaryLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        checkmarkColor: Colors.white,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((s) {
            if (s.contains(WidgetState.selected)) return Colors.white;
            return AnaliticaTokens.inkMuted;
          }),
          backgroundColor: WidgetStateProperty.resolveWith((s) {
            if (s.contains(WidgetState.selected)) return AnaliticaTokens.ink;
            return AnaliticaTokens.surfaceMuted;
          }),
          side: const WidgetStatePropertyAll(
            BorderSide(color: AnaliticaTokens.border),
          ),
        ),
      ),
    );
  }

  static Future<T?> mostrar<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool barrierDismissible = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierColor: const Color(0xFF111827).withValues(alpha: 0.45),
      builder: (ctx) => Theme(
        data: tema(ctx),
        child: builder(ctx),
      ),
    );
  }
}
