import 'package:flutter/material.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_skeleton.dart';
import 'package:intl/intl.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
import 'package:reserva_canchas/core/widgets/foody_estado_ui.dart';
import 'package:reserva_canchas/features/admin/data/dashboard_repository.dart';

/// Vista cadena — KPIs agregados y desglose por sucursal (permiso `gestionar_sucursales`).
class DashboardConsolidadoWidget extends StatefulWidget {
  const DashboardConsolidadoWidget({
    super.key,
    this.onSeleccionarSucursal,
    this.onIrAlertas,
    this.onIrPedidos,
    this.onIrReportes,
  });

  final void Function(String sucursalId)? onSeleccionarSucursal;
  final VoidCallback? onIrAlertas;
  final VoidCallback? onIrPedidos;
  final VoidCallback? onIrReportes;

  @override
  State<DashboardConsolidadoWidget> createState() =>
      _DashboardConsolidadoWidgetState();
}

class _DashboardConsolidadoWidgetState
    extends State<DashboardConsolidadoWidget> {
  ColorScheme get _scheme => Theme.of(context).colorScheme;

  final _repo = DashboardRepository();
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _recargar();
  }

  void _recargar() {
    setState(() {
      _future = _repo.consolidado();
    });
  }

  @override
  Widget build(BuildContext context) {
    final moneda =
        NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.hub_outlined, color: ColoresFoody.secundario),
            const SizedBox(width: 8),
            Text(
              'Cadena — todas las sedes',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Actualizar',
              onPressed: _recargar,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return AnaliticaSkeleton.seccion(
                  etiqueta: 'Cargando consolidado');
            }
            if (snapshot.hasError) {
              return FoodyEstadoUi.desdeExcepcion(
                error: snapshot.error!,
                contexto: 'cargar consolidado',
                onReintentar: _recargar,
              );
            }

            final d = snapshot.data!;
            final totales =
                Map<String, dynamic>.from(d['totales'] as Map? ?? {});
            final sedes = (d['por_sucursal'] as List?)
                    ?.map((e) => Map<String, dynamic>.from(e as Map))
                    .toList() ??
                <Map<String, dynamic>>[];
            final nSedes = d['sucursales_activas'] as int? ?? sedes.length;
            final alertas = totales['alertas_pendientes'] as int? ?? 0;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '$nSedes sucursales activas',
                  style:
                      TextStyle(color: _scheme.onSurfaceVariant, fontSize: 13),
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columnas = constraints.maxWidth > 700 ? 4 : 2;
                    return GridView.count(
                      crossAxisCount: columnas,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.6,
                      children: [
                        _TarjetaTotal(
                          titulo: 'Ventas hoy (cadena)',
                          valor: moneda.format(totales['ventas_hoy'] ?? 0),
                          color: ColoresFoody.primario,
                          onTap: widget.onIrReportes,
                        ),
                        _TarjetaTotal(
                          titulo: 'Pedidos activos',
                          valor: '${totales['pedidos_activos'] ?? 0}',
                          color: ColoresFoody.secundario,
                          onTap: widget.onIrPedidos,
                        ),
                        _TarjetaTotal(
                          titulo: 'Cerrados hoy',
                          valor: '${totales['pedidos_completados_hoy'] ?? 0}',
                          color: ColoresFoody.exito,
                          onTap: widget.onIrPedidos,
                        ),
                        _TarjetaTotal(
                          titulo: 'Alertas pendientes',
                          valor: '$alertas',
                          color: ColoresFoody.acento,
                          onTap: alertas > 0 ? widget.onIrAlertas : null,
                        ),
                      ],
                    );
                  },
                ),
                if (sedes.length > 1) ...[
                  const SizedBox(height: 20),
                  Text(
                    'Por sucursal',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  ...sedes.map((s) {
                    final sid = s['sucursal_id'] as String? ?? '';
                    final alertasSede = s['alertas_pendientes'] as int? ?? 0;
                    final activos = s['pedidos_activos'] as int? ?? 0;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              ColoresFoody.secundario.withValues(alpha: 0.15),
                          child: const Icon(
                            Icons.store,
                            color: ColoresFoody.secundario,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          s['nombre'] as String? ?? 'Sucursal',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          'Ventas ${moneda.format(s['ventas_hoy'] ?? 0)} · '
                          '$activos activos'
                          '${alertasSede > 0 ? ' · $alertasSede alertas' : ''}',
                        ),
                        trailing: widget.onSeleccionarSucursal != null
                            ? const Icon(Icons.chevron_right)
                            : null,
                        onTap: widget.onSeleccionarSucursal != null &&
                                sid.isNotEmpty
                            ? () => widget.onSeleccionarSucursal!(sid)
                            : null,
                      ),
                    );
                  }),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _TarjetaTotal extends StatelessWidget {
  const _TarjetaTotal({
    required this.titulo,
    required this.valor,
    required this.color,
    this.onTap,
  });

  final String titulo;
  final String valor;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: Theme.of(context).textTheme.bodySmall),
              const Spacer(),
              Text(
                valor,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
