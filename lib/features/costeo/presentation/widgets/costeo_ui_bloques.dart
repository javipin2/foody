import 'package:flutter/material.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';

/// Etiqueta de sección (estilo guía costeo).
class CosteoEtiquetaSeccion extends StatelessWidget {
  const CosteoEtiquetaSeccion({
    super.key,
    required this.titulo,
    this.subtitulo,
  });

  final String titulo;
  final String? subtitulo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: Colors.grey.shade600,
            ),
          ),
          if (subtitulo != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitulo!,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        ],
      ),
    );
  }
}

/// Tarjeta «lo que ve el cliente».
class CosteoPlatoClienteCard extends StatelessWidget {
  const CosteoPlatoClienteCard({
    super.key,
    required this.nombre,
    required this.precio,
  });

  final String nombre;
  final String precio;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: ColoresFoody.primario,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(12),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nombre,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'El cliente solo ve este nombre y el precio.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          precio,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: ColoresFoody.texto,
                          ),
                        ),
                        Text(
                          'precio de venta',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CosteoFlechaFlujo extends StatelessWidget {
  const CosteoFlechaFlujo({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Icon(Icons.arrow_downward, color: Colors.grey.shade400, size: 28),
      ),
    );
  }
}

/// Badge de categoría en receta (naranja / verde / beige).
class CosteoBadgeGrupo extends StatelessWidget {
  const CosteoBadgeGrupo({
    super.key,
    required this.texto,
    required this.color,
  });

  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color.withValues(alpha: 0.95),
        ),
      ),
    );
  }
}

/// Línea de resumen de costo (solo lectura).
class CosteoLineaResumen extends StatelessWidget {
  const CosteoLineaResumen({
    super.key,
    required this.nombre,
    required this.detalle,
    required this.total,
    this.detallePrecio,
    this.extra,
  });

  final String nombre;
  final String detalle;
  final String total;
  final String? detallePrecio;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  detalle,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                if (extra != null) ...[
                  const SizedBox(height: 6),
                  extra!,
                ],
              ],
            ),
          ),
          if (detallePrecio != null)
            Padding(
              padding: const EdgeInsets.only(right: 12, top: 2),
              child: Text(
                detallePrecio!,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ),
          Text(
            total,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// Bloque agrupado de líneas de receta.
class CosteoGrupoReceta extends StatelessWidget {
  const CosteoGrupoReceta({
    super.key,
    required this.titulo,
    required this.subtitulo,
    required this.colorBadge,
    required this.lineas,
  });

  final String titulo;
  final String subtitulo;
  final Color colorBadge;
  final List<Widget> lineas;

  @override
  Widget build(BuildContext context) {
    if (lineas.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CosteoBadgeGrupo(texto: titulo, color: colorBadge),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  subtitulo,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...lineas,
        ],
      ),
    );
  }
}

/// Pie con costo total, food cost y margen.
class CosteoResumenPie extends StatelessWidget {
  const CosteoResumenPie({
    super.key,
    required this.tituloCosto,
    required this.costoTotal,
    required this.foodCostPct,
    required this.margenBruto,
    required this.margenPct,
    required this.colorFoodCost,
    this.lineasExtra = const [],
  });

  final String tituloCosto;
  final String costoTotal;
  final double? foodCostPct;
  final String margenBruto;
  final String margenPct;
  final Color colorFoodCost;
  final List<Widget> lineasExtra;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...lineasExtra,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                tituloCosto,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                costoTotal,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: ColoresFoody.primario,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _kpiMini(
                  'Food cost',
                  foodCostPct != null ? '${foodCostPct!.toStringAsFixed(1)}%' : '—',
                  colorFoodCost,
                  foodCostPct != null ? (foodCostPct! / 100).clamp(0, 1) : 0,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _kpiMini('Margen bruto', margenBruto, ColoresFoody.exito, null),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _kpiMini('Margen %', margenPct, ColoresFoody.exito, null),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kpiMini(String label, String valor, Color color, double? progreso) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        const SizedBox(height: 4),
        Text(
          valor,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        if (progreso != null) ...[
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progreso,
              minHeight: 6,
              backgroundColor: Colors.grey.shade200,
              color: color,
            ),
          ),
        ],
      ],
    );
  }
}

/// Pasos guía compactos (insumos / costeo).
class GuiaPasosCompacta extends StatelessWidget {
  const GuiaPasosCompacta({
    super.key,
    required this.pasos,
  });

  final List<String> pasos;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ColoresFoody.primario.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: ColoresFoody.primario.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.route_outlined, size: 18, color: ColoresFoody.primario),
              const SizedBox(width: 6),
              Text(
                'Orden recomendado',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: ColoresFoody.primario,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...pasos.asMap().entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${e.key + 1}.',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: ColoresFoody.primario,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          e.value,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
