import 'package:flutter/material.dart';
import 'package:reserva_canchas/core/saas_ui/saas_tokens.dart';

/// Superficie premium con hover lift sutil.
class SaaSSurface extends StatefulWidget {
  const SaaSSurface({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.height,
    this.borderRadius,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final double? height;
  final double? borderRadius;

  @override
  State<SaaSSurface> createState() => _SaaSSurfaceState();
}

class _SaaSSurfaceState extends State<SaaSSurface> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.borderRadius ?? SaaSTokens.r12;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedScale(
        scale: _hover && widget.onTap != null ? 1.01 : 1.0,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: widget.height,
          decoration: BoxDecoration(
            color: SaaSTokens.surface(context),
            borderRadius: BorderRadius.circular(r),
            border: Border.all(
              color: _hover
                  ? SaaSTokens.border(context)
                  : SaaSTokens.borderSoft(context),
            ),
            boxShadow: _hover
                ? SaaSTokens.shadowLift(context)
                : SaaSTokens.shadowSoft(context),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(r),
              child: Padding(
                padding: widget.padding ??
                    const EdgeInsets.all(SaaSTokens.s16),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SaaSSectionHeader extends StatelessWidget {
  const SaaSSectionHeader({
    super.key,
    required this.titulo,
    this.subtitulo,
    this.trailing,
    this.icono,
  });

  final String titulo;
  final String? subtitulo;
  final Widget? trailing;
  final IconData? icono;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SaaSTokens.s12, top: SaaSTokens.s8),
      child: Row(
        children: [
          if (icono != null) ...[
            Icon(icono, size: 18, color: SaaSTokens.inkMuted(context)),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: SaaSTokens.ink(context),
                  ),
                ),
                if (subtitulo != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitulo!,
                    style: TextStyle(
                      fontSize: 12,
                      color: SaaSTokens.inkMuted(context),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
