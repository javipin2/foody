import 'package:flutter/material.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_tokens.dart';

/// Superficie blanca minimal — sin fondos tintados.
class AnaliticaSurface extends StatefulWidget {
  const AnaliticaSurface({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.gradient,
    this.accent,
    this.elevated = false,
    this.glass = false,
    this.borderRadius,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Gradient? gradient;
  final Color? accent;
  final bool elevated;
  final bool glass;
  final BorderRadius? borderRadius;

  @override
  State<AnaliticaSurface> createState() => _AnaliticaSurfaceState();
}

class _AnaliticaSurfaceState extends State<AnaliticaSurface> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final radius =
        widget.borderRadius ?? BorderRadius.circular(AnaliticaTokens.r12);
    final lift = widget.elevated || _hover;

    // ponytail: accent/gradient params se ignoran para fondos; solo borde neutro.
    final body = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      padding: widget.padding ?? const EdgeInsets.all(AnaliticaTokens.s12),
      decoration: BoxDecoration(
        color: AnaliticaTokens.surfaceOf(context),
        borderRadius: radius,
        border: Border.all(color: AnaliticaTokens.borderOf(context)),
        boxShadow: lift
            ? AnaliticaTokens.shadowLiftOf(context)
            : AnaliticaTokens.shadowSoftOf(context),
      ),
      child: widget.child,
    );

    if (widget.onTap == null) return body;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: radius,
          hoverColor: AnaliticaTokens.surfaceMutedOf(context),
          child: body,
        ),
      ),
    );
  }
}
