import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:reserva_canchas/core/layout/foody_breakpoints.dart';
import 'package:reserva_canchas/core/saas_ui/saas_tokens.dart';

/// KPI premium reutilizable (Insights / Finanzas).
/// Layout fijo: título + chip Δ% · valor grande · sparkline · caption.
class SaaSKpiCard extends StatefulWidget {
  const SaaSKpiCard({
    super.key,
    required this.etiqueta,
    required this.valor,
    this.deltaPct,
    this.subtitulo,
    this.icono,
    this.onTap,
    this.acento,
    this.sparkline,
    this.tooltip,
    this.alturaFija = 136,
    /// Si true, Δ positivo se pinta rojo (p. ej. cancelaciones).
    this.invertirDelta = false,
  });

  final String etiqueta;
  final String valor;
  final double? deltaPct;
  final String? subtitulo;
  final IconData? icono;
  final VoidCallback? onTap;
  final Color? acento;
  final List<double>? sparkline;
  final String? tooltip;
  final double alturaFija;
  final bool invertirDelta;

  @override
  State<SaaSKpiCard> createState() => _SaaSKpiCardState();
}

class _SaaSKpiCardState extends State<SaaSKpiCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.acento ?? SaaSTokens.chart(context);
    final delta = widget.deltaPct;

    final card = MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedScale(
        scale: _hover ? 1.012 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: widget.alturaFija,
          decoration: BoxDecoration(
            color: SaaSTokens.surface(context),
            borderRadius: BorderRadius.circular(SaaSTokens.r12),
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
              borderRadius: BorderRadius.circular(SaaSTokens.r12),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Fila superior: etiqueta + chip Δ% (siempre misma altura)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (widget.icono != null) ...[
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(widget.icono, size: 15, color: color),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Text(
                            widget.etiqueta,
                            style: TextStyle(
                              fontSize: 12,
                              color: SaaSTokens.inkMuted(context),
                              fontWeight: FontWeight.w500,
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        _DeltaChip(
                          deltaPct: delta,
                          invertir: widget.invertirDelta,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.valor,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: SaaSTokens.ink(context),
                        height: 1.05,
                        letterSpacing: -0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.sparkline != null &&
                        widget.sparkline!.length >= 2) ...[
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 20,
                        child: _MiniSpark(
                          valores: widget.sparkline!,
                          color: color.withValues(alpha: 0.8),
                        ),
                      ),
                    ] else
                      const SizedBox(height: 4),
                    const Spacer(),
                    Text(
                      widget.subtitulo ??
                          (delta != null
                              ? 'vs periodo anterior'
                              : 'Sin comparativa'),
                      style: TextStyle(
                        fontSize: 11,
                        color: SaaSTokens.inkSoft(context),
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return widget.tooltip == null
        ? card
        : Tooltip(message: widget.tooltip!, child: card);
  }
}

/// Chip compacto de ganancia / pérdida (▲ verde · ▼ rojo).
class _DeltaChip extends StatelessWidget {
  const _DeltaChip({required this.deltaPct, this.invertir = false});

  final double? deltaPct;
  final bool invertir;

  @override
  Widget build(BuildContext context) {
    final delta = deltaPct;
    if (delta == null) {
      // Reserva espacio para alinear todas las tarjetas.
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: SaaSTokens.surfaceMuted(context),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '—',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: SaaSTokens.inkSoft(context),
          ),
        ),
      );
    }

    final positivo = delta > 0;
    final neutro = delta == 0;
    final bueno = invertir ? !positivo : positivo;
    final color = neutro
        ? SaaSTokens.inkSoft(context)
        : (bueno ? SaaSTokens.positivo : SaaSTokens.negativo);
    final icono = neutro
        ? Icons.remove_rounded
        : (positivo
            ? Icons.arrow_upward_rounded
            : Icons.arrow_downward_rounded);
    final txt = neutro
        ? '0%'
        : '${positivo ? '+' : ''}${delta.toStringAsFixed(1)}%';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 12, color: color),
          const SizedBox(width: 2),
          Text(
            txt,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniSpark extends StatelessWidget {
  const _MiniSpark({required this.valores, required this.color});

  final List<double> valores;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final min = valores.reduce((a, b) => a < b ? a : b);
    final max = valores.reduce((a, b) => a > b ? a : b);
    final spots = <FlSpot>[
      for (var i = 0; i < valores.length; i++) FlSpot(i.toDouble(), valores[i]),
    ];
    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (valores.length - 1).toDouble(),
        minY: min == max ? min - 1 : min,
        maxY: min == max ? max + 1 : max,
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: color,
            barWidth: 1.5,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: color.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 400),
    );
  }
}

class SaaSKpiGrid extends StatelessWidget {
  const SaaSKpiGrid({
    super.key,
    required this.children,
    this.minChildWidth = 200,
    this.altura = 136,
  });

  final List<Widget> children;
  final double minChildWidth;
  final double altura;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final cols = FoodyBreakpoints.esLarge(w)
            ? (w / minChildWidth).floor().clamp(4, 6)
            : FoodyBreakpoints.esExpanded(w)
                ? 3
                : 2;
        return GridView.count(
          crossAxisCount: cols.clamp(2, children.length.clamp(2, 6)),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: (w / cols) / altura,
          children: children,
        );
      },
    );
  }
}
