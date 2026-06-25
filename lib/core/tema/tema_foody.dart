import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';

class TemaFoody {
  TemaFoody._();

  static ThemeData tema() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: ColoresFoody.primario,
        primary: ColoresFoody.primario,
        secondary: ColoresFoody.secundario,
      ),
      scaffoldBackgroundColor: ColoresFoody.fondo,
      textTheme: TextTheme(
        bodyMedium: GoogleFonts.inter(color: ColoresFoody.texto),
        titleLarge: GoogleFonts.poppins(
          color: ColoresFoody.texto,
          fontWeight: FontWeight.w600,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: ColoresFoody.primario,
        foregroundColor: Colors.white,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}
