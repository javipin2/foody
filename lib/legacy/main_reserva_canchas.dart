// Bootstrap anterior (Tu Cancha Facil) — retirado en P3-03.
// La app Foody arranca desde lib/main.dart:
//   flutter run
//
// Este archivo queda como ancla historica; ya no compila el flujo de reservas.

import 'package:flutter/material.dart';

void main() {
  runApp(
    const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Legacy Tu Cancha Facil removido (P3-03).\n\n'
              'Usa el entry point Foody:\n'
              '  flutter run\n'
              '  (lib/main.dart)',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    ),
  );
}
