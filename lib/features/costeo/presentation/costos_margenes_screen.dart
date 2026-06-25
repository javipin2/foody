import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
import 'package:reserva_canchas/features/catalogo/data/catalogo_admin_repository.dart';
import 'package:reserva_canchas/features/costeo/domain/unidad_costeo_util.dart';
import 'package:reserva_canchas/features/costeo/presentation/widgets/costeo_ui_bloques.dart';
import 'package:reserva_canchas/features/costeo/presentation/widgets/producto_items_incluidos_panel.dart';
import 'package:reserva_canchas/features/costeo/presentation/widgets/receta_producto_panel.dart';
import 'package:reserva_canchas/features/inventario/data/costeo_repository.dart';
import 'package:reserva_canchas/features/inventario/data/inventario_repository.dart';
import 'package:reserva_canchas/features/inventario/presentation/widgets/stock_visual_widgets.dart';

/// Costos y márgenes — master-detail responsive vinculado al menú.
class CostosMargenesScreen extends StatefulWidget {
  const CostosMargenesScreen({
    super.key,
    this.sucursalId,
    this.productoIdInicial,
  });

  final String? sucursalId;
  final String? productoIdInicial;

  @override
  State<CostosMargenesScreen> createState() => _CostosMargenesScreenState();
}

class _CostosMargenesScreenState extends State<CostosMargenesScreen>
    with SingleTickerProviderStateMixin {
  final _costeoRepo = CosteoRepository();
  final _inventarioRepo = InventarioRepository();
  final _catalogoRepo = CatalogoAdminRepository();

  List<Map<String, dynamic>> _productos = [];
  List<Map<String, dynamic>> _ingredientes = [];
  List<Map<String, dynamic>> _subrecetas = [];
  String? _seleccionadoId;
  double? _umbralMargen;
  int _productosBajoMargen = 0;

  bool _cargando = true;
  bool _recalculandoSucursal = false;
  bool _guardandoMargen = false;
  String? _error;
  Map<String, dynamic>? _impactoStock;
  bool _cargandoImpacto = false;
  final _busquedaCtrl = TextEditingController();
  String _filtroLista = 'todos';
  TabController? _tabDetalleCtrl;

  TabController get _tabsDetalle =>
      _tabDetalleCtrl ??= TabController(length: 2, vsync: this);

  final _moneda = NumberFormat.currency(
    locale: 'es_CO',
    symbol: r'$',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _tabsDetalle;
    _seleccionadoId = widget.productoIdInicial;
    _cargar();
  }

  @override
  void dispose() {
    _tabDetalleCtrl?.dispose();
    _tabDetalleCtrl = null;
    _busquedaCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(CostosMargenesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.productoIdInicial != widget.productoIdInicial &&
        widget.productoIdInicial != null) {
      _seleccionarProducto(widget.productoIdInicial);
    }
  }

  Future<void> _cargar({bool silent = false}) async {
    final sid = widget.sucursalId;
    if (sid == null) {
      setState(() {
        _cargando = false;
        _error = 'Sin sucursal en sesión';
      });
      return;
    }
    if (!silent) {
      setState(() {
        _cargando = true;
        _error = null;
      });
    }
    try {
      final results = await Future.wait([
        _costeoRepo.resumen(sid),
        _costeoRepo.subrecetas(sid),
        _inventarioRepo.ingredientes(sid),
      ]);
      if (!mounted) return;
      final resumen = results[0] as Map<String, dynamic>;
      final productosRaw = resumen['productos'];
      final productos = productosRaw is List
          ? productosRaw
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList()
          : <Map<String, dynamic>>[];
      setState(() {
        _productos = productos;
        _subrecetas = List<Map<String, dynamic>>.from(results[1] as List);
        _ingredientes = List<Map<String, dynamic>>.from(results[2] as List);
        _umbralMargen = num.tryParse('${resumen['umbral_margen']}')?.toDouble();
        _productosBajoMargen =
            (resumen['productos_bajo_margen'] as num?)?.toInt() ?? 0;
        if (_seleccionadoId == null && productos.isNotEmpty) {
          _seleccionadoId = productos.first['id'] as String?;
        } else if (_seleccionadoId != null &&
            !productos.any((p) => p['id'] == _seleccionadoId)) {
          _seleccionadoId =
              productos.isNotEmpty ? productos.first['id'] as String? : null;
        }
        _cargando = false;
      });
      await _cargarImpactoStock();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _cargando = false;
      });
    }
  }

  Future<void> _cargarImpactoStock() async {
    final sid = widget.sucursalId;
    final pid = _seleccionadoId;
    if (sid == null || pid == null) {
      if (mounted) setState(() => _impactoStock = null);
      return;
    }
    setState(() => _cargandoImpacto = true);
    try {
      final impacto = await _costeoRepo.impactoStockProducto(
        productoId: pid,
        sucursalId: sid,
      );
      if (!mounted) return;
      setState(() {
        _impactoStock = impacto;
        _cargandoImpacto = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _impactoStock = null;
        _cargandoImpacto = false;
      });
    }
  }

  void _seleccionarProducto(String? id) {
    setState(() => _seleccionadoId = id);
    final tabs = _tabDetalleCtrl;
    if (tabs != null && tabs.index != 0) {
      tabs.index = 0;
    }
    _cargarImpactoStock();
  }

  Map<String, dynamic>? get _productoSeleccionado {
    if (_seleccionadoId == null) return null;
    for (final p in _productos) {
      if (p['id'] == _seleccionadoId) return p;
    }
    return null;
  }

  Future<void> _recalcularSucursal() async {
    final sid = widget.sucursalId;
    if (sid == null || _recalculandoSucursal) return;
    setState(() => _recalculandoSucursal = true);
    try {
      final res = await _costeoRepo.recalcular(sid);
      await _cargar();
      if (mounted) {
        final nProd = res['productos_recalculados'] ?? 0;
        final nSub = res['subrecetas_recalculadas'] ?? 0;
        final nCombo = res['combos_recalculados'] ?? 0;
        final bajo = _productosBajoMargen;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Recálculo: $nProd platos, $nSub subrecetas, $nCombo combos'
              '${bajo > 0 ? ' · $bajo bajo umbral' : ''}',
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _recalculandoSucursal = false);
    }
  }

  Future<void> _recalcularProducto(String productoId) async {
    final sid = widget.sucursalId;
    if (sid == null) return;
    try {
      await _costeoRepo.recalcularProducto(productoId, sid);
      await _cargar(silent: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al recalcular: $e')),
        );
      }
    }
  }

  Future<void> _guardarMargenObjetivo(double margen) async {
    final p = _productoSeleccionado;
    if (p == null || _guardandoMargen) return;
    setState(() => _guardandoMargen = true);
    try {
      await _catalogoRepo.actualizarMargenObjetivo(
        p['id'] as String,
        margen,
      );
      final idx = _productos.indexWhere((x) => x['id'] == p['id']);
      if (idx >= 0) {
        _productos[idx] = {
          ..._productos[idx],
          'margen_objetivo': margen,
        };
      }
      await _recalcularProducto(p['id'] as String);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _guardandoMargen = false);
    }
  }

  double _num(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

  double _margenObjetivoActual(Map<String, dynamic> p) {
    final m = num.tryParse('${p['margen_objetivo']}');
    if (m == null) return 35;
    return m.toDouble().clamp(5, 80);
  }

  Color _colorFoodCost(num? foodCost) {
    if (foodCost == null) return Colors.grey;
    if (foodCost < 35) return Colors.green.shade700;
    if (foodCost <= 50) return Colors.orange.shade800;
    return Colors.red.shade700;
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            FilledButton(onPressed: _cargar, child: const Text('Reintentar')),
          ],
        ),
      );
    }

    final ancho = MediaQuery.sizeOf(context).width;
    final esAncho = ancho >= 900;
    final umbral = _umbralMargen ?? 35;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _cabecera(umbral),
        Expanded(
          child: esAncho
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: 320, child: _listaMaestro(umbral)),
                    const VerticalDivider(width: 1),
                    Expanded(child: _panelDetalle()),
                  ],
                )
              : _vistaMovil(),
        ),
      ],
    );
  }

  Widget _vistaMovil() {
    if (_seleccionadoId == null) {
      return _listaMaestro(_umbralMargen ?? 35);
    }
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => _seleccionadoId = null),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Volver al listado'),
          ),
        ),
        Expanded(child: _panelDetalle()),
      ],
    );
  }

  Widget _cabecera(double umbral) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Costos y márgenes',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Elige un plato → revisa costo → ajusta receta o incluidos',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Actualizar',
                onPressed: _cargar,
                icon: const Icon(Icons.refresh),
              ),
              FilledButton.tonalIcon(
                onPressed: _recalculandoSucursal ? null : _recalcularSucursal,
                icon: _recalculandoSucursal
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.calculate_outlined, size: 20),
                label: Text(
                  _recalculandoSucursal ? 'Recalculando…' : 'Recalcular todo',
                ),
              ),
            ],
          ),
          if (_productosBajoMargen > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: Colors.orange.shade800),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$_productosBajoMargen plato(s) bajo $umbral% de margen',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade900,
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

  List<Map<String, dynamic>> get _productosFiltrados {
    final q = _busquedaCtrl.text.trim().toLowerCase();
    return _productos.where((p) {
      final nombre = (p['nombre'] as String? ?? '').toLowerCase();
      if (q.isNotEmpty && !nombre.contains(q)) return false;
      final sinReceta = p['costo_calculado'] == null;
      final margen = num.tryParse('${p['margen_porcentaje']}');
      final umbral = _umbralMargen ?? 35;
      switch (_filtroLista) {
        case 'sin_receta':
          return sinReceta;
        case 'bajo_margen':
          return margen != null && margen < umbral;
        default:
          return true;
      }
    }).toList();
  }

  void _mostrarAjusteMargen(Map<String, dynamic> p) {
    var margenObj = _margenObjetivoActual(p);
    final costo = _num(p['costo_calculado']);
    if (costo <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Primero configura la receta para tener un costo de referencia',
          ),
        ),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final precioCalc = calcularPrecioSugeridoUi(costo, margenObj);
          final divisor = (1 - margenObj / 100).toStringAsFixed(2);

          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              0,
              20,
              24 + MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Margen objetivo',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Precio sugerido = costo ÷ (1 − margen%). '
                  'Usa el costo del servidor, igual que la calculadora.',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Costo del plato: ${_moneda.format(costo)}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_moneda.format(costo)} ÷ $divisor = ${_moneda.format(precioCalc)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '${margenObj.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: ColoresFoody.primario,
                  ),
                  textAlign: TextAlign.center,
                ),
                Slider(
                  value: margenObj.clamp(5, 80),
                  min: 5,
                  max: 80,
                  divisions: 75,
                  activeColor: ColoresFoody.primario,
                  onChanged: _guardandoMargen
                      ? null
                      : (v) => setSheet(() => margenObj = v),
                ),
                FilledButton.icon(
                  onPressed: _guardandoMargen
                      ? null
                      : () async {
                          await _guardarMargenObjetivo(margenObj);
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          await _aplicarPrecioSugeridoConMargen(
                            p['id'] as String,
                            precioCalc.toDouble(),
                          );
                        },
                  icon: _guardandoMargen
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.price_check_outlined),
                  label: Text(
                    _guardandoMargen
                        ? 'Guardando…'
                        : 'Aplicar precio ${_moneda.format(precioCalc)}',
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _guardandoMargen
                      ? null
                      : () async {
                          await _guardarMargenObjetivo(margenObj);
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                  child: const Text('Solo guardar margen (sin cambiar precio)'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _aplicarPrecioSugeridoConMargen(
    String productoId,
    double precio,
  ) async {
    try {
      await _catalogoRepo.actualizarPrecio(productoId, precio);
      await _recalcularProducto(productoId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Precio actualizado a ${_moneda.format(precio)}'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Widget _listaMaestro(double umbral) {
    final productos = _productosFiltrados;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            controller: _busquedaCtrl,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Buscar plato…',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              _chipFiltro('todos', 'Todos'),
              _chipFiltro('sin_receta', 'Sin receta'),
              _chipFiltro('bajo_margen', 'Bajo margen'),
            ],
          ),
        ),
        Expanded(
          child: productos.isEmpty
              ? Center(
                  child: Text(
                    _productos.isEmpty
                        ? 'Sin productos en el menú'
                        : 'Ningún plato coincide con el filtro',
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  itemCount: productos.length,
                  itemBuilder: (_, i) => _tarjetaProducto(productos[i], umbral),
                ),
        ),
      ],
    );
  }

  Widget _chipFiltro(String id, String label) {
    final sel = _filtroLista == id;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: sel,
        onSelected: (_) => setState(() => _filtroLista = id),
        selectedColor: ColoresFoody.primario.withValues(alpha: 0.15),
        checkmarkColor: ColoresFoody.primario,
        labelStyle: TextStyle(
          color: sel ? ColoresFoody.primario : Colors.grey.shade700,
          fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _tarjetaProducto(Map<String, dynamic> p, double umbral) {
    final id = p['id'] as String;
    final seleccionado = _seleccionadoId == id;
    final margen = num.tryParse('${p['margen_porcentaje']}');
    final foodCost = num.tryParse('${p['food_cost_porcentaje']}');
    final bajo = margen != null && margen < umbral;
    final sinReceta = p['costo_calculado'] == null;
    final fcColor = _colorFoodCost(foodCost);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: seleccionado
            ? ColoresFoody.primario.withValues(alpha: 0.08)
            : Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _seleccionarProducto(id),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: seleccionado
                    ? ColoresFoody.primario.withValues(alpha: 0.5)
                    : Colors.grey.shade200,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: sinReceta
                        ? Colors.amber.shade700
                        : bajo
                            ? Colors.orange.shade700
                            : ColoresFoody.exito,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p['nombre'] as String? ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        sinReceta
                            ? 'Falta receta'
                            : '${_moneda.format(_num(p['precio']))} · margen ${margen?.toStringAsFixed(0) ?? '—'}%',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!sinReceta && foodCost != null)
                  Text(
                    'FC ${foodCost.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: fcColor,
                    ),
                  ),
                const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _panelDetalle() {
    final p = _productoSeleccionado;
    if (p == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.restaurant_menu_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'Selecciona un plato del listado',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    final precio = _num(p['precio']);
    final costo = p['costo_calculado'] != null
        ? num.tryParse('${p['costo_calculado']}')
        : null;
    final margenReal = num.tryParse('${p['margen_porcentaje']}');
    final foodCost = num.tryParse('${p['food_cost_porcentaje']}');
    final fcColor = _colorFoodCost(foodCost);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: CosteoEtiquetaSeccion(
                      titulo: 'El plato que el cliente ve en el menú',
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _mostrarAjusteMargen(p),
                    icon: const Icon(Icons.tune, size: 18),
                    label: const Text('Margen objetivo'),
                  ),
                ],
              ),
              CosteoPlatoClienteCard(
                nombre: p['nombre'] as String? ?? '',
                precio: _moneda.format(precio),
              ),
              if (_cargandoImpacto)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(minHeight: 2),
                )
              else if (_impactoStock != null)
                StockImpactoProductoCard(impacto: _impactoStock!),
              const CosteoFlechaFlujo(),
              const CosteoEtiquetaSeccion(
                titulo: 'Lo que el sistema costea por detrás',
              ),
            ],
          ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: TabBar(
              controller: _tabsDetalle,
              labelColor: ColoresFoody.primario,
              unselectedLabelColor: Colors.grey.shade600,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              tabs: const [
                Tab(text: 'Qué cuesta hacerlo'),
                Tab(text: 'Qué va incluido'),
              ],
            ),
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabsDetalle,
            children: [
              RecetaProductoPanel(
                key: ValueKey('receta-${p['id']}'),
                productoId: p['id'] as String,
                nombreProducto: p['nombre'] as String? ?? '',
                ingredientes: _ingredientes,
                subrecetas: _subrecetas,
                onGuardado: () => _recalcularProducto(p['id'] as String),
                precioVenta: precio,
                colorFoodCost: fcColor,
              ),
              ProductoItemsIncluidosPanel(
                key: ValueKey('incluye-${p['id']}'),
                productoId: p['id'] as String,
                nombreProducto: p['nombre'] as String? ?? '',
                productosDisponibles: _productos,
                onGuardado: () => _recalcularProducto(p['id'] as String),
                onCostosActualizados: () => _cargar(silent: true),
                precioVenta: precio,
                costoTotalProducto: costo?.toDouble(),
                foodCostPct: foodCost?.toDouble(),
                margenPct: margenReal?.toDouble(),
              ),
            ],
          ),
        ),
      ],
    );
  }

}
