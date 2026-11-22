import 'package:flutter/material.dart';
import 'package:reserva_canchas/core/saas_ui/saas_surface.dart';
import 'package:reserva_canchas/core/saas_ui/saas_tokens.dart';

class SaaSChartCard extends StatelessWidget {
  const SaaSChartCard({
    super.key,
    required this.titulo,
    required this.child,
    this.subtitulo,
    this.icono,
    this.trailing,
    this.vacio = false,
    this.mensajeVacio = 'Sin datos en este periodo',
    this.altura = 280,
  });

  final String titulo;
  final String? subtitulo;
  final IconData? icono;
  final Widget child;
  final Widget? trailing;
  final bool vacio;
  final String mensajeVacio;
  final double altura;

  @override
  Widget build(BuildContext context) {
    return SaaSSurface(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (icono != null) ...[
                Icon(icono, size: 16, color: SaaSTokens.inkMuted(context)),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: SaaSTokens.ink(context),
                      ),
                    ),
                    if (subtitulo != null)
                      Text(
                        subtitulo!,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: SaaSTokens.inkMuted(context),
                        ),
                      ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: altura,
            child: vacio
                ? Center(
                    child: Text(
                      mensajeVacio,
                      style: TextStyle(
                        color: SaaSTokens.inkSoft(context),
                        fontSize: 13,
                      ),
                    ),
                  )
                : child,
          ),
        ],
      ),
    );
  }
}

class SaaSChartsGrid extends StatelessWidget {
  const SaaSChartsGrid({
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
        final wide = c.maxWidth >= 900;
        if (!wide || children.length == 1) {
          return Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                children[i],
              ],
            ],
          );
        }
        final cols = columnsDesktop.clamp(2, 4);
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final w in children)
              SizedBox(
                width: (c.maxWidth - 10 * (cols - 1)) / cols,
                child: w,
              ),
          ],
        );
      },
    );
  }
}
