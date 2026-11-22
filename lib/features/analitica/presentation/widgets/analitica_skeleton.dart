import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_tokens.dart';

/// Skeletons premium del Centro de Análisis.
class AnaliticaSkeleton {
  AnaliticaSkeleton._();

  static Widget resumen() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        _bloque(altura: 120, radio: AnaliticaTokens.r20),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, c) {
            final cols = c.maxWidth >= 1100
                ? 4
                : c.maxWidth >= 720
                    ? 3
                    : 2;
            return GridView.count(
              crossAxisCount: cols,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 1.45,
              children: List.generate(6, (_) => _bloque(radio: AnaliticaTokens.r20)),
            );
          },
        ),
        const SizedBox(height: 20),
        _bloque(altura: 72, radio: AnaliticaTokens.r16),
        const SizedBox(height: 16),
        _bloque(altura: 220, radio: AnaliticaTokens.r20),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _bloque(altura: 220, radio: AnaliticaTokens.r20)),
            const SizedBox(width: 14),
            Expanded(child: _bloque(altura: 220, radio: AnaliticaTokens.r20)),
          ],
        ),
        const SizedBox(height: 16),
        _bloque(altura: 280, radio: AnaliticaTokens.r20),
      ],
    );
  }

  static Widget tab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _bloque(altura: 64, radio: AnaliticaTokens.r16),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _bloque(altura: 100, radio: AnaliticaTokens.r16)),
            const SizedBox(width: 12),
            Expanded(child: _bloque(altura: 100, radio: AnaliticaTokens.r16)),
          ],
        ),
        const SizedBox(height: 16),
        _bloque(altura: 240, radio: AnaliticaTokens.r20),
        const SizedBox(height: 12),
        _bloque(altura: 240, radio: AnaliticaTokens.r20),
      ],
    );
  }

  static Widget _bloque({double? altura, double radio = 12}) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE8EDF3),
      highlightColor: const Color(0xFFF7FAFC),
      child: Container(
        height: altura,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radio),
        ),
      ),
    );
  }
}
