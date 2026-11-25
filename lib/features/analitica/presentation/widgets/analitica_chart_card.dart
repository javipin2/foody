import 'package:flutter/material.dart';
import 'package:reserva_canchas/core/layout/foody_breakpoints.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_tokens.dart';

/// Contenedor de gráfica — blanco, sin tintas.
class AnaliticaChartCard extends StatelessWidget {
  const AnaliticaChartCard({
    super.key,
    required this.titulo,
    required this.child,
    this.subtitulo,
    this.altura = 200,
    this.trailing,
    this.vacio = false,
    this.mensajeVacio = 'Sin datos en el periodo',
    this.icono,
    this.acento,
  });

  final String titulo;
  final String? subtitulo;
  final Widget child;
  final double altura;
  final Widget? trailing;
  final bool vacio;
  final String mensajeVacio;
  final IconData? icono;
  final Color? acento;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AnaliticaTokens.surfaceOf(context),
        borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
        border: Border.all(color: AnaliticaTokens.borderOf(context)),
        boxShadow: AnaliticaTokens.shadowSoftOf(context),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (icono != null) ...[
                Icon(icono,
                    size: 15, color: AnaliticaTokens.inkSoftOf(context)),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                        color: AnaliticaTokens.inkOf(context),
                        letterSpacing: -0.1,
                      ),
                    ),
                    if (subtitulo != null)
                      Text(
                        subtitulo!,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AnaliticaTokens.inkSoftOf(context),
                        ),
                      ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: altura,
            child: vacio ? _empty(context) : child,
          ),
        ],
      ),
    );
  }

  Widget _empty(BuildContext context) {
    final inkSoft = AnaliticaTokens.inkSoftOf(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icono ?? Icons.query_stats_rounded,
            size: 20,
            color: inkSoft,
          ),
          const SizedBox(height: 5),
          Text(
            mensajeVacio,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: inkSoft,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}

class AnaliticaChartsGrid extends StatelessWidget {
  const AnaliticaChartsGrid({
    super.key,
    required this.children,
    this.columnsDesktop = 2,
  });

  final List<Widget> children;
  final int columnsDesktop;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final cols = FoodyBreakpoints.esLarge(w)
            ? columnsDesktop.clamp(1, 3)
            : FoodyBreakpoints.esCompact(w)
                ? 1
                : 2;
        if (cols == 1 || children.length == 1) {
          return Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                children[i],
              ],
            ],
          );
        }
        final filas = <Widget>[];
        for (var i = 0; i < children.length; i += cols) {
          if (i > 0) filas.add(const SizedBox(height: 10));
          final slice = children.skip(i).take(cols).toList();
          filas.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var j = 0; j < slice.length; j++) ...[
                  if (j > 0) const SizedBox(width: 10),
                  Expanded(child: slice[j]),
                ],
                if (slice.length < cols)
                  for (var k = slice.length; k < cols; k++) ...[
                    const SizedBox(width: 10),
                    const Expanded(child: SizedBox.shrink()),
                  ],
              ],
            ),
          );
        }
        return Column(children: filas);
      },
    );
  }
}
