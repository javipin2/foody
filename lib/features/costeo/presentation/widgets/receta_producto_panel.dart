import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_tokens.dart';
import 'package:reserva_canchas/features/costeo/domain/unidad_costeo_util.dart';
import 'package:reserva_canchas/features/costeo/presentation/widgets/costeo_ui_bloques.dart';
import 'package:reserva_canchas/features/inventario/data/inventario_repository.dart';
import 'package:reserva_canchas/features/inventario/presentation/widgets/dialogo_insumo_form.dart';
import 'package:reserva_canchas/features/inventario/presentation/widgets/stock_visual_widgets.dart';

/// Editor inline de receta de un producto, bebida o topping.
class RecetaProductoPanel extends StatefulWidget {
  const RecetaProductoPanel({
    super.key,
    required this.productoId,
    required this.nombreProducto,
    required this.ingredientes,
    required this.subrecetas,
    required this.onGuardado,
    this.tipoEntidad = 'producto',
    this.sucursalId,
    this.onInsumosCambiados,
    this.onIrInsumos,
    this.precioVenta,
    this.costoPreparacion,
    this.foodCostPct,
    this.margenPct,
    this.margenBruto,
    this.colorFoodCost,
    this.scrollExterno = false,
  });

  final String productoId;
  /// producto | bebida | topping
  final String tipoEntidad;
  final String nombreProducto;
  final List<Map<String, dynamic>> ingredientes;
  final List<Map<String, dynamic>> subrecetas;
  final VoidCallback onGuardado;
  /// NAV-MC-04: permite crear insumos sin salir de Costos.
  final String? sucursalId;
  final VoidCallback? onInsumosCambiados;
  /// NAV-MG-03: navegar a Insumos (p. ej. crear subrecetas).
  final VoidCallback? onIrInsumos;
  final double? precioVenta;
  final double? costoPreparacion;
  final double? foodCostPct;
  final double? margenPct;
  final double? margenBruto;
  final Color? colorFoodCost;
  /// Padre hace el scroll (un solo ListView en Costos).
  final bool scrollExterno;

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
  late final TextEditingController _margenPctCtrl;

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
    _margenPctCtrl = TextEditingController(text: '5');
    _cargarReceta();
  }

  @override
  void dispose() {
    _margenPctCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(RecetaProductoPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.productoId != widget.productoId ||
        oldWidget.tipoEntidad != widget.tipoEntidad) {
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

  List<Map<String, dynamic>> get _insumosEmpaque => widget.ingredientes
      .where((i) => (i['categoria_insumo'] as String? ?? '') == 'empaque')
      .toList();

  List<Map<String, dynamic>> _insumosParaTipo(String tipo) {
    if (tipo == 'empaque') return _insumosEmpaque;
    if (tipo == 'ingrediente') {
      return widget.ingredientes
          .where((i) => (i['categoria_insumo'] as String? ?? '') != 'empaque')
          .toList();
    }
    return widget.ingredientes;
  }

  double _sumaLineas(Iterable<Map<String, dynamic>> lineas) =>
      lineas.fold<double>(0, (s, f) => s + _valorLinea(f));

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
    if (tipo == 'empaque' && _insumosEmpaque.isNotEmpty) {
      final ing = _insumosEmpaque.first;
      return <String, dynamic>{
        'tipo_item': 'empaque',
        'ingrediente_id': ing['id'] as String,
        'nombre_insumo': ing['nombre'] as String? ?? '',
        'cantidad': 1.0,
        'unidad': ing['unidad_base'] as String? ?? 'und',
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
      final receta = await _repo.recetaProducto(
        widget.productoId,
        tipoEntidad: widget.tipoEntidad,
      );
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
        _margenPctCtrl.text = (_margenError * 100).toStringAsFixed(1);
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
    final base = ing['unidad_base'] as String? ?? 'und';
    final actual = fila['unidad'] as String?;
    if (actual == null || !unidadesCosteoCompatibles(actual, base)) {
      fila['unidad'] = base;
    }
  }

  Map<String, dynamic>? _resolverInsumoPorNombre(
    String texto, {
    List<Map<String, dynamic>>? pool,
  }) {
    final lista = pool ?? widget.ingredientes;
    final q = texto.trim().toLowerCase();
    if (q.isEmpty) return null;
    for (final ing in lista) {
      if ((ing['nombre'] as String? ?? '').toLowerCase() == q) return ing;
    }
    for (final ing in lista) {
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

  bool _esSoloCosto(Map<String, dynamic> fila) {
    final ing = _ingredientePorId(fila['ingrediente_id'] as String?);
    if (ing == null) return false;
    if (ing['descontar_stock'] == false) return true;
    final u = (ing['unidad_base'] as String? ?? '').toLowerCase();
    return u == 'servicio' || u == 'porción' || u == 'porcion';
  }

  void _vincularSubreceta(Map<String, dynamic> fila, Map<String, dynamic> sr) {
    fila['subreceta_id'] = sr['id'] as String;
    final uRes = sr['unidad_resultado'] as String? ?? 'und';
    final actual = fila['unidad'] as String?;
    if (actual == null || !unidadesCosteoCompatibles(actual, uRes)) {
      fila['unidad'] = uRes;
    }
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

  /// NAV-MC-04: crea insumo (o empaque) sin salir de Costos y refresca la lista.
  Future<void> _crearInsumoDesdeCostos({String? categoriaInicial}) async {
    final sid = widget.sucursalId;
    if (sid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sin sucursal para crear el insumo')),
      );
      return;
    }
    final res = await mostrarDialogoInsumo(
      context: context,
      categoriaInicial: categoriaInicial,
    );
    if (res == null || !mounted) return;
    try {
      if (res.esSoloCosto) {
        await _repo.crearIngrediente(
          sucursalId: sid,
          nombre: res.nombre,
          proveedor: res.proveedor,
          unidadBase: res.unidadBase,
          categoriaInsumo: res.categoriaInsumo,
          costoUnitario: res.costoUnitario,
          descontarStock: res.descontarStock,
        );
      } else {
        await _repo.crearIngrediente(
          sucursalId: sid,
          nombre: res.nombre,
          proveedor: res.proveedor,
          unidadBase: res.unidadBase,
          categoriaInsumo: res.categoriaInsumo,
          precioCompra: res.precioCompra,
          pesoBruto: res.pesoBruto,
          pesoNeto: res.pesoNeto,
          stockMinimo: res.stockMinimo,
          stockActual: res.stockActual,
        );
      }
      widget.onInsumosCambiados?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              categoriaInicial == 'empaque'
                  ? 'Empaque creado. Ya puedes agregarlo a la receta.'
                  : 'Insumo creado. Ya puedes agregarlo a la receta.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensajeErrorHttp(e, contexto: 'crear insumo'))),
        );
      }
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
        final uRes = sr['unidad_resultado'] as String? ?? 'und';
        final uLinea = fila['unidad'] as String? ?? uRes;
        if (!unidadesCosteoCompatibles(uLinea, uRes)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Unidad «$uLinea» incompatible con «${sr['nombre']}» ($uRes). '
                'Usa g/kg o ml/L.',
              ),
            ),
          );
          return;
        }
        fila['unidad'] = normalizarUnidadCosteo(uLinea);
        paraGuardar.add(Map<String, dynamic>.from(fila));
        continue;
      }

      final nombre = (fila['nombre_insumo'] as String? ?? '').trim();
      if (fila['ingrediente_id'] == null && nombre.isEmpty) continue;
      final poolInsumos = _insumosParaTipo(tipo);
      if (fila['ingrediente_id'] == null && nombre.isNotEmpty) {
        final match = _resolverInsumoPorNombre(nombre, pool: poolInsumos);
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
      if (tipo == 'empaque' &&
          (ing['categoria_insumo'] as String? ?? '') != 'empaque') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '«${ing['nombre']}» no es un empaque. '
              'Créalo en Insumos con categoría empaque.',
            ),
          ),
        );
        return;
      }
      final uBase = ing['unidad_base'] as String? ?? 'und';
      final uLinea = fila['unidad'] as String? ?? uBase;
      if (!unidadesCosteoCompatibles(uLinea, uBase)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '«${ing['nombre']}» está en $uBase; no puedes usar «$uLinea». '
              'Elige g/kg o ml/L de la misma familia.',
            ),
          ),
        );
        return;
      }
      fila['unidad'] = normalizarUnidadCosteo(uLinea);
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
      final margenPct =
          double.tryParse(_margenPctCtrl.text.replaceAll(',', '.')) ?? 5;
      _margenError = (margenPct / 100).clamp(0, 0.5);
      await _repo.configurarReceta(
        productoId: widget.productoId,
        items: paraGuardar,
        margenError: _margenError,
        tipoEntidad: widget.tipoEntidad,
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
      etiqueta: tipo == 'empaque' ? 'Empaque' : null,
    );
  }

  Widget _vistaResumen() {
    final directos = <Map<String, dynamic>>[];
    final subrecetas = <Map<String, dynamic>>[];
    final empaques = <Map<String, dynamic>>[];
    final indirectos = <Map<String, dynamic>>[];

    for (final fila in _filas) {
      final tipo = fila['tipo_item'] as String? ?? 'ingrediente';
      if (tipo == 'subreceta') {
        subrecetas.add(fila);
      } else if (tipo == 'empaque') {
        empaques.add(fila);
      } else if (_esSoloCosto(fila)) {
        indirectos.add(fila);
      } else if (fila['ingrediente_id'] != null) {
        directos.add(fila);
      }
    }

    final sumaSinEmpaque =
        _sumaLineas([...directos, ...subrecetas, ...indirectos]);
    final sumaEmpaques = _sumaLineas(empaques);
    final costoMesa = sumaSinEmpaque * (1 + _margenError);
    final costoDomicilio = costoMesa + sumaEmpaques;
    // Preview de líneas (edición); % food cost / margen = solo API.
    final costoTotal =
        costoMesa > 0 ? costoMesa : (widget.costoPreparacion ?? 0);
    // AQ-SOLID-08: % food cost / margen solo del API.
    final fc = widget.foodCostPct;
    final margenBruto = widget.margenBruto;
    final margenPct = widget.margenPct;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CosteoGrupoReceta(
          titulo: 'Ingredientes directos',
          subtitulo: 'descuentan inventario al vender',
          colorBadge: AnaliticaTokens.ventas,
          lineas: directos.map(_lineaResumen).toList(),
        ),
        CosteoGrupoReceta(
          titulo: 'Subrecetas reutilizables',
          subtitulo: 'ya costeadas, se jalan por gramo',
          colorBadge: AnaliticaTokens.pedidos,
          lineas: subrecetas.map(_lineaResumen).toList(),
        ),
        CosteoGrupoReceta(
          titulo: 'Costos indirectos',
          subtitulo: 'solo costo, no descuentan inventario',
          colorBadge: AnaliticaTokens.inkMuted,
          lineas: indirectos.map(_lineaResumen).toList(),
        ),
        CosteoGrupoReceta(
          titulo: 'Empaques domicilio',
          subtitulo: 'solo para llevar / domicilio, no en mesa',
          colorBadge: const Color(0xFFD97706),
          lineas: empaques.map(_lineaResumen).toList(),
        ),
        if (directos.isEmpty &&
            subrecetas.isEmpty &&
            indirectos.isEmpty &&
            empaques.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Icon(
                  Icons.blender_outlined,
                  size: 36,
                  color: AnaliticaTokens.inkSoft,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Aún no hay receta',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AnaliticaTokens.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pulsa «Editar receta» para agregar insumos.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        CosteoResumenPie(
          tituloCosto: 'Costo mesa (sin empaques)',
          costoTotal: _moneda.format(costoTotal),
          foodCostPct: fc,
          margenBruto: margenBruto != null ? _moneda.format(margenBruto) : '—',
          margenPct: margenPct != null ? '${margenPct.toStringAsFixed(1)}%' : '—',
          colorFoodCost: widget.colorFoodCost ?? AnaliticaTokens.inventario,
          lineasExtra: [
            if (sumaSinEmpaque > 0) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Suma insumos + subrecetas + indirectos',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                  Text(_moneda.format(sumaSinEmpaque)),
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
                    Text(_moneda.format(costoMesa - sumaSinEmpaque)),
                  ],
                ),
            ],
            if (sumaEmpaques > 0) ...[
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '+ Empaques domicilio',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                  Text(_moneda.format(sumaEmpaques)),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Costo domicilio / llevar',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  Text(
                    _moneda.format(costoDomicilio),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AnaliticaTokens.pedidos,
                    ),
                  ),
                ],
              ),
            ],
            const Divider(height: 16),
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'El costo mesa no incluye empaques. '
                'El margen real con productos incluidos está en «Incluidos».',
                style: TextStyle(fontSize: 11, color: AnaliticaTokens.inkMuted),
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
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AnaliticaTokens.ink,
            ),
          ),
        ),
      );
    }
    if (widget.ingredientes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.inventory_2_outlined,
              size: 36,
              color: AnaliticaTokens.inkSoft,
            ),
            const SizedBox(height: 12),
            const Text(
              'Primero crea insumos',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AnaliticaTokens.ink,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Sin insumos no se puede armar la receta de este plato.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AnaliticaTokens.inkMuted,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: widget.sucursalId == null
                  ? null
                  : () => _crearInsumoDesdeCostos(),
              style: FilledButton.styleFrom(
                backgroundColor: AnaliticaTokens.ink,
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Crear primer insumo'),
            ),
          ],
        ),
      );
    }

    // Un solo scroll con el padre (Costos) cuando [scrollExterno].
    final cuerpo = <Widget>[
      _barraAcciones(),
      if (_modoEdicion) ...[
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AnaliticaTokens.surfaceMuted,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AnaliticaTokens.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Cómo armar la receta',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                  color: AnaliticaTokens.ink,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '1) Elige tipo · 2) Busca el insumo · 3) Indica cantidad · 4) Guarda',
                style: TextStyle(
                  fontSize: 12,
                  color: AnaliticaTokens.inkMuted,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  SizedBox(
                    width: 118,
                    child: TextFormField(
                      controller: _margenPctCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Merma %',
                        helperText: 'opcional',
                        isDense: true,
                        border: OutlineInputBorder(),
                        suffixText: '%',
                      ),
                      onChanged: (v) {
                        final pct =
                            double.tryParse(v.replaceAll(',', '.')) ?? 5;
                        setState(() {
                          _margenError = (pct / 100).clamp(0, 0.5);
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Holgura sobre insumos de mesa (no empaques).',
                      style: TextStyle(
                        fontSize: 11,
                        color: AnaliticaTokens.inkSoft,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < _filas.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _filaEditor(i),
        ],
      ] else ...[
        const SizedBox(height: 12),
        _vistaResumen(),
      ],
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 8),
        children: cuerpo,
      ),
    );
  }

  Widget _barraAcciones() {
    if (!_modoEdicion) {
      return Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.icon(
          onPressed: () => setState(() => _modoEdicion = true),
          style: FilledButton.styleFrom(
            backgroundColor: AnaliticaTokens.ink,
          ),
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('Editar receta'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.icon(
              onPressed: _guardando ? null : _guardar,
              style: FilledButton.styleFrom(
                backgroundColor: AnaliticaTokens.ink,
              ),
              icon: _guardando
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_outlined, size: 18),
              label: Text(_guardando ? 'Guardando…' : 'Guardar receta'),
            ),
            OutlinedButton(
              onPressed: _guardando
                  ? null
                  : () {
                      setState(() => _modoEdicion = false);
                      _cargarReceta();
                    },
              child: const Text('Cancelar'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          'Agregar a la receta',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AnaliticaTokens.inkSoft,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => setState(
                () => _filas.add(_filaPorDefecto(tipo: 'ingrediente')),
              ),
              icon: const Icon(Icons.restaurant_outlined, size: 16),
              label: const Text('Insumo'),
            ),
            // NAV-MC-11: siempre visible; si no hay subrecetas, guía a Insumos.
            OutlinedButton.icon(
              onPressed: widget.subrecetas.isNotEmpty
                  ? () => setState(
                        () => _filas.add(_filaPorDefecto(tipo: 'subreceta')),
                      )
                  : () {
                      final ir = widget.onIrInsumos;
                      if (ir != null) {
                        ir();
                        return;
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Crea subrecetas en Insumos › Subrecetas y vuelve aquí',
                          ),
                        ),
                      );
                    },
              icon: const Icon(Icons.layers_outlined, size: 16),
              label: Text(
                widget.subrecetas.isEmpty ? 'Subreceta…' : 'Subreceta',
              ),
            ),
            // NAV-MC-04: si no hay empaques, el botón abre el diálogo de creación.
            OutlinedButton.icon(
              onPressed: _insumosEmpaque.isEmpty
                  ? (widget.sucursalId == null
                      ? null
                      : () => _crearInsumoDesdeCostos(
                            categoriaInicial: 'empaque',
                          ))
                  : () => setState(
                        () => _filas.add(_filaPorDefecto(tipo: 'empaque')),
                      ),
              icon: const Icon(Icons.takeout_dining_outlined, size: 16),
              label: Text(
                _insumosEmpaque.isEmpty ? 'Crear empaque' : 'Empaque',
              ),
            ),
            TextButton(
              onPressed: widget.sucursalId == null
                  ? null
                  : () => _crearInsumoDesdeCostos(),
              style: TextButton.styleFrom(
                foregroundColor: AnaliticaTokens.inkMuted,
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('Nuevo insumo…'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _filaEditor(int i) {
    final fila = _filas[i];
    final tipo = fila['tipo_item'] as String? ?? 'ingrediente';
    final valor = _valorLinea(fila);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 12),
      decoration: BoxDecoration(
        color: AnaliticaTokens.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AnaliticaTokens.border),
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
                  color: AnaliticaTokens.surfaceMuted,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${i + 1}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AnaliticaTokens.ink,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: tipo,
                  decoration: const InputDecoration(
                    labelText: 'Tipo',
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
                color: AnaliticaTokens.alertas,
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
                isDense: true,
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
                  'Puedes usar g/kg o ml/L según la familia de la subreceta; '
                  'el backend convierte al costear y descontar stock.',
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
                final pool = _insumosParaTipo(tipo);
                final q = text.text.trim().toLowerCase();
                if (q.isEmpty) return pool;
                return pool.where(
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
                    final pool = _insumosParaTipo(tipo);
                    final match = _resolverInsumoPorNombre(v, pool: pool);
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
              final campoUnidad = DropdownButtonFormField<String>(
                key: ValueKey(
                  'u-$i-${fila['ingrediente_id']}-${fila['subreceta_id']}',
                ),
                initialValue: _unidadLineaValida(fila),
                decoration: const InputDecoration(
                  labelText: 'Unidad',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: _opcionesUnidadLinea(fila)
                    .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => fila['unidad'] = v);
                },
              );
              final subtotal = _bloqueSubtotal(valor);

              if (constraints.maxWidth < 320) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    campoCantidad,
                    const SizedBox(height: 10),
                    campoUnidad,
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
                  Expanded(flex: 2, child: campoCantidad),
                  const SizedBox(width: 10),
                  Expanded(child: campoUnidad),
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

  List<String> _opcionesUnidadLinea(Map<String, dynamic> fila) {
    final tipo = fila['tipo_item'] as String? ?? 'ingrediente';
    if (tipo == 'subreceta') {
      final sr = _subrecetaPorId(fila['subreceta_id'] as String?);
      final base = sr?['unidad_resultado'] as String? ?? 'und';
      return unidadesDeFamiliaCosteo(base);
    }
    final ing = _ingredientePorId(fila['ingrediente_id'] as String?);
    final base = ing?['unidad_base'] as String? ??
        (fila['unidad'] as String? ?? 'und');
    return unidadesDeFamiliaCosteo(base);
  }

  String _unidadLineaValida(Map<String, dynamic> fila) {
    final opciones = _opcionesUnidadLinea(fila);
    final actual = normalizarUnidadCosteo(fila['unidad'] as String? ?? '');
    if (opciones.contains(actual)) return actual;
    return opciones.first;
  }

  Widget _bloqueSubtotal(double valor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Subtotal',
          style: TextStyle(fontSize: 11, color: AnaliticaTokens.inkSoft),
        ),
        const SizedBox(height: 2),
        Text(
          valor > 0 ? _moneda.format(valor) : '—',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: valor > 0 ? AnaliticaTokens.ink : AnaliticaTokens.inkSoft,
          ),
        ),
      ],
    );
  }
}
