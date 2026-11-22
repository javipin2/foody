import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';

class TemaFoody {
  TemaFoody._();

  /// Compat: alias de [claro].
  static ThemeData tema() => claro();

  static ThemeData claro() => _construir(
        brightness: Brightness.light,
        scheme: ColorScheme.fromSeed(
          seedColor: ColoresFoody.primario,
          brightness: Brightness.light,
          primary: ColoresFoody.primario,
          secondary: ColoresFoody.secundario,
          error: ColoresFoody.error,
          surface: const Color(0xFFFFFFFF),
        ),
        scaffold: const Color(0xFFF7F8FA),
        card: const Color(0xFFFFFFFF),
        border: const Color(0xFFE5E7EB),
        ink: const Color(0xFF111827),
        inkMuted: const Color(0xFF6B7280),
        inputFill: Colors.white,
        appBarBg: ColoresFoody.primario,
        appBarFg: Colors.white,
      );

  static ThemeData oscuro() => _construir(
        brightness: Brightness.dark,
        scheme: ColorScheme.fromSeed(
          seedColor: ColoresFoody.primario,
          brightness: Brightness.dark,
          primary: ColoresFoody.primario,
          secondary: ColoresFoody.secundario,
          error: const Color(0xFFF87171),
          surface: const Color(0xFF16181D),
        ),
        scaffold: const Color(0xFF0B0C0F),
        card: const Color(0xFF16181D),
        border: const Color(0xFF2A2E36),
        ink: const Color(0xFFF3F4F6),
        inkMuted: const Color(0xFF9CA3AF),
        inputFill: const Color(0xFF1C1F26),
        appBarBg: const Color(0xFF16181D),
        appBarFg: const Color(0xFFF3F4F6),
      );

  static ThemeData _construir({
    required Brightness brightness,
    required ColorScheme scheme,
    required Color scaffold,
    required Color card,
    required Color border,
    required Color ink,
    required Color inkMuted,
    required Color inputFill,
    required Color appBarBg,
    required Color appBarFg,
  }) {
    const radius = BorderRadius.all(Radius.circular(12));
    final isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      textTheme: TextTheme(
        bodyMedium: GoogleFonts.inter(color: ink),
        bodySmall: GoogleFonts.inter(color: inkMuted, fontSize: 13),
        titleLarge: GoogleFonts.poppins(
          color: ink,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: GoogleFonts.poppins(
          color: ink,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
        headlineSmall: GoogleFonts.poppins(
          color: ink,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
        labelLarge: GoogleFonts.inter(
          color: ink,
          fontWeight: FontWeight.w600,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: appBarBg,
        foregroundColor: appBarFg,
        elevation: 0,
        scrolledUnderElevation: isDark ? 0 : 1,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: appBarFg,
        ),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: border),
        ),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ColoresFoody.primario,
          foregroundColor: Colors.white,
          minimumSize: const Size(64, 44),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ColoresFoody.primario,
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(borderRadius: radius),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        border: OutlineInputBorder(borderRadius: radius),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: ColoresFoody.primario, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? const Color(0xFF1C1F26) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide(color: border),
        labelStyle: GoogleFonts.inter(color: ink, fontSize: 12),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: ColoresFoody.primario,
        unselectedLabelColor: inkMuted,
        indicatorColor: ColoresFoody.primario,
        labelStyle:
            GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: card,
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: card,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: border),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2E36) : const Color(0xFF111827),
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: GoogleFonts.inter(color: Colors.white, fontSize: 12),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1),
      iconTheme: IconThemeData(color: inkMuted),
    );
  }
}
