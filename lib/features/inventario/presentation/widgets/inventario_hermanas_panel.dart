import 'package:flutter/material.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';
import 'package:reserva_canchas/features/inventario/data/inventario_repository.dart';
import 'package:reserva_canchas/features/inventario/presentation/widgets/stock_visual_widgets.dart';

/// Vista solo lectura del inventario en sucursales hermanas del mismo restaurante.
class InventarioHermanasPanel extends StatefulWidget {
  const InventarioHermanasPanel({super.key});

  @override
  State<InventarioHermanasPanel> createState() =>
      _InventarioHermanasPanelState();
}

class _InventarioHermanasPanelState extends State<InventarioHermanasPanel> {
  final _repo = InventarioRepository();
  Map<String, dynamic>? _resumen;
  bool _cargando = true;
  String? _error;
  String? _sucursalDetalleId;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final data = await _repo.resumenHermanas();
      if (!mounted) return;
      setState(() {
        _resumen = data;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = mensajeErrorHttp(e, contexto: 'inventario otras sucursales');
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _cargar, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }

    final puede = _resumen?['puede_ver_hermanas'] == true;
    final sucursales = (_resumen?['sucursales'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();

    if (!puede) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No tienes permiso para consultar inventario de otras sucursales.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_sucursalDetalleId != null) {
      final sede = sucursales.firstWhere(
        (s) => s['sucursal_id'] == _sucursalDetalleId,
        orElse: () => <String, dynamic>{},
      );
      return _DetalleSucursalHermana(
        sede: sede,
        onVolver: () => setState(() => _sucursalDetalleId = null),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ColoresFoody.secundario.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: ColoresFoody.secundario.withValues(alpha: 0.35),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.visibility_outlined, color: ColoresFoody.secundario),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Solo lectura. No puedes editar ni comprar en otra sede.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ...sucursales.map((s) => _TarjetaSucursalHermana(
                data: s,
                onVerDetalle: s['es_propia'] == true
                    ? null
                    : () => setState(
                          () => _sucursalDetalleId = s['sucursal_id'] as String?,
                        ),
              )),
        ],
      ),
    );
  }
}

class _TarjetaSucursalHermana extends StatelessWidget {
  const _TarjetaSucursalHermana({
    required this.data,
    this.onVerDetalle,
  });

  final Map<String, dynamic> data;
  final VoidCallback? onVerDetalle;

  @override
  Widget build(BuildContext context) {
    final esPropia = data['es_propia'] == true;
    final agotados = (data['agotados'] as num?)?.toInt() ?? 0;
    final bajos = (data['bajo_stock'] as num?)?.toInt() ?? 0;
    final alertas = (data['alertas'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  esPropia ? Icons.store : Icons.store_outlined,
                  color: esPropia
                      ? ColoresFoody.primario
                      : Colors.grey.shade700,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    data['nombre'] as String? ?? 'Sucursal',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (esPropia)
                  const Chip(
                    label: Text('Tu sede', style: TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                  )
                else
                  const Chip(
                    label: Text('Solo lectura', style: TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${data['total_insumos']} insumos · '
              '$bajos bajo stock · $agotados agotados',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            if (alertas.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...alertas.take(3).map((a) {
                final stock = num.tryParse('${a['stock_actual']}') ?? 0;
                final min = num.tryParse('${a['stock_minimo']}') ?? 0;
                final estado = stockEstadoDesde(stock: stock, minimo: min);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      StockBadge(estado: estado, compacto: true),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${a['nombre']}: ${a['stock_actual']} ${a['unidad_base']}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
            if (onVerDetalle != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onVerDetalle,
                  icon: const Icon(Icons.list_alt, size: 18),
                  label: const Text('Ver inventario completo'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetalleSucursalHermana extends StatefulWidget {
  const _DetalleSucursalHermana({
    required this.sede,
    required this.onVolver,
  });

  final Map<String, dynamic> sede;
  final VoidCallback onVolver;

  @override
  State<_DetalleSucursalHermana> createState() =>
      _DetalleSucursalHermanaState();
}

class _DetalleSucursalHermanaState extends State<_DetalleSucursalHermana> {
  final _repo = InventarioRepository();
  List<Map<String, dynamic>> _ingredientes = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final sid = widget.sede['sucursal_id'] as String?;
    if (sid == null) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final lista = await _repo.ingredientes(sid);
      if (!mounted) return;
      setState(() {
        _ingredientes = lista;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = mensajeErrorHttp(e, contexto: 'inventario');
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: Row(
            children: [
              IconButton(
                onPressed: widget.onVolver,
                icon: const Icon(Icons.arrow_back),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.sede['nombre'] as String? ?? 'Sucursal',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const Text(
                      'Solo lectura — otra sede',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _cargando
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text(_error!))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _ingredientes.length,
                      itemBuilder: (_, i) {
                        final ing = _ingredientes[i];
                        final stock =
                            num.tryParse('${ing['stock_actual']}') ?? 0;
                        final min =
                            num.tryParse('${ing['stock_minimo']}') ?? 0;
                        final estado = stockEstadoDesde(
                          stock: stock,
                          minimo: min,
                          descontarStock: ing['descontar_stock'] != false,
                        );
                        return ListTile(
                          leading: StockBadge(estado: estado, compacto: true),
                          title: Text('${ing['nombre']}'),
                          subtitle: StockBarra(
                            stock: stock,
                            minimo: min,
                            unidad: '${ing['unidad_base'] ?? 'und'}',
                          ),
                          dense: true,
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
