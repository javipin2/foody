import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:reserva_canchas/core/layout/foody_breakpoints.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_sparkline.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_tokens.dart';

/// KPI denso, fondo blanco, acento mínimo.
class AnaliticaKpiCard extends StatefulWidget {
  const AnaliticaKpiCard({
    super.key,
    required this.etiqueta,
    required this.valor,
    this.deltaPct,
    this.subtitulo,
    this.icono,
    this.onTap,
    this.acento,
    this.sparkline,
    this.estado,
    this.tooltip,
    this.destacado = false,
  });

  final String etiqueta;
  final String valor;
  final double? deltaPct;
  final String? subtitulo;
  final IconData? icono;
  final VoidCallback? onTap;
  final Color? acento;
  final List<double>? sparkline;
  final String? estado;
  final String? tooltip;

  /// Métricas primarias (más peso tipográfico).
  final bool destacado;

  @override
  State<AnaliticaKpiCard> createState() => _AnaliticaKpiCardState();
}

class _AnaliticaKpiCardState extends State<AnaliticaKpiCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.acento ?? AnaliticaTokens.chartOf(context);
    final delta = widget.deltaPct;
    Color? deltaColor;
    String? deltaTxt;
    IconData? deltaIcon;
    if (delta != null) {
      if (delta > 0) {
        deltaColor = AnaliticaTokens.inventario;
        deltaTxt = '+${delta.toStringAsFixed(1)}%';
        deltaIcon = Icons.arrow_upward_rounded;
      } else if (delta < 0) {
        deltaColor = AnaliticaTokens.alertas;
        deltaTxt = '${delta.toStringAsFixed(1)}%';
        deltaIcon = Icons.arrow_downward_rounded;
      } else {
        deltaColor = AnaliticaTokens.inkSoftOf(context);
        deltaTxt = '0%';
        deltaIcon = Icons.remove_rounded;
      }
    }

    final card = MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: AnaliticaTokens.surfaceOf(context),
          borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
          border: Border.all(
            color: _hover
                ? AnaliticaTokens.borderOf(context)
                : AnaliticaTokens.borderSoftOf(context),
          ),
          boxShadow: _hover
              ? AnaliticaTokens.shadowLiftOf(context)
              : AnaliticaTokens.shadowSoftOf(context),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (widget.icono != null) ...[
                        Icon(widget.icono, size: 15, color: color),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          widget.etiqueta,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AnaliticaTokens.inkMutedOf(context),
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (widget.estado != null)
                        Text(
                          widget.estado!,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: AnaliticaTokens.inkSoftOf(context),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      widget.valor,
                      key: ValueKey(widget.valor),
                      style: TextStyle(
                        fontSize: widget.destacado ? 20 : 17,
                        fontWeight: widget.destacado
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: AnaliticaTokens.inkOf(context),
                        height: 1.1,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (widget.sparkline != null &&
                      widget.sparkline!.length >= 2) ...[
                    const SizedBox(height: 4),
                    AnaliticaSparkline(
                      valores: widget.sparkline!,
                      color: color.withValues(alpha: 0.7),
                      height: 22,
                    ),
                  ],
                  const Spacer(),
                  if (deltaTxt != null || widget.subtitulo != null)
                    Row(
                      children: [
                        if (deltaTxt != null) ...[
                          Icon(deltaIcon, size: 12, color: deltaColor),
                          const SizedBox(width: 2),
                          Text(
                            deltaTxt,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: deltaColor,
                            ),
                          ),
                          if (widget.subtitulo != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              '·',
                              style: TextStyle(
                                color: AnaliticaTokens.borderOf(context),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                        ],
                        if (widget.subtitulo != null)
                          Expanded(
                            child: Text(
                              widget.subtitulo!,
                              style: TextStyle(
                                fontSize: 10.5,
                                color: AnaliticaTokens.inkSoftOf(context),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final wrapped = widget.tooltip == null
        ? card
        : Tooltip(message: widget.tooltip!, child: card);

    return wrapped.animate().fadeIn(duration: 200.ms);
  }
}

class AnaliticaKpiGrid extends StatelessWidget {
  const AnaliticaKpiGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final cols = FoodyBreakpoints.esLarge(w)
            ? 6
            : FoodyBreakpoints.esExpanded(w)
                ? 3
                : 2;
        return GridView.count(
          crossAxisCount: cols.clamp(2, children.length.clamp(2, 6)),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: FoodyBreakpoints.esLarge(w)
              ? 1.55
              : FoodyBreakpoints.esExpanded(w)
                  ? 1.65
                  : 1.45,
          children: children,
        );
      },
    );
  }
}
