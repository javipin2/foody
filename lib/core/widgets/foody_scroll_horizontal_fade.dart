import 'package:flutter/material.dart';

/// Fade al borde derecho: hint visual de que la fila horizontal se puede deslizar.
class FoodyScrollHorizontalFade extends StatelessWidget {
  const FoodyScrollHorizontalFade({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) => const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [Colors.white, Colors.white, Colors.transparent],
        stops: [0.0, 0.86, 1.0],
      ).createShader(rect),
      child: child,
    );
  }
}
