import 'package:flutter/material.dart';
import 'package:reserva_canchas/core/widgets/foody_dialogo.dart';
import 'package:intl/intl.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_tokens.dart';
import 'package:reserva_canchas/features/catalogo/data/catalogo_admin_repository.dart';
import 'package:reserva_canchas/features/costeo/presentation/widgets/costeo_ui_bloques.dart';
import 'package:reserva_canchas/features/inventario/presentation/widgets/stock_visual_widgets.dart';

/// Configura productos del menú incluidos automáticamente en un plato.
class ProductoItemsIncluidosPanel extends StatefulWidget {
  const ProductoItemsIncluidosPanel({
    super.key,
    required this.productoId,
    required this.nombreProducto,
    required this.productosDisponibles,
    required this.onGuardado,
    this.catalogoRepository,
    this.onCostosActualizados,
    this.precioVenta,
    this.costoTotalProducto,
    this.foodCostPct,
    this.margenPct,
    this.margenBruto,
    this.scrollExterno = false,
  });

  final String productoId;
  final String nombreProducto;
  final List<Map<String, dynamic>> productosDisponibles;
  final VoidCallback onGuardado;
  final CatalogoAdminRepository? catalogoRepository;
  /// Tras cargar incluidos el backend recalcula; refresca listado sin otro POST.
  final VoidCallback? onCostosActualizados;
  final double? precioVenta;
  /// `costo_calculado` del producto (receta + incluidos).
  final double? costoTotalProducto;
  final double? foodCostPct;
  final double? margenPct;
  /// Margen en dinero ya calculado por el API (opcional).
  final double? margenBruto;
  final bool scrollExterno;

  @override
  State<ProductoItemsIncluidosPanel> createState() =>
      _ProductoItemsIncluidosPanelState();
}

class _ProductoItemsIncluidosPanelState
    extends State<ProductoItemsIncluidosPanel> {
  late final CatalogoAdminRepository _repo =
      widget.catalogoRepository ?? CatalogoAdminRepository();
  final _listaCtrl = ScrollController();
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _filas = [];
  bool _cargando = true;
  bool _guardando = false;
  bool _modoEdicion = false;

  final _moneda = NumberFormat.currency(
    locale: 'es_CO',
    symbol: r'$',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _listaCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ProductoItemsIncluidosPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.productoId != widget.productoId) {
      _modoEdicion = false;
      _cargar();
    }
  }

  List<Map<String, dynamic>> get _opcionesIncluir {
    return widget.productosDisponibles
        .where((p) => p['id'] != widget.productoId)
        .toList();
  }

  Map<String, dynamic> _nuevaFila({
    required String productoIncluidoId,
    double cantidad = 1,
  }) {
    return <String, dynamic>{
      'producto_incluido_id': productoIncluidoId,
      'cantidad': cantidad,
    };
  }

  String _nombreProducto(String? id) {
    if (id == null) return '—';
    for (final p in widget.productosDisponibles) {
      if (p['id'] == id) return p['nombre'] as String? ?? '—';
    }
    return '—';
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final items = await _repo.listarItemsIncluidos(widget.productoId);
      if (!mounted) return;
      setState(() {
        _items = items;
        _filas = items
            .map(
              (e) => _nuevaFila(
                productoIncluidoId: '${e['producto_incluido_id']}',
                cantidad: num.tryParse('${e['cantidad']}')?.toDouble() ?? 1,
              ),
            )
            .toList();
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _items = [];
        _filas = [];
        _cargando = false;
      });
    }
  }

  void _avisarSinOpciones() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Crea primero el producto en Menú (ej. Rosquete) y vuelve aquí.',
        ),
      ),
    );
  }

  Future<void> _elegirProductoMenu() async {
    final opciones = _opcionesIncluir;
    if (opciones.isEmpty) {
      _avisarSinOpciones();
      return;
    }

    final yaUsados = _filas
        .map((f) => f['producto_incluido_id'] as String?)
        .whereType<String>()
        .toSet();
    final disponibles =
        opciones.where((p) => !yaUsados.contains(p['id'])).toList();
    if (disponibles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ya agregaste todos los productos')),
      );
      return;
    }

    final elegido = await FoodyDialogo.mostrar<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Agregar del menú'),
        children: disponibles
            .map(
              (p) => SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, p['id'] as String),
                child: Text(p['nombre'] as String? ?? '—'),
              ),
            )
            .toList(),
      ),
    );
    if (elegido == null) return;

    setState(() {
      _modoEdicion = true;
      _filas.add(_nuevaFila(productoIncluidoId: elegido));
    });
  }

  Future<void> _guardar() async {
    if (_guardando) return;
    setState(() => _guardando = true);
    try {
      await _repo.configurarItemsIncluidos(
        productoId: widget.productoId,
        items: _filas
            .map(
              (f) => _nuevaFila(
                productoIncluidoId: '${f['producto_incluido_id']}',
                cantidad: (f['cantidad'] as num?)?.toDouble() ?? 1,
              ),
            )
            .toList(),
      );
      await _cargar();
      widget.onGuardado();
      widget.onCostosActualizados?.call();
      if (mounted) {
        setState(() => _modoEdicion = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Incluidos guardados')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensajeErrorHttp(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  double get _costoIncluidosGuardado {
    return _items.fold<double>(0, (sum, e) {
      final c = num.tryParse('${e['producto_incluido_costo']}');
      final q = num.tryParse('${e['cantidad']}') ?? 1;
      return sum + (c != null ? c * q : 0);
    });
  }

  Widget _vistaResumen() {
    final incluidos = _costoIncluidosGuardado;
    // costo_calculado del backend ya incluye receta + incluidos
    final total = widget.costoTotalProducto ?? incluidos;
    final prepSolo = (total - incluidos).clamp(0.0, double.infinity);
    final precio = widget.precioVenta;
    // AQ-SOLID-08: % / margen solo del API; sin restar precio−costo en Dart.
    final fc = widget.foodCostPct;
    final margenPct = widget.margenPct;
    final margenBruto = widget.margenBruto;

    Color fcColor = AnaliticaTokens.inventario;
    if (fc != null) {
      if (fc > 50) {
        fcColor = AnaliticaTokens.alertas;
      } else if (fc > 35) {
        fcColor = const Color(0xFFD97706);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const StockAvisoIncluidos(),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AnaliticaTokens.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AnaliticaTokens.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CosteoBadgeGrupo(
                    texto: 'Incluido sin costo extra',
                    color: AnaliticaTokens.pedidos,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'El cliente paga un solo precio; aquí sumamos el costo '
                      'real de todo lo que sale de inventario.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AnaliticaTokens.inkSoft,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_items.isEmpty)
                const Text(
                  'Nada incluido aún.\nEj.: 2× Rosquete con el hígado encebollado.',
                  style: TextStyle(
                    color: AnaliticaTokens.inkMuted,
                    fontSize: 13,
                  ),
                )
              else
                ..._items.map((e) {
                  final nombre = e['producto_incluido_nombre'] as String? ??
                      _nombreProducto('${e['producto_incluido_id']}');
                  final cant = num.tryParse('${e['cantidad']}') ?? 1;
                  final costoUnit =
                      num.tryParse('${e['producto_incluido_costo']}') ?? 0;
                  final costoLinea = costoUnit * cant;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_outline,
                          size: 18,
                          color: AnaliticaTokens.pedidos,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$nombre × ${cant == cant.roundToDouble() ? cant.toInt() : cant}',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                cant > 1 && costoUnit > 0
                                    ? '${_moneda.format(costoUnit)} c/u · stock ×$cant'
                                    : 'stock se descuenta ×$cant al vender',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (costoLinea > 0)
                          Text(
                            _moneda.format(costoLinea),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
        const SizedBox(height: 12),
        CosteoResumenPie(
          tituloCosto: 'Costo real total del plato',
          costoTotal: _moneda.format(total),
          foodCostPct: fc,
          margenBruto:
              margenBruto != null ? _moneda.format(margenBruto) : '—',
          margenPct:
              margenPct != null ? '${margenPct.toStringAsFixed(1)}%' : '—',
          colorFoodCost: fcColor,
          lineasExtra: [
            if (precio != null && precio > 0) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Precio de venta',
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey.shade700),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _moneda.format(precio),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Preparación ${widget.nombreProducto}',
                    style:
                        TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                ),
                const SizedBox(width: 8),
                Text(_moneda.format(prepSolo)),
              ],
            ),
            if (incluidos > 0)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Productos incluidos',
                      style:
                          TextStyle(fontSize: 13, color: Colors.grey.shade700),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(_moneda.format(incluidos)),
                ],
              ),
            const Divider(height: 20),
            if (precio != null && precio > 0 && total > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Food cost = ${_moneda.format(total)} ÷ ${_moneda.format(precio)} '
                  '= ${fc?.toStringAsFixed(1) ?? '—'}% · '
                  'Margen = ${_moneda.format(precio - total)} '
                  '(${margenPct?.toStringAsFixed(1) ?? '—'}%)',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text(
            '¿Cómo se configura?',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AnaliticaTokens.ink,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '1. Crea el producto en Menú (ej. Rosquete)\n'
                '2. Aquí pulsa «Agregar del menú» y la cantidad (ej. 2)\n'
                '3. El costo de cada uno sale de su receta en Costos\n'
                '4. Pulsa «Recalcular todo» si cambiaste insumos recientemente',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final opciones = _opcionesIncluir;
    final toolbar = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (!_modoEdicion) ...[
          FilledButton.icon(
            onPressed: opciones.isEmpty ? _avisarSinOpciones : _elegirProductoMenu,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Agregar del menú'),
          ),
          if (_filas.isNotEmpty)
            OutlinedButton.icon(
              onPressed: () => setState(() => _modoEdicion = true),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Editar'),
            ),
        ] else ...[
          OutlinedButton(
            onPressed: _guardando
                ? null
                : () {
                    setState(() => _modoEdicion = false);
                    _cargar();
                  },
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: _guardando ? null : _guardar,
            icon: _guardando
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined, size: 18),
            label: Text(_guardando ? 'Guardando…' : 'Guardar'),
          ),
          FilledButton.tonalIcon(
            onPressed: _elegirProductoMenu,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Agregar'),
          ),
        ],
      ],
    );

    final cuerpo = <Widget>[
      toolbar,
      const SizedBox(height: 12),
      if (_modoEdicion && _filas.isNotEmpty)
        for (var i = 0; i < _filas.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _filaEditor(i, opciones),
        ]
      else
        _vistaResumen(),
    ];

    if (widget.scrollExterno) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: cuerpo,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          toolbar,
          const SizedBox(height: 12),
          Expanded(
            child: _modoEdicion && _filas.isNotEmpty
                ? ListView.separated(
                    controller: _listaCtrl,
                    itemCount: _filas.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _filaEditor(i, opciones),
                  )
                : ListView(
                    children: [_vistaResumen()],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _filaEditor(int i, List<Map<String, dynamic>> opciones) {
    final fila = _filas[i];
    final idSel = fila['producto_incluido_id'] as String?;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<String>(
              initialValue: opciones.any((p) => p['id'] == idSel)
                  ? idSel
                  : opciones.isNotEmpty
                      ? opciones.first['id'] as String?
                      : null,
              decoration: const InputDecoration(
                labelText: 'Producto del menú',
                border: OutlineInputBorder(),
              ),
              items: opciones
                  .map(
                    (p) => DropdownMenuItem(
                      value: p['id'] as String,
                      child: Text(p['nombre'] as String? ?? ''),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => fila['producto_incluido_id'] = v);
              },
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 72,
            child: TextFormField(
              initialValue: '${fila['cantidad']}',
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Cant.',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) {
                fila['cantidad'] =
                    double.tryParse(v.replaceAll(',', '.')) ?? 1;
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => setState(() => _filas.removeAt(i)),
          ),
        ],
      ),
    );
  }
}
