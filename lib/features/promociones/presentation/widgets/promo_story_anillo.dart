import 'package:flutter/material.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_tokens.dart';

/// Anillo de estado (WhatsApp): anillo ink si no visto, gris si ya visto.
class PromoStoryAnillo extends StatelessWidget {
  const PromoStoryAnillo({
    super.key,
    this.imagenUrl,
    required this.etiqueta,
    required this.onTap,
    this.tamano = 64,
    this.visto = false,
  });

  final String? imagenUrl;
  final String etiqueta;
  final VoidCallback onTap;
  final double tamano;
  final bool visto;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: tamano + 8,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: tamano,
              height: tamano,
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: visto
                    ? null
                    : const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AnaliticaTokens.ink,
                          AnaliticaTokens.inkMuted,
                        ],
                      ),
                color: visto ? const Color(0xFFB0B8C1) : null,
              ),
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AnaliticaTokens.surface,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(2.5),
                  child: ClipOval(
                    child: imagenUrl != null && imagenUrl!.isNotEmpty
                        ? Image.network(
                            imagenUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _placeholder(),
                          )
                        : _placeholder(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              etiqueta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                height: 1.1,
                color: visto ? AnaliticaTokens.inkSoft : AnaliticaTokens.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return const ColoredBox(
      color: AnaliticaTokens.surfaceMuted,
      child: Icon(
        Icons.local_offer_rounded,
        color: AnaliticaTokens.ink,
        size: 28,
      ),
    );
  }
}
