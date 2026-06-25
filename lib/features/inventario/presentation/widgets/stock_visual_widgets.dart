import 'package:flutter/material.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';

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

Color colorStockEstado(StockEstado e) {
  switch (e) {
    case StockEstado.ok:
      return ColoresFoody.exito;
    case StockEstado.bajo:
      return const Color(0xFFFF9800);
    case StockEstado.agotado:
      return ColoresFoody.error;
    case StockEstado.soloCosto:
      return Colors.brown.shade400;
    case StockEstado.sinReceta:
      return Colors.grey;
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

/// Badge compacto de estado de inventario.
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
        vertical: compacto ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
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
            size: compacto ? 12 : 14,
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

/// Barra de stock vs mínimo.
class StockBarra extends StatelessWidget {
  const StockBarra({
    super.key,
    required this.stock,
    required this.minimo,
    required this.unidad,
    this.alto = 6,
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
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: alto,
            backgroundColor: Colors.grey.shade200,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Quedan ${_fmt(stock)} $unidad · mín. ${_fmt(minimo)}',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
        ),
      ],
    );
  }

  String _fmt(num v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(1);
  }
}

/// Banner superior con resumen de alertas de inventario.
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
    final color = severo ? ColoresFoody.error : const Color(0xFFFF9800);
    final partes = <String>[];
    if (agotados > 0) partes.add('$agotados agotado${agotados > 1 ? 's' : ''}');
    if (bajos > 0) partes.add('$bajos bajo mínimo');

    return Material(
      color: color.withValues(alpha: 0.1),
      child: InkWell(
        onTap: onVerBajos,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(
                severo ? Icons.inventory_outlined : Icons.warning_amber,
                color: color,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Alertas de inventario',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: color,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      '${partes.join(' · ')}. '
                      'Los platos con receta no se pueden vender sin stock.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                    ),
                  ],
                ),
              ),
              if (onVerBajos != null)
                Icon(Icons.chevron_right, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

/// Línea bajo un insumo en receta: cuánto descuenta y cuánto queda.
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
      return Row(
        children: [
          Icon(Icons.payments_outlined, size: 14, color: Colors.brown.shade400),
          const SizedBox(width: 4),
          Text(
            'Solo costo · no descuenta inventario',
            style: TextStyle(fontSize: 11, color: Colors.brown.shade600),
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
            Icon(Icons.remove_circle_outline, size: 14, color: ColoresFoody.primario),
            const SizedBox(width: 4),
            Text(
              'Venta descuenta ${_fmt(cantidadReceta)} $unidadReceta',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: ColoresFoody.primario,
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

/// Tarjeta de impacto de stock al vender 1 unidad (admin costos).
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
    final color = puede ? ColoresFoody.exito : ColoresFoody.error;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                puede ? Icons.check_circle_outline : Icons.block,
                color: color,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  puede
                      ? 'Stock OK para vender 1 unidad'
                      : 'No se puede vender: falta inventario',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          if (incluidos.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Incluye (también descuenta stock): '
              '${incluidos.map((i) => '${i['cantidad']}× ${i['nombre']}').join(', ')}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade800),
            ),
          ],
          if (faltas.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...faltas.map((f) {
              return Text(
                '• ${f['nombre']}: necesitas ${f['necesita']} ${f['unidad']}, '
                'hay ${f['disponible']}',
                style: TextStyle(fontSize: 12, color: ColoresFoody.error),
              );
            }),
          ] else if (ingredientes.isNotEmpty) ...[
            const SizedBox(height: 8),
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
                        '${ing['nombre']}: −${ing['necesita']} ${ing['unidad']} '
                        '(quedan ${ing['disponible']})',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

/// Aviso de impacto de ítems incluidos en el stock.
class StockAvisoIncluidos extends StatelessWidget {
  const StockAvisoIncluidos({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ColoresFoody.acento.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ColoresFoody.primario.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18, color: ColoresFoody.primario),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Cada ítem incluido también descuenta su receta al vender. '
              'Si un incluido no tiene stock (ej. queso en rosquetes), '
              'el plato completo no se puede pedir.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
            ),
          ),
        ],
      ),
    );
  }
}
