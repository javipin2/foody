import 'package:flutter/material.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_tokens.dart';

/// Indicador de pasos checkout cliente: 1 Carrito · 2 Confirmar · 3 Seguimiento.
class FoodyPasosPedido extends StatelessWidget {
  const FoodyPasosPedido({super.key, required this.pasoActual});

  /// 1 = carrito, 2 = checkout, 3 = confirmado/seguimiento
  final int pasoActual;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          _Paso(
            numero: 1,
            etiqueta: 'Carrito',
            activo: pasoActual >= 1,
            actual: pasoActual == 1,
          ),
          _Conector(activo: pasoActual >= 2),
          _Paso(
            numero: 2,
            etiqueta: 'Confirmar',
            activo: pasoActual >= 2,
            actual: pasoActual == 2,
          ),
          _Conector(activo: pasoActual >= 3),
          _Paso(
            numero: 3,
            etiqueta: 'Listo',
            activo: pasoActual >= 3,
            actual: pasoActual == 3,
          ),
        ],
      ),
    );
  }
}

class _Conector extends StatelessWidget {
  const _Conector({required this.activo});

  final bool activo;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          color: activo ? AnaliticaTokens.ink : AnaliticaTokens.border,
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}

class _Paso extends StatelessWidget {
  const _Paso({
    required this.numero,
    required this.etiqueta,
    required this.activo,
    required this.actual,
  });

  final int numero;
  final String etiqueta;
  final bool activo;
  final bool actual;

  @override
  Widget build(BuildContext context) {
    final Color fondo;
    final Color texto;
    if (actual) {
      fondo = AnaliticaTokens.ink;
      texto = Colors.white;
    } else if (activo) {
      fondo = AnaliticaTokens.surfaceMuted;
      texto = AnaliticaTokens.ink;
    } else {
      fondo = AnaliticaTokens.borderSoft;
      texto = AnaliticaTokens.inkSoft;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: fondo,
            border: Border.all(
              color: actual || activo
                  ? AnaliticaTokens.ink
                  : AnaliticaTokens.border,
              width: 1.2,
            ),
          ),
          child: Text(
            '$numero',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: texto,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          etiqueta,
          style: TextStyle(
            fontSize: 11,
            fontWeight: actual ? FontWeight.w700 : FontWeight.w500,
            color: actual || activo
                ? AnaliticaTokens.ink
                : AnaliticaTokens.inkMuted,
          ),
        ),
      ],
    );
  }
}
