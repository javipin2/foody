import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';
import 'package:reserva_canchas/features/costeo/domain/unidad_costeo_util.dart';
import 'package:reserva_canchas/features/costeo/presentation/widgets/costeo_ui_bloques.dart';
import 'package:reserva_canchas/features/inventario/data/inventario_repository.dart';
import 'package:reserva_canchas/features/inventario/presentation/widgets/stock_visual_widgets.dart';

/// Editor inline de receta de un producto (insumos, subrecetas, empaques).
class RecetaProductoPanel extends StatefulWidget {
  const RecetaProductoPanel({
    super.key,
    required this.productoId,
    required this.nombreProducto,
    required this.ingredientes,
    required this.subrecetas,
    required this.onGuardado,
    this.precioVenta,
    this.costoPreparacion,
    this.foodCostPct,
    this.margenPct,
    this.margenBruto,
    this.colorFoodCost,
  });

  final String productoId;
  final String nombreProducto;
  final List<Map<String, dynamic>> ingredientes;
  final List<Map<String, dynamic>> subrecetas;
  final VoidCallback onGuardado;
  final double? precioVenta;
  final double? costoPreparacion;
  final double? foodCostPct;
  final double? margenPct;
  final double? margenBruto;
  final Color? colorFoodCost;

  @override
  State<RecetaProductoPanel> createState() => _RecetaProductoPanelState();
}

class _RecetaProductoPanelState extends State<RecetaProductoPanel> {
  final _repo = InventarioRepository();
  List<Map<String, dynamic>> _filas = [];
  bool _cargando = true;
  bool _guardando = false;
  bool _modoEdicion = false;
  double _margenError = 0.05;

  final _moneda = NumberFormat.currency(
    locale: 'es_CO',
    symbol: r'$',
    decimalDigits: 0,
  );

  final _monedaDetalle = NumberFormat.currency(
    locale: 'es_CO',
    symbol: r'$',
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();
    _cargarReceta();
  }

  @override
  void didUpdateWidget(RecetaProductoPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.productoId != widget.productoId) {
      _modoEdicion = false;
      _cargarReceta();
    }
  }

  Map<String, dynamic>? _ingredientePorId(String? id) {
    if (id == null) return null;
    for (final ing in widget.ingredientes) {
      if (ing['id'] == id) return ing;
    }
    return null;
  }

  Map<String, dynamic>? _subrecetaPorId(String? id) {
    if (id == null) return null;
    for (final sr in widget.subrecetas) {
      if (sr['id'] == id) return sr;
    }
    return null;
  }

  String _nombreInsumo(String? id) =>
      _ingredientePorId(id)?['nombre'] as String? ?? '';

  Map<String, dynamic> _filaPorDefecto({String tipo = 'ingrediente'}) {
    if (tipo == 'subreceta' && widget.subrecetas.isNotEmpty) {
      final sr = widget.subrecetas.first;
      return <String, dynamic>{
        'tipo_item': 'subreceta',
        'subreceta_id': sr['id'] as String,
        'cantidad': 1.0,
        'unidad': sr['unidad_resultado'] as String? ?? 'g',
      };
    }
    return <String, dynamic>{
      'tipo_item': tipo,
      'ingrediente_id': null,
      'nombre_insumo': '',
      'cantidad': 1.0,
      'unidad': 'und',
    };
  }

  Future<void> _cargarReceta() async {
    setState(() => _cargando = true);
    try {
      final receta = await _repo.recetaProducto(widget.productoId);
      final items = receta['items'] as List<dynamic>? ?? [];
      final margen = num.tryParse('${receta['margen_error']}')?.toDouble();
      final filas = items.map((e) {
        final map = Map<String, dynamic>.from(e as Map);
        final tipo = map['tipo_item'] as String? ?? 'ingrediente';
        final ingId = map['ingrediente_id'] as String?;
        return <String, dynamic>{
          'tipo_item': tipo,
          if (ingId != null) 'ingrediente_id': ingId,
          if (map['subreceta_id'] != null)
            'subreceta_id': map['subreceta_id'] as String,
          'nombre_insumo': _nombreInsumo(ingId),
          'cantidad': map['cantidad'] is num
              ? (map['cantidad'] as num).toDouble()
              : double.tryParse(
                    '${map['cantidad']}'.replaceAll(',', '.'),
                  ) ??
                  1,
          'unidad': map['unidad'] as String? ?? 'und',
        };
      }).toList();
      if (!mounted) return;
      setState(() {
        _margenError = margen ?? 0.05;
        _filas = filas.isEmpty ? [_filaPorDefecto()] : filas;
        _cargando = false;
        _modoEdicion = filas.isEmpty;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _filas = [_filaPorDefecto()];
        _cargando = false;
        _modoEdicion = true;
      });
    }
  }

  void _vincularInsumo(Map<String, dynamic> fila, Map<String, dynamic> ing) {
    fila['ingrediente_id'] = ing['id'] as String;
    fila['nombre_insumo'] = ing['nombre'] as String? ?? '';
    fila['unidad'] = ing['unidad_base'] as String? ?? 'und';
  }

  Map<String, dynamic>? _resolverInsumoPorNombre(String texto) {
    final q = texto.trim().toLowerCase();
    if (q.isEmpty) return null;
    for (final ing in widget.ingredientes) {
      if ((ing['nombre'] as String? ?? '').toLowerCase() == q) return ing;
    }
    for (final ing in widget.ingredientes) {
      if ((ing['nombre'] as String? ?? '').toLowerCase().contains(q)) {
        return ing;
      }
    }
    return null;
  }

  double _costoUnitarioInsumo(Map<String, dynamic>? ing) {
    if (ing == null) return 0;
    return num.tryParse(
          '${ing['costo_real'] ?? ing['costo_unitario_actual']}',
        )?.toDouble() ??
        0;
  }

  double _valorLinea(Map<String, dynamic> fila) {
    final cant = (fila['cantidad'] as num?)?.toDouble() ?? 0;
    final tipo = fila['tipo_item'] as String? ?? 'ingrediente';
    if (tipo == 'subreceta') {
      final sr = _subrecetaPorId(fila['subreceta_id'] as String?);
      if (sr == null) return 0;
      final costo = num.tryParse('${sr['costo_por_unidad']}')?.toDouble() ?? 0;
      final uLinea = fila['unidad'] as String? ?? 'und';
      final uRes = sr['unidad_resultado'] as String? ?? uLinea;
      final cantEfectiva = convertirCantidadCosteo(cant, uLinea, uRes);
      return cantEfectiva * costo;
    }
    final ing = _ingredientePorId(fila['ingrediente_id'] as String?);
    if (ing == null) return 0;
    final unidadLinea = fila['unidad'] as String? ?? 'und';
    final unidadBase = ing['unidad_base'] as String? ?? unidadLinea;
    final rend = num.tryParse('${ing['rendimiento_porcentaje']}')?.toDouble();
    final pesoNeto = num.tryParse('${ing['peso_neto']}')?.toDouble();
    return costoLineaIngredienteUi(
      cantidad: cant,
      unidadLinea: unidadLinea,
      unidadBaseInsumo: unidadBase,
      costoUnitarioBase: _costoUnitarioInsumo(ing),
      rendimientoPorcentaje: rend,
      pesoNeto: pesoNeto,
    );
  }

  double get _costoLocalFilas =>
      _filas.fold<double>(0, (s, f) => s + _valorLinea(f));

  bool _esSoloCosto(Map<String, dynamic> fila) {
    final ing = _ingredientePorId(fila['ingrediente_id'] as String?);
    if (ing == null) return false;
    if (ing['descontar_stock'] == false) return true;
    final u = (ing['unidad_base'] as String? ?? '').toLowerCase();
    return u == 'servicio' || u == 'porción' || u == 'porcion';
  }

  void _vincularSubreceta(Map<String, dynamic> fila, Map<String, dynamic> sr) {
    fila['subreceta_id'] = sr['id'] as String;
    fila['unidad'] = sr['unidad_resultado'] as String? ?? 'und';
  }

  String _etiquetaCantidadSubreceta(Map<String, dynamic> fila) {
    final u = normalizarUnidadCosteo(fila['unidad'] as String? ?? 'und');
    switch (u) {
      case 'und':
        return 'Cuántas unidades';
      case 'kg':
        return 'Cuántos kilos';
      case 'g':
        return 'Cuántos gramos';
      case 'l':
        return 'Cuántos litros';
      case 'ml':
        return 'Cuántos mililitros';
      default:
        return 'Cantidad ($u)';
    }
  }

  String _etiquetaCantidad(Map<String, dynamic> fila) {
    final tipo = fila['tipo_item'] as String? ?? 'ingrediente';
    if (tipo == 'subreceta') return _etiquetaCantidadSubreceta(fila);
    if (_esSoloCosto(fila)) return 'Costo en este plato';
    final u = (fila['unidad'] as String? ?? 'und').toLowerCase();
    switch (u) {
      case 'und':
        return 'Unidades';
      case 'kg':
        return 'Kilos';
      case 'g':
        return 'Gramos';
      case 'l':
        return 'Litros';
      case 'ml':
        return 'Mililitros';
      default:
        return 'Cantidad';
    }
  }

  Future<void> _guardar() async {
    if (widget.ingredientes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Crea insumos en «Insumos» antes de armar la receta'),
        ),
      );
      return;
    }

    final paraGuardar = <Map<String, dynamic>>[];
    for (final fila in _filas) {
      final tipo = fila['tipo_item'] as String? ?? 'ingrediente';
      if (tipo == 'subreceta') {
        if (fila['subreceta_id'] == null) continue;
        final sr = _subrecetaPorId(fila['subreceta_id'] as String);
        if (sr == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Subreceta no encontrada')),
          );
          return;
        }
        _vincularSubreceta(fila, sr);
        paraGuardar.add(Map<String, dynamic>.from(fila));
        continue;
      }

      final nombre = (fila['nombre_insumo'] as String? ?? '').trim();
      if (fila['ingrediente_id'] == null && nombre.isEmpty) continue;
      if (fila['ingrediente_id'] == null && nombre.isNotEmpty) {
        final match = _resolverInsumoPorNombre(nombre);
        if (match != null) _vincularInsumo(fila, match);
      }
      if (fila['ingrediente_id'] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              nombre.isEmpty
                  ? 'Completa cada línea de la receta'
                  : '«$nombre» no existe en Insumos.',
            ),
          ),
        );
        return;
      }
      final ing = _ingredientePorId(fila['ingrediente_id'] as String)!;
      fila['unidad'] = ing['unidad_base'] as String? ?? 'und';
      paraGuardar.add(Map<String, dynamic>.from(fila));
    }

    if (paraGuardar.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega al menos una línea a la receta')),
      );
      return;
    }

    setState(() => _guardando = true);
    try {
      await _repo.configurarReceta(
        productoId: widget.productoId,
        items: paraGuardar,
      );
      widget.onGuardado();
      if (mounted) {
        setState(() => _modoEdicion = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Receta guardada')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensajeErrorHttp(e, contexto: 'guardar receta')),
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Widget _lineaResumen(Map<String, dynamic> fila) {
    final tipo = fila['tipo_item'] as String? ?? 'ingrediente';
    final cant = fila['cantidad'];
    final total = _valorLinea(fila);

    String nombre;
    String detalle;
    String? precioUnit;

    if (tipo == 'subreceta') {
      final sr = _subrecetaPorId(fila['subreceta_id'] as String?);
      nombre = sr?['nombre'] as String? ?? 'Subreceta';
      final uLinea = fila['unidad'] as String? ?? 'und';
      final uRes = sr?['unidad_resultado'] as String? ?? uLinea;
      detalle = '$cant $uLinea';
      final unit = num.tryParse('${sr?['costo_por_unidad']}') ?? 0;
      if (unit > 0) {
        final unitLinea = costoUnitarioEnUnidadLinea(
          unidadLinea: uLinea,
          unidadBaseInsumo: uRes,
          costoUnitarioBase: unit.toDouble(),
        );
        precioUnit = '${_monedaDetalle.format(unitLinea)}/$uLinea';
      }
    } else {
      final ing = _ingredientePorId(fila['ingrediente_id'] as String?);
      nombre = ing?['nombre'] as String? ?? fila['nombre_insumo'] as String? ?? '—';
      final uLinea = fila['unidad'] as String? ?? 'und';
      final uBase = ing?['unidad_base'] as String? ?? uLinea;
      detalle = '$cant $uLinea';
      final unitBase = _costoUnitarioInsumo(ing);
      if (unitBase > 0) {
        if (unidadesCosteoCompatibles(uLinea, uBase) &&
            normalizarUnidadCosteo(uLinea) != normalizarUnidadCosteo(uBase)) {
          final unitLinea = costoUnitarioEnUnidadLinea(
            unidadLinea: uLinea,
            unidadBaseInsumo: uBase,
            costoUnitarioBase: unitBase,
          );
          precioUnit = '${_monedaDetalle.format(unitLinea)}/$uLinea';
        } else {
          precioUnit = '${_monedaDetalle.format(unitBase)}/$uBase';
        }
      }
    }

    Widget? stockExtra;
    if (tipo != 'subreceta') {
      final ing = _ingredientePorId(fila['ingrediente_id'] as String?);
      if (ing != null) {
        final uLinea = fila['unidad'] as String? ?? 'und';
        stockExtra = StockLineaReceta(
          cantidadReceta: cant is num ? cant : 0,
          unidadReceta: uLinea,
          stockActual: num.tryParse('${ing['stock_actual']}') ?? 0,
          stockMinimo: num.tryParse('${ing['stock_minimo']}') ?? 0,
          unidadBase: ing['unidad_base'] as String? ?? uLinea,
          descontarStock: ing['descontar_stock'] != false,
        );
      }
    }

    return CosteoLineaResumen(
      nombre: nombre,
      detalle: detalle,
      detallePrecio: precioUnit,
      total: _moneda.format(total),
      extra: stockExtra,
    );
  }

  Widget _vistaResumen() {
    final directos = <Map<String, dynamic>>[];
    final subrecetas = <Map<String, dynamic>>[];
    final indirectos = <Map<String, dynamic>>[];

    for (final fila in _filas) {
      final tipo = fila['tipo_item'] as String? ?? 'ingrediente';
      if (tipo == 'subreceta') {
        subrecetas.add(fila);
      } else if (tipo == 'empaque' || _esSoloCosto(fila)) {
        indirectos.add(fila);
      } else if (fila['ingrediente_id'] != null) {
        directos.add(fila);
      }
    }

    final costoRecetaSinMargen = _costoLocalFilas;
    final costoReceta = costoRecetaSinMargen * (1 + _margenError);
    // Esta pestaña es SOLO la receta — nunca sumar productos incluidos aquí.
    final costoTotal =
        costoReceta > 0 ? costoReceta : (widget.costoPreparacion ?? 0);
    final precio = widget.precioVenta;
    final fc = precio != null && precio > 0 && costoTotal > 0
        ? (costoTotal / precio) * 100
        : null;
    final margenBruto = precio != null ? precio - costoTotal : null;
    final margenPct = precio != null && precio > 0 && costoTotal > 0
        ? ((precio - costoTotal) / precio) * 100
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CosteoGrupoReceta(
          titulo: 'Ingredientes directos',
          subtitulo: 'descuentan inventario al vender',
          colorBadge: ColoresFoody.primario,
          lineas: directos.map(_lineaResumen).toList(),
        ),
        CosteoGrupoReceta(
          titulo: 'Subrecetas reutilizables',
          subtitulo: 'ya costeadas, se jalan por gramo',
          colorBadge: ColoresFoody.secundario,
          lineas: subrecetas.map(_lineaResumen).toList(),
        ),
        CosteoGrupoReceta(
          titulo: 'Costos indirectos',
          subtitulo: 'solo costo, no descuentan inventario',
          colorBadge: const Color(0xFFBCAAA4),
          lineas: indirectos.map(_lineaResumen).toList(),
        ),
        if (directos.isEmpty && subrecetas.isEmpty && indirectos.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Aún no hay receta.\nPulsa «Editar receta» para agregar insumos.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
        const SizedBox(height: 8),
        CosteoResumenPie(
          tituloCosto: 'Costo de preparación (solo receta)',
          costoTotal: _moneda.format(costoTotal),
          foodCostPct: fc,
          margenBruto: margenBruto != null ? _moneda.format(margenBruto) : '—',
          margenPct: margenPct != null ? '${margenPct.toStringAsFixed(1)}%' : '—',
          colorFoodCost: widget.colorFoodCost ?? ColoresFoody.exito,
          lineasExtra: [
            if (costoRecetaSinMargen > 0) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Suma de insumos',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                  Text(_moneda.format(costoRecetaSinMargen)),
                ],
              ),
              if (_margenError > 0)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '+ Margen de error ${(_margenError * 100).toStringAsFixed(0)}%',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                    Text(
                      _moneda.format(costoTotal - costoRecetaSinMargen),
                    ),
                  ],
                ),
              const Divider(height: 16),
            ],
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Estos porcentajes son solo de la receta. '
                'Si el plato incluye otros productos del menú, '
                'el margen real está en «Qué va incluido».',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
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
      return const Center(child: CircularProgressIndicator());
    }
    if (widget.ingredientes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Primero crea insumos en la pestaña «Insumos».',
          style: TextStyle(color: Colors.grey.shade700),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _barraAcciones(),
          if (_modoEdicion) ...[
            const SizedBox(height: 8),
            Text(
              'Agrega cada insumo con su cantidad. El costo se calcula solo.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
          const SizedBox(height: 14),
          Expanded(
            child: _modoEdicion
                ? ListView.separated(
                    padding: const EdgeInsets.only(bottom: 8),
                    itemCount: _filas.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _filaEditor(i),
                  )
                : ListView(
                    children: [_vistaResumen()],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _barraAcciones() {
    if (!_modoEdicion) {
      return Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.icon(
          onPressed: () => setState(() => _modoEdicion = true),
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('Editar receta'),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton(
              onPressed: _guardando
                  ? null
                  : () {
                      setState(() => _modoEdicion = false);
                      _cargarReceta();
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
              label: Text(_guardando ? 'Guardando…' : 'Guardar receta'),
            ),
          ],
        ),
        FilledButton.tonalIcon(
          onPressed: () => setState(() => _filas.add(_filaPorDefecto())),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Agregar línea'),
        ),
      ],
    );
  }

  Widget _filaEditor(int i) {
    final fila = _filas[i];
    final tipo = fila['tipo_item'] as String? ?? 'ingrediente';
    final valor = _valorLinea(fila);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: ColoresFoody.primario.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${i + 1}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: ColoresFoody.primario,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: tipo,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de línea',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: 'ingrediente',
                      child: Text('Insumo directo'),
                    ),
                    if (widget.subrecetas.isNotEmpty)
                      const DropdownMenuItem(
                        value: 'subreceta',
                        child: Text('Subreceta'),
                      ),
                    const DropdownMenuItem(
                      value: 'empaque',
                      child: Text('Empaque (llevar)'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _filas[i] = _filaPorDefecto(tipo: v));
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                color: Colors.red.shade400,
                tooltip: 'Quitar línea',
                onPressed: _filas.length > 1
                    ? () => setState(() => _filas.removeAt(i))
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (tipo == 'subreceta') ...[
            DropdownButtonFormField<String>(
              initialValue: fila['subreceta_id'] as String?,
              decoration: const InputDecoration(
                labelText: 'Subreceta',
                border: OutlineInputBorder(),
              ),
              items: widget.subrecetas
                  .map(
                    (sr) => DropdownMenuItem(
                      value: sr['id'] as String,
                      child: Text(sr['nombre'] as String? ?? ''),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  final sr = _subrecetaPorId(v);
                  if (sr != null) {
                    setState(() => _vincularSubreceta(fila, sr));
                  }
                }
              },
            ),
            if (fila['subreceta_id'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Se mide en ${fila['unidad'] ?? 'und'} '
                  '(unidad de la subreceta, no en gramos)',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ),
          ] else
            Autocomplete<Map<String, dynamic>>(
              initialValue: TextEditingValue(
                text: fila['nombre_insumo'] as String? ?? '',
              ),
              displayStringForOption: (o) => o['nombre'] as String? ?? '',
              optionsBuilder: (text) {
                final q = text.text.trim().toLowerCase();
                if (q.isEmpty) return widget.ingredientes;
                return widget.ingredientes.where(
                  (ing) => (ing['nombre'] as String? ?? '')
                      .toLowerCase()
                      .contains(q),
                );
              },
              onSelected: (ing) {
                setState(() => _vincularInsumo(fila, ing));
              },
              fieldViewBuilder: (ctx, ctrl, focus, onSubmit) {
                return TextFormField(
                  controller: ctrl,
                  focusNode: focus,
                  decoration: InputDecoration(
                    labelText: tipo == 'empaque' ? 'Empaque' : 'Insumo',
                    hintText: 'Buscar…',
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (v) {
                    fila['nombre_insumo'] = v;
                    final match = _resolverInsumoPorNombre(v);
                    if (match != null &&
                        (match['nombre'] as String).toLowerCase() ==
                            v.trim().toLowerCase()) {
                      _vincularInsumo(fila, match);
                    } else {
                      fila['ingrediente_id'] = null;
                    }
                    setState(() {});
                  },
                );
              },
            ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final campoCantidad = TextFormField(
                key: ValueKey('cant-${fila['ingrediente_id']}-$i'),
                initialValue: '${fila['cantidad']}',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: _etiquetaCantidad(fila),
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (v) {
                  setState(() {
                    fila['cantidad'] =
                        double.tryParse(v.replaceAll(',', '.')) ?? 1;
                  });
                },
              );
              final subtotal = _bloqueSubtotal(valor);

              if (constraints.maxWidth < 260) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    campoCantidad,
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: subtotal,
                    ),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: campoCantidad),
                  const SizedBox(width: 14),
                  subtotal,
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _bloqueSubtotal(double valor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Subtotal',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 2),
        Text(
          valor > 0 ? _moneda.format(valor) : '—',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: valor > 0 ? ColoresFoody.primario : Colors.grey.shade500,
          ),
        ),
      ],
    );
  }
}
