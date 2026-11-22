import 'package:flutter/material.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_tokens.dart';

enum StockEstado { ok, bajo, agotado, soloCosto, sinReceta }

StockEstado stockEstadoDesde({
  required num stock,
  required num minimo,
  bool descontarStock = true,
  bool tieneReceta = true,
}) {
  if (!tieneReceta) return StockEstado.sinReceta;
  if (!descontarStock) return StockEstado.soloCosto;
  if (stock <= 0) return StockEstado.agotado;
  if (stock <= minimo) return StockEstado.bajo;
  return StockEstado.ok;
}

/// Colores de riesgo (semánticos; UI neutra alrededor).
Color colorStockEstado(StockEstado e) {
  switch (e) {
    case StockEstado.ok:
      return AnaliticaTokens.inventario;
    case StockEstado.bajo:
      return const Color(0xFFD97706); // ámbar
    case StockEstado.agotado:
      return AnaliticaTokens.alertas;
    case StockEstado.soloCosto:
      return AnaliticaTokens.inkMuted;
    case StockEstado.sinReceta:
      return AnaliticaTokens.inkSoft;
  }
}

String etiquetaStockEstado(StockEstado e) {
  switch (e) {
    case StockEstado.ok:
      return 'Stock OK';
    case StockEstado.bajo:
      return 'Bajo stock';
    case StockEstado.agotado:
      return 'Agotado';
    case StockEstado.soloCosto:
      return 'Solo costo';
    case StockEstado.sinReceta:
      return 'Sin receta';
  }
}

class StockBadge extends StatelessWidget {
  const StockBadge({
    super.key,
    required this.estado,
    this.compacto = false,
  });

  final StockEstado estado;
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    final color = colorStockEstado(estado);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compacto ? 6 : 8,
        vertical: compacto ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            estado == StockEstado.agotado
                ? Icons.error_outline
                : estado == StockEstado.bajo
                    ? Icons.warning_amber_rounded
                    : estado == StockEstado.soloCosto
                        ? Icons.payments_outlined
                        : Icons.inventory_2_outlined,
            size: compacto ? 12 : 13,
            color: color,
          ),
          if (!compacto) ...[
            const SizedBox(width: 4),
            Text(
              etiquetaStockEstado(estado),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class StockBarra extends StatelessWidget {
  const StockBarra({
    super.key,
    required this.stock,
    required this.minimo,
    required this.unidad,
    this.alto = 5,
  });

  final num stock;
  final num minimo;
  final String unidad;
  final double alto;

  @override
  Widget build(BuildContext context) {
    final estado = stockEstadoDesde(stock: stock, minimo: minimo);
    final color = colorStockEstado(estado);
    final maxRef = minimo > 0 ? minimo * 3 : (stock > 0 ? stock : 1);
    final pct = (stock / maxRef).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: alto,
            backgroundColor: AnaliticaTokens.borderSoft,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Quedan ${_fmt(stock)} $unidad · mín. ${_fmt(minimo)}',
          style: const TextStyle(
            fontSize: 11,
            color: AnaliticaTokens.inkSoft,
          ),
        ),
      ],
    );
  }

  String _fmt(num v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(1);
  }
}

/// Banner compacto de alertas (mantiene color de riesgo).
class StockAlertaBanner extends StatelessWidget {
  const StockAlertaBanner({
    super.key,
    required this.agotados,
    required this.bajos,
    this.onVerBajos,
  });

  final int agotados;
  final int bajos;
  final VoidCallback? onVerBajos;

  @override
  Widget build(BuildContext context) {
    if (agotados == 0 && bajos == 0) return const SizedBox.shrink();

    final severo = agotados > 0;
    final color = severo ? AnaliticaTokens.alertas : const Color(0xFFD97706);
    final partes = <String>[];
    if (agotados > 0) partes.add('$agotados agotado${agotados > 1 ? 's' : ''}');
    if (bajos > 0) partes.add('$bajos bajo mínimo');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Material(
        color: AnaliticaTokens.surface,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onVerBajos,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                Icon(
                  severo ? Icons.inventory_2_outlined : Icons.warning_amber,
                  color: color,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Alertas de inventario',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: color,
                          fontSize: 12.5,
                        ),
                      ),
                      Text(
                        partes.join(' · '),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AnaliticaTokens.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onVerBajos != null)
                  Icon(Icons.chevron_right, size: 18, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class StockLineaReceta extends StatelessWidget {
  const StockLineaReceta({
    super.key,
    required this.cantidadReceta,
    required this.unidadReceta,
    required this.stockActual,
    required this.stockMinimo,
    required this.unidadBase,
    this.descontarStock = true,
  });

  final num cantidadReceta;
  final String unidadReceta;
  final num stockActual;
  final num stockMinimo;
  final String unidadBase;
  final bool descontarStock;

  @override
  Widget build(BuildContext context) {
    if (!descontarStock) {
      return const Row(
        children: [
          Icon(Icons.payments_outlined, size: 14, color: AnaliticaTokens.inkMuted),
          SizedBox(width: 4),
          Text(
            'Solo costo · no descuenta inventario',
            style: TextStyle(fontSize: 11, color: AnaliticaTokens.inkMuted),
          ),
        ],
      );
    }

    final estado = stockEstadoDesde(
      stock: stockActual,
      minimo: stockMinimo,
    );
    final color = colorStockEstado(estado);
    final cubre = stockActual >= cantidadReceta;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.remove_circle_outline,
              size: 14,
              color: AnaliticaTokens.ventas,
            ),
            const SizedBox(width: 4),
            Text(
              'Venta descuenta ${_fmt(cantidadReceta)} $unidadReceta',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AnaliticaTokens.inkMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            StockBadge(estado: estado, compacto: true),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                cubre
                    ? 'Quedan ${_fmt(stockActual)} $unidadBase'
                    : 'Faltan ${_fmt(cantidadReceta - stockActual)} $unidadBase (hay ${_fmt(stockActual)})',
                style: TextStyle(fontSize: 11, color: color),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _fmt(num v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(1);
  }
}

class StockImpactoProductoCard extends StatelessWidget {
  const StockImpactoProductoCard({
    super.key,
    required this.impacto,
  });

  final Map<String, dynamic> impacto;

  @override
  Widget build(BuildContext context) {
    final puede = impacto['puede_vender'] == true;
    final ingredientes = (impacto['ingredientes'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final faltas = (impacto['faltas'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final incluidos = (impacto['incluidos'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final color =
        puede ? AnaliticaTokens.inventario : AnaliticaTokens.alertas;
    final hayDetalle =
        faltas.isNotEmpty || incluidos.isNotEmpty || ingredientes.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: AnaliticaTokens.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: !puede,
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          leading: Icon(
            puede ? Icons.check_circle_outline : Icons.block,
            color: color,
            size: 20,
          ),
          title: Text(
            puede ? 'Stock OK · 1 venta' : 'Sin stock suficiente',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: color,
              fontSize: 13,
            ),
          ),
          subtitle: hayDetalle
              ? Text(
                  puede ? 'Ver consumo' : 'Ver faltantes',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AnaliticaTokens.inkSoft,
                  ),
                )
              : null,
          children: [
            if (incluidos.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'Incluye: '
                  '${incluidos.map((i) => '${i['cantidad']}× ${i['nombre']}').join(', ')}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AnaliticaTokens.inkMuted,
                  ),
                ),
              ),
            if (faltas.isNotEmpty)
              ...faltas.map((f) {
                return Text(
                  '• ${f['nombre']}: necesitas ${f['necesita']} ${f['unidad']}, '
                  'hay ${f['disponible']}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AnaliticaTokens.alertas,
                  ),
                );
              })
            else if (ingredientes.isNotEmpty)
              ...ingredientes.take(4).map((ing) {
                final estado = stockEstadoDesde(
                  stock: num.tryParse('${ing['disponible']}') ?? 0,
                  minimo: num.tryParse('${ing['minimo']}') ?? 0,
                  descontarStock: ing['descontar_stock'] != false,
                );
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      StockBadge(estado: estado, compacto: true),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${ing['nombre']}: −${ing['necesita']} ${ing['unidad']}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class StockAvisoIncluidos extends StatelessWidget {
  const StockAvisoIncluidos({super.key});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Container(
        decoration: BoxDecoration(
          color: AnaliticaTokens.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AnaliticaTokens.border),
        ),
        child: const ExpansionTile(
          initiallyExpanded: false,
          tilePadding: EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: EdgeInsets.fromLTRB(12, 0, 12, 10),
          leading: Icon(
            Icons.info_outline,
            size: 18,
            color: AnaliticaTokens.inkMuted,
          ),
          title: Text(
            'Incluidos también descuentan stock',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          children: [
            Text(
              'Si un incluido no tiene stock, el plato completo no se puede pedir.',
              style: TextStyle(fontSize: 12, color: AnaliticaTokens.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}
