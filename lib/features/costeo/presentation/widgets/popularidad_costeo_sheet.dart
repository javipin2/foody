import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';
import 'package:reserva_canchas/features/inventario/data/costeo_repository.dart';

/// Simulador ingeniería de menú — popularidad y margen por canal (P2-13).
Future<void> mostrarPopularidadCosteo({
  required BuildContext context,
  required String sucursalId,
  required CosteoRepository repo,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _PopularidadCosteoSheet(
      sucursalId: sucursalId,
      repo: repo,
    ),
  );
}

class _PopularidadCosteoSheet extends StatefulWidget {
  const _PopularidadCosteoSheet({
    required this.sucursalId,
    required this.repo,
  });

  final String sucursalId;
  final CosteoRepository repo;

  @override
  State<_PopularidadCosteoSheet> createState() =>
      _PopularidadCosteoSheetState();
}

class _PopularidadCosteoSheetState extends State<_PopularidadCosteoSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  String _preset = '30d';
  bool _cargando = true;
  String? _error;
  Map<String, dynamic>? _datos;

  final _moneda = NumberFormat.currency(
    locale: 'es_CO',
    symbol: r'$',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _cargar();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final d = await widget.repo.simuladorPopularidad(
        widget.sucursalId,
        preset: _preset,
      );
      if (mounted) {
        setState(() {
          _datos = d;
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = mensajeErrorHttp(e, contexto: 'popularidad');
          _cargando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final altura = MediaQuery.sizeOf(context).height * 0.88;
    final periodo = _datos?['periodo'] as Map<String, dynamic>?;

    return SizedBox(
      height: altura,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Popularidad ventas',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (periodo != null)
                        Text(
                          periodo['label'] as String? ??
                              '${periodo['desde']} → ${periodo['hasta']}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _cargando ? null : _cargar,
                  icon: const Icon(Icons.refresh),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Wrap(
              spacing: 8,
              children: [
                for (final p in const [
                  ('7d', '7 días'),
                  ('30d', '30 días'),
                  ('mes', 'Mes'),
                ])
                  ChoiceChip(
                    label: Text(p.$2),
                    selected: _preset == p.$1,
                    onSelected: _cargando
                        ? null
                        : (_) {
                            setState(() => _preset = p.$1);
                            _cargar();
                          },
                  ),
              ],
            ),
          ),
          TabBar(
            controller: _tabs,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: ColoresFoody.primario,
            tabs: const [
              Tab(text: 'Mesa'),
              Tab(text: 'Domicilio / llevar'),
            ],
          ),
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!, textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: _cargar,
                              child: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      )
                    : TabBarView(
                        controller: _tabs,
                        children: [
                          _panelCanal(_datos?['mesa'] as Map<String, dynamic>?),
                          _panelCanal(
                            _datos?['domicilio'] as Map<String, dynamic>?,
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _panelCanal(Map<String, dynamic>? canal) {
    if (canal == null) {
      return const Center(child: Text('Sin datos'));
    }
    final productos =
        (canal['productos'] as List<dynamic>? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
    final totales = canal['totales'] as Map<String, dynamic>? ?? {};
    final resumen = canal['resumen_matriz'] as Map<String, dynamic>? ?? {};

    if (productos.isEmpty) {
      return Center(
        child: Text(
          'Sin ventas en este periodo',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _tarjetaResumen(totales, resumen),
        const SizedBox(height: 8),
        ...productos.map(_filaProducto),
      ],
    );
  }

  Widget _tarjetaResumen(
    Map<String, dynamic> totales,
    Map<String, dynamic> resumen,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ColoresFoody.secundario.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ventas ${_moneda.format(_num(totales['ventas']))} · '
            '${totales['cantidad'] ?? 0} uds · '
            'Margen ${_moneda.format(_num(totales['margen_bruto']))}',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _chipMatriz('Estrella', resumen['estrella'], Colors.amber.shade800),
              _chipMatriz('Caballo', resumen['caballo'], ColoresFoody.primario),
              _chipMatriz('Puzzle', resumen['puzzle'], ColoresFoody.secundario),
              _chipMatriz('Perro', resumen['perro'], Colors.grey.shade600),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chipMatriz(String label, dynamic count, Color color) {
    return Chip(
      label: Text('$label ${count ?? 0}', style: const TextStyle(fontSize: 11)),
      visualDensity: VisualDensity.compact,
      backgroundColor: color.withValues(alpha: 0.15),
      side: BorderSide(color: color.withValues(alpha: 0.4)),
    );
  }

  Widget _filaProducto(Map<String, dynamic> p) {
    final matriz = p['clasificacion_matriz'] as String? ?? 'perro';
    final abc = p['clasificacion_abc'] as String? ?? 'C';

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        title: Text(
          p['nombre'] as String? ?? '',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          '${p['cantidad'] ?? 0} uds · '
          '${p['margen_porcentaje'] ?? 0}% margen · '
          '${p['participacion_ventas_pct'] ?? 0}% ventas',
          style: const TextStyle(fontSize: 11),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _moneda.format(_num(p['ventas'])),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _badgeAbc(abc),
                const SizedBox(width: 4),
                _badgeMatriz(matriz),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _badgeAbc(String abc) {
    final color = abc == 'A'
        ? Colors.green.shade700
        : abc == 'B'
            ? Colors.orange.shade800
            : Colors.grey.shade600;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(abc, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
    );
  }

  Widget _badgeMatriz(String matriz) {
    final label = switch (matriz) {
      'estrella' => '★',
      'caballo' => '♞',
      'puzzle' => '?',
      _ => '·',
    };
    return Text(label, style: const TextStyle(fontSize: 12));
  }

  double _num(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
}
