import 'package:flutter/material.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_tokens.dart';

/// Encabezado de sección — tipografía, sin cajas de color.
class AnaliticaSectionHeader extends StatelessWidget {
  const AnaliticaSectionHeader({
    super.key,
    required this.titulo,
    this.subtitulo,
    this.icono,
    this.color,
    this.trailing,
  });

  final String titulo;
  final String? subtitulo;
  final IconData? icono;
  final Color? color;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icono != null) ...[
            Icon(icono, size: 16, color: AnaliticaTokens.inkSoft),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AnaliticaTokens.ink,
                    letterSpacing: -0.2,
                  ),
                ),
                if (subtitulo != null)
                  Text(
                    subtitulo!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AnaliticaTokens.inkSoft,
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
