import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
import 'package:reserva_canchas/features/admin/data/dashboard_repository.dart';

class DashboardResumenWidget extends StatefulWidget {
  const DashboardResumenWidget({
    super.key,
    this.sucursalId,
    this.onIrPedidos,
    this.onIrMesas,
    this.onIrAlertas,
  });

  final String? sucursalId;
  final VoidCallback? onIrPedidos;
  final VoidCallback? onIrMesas;
  final VoidCallback? onIrAlertas;

  @override
  State<DashboardResumenWidget> createState() => _DashboardResumenWidgetState();
}

class _DashboardResumenWidgetState extends State<DashboardResumenWidget> {
  final _repo = DashboardRepository();
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _recargar();
  }

  void _recargar() {
    setState(() {
      _future = _repo.resumen(sucursalId: widget.sucursalId);
    });
  }

  @override
  void didUpdateWidget(DashboardResumenWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sucursalId != widget.sucursalId) {
      _recargar();
    }
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
            Text(
              'Resumen del día',
              style: Theme.of(context).textTheme.titleMedium,
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
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            final d = snapshot.data!;
            final qr = d['pedidos_pendientes_qr'] as int? ?? 0;
            final alertas = d['alertas_pendientes'] as int? ?? 0;

            return LayoutBuilder(
              builder: (context, constraints) {
                final columnas = constraints.maxWidth > 700 ? 4 : 2;
                return GridView.count(
                  crossAxisCount: columnas,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.5,
                  children: [
                    _Tarjeta(
                      titulo: 'Ventas hoy',
                      valor: moneda.format(d['ventas_hoy']),
                      color: ColoresFoody.primario,
                    ),
                    _Tarjeta(
                      titulo: 'Pedidos activos',
                      valor: '${d['pedidos_activos']}',
                      color: ColoresFoody.secundario,
                      badge: qr > 0 ? '$qr QR' : null,
                      onTap: widget.onIrPedidos,
                    ),
                    _Tarjeta(
                      titulo: 'Completados hoy',
                      valor: '${d['pedidos_completados_hoy']}',
                      color: ColoresFoody.exito,
                    ),
                    _Tarjeta(
                      titulo: 'Alertas',
                      valor: '$alertas',
                      color: ColoresFoody.acento,
                      onTap: alertas > 0 ? widget.onIrAlertas : null,
                    ),
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({
    required this.titulo,
    required this.valor,
    required this.color,
    this.badge,
    this.onTap,
  });

  final String titulo;
  final String valor;
  final Color color;
  final String? badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: ColoresFoody.tarjeta,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(titulo, style: Theme.of(context).textTheme.bodyMedium),
                  ),
                  if (badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: ColoresFoody.error.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badge!,
                        style: TextStyle(
                          fontSize: 11,
                          color: ColoresFoody.error,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Text(
                valor,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              if (onTap != null)
                Text(
                  'Toca para ver',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
