import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:reserva_canchas/core/layout/foody_breakpoints.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';
import 'package:reserva_canchas/core/saas_ui/saas_ui.dart';
import 'package:reserva_canchas/core/widgets/foody_estado_ui.dart';
import 'package:reserva_canchas/core/widgets/foody_scroll_horizontal_fade.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_skeleton.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_tokens.dart';
import 'package:reserva_canchas/features/catalogo/data/catalogo_admin_repository.dart';
import 'package:reserva_canchas/features/costeo/domain/unidad_costeo_util.dart';
import 'package:reserva_canchas/features/costeo/presentation/widgets/costeo_stitch_ui.dart';
import 'package:reserva_canchas/features/costeo/presentation/widgets/costeo_ui_bloques.dart';
import 'package:reserva_canchas/features/costeo/presentation/widgets/producto_items_incluidos_panel.dart';
import 'package:reserva_canchas/features/costeo/presentation/widgets/popularidad_costeo_sheet.dart';
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
    this.onVolverAlMenu,
    this.onIrInsumos,
  });

  final String? sucursalId;
  final String? productoIdInicial;
  /// NAV-ADM-20: regresar a Menú tras venir desde un producto.
  final VoidCallback? onVolverAlMenu;
  /// NAV-MG-03: atajo a Insumos (subrecetas / mercado).
  final VoidCallback? onIrInsumos;

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
  double? _margenObjetivoDefault;
  int _productosBajoMargen = 0;

  bool _cargando = true;
  bool _recalculandoSucursal = false;
  bool _guardandoMargen = false;
  bool _guardandoMargenesSede = false;
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
      final bebidasRaw = resumen['bebidas'];
      final toppingsRaw = resumen['toppings'];
      final combosRaw = resumen['combos'];
      final productos = <Map<String, dynamic>>[];
      if (productosRaw is List) {
        for (final e in productosRaw) {
          if (e is Map) {
            productos.add({
              ...Map<String, dynamic>.from(e),
              'tipo_entidad': e['tipo_entidad'] ?? 'producto',
            });
          }
        }
      }
      if (bebidasRaw is List) {
        for (final e in bebidasRaw) {
          if (e is Map) {
            productos.add({
              ...Map<String, dynamic>.from(e),
              'tipo_entidad': 'bebida',
            });
          }
        }
      }
      if (toppingsRaw is List) {
        for (final e in toppingsRaw) {
          if (e is Map) {
            productos.add({
              ...Map<String, dynamic>.from(e),
              'tipo_entidad': 'topping',
            });
          }
        }
      }
      if (combosRaw is List) {
        for (final e in combosRaw) {
          if (e is Map) {
            final m = Map<String, dynamic>.from(e);
            productos.add({
              ...m,
              'tipo_entidad': 'combo',
              // UI unifica precio; combos usan precio_fijo en API.
              'precio': m['precio'] ?? m['precio_fijo'],
            });
          }
        }
      }
      productos.sort(
        (a, b) => ('${a['nombre']}'.toLowerCase())
            .compareTo('${b['nombre']}'.toLowerCase()),
      );
      setState(() {
        _productos = productos;
        _subrecetas = List<Map<String, dynamic>>.from(results[1] as List);
        _ingredientes = List<Map<String, dynamic>>.from(results[2] as List);
        _umbralMargen = num.tryParse('${resumen['umbral_margen']}')?.toDouble();
        _margenObjetivoDefault =
            num.tryParse('${resumen['margen_objetivo_default']}')?.toDouble();
        _productosBajoMargen =
            (resumen['productos_bajo_margen'] as num?)?.toInt() ?? 0;
        // NAV-MC-21: no auto-abrir el primer plato (en móvil se pierde el listado).
        // Solo conserva selección válida o la que vino por deep-link.
        if (_seleccionadoId != null &&
            !productos.any((p) => p['id'] == _seleccionadoId)) {
          _seleccionadoId = widget.productoIdInicial != null &&
                  productos.any((p) => p['id'] == widget.productoIdInicial)
              ? widget.productoIdInicial
              : null;
        }
        _cargando = false;
      });
      await _cargarImpactoStock();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = mensajeErrorHttp(e, contexto: 'cargar costos');
        _cargando = false;
      });
    }
  }

  Future<void> _cargarImpactoStock() async {
    final sid = widget.sucursalId;
    final pid = _seleccionadoId;
    final p = _productoSeleccionado;
    if (sid == null || pid == null) {
      if (mounted) setState(() => _impactoStock = null);
      return;
    }
    final tipo = p?['tipo_entidad'] as String? ?? 'producto';
    if (tipo == 'combo') {
      if (mounted) setState(() => _impactoStock = null);
      return;
    }
    setState(() => _cargandoImpacto = true);
    try {
      final impacto = await _costeoRepo.impactoStockProducto(
        productoId: pid,
        sucursalId: sid,
        tipoEntidad: tipo,
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
    setState(() {
      _seleccionadoId = id;
    });
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
          SnackBar(content: Text(mensajeErrorHttp(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _recalculandoSucursal = false);
    }
  }

  Future<void> _recalcularProducto(String productoId) async {
    final sid = widget.sucursalId;
    if (sid == null) return;
    String tipo = 'producto';
    for (final x in _productos) {
      if (x['id'] == productoId) {
        tipo = x['tipo_entidad'] as String? ?? 'producto';
        break;
      }
    }
    try {
      if (tipo == 'combo') {
        await _costeoRepo.recalcularCombo(productoId, sid);
      } else {
        await _costeoRepo.recalcularProducto(
          productoId,
          sid,
          tipoEntidad: tipo,
        );
      }
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
    final tipo = p['tipo_entidad'] as String? ?? 'producto';
    if (tipo != 'producto') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tipo == 'combo'
                ? 'El margen del combo sale del precio fijo y del costo recalculado.'
                : 'Ajusta el precio del extra en Menú; el margen se calcula solo.',
          ),
        ),
      );
      return;
    }
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
          SnackBar(content: Text(mensajeErrorHttp(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _guardandoMargen = false);
    }
  }

  Future<void> _guardarMargenesSede() async {
    final sid = widget.sucursalId;
    if (sid == null || _guardandoMargenesSede) return;

    final margenDef =
        (_margenObjetivoDefault ?? 35).clamp(5, 80).toDouble();
    final umbral = (_umbralMargen ?? 35).clamp(5, 80).toDouble();

    setState(() => _guardandoMargenesSede = true);
    try {
      await _costeoRepo.actualizarMargenesSucursal(
        sid,
        margenObjetivoDefault: margenDef,
        umbralAlertaMargen: umbral,
      );
      if (!mounted) return;
      await _cargar(silent: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensajeErrorHttp(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _guardandoMargenesSede = false);
    }
  }

  double _num(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

  double _margenObjetivoActual(Map<String, dynamic> p) {
    final m = num.tryParse('${p['margen_objetivo']}');
    final fallback = (_margenObjetivoDefault ?? 35).clamp(5, 80).toDouble();
    if (m == null) return fallback;
    return m.toDouble().clamp(5, 80).toDouble();
  }

  Color _colorFoodCost(num? foodCost) {
    if (foodCost == null) return AnaliticaTokens.inkSoft;
    if (foodCost < 35) return AnaliticaTokens.inventario;
    if (foodCost <= 50) return const Color(0xFFD97706);
    return AnaliticaTokens.alertas;
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return ColoredBox(
        color: AnaliticaTokens.canvas,
        child: AnaliticaSkeleton.tab(),
      );
    }
    if (_error != null) {
      return FoodyEstadoUi.desdeMensaje(
        mensaje: _error!,
        onReintentar: _cargar,
      );
    }

    final ancho = FoodyBreakpoints.widthOf(context);
    final esAncho = FoodyBreakpoints.splitOperacion(ancho);
    final compacto = FoodyBreakpoints.esCompact(ancho);
    final umbral = _umbralMargen ?? 35;

    // Lista = mockups listado (scroll único). Detalle = mockup 2 columnas.
    if (_seleccionadoId == null) {
      return _paginaLista(
        umbral: umbral,
        esAncho: esAncho,
        compacto: compacto,
      );
    }
    return _paginaDetalle(
      umbral: umbral,
      esAncho: esAncho,
      compacto: compacto,
    );
  }

  Widget _paginaLista({
    required double umbral,
    required bool esAncho,
    required bool compacto,
  }) {
    final productos = _productosFiltrados;
    final padH = compacto ? 12.0 : 20.0;

    return ColoredBox(
      color: SaaSTokens.canvas(context),
      child: Stack(
        children: [
          CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _cabecera(
                  umbral,
                  esAncho: esAncho,
                  compacto: compacto,
                  enDetalle: false,
                ),
              ),
              SliverToBoxAdapter(
                child: _resumenEstadoCards(
                  umbral,
                  esAncho: esAncho,
                  compacto: compacto,
                ),
              ),
              if (widget.sucursalId != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(padH, 8, padH, 4),
                    child: _cardMargenesSedeEditor(compacto: compacto),
                  ),
                ),
              if (widget.onIrInsumos != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(padH, 0, padH, 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: widget.onIrInsumos,
                        style: TextButton.styleFrom(
                          foregroundColor: CosteoStitch.teal,
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.inventory_2_outlined, size: 16),
                        label: Text(
                          compacto
                              ? '¿Falta un ingrediente? Insumos'
                              : '¿Falta un ingrediente? Crear en Insumos',
                        ),
                      ),
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(padH, 8, padH, 4),
                  child: esAncho
                      ? Row(
                          children: [
                            Expanded(child: _campoBusqueda()),
                            const SizedBox(width: 12),
                            Flexible(child: _pillsFiltro(umbral)),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _campoBusqueda(),
                            const SizedBox(height: 8),
                            _pillsFiltro(umbral),
                          ],
                        ),
                ),
              ),
              if (productos.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _vacioLista(),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(padH, 4, padH, compacto ? 96 : 32),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => _tarjetaProducto(
                        productos[i],
                        umbral,
                        filaAncha: esAncho,
                      ),
                      childCount: productos.length,
                    ),
                  ),
                ),
            ],
          ),
          if (compacto)
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton.extended(
                onPressed: _armarPrimeraReceta,
                backgroundColor: CosteoStitch.coral,
                foregroundColor: Colors.white,
                elevation: 3,
                icon: const Icon(Icons.restaurant_menu_rounded, size: 20),
                label: const Text(
                  'ARMAR RECETA',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _paginaDetalle({
    required double umbral,
    required bool esAncho,
    required bool compacto,
  }) {
    return ColoredBox(
      color: SaaSTokens.canvas(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _cabecera(
            umbral,
            esAncho: esAncho,
            compacto: compacto,
            enDetalle: true,
          ),
          Expanded(
            child: esAncho
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 340,
                        child: ListView(
                          primary: false,
                          padding: const EdgeInsets.fromLTRB(20, 8, 12, 24),
                          children: _detalleColumnaIzquierda(
                            umbral: umbral,
                            compacto: compacto,
                          ),
                        ),
                      ),
                      VerticalDivider(
                        width: 1,
                        color: SaaSTokens.border(context),
                      ),
                      Expanded(
                        child: _panelDetalle(
                          compacto: compacto,
                          enColumnaDerecha: true,
                        ),
                      ),
                    ],
                  )
                : _panelDetalle(compacto: compacto, enColumnaDerecha: false),
          ),
        ],
      ),
    );
  }

  Widget _campoBusqueda() {
    return TextField(
      controller: _busquedaCtrl,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: 'Buscar plato…',
        hintStyle: TextStyle(color: SaaSTokens.inkSoft(context)),
        prefixIcon: Icon(
          Icons.search,
          size: 18,
          color: SaaSTokens.inkSoft(context),
        ),
        isDense: true,
        filled: true,
        fillColor: SaaSTokens.surface(context),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: SaaSTokens.border(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: SaaSTokens.border(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: CosteoStitch.coral),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }

  Widget _pillsFiltro(double umbral) {
    final conteos = _conteosEstado(umbral);
    return FoodyScrollHorizontalFade(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            CosteoFiltroPill(
              label: 'Todos',
              selected: _filtroLista == 'todos',
              onTap: () => setState(() => _filtroLista = 'todos'),
            ),
            CosteoFiltroPill(
              label: 'Críticos',
              selected: _filtroLista == 'bajo_margen',
              onTap: () => setState(() => _filtroLista = 'bajo_margen'),
            ),
            CosteoFiltroPill(
              label: 'Saludables',
              selected: _filtroLista == 'saludable',
              onTap: () => setState(() => _filtroLista = 'saludable'),
            ),
            CosteoFiltroPill(
              label: 'Sin datos',
              selected: _filtroLista == 'sin_receta',
              onTap: () => setState(() => _filtroLista = 'sin_receta'),
              dot: conteos.sinDatos > 0 ? CosteoStitch.coral : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _vacioLista() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.restaurant_menu_outlined,
              size: 40,
              color: SaaSTokens.inkSoft(context),
            ),
            const SizedBox(height: 12),
            Text(
              _productos.isEmpty
                  ? 'Sin ítems en el menú'
                  : 'Ningún ítem coincide con el filtro',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: SaaSTokens.ink(context),
              ),
            ),
            if (_productos.isEmpty && widget.onVolverAlMenu != null) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: widget.onVolverAlMenu,
                style: FilledButton.styleFrom(
                  backgroundColor: CosteoStitch.coral,
                ),
                icon: const Icon(Icons.restaurant_menu_outlined),
                label: const Text('Ir a Menú'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _armarPrimeraReceta() {
    setState(() => _filtroLista = 'sin_receta');
    final sin = _productos.where((p) {
      return p['receta_id'] == null && p['costo_calculado'] == null;
    });
    if (sin.isNotEmpty) {
      _seleccionarProducto(sin.first['id'] as String);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Todos los ítems ya tienen costo')),
      );
    }
  }

  String _categoriaDe(Map<String, dynamic> p) {
    final tipo = p['tipo_entidad'] as String? ?? 'producto';
    if (tipo == 'bebida') return 'Bebida';
    if (tipo == 'topping') return 'Topping / adicional';
    if (tipo == 'combo') return 'Combo';
    return p['categoria_nombre'] as String? ?? 'Plato';
  }

  String _precioSugLabel(Map<String, dynamic> p) {
    final sug = p['precio_sugerido'];
    if (sug != null && _num(sug) > 0) return _moneda.format(_num(sug));
    final costo = p['costo_calculado'];
    if (costo != null && _num(costo) > 0) {
      return _moneda.format(
        calcularPrecioSugeridoUi(_num(costo), _margenObjetivoActual(p)),
      );
    }
    return '—';
  }

  List<Widget> _detalleColumnaIzquierda({
    required double umbral,
    required bool compacto,
  }) {
    final p = _productoSeleccionado;
    if (p == null) return const [];
    final precio = _num(p['precio']);
    final margenReal = num.tryParse('${p['margen_porcentaje']}');
    final sinReceta = p['costo_calculado'] == null;
    final id = p['id'] as String? ?? '';
    final idCorto =
        '#${id.length > 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase()}';
    return [
      CosteoPreviewHeroCard(
        nombre: p['nombre'] as String? ?? '',
        precioLabel: _moneda.format(precio),
        imagenUrl: p['imagen_url'] as String?,
        categoria: _categoriaDe(p),
        idCorto: idCorto,
        esPremium: margenReal != null && margenReal >= umbral,
      ),
      const SizedBox(height: 12),
      CosteoEstadoFinancieroCard(
        margenPct: margenReal,
        nivel: costeoNivelDe(
          margenPct: margenReal,
          sinReceta: sinReceta,
          umbral: umbral,
        ),
        umbral: umbral,
        onAjustar: () => _mostrarAjusteMargen(p),
      ),
    ];
  }


  ({int saludable, int bajo, int sinDatos, double? margenGlobal})
      _conteosEstado(double umbral) {
    var s = 0, b = 0, n = 0;
    var suma = 0.0;
    var conMargen = 0;
    for (final p in _productos) {
      final sinReceta =
          p['receta_id'] == null && p['costo_calculado'] == null;
      final margen = num.tryParse('${p['margen_porcentaje']}');
      final nivel = costeoNivelDe(
        margenPct: margen,
        sinReceta: sinReceta,
        umbral: umbral,
      );
      switch (nivel) {
        case CosteoRiesgoNivel.saludable:
          s++;
        case CosteoRiesgoNivel.bajo:
        case CosteoRiesgoNivel.critico:
          b++;
        case CosteoRiesgoNivel.sinDatos:
          n++;
      }
      if (margen != null) {
        suma += margen.toDouble();
        conMargen++;
      }
    }
    return (
      saludable: s,
      bajo: b,
      sinDatos: n,
      margenGlobal: conMargen == 0 ? null : suma / conMargen,
    );
  }

  Widget _resumenEstadoCards(
    double umbral, {
    required bool esAncho,
    required bool compacto,
  }) {
    final c = _conteosEstado(umbral);
    final cards = [
      CosteoStatusSummaryCard(
        titulo: 'Saludable',
        cantidad: c.saludable,
        leyenda: 'Margen ≥ ${umbral.toStringAsFixed(0)}%',
        nivel: CosteoRiesgoNivel.saludable,
        onTap: () => setState(() => _filtroLista = 'saludable'),
      ),
      CosteoStatusSummaryCard(
        titulo: 'Margen bajo',
        cantidad: c.bajo,
        leyenda: 'Margen < ${umbral.toStringAsFixed(0)}%',
        nivel: CosteoRiesgoNivel.bajo,
        onTap: () => setState(() => _filtroLista = 'bajo_margen'),
      ),
      CosteoStatusSummaryCard(
        titulo: 'Sin costear',
        cantidad: c.sinDatos,
        leyenda: 'Falta información',
        nivel: CosteoRiesgoNivel.sinDatos,
        onTap: () => setState(() => _filtroLista = 'sin_receta'),
      ),
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(compacto ? 12 : 16, 10, compacto ? 12 : 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Móvil: margen global (mockup). Desktop: solo las 3 cards.
          if (!esAncho && c.margenGlobal != null) ...[
            Text(
              'MARGEN GLOBAL',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.7,
                color: SaaSTokens.inkMuted(context),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${c.margenGlobal!.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.8,
                    color: SaaSTokens.ink(context),
                  ),
                ),
                const SizedBox(width: 10),
                CosteoMargenBadge(
                  nivel: costeoNivelDe(
                    margenPct: c.margenGlobal,
                    sinReceta: false,
                    umbral: umbral,
                  ),
                  margenPct: c.margenGlobal,
                  compacto: true,
                ),
              ],
            ),
            const SizedBox(height: 4),
          ] else if (esAncho) ...[
            Row(
              children: [
                for (var i = 0; i < cards.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(child: cards[i]),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _cardMargenesSedeEditor({required bool compacto}) {
    final margenDef = (_margenObjetivoDefault ?? 35).clamp(5, 80).toDouble();
    final umbral = (_umbralMargen ?? 35).clamp(5, 80).toDouble();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SaaSTokens.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SaaSTokens.borderSoft(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Configuración de márgenes de sede',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: compacto ? 13.5 : 14.5,
              color: SaaSTokens.ink(context),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Margen objetivo default: ${margenDef.toStringAsFixed(0)}%',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
          ),
          Slider(
            value: margenDef,
            min: 5,
            max: 80,
            divisions: 75,
            activeColor: CosteoStitch.coral,
            onChanged: _guardandoMargenesSede
                ? null
                : (v) => setState(() => _margenObjetivoDefault = v),
          ),
          const SizedBox(height: 8),
          Text(
            'Umbral alerta margen: ${umbral.toStringAsFixed(0)}%',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
          ),
          Slider(
            value: umbral,
            min: 5,
            max: 80,
            divisions: 75,
            activeColor: CosteoStitch.teal,
            onChanged: _guardandoMargenesSede
                ? null
                : (v) => setState(() => _umbralMargen = v),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _guardandoMargenesSede ? null : _guardarMargenesSede,
                  icon: _guardandoMargenesSede
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined, size: 18),
                  label: const Text('Guardar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cabecera(
    double umbral, {
    required bool esAncho,
    required bool compacto,
    required bool enDetalle,
  }) {
    // Back: en detalle vuelve al listado; si no, al menú.
    final hayDetalle = enDetalle && _seleccionadoId != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(compacto ? 12 : 20, 12, 8, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hayDetalle) ...[
                IconButton(
                  tooltip: 'Volver al listado',
                  onPressed: () => _seleccionarProducto(null),
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.arrow_back,
                    size: 20,
                    color: SaaSTokens.inkMuted(context),
                  ),
                ),
              ] else if (widget.onVolverAlMenu != null) ...[
                IconButton(
                  tooltip: 'Volver al menú',
                  onPressed: widget.onVolverAlMenu,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.arrow_back,
                    size: 20,
                    color: SaaSTokens.inkMuted(context),
                  ),
                ),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Receta → Costos → Precio sugerido',
                      style: TextStyle(
                        fontSize: 11,
                        color: SaaSTokens.inkSoft(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hayDetalle
                          ? (_productoSeleccionado?['nombre'] as String? ??
                              'Costos')
                          : 'Costos y Márgenes',
                      style: TextStyle(
                        fontSize: compacto ? 24 : 28,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.6,
                        color: CosteoStitch.titulo(context),
                        height: 1.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (!hayDetalle) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Ingeniería de menú: costo, margen y precio sugerido.',
                        style: TextStyle(
                          fontSize: 13,
                          color: SaaSTokens.inkMuted(context),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (esAncho) ...[
                IconButton(
                  tooltip: 'Actualizar',
                  onPressed: _cargar,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.refresh_rounded,
                    size: 20,
                    color: SaaSTokens.inkMuted(context),
                  ),
                ),
                if (widget.sucursalId != null)
                  IconButton(
                    tooltip: 'Popularidad ventas (ABC)',
                    onPressed: () => mostrarPopularidadCosteo(
                      context: context,
                      sucursalId: widget.sucursalId!,
                      repo: _costeoRepo,
                    ),
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      Icons.insights_outlined,
                      size: 20,
                      color: SaaSTokens.inkMuted(context),
                    ),
                  ),
                FilledButton.icon(
                  onPressed: _recalculandoSucursal ? null : _recalcularSucursal,
                  style: FilledButton.styleFrom(
                    backgroundColor: CosteoStitch.coral,
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: _recalculandoSucursal
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.calculate_outlined, size: 18),
                  label: Text(
                    _recalculandoSucursal ? 'Recalculando…' : 'Recalcular todo',
                  ),
                ),
              ] else
                _accionesMovil(),
            ],
          ),
        ],
      ),
    );
  }

  /// NAV-MC-03: acciones del header agrupadas para móvil (evita partir el título).
  Widget _accionesMovil() {
    return PopupMenuButton<String>(
      tooltip: 'Acciones',
      icon: _recalculandoSucursal
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.more_vert),
      onSelected: (v) {
        switch (v) {
          case 'recalcular':
            if (!_recalculandoSucursal) _recalcularSucursal();
          case 'popularidad':
            if (widget.sucursalId != null) {
              mostrarPopularidadCosteo(
                context: context,
                sucursalId: widget.sucursalId!,
                repo: _costeoRepo,
              );
            }
          case 'insumos':
            widget.onIrInsumos?.call();
          case 'actualizar':
            _cargar();
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'recalcular',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.calculate_outlined),
            title: Text('Recalcular todo'),
          ),
        ),
        if (widget.sucursalId != null)
          const PopupMenuItem(
            value: 'popularidad',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.insights_outlined),
              title: Text('Popularidad ventas (ABC)'),
            ),
          ),
        if (widget.onIrInsumos != null)
          const PopupMenuItem(
            value: 'insumos',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.inventory_2_outlined),
              title: Text('Ir a Insumos'),
            ),
          ),
        const PopupMenuItem(
          value: 'actualizar',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.refresh),
            title: Text('Actualizar'),
          ),
        ),
      ],
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
      final nivel = costeoNivelDe(
        margenPct: margen,
        sinReceta: sinReceta,
        umbral: umbral,
      );
      switch (_filtroLista) {
        case 'sin_receta':
          return nivel == CosteoRiesgoNivel.sinDatos;
        case 'bajo_margen':
          return nivel == CosteoRiesgoNivel.bajo ||
              nivel == CosteoRiesgoNivel.critico;
        case 'saludable':
          return nivel == CosteoRiesgoNivel.saludable;
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
                    color: AnaliticaTokens.ink,
                  ),
                  textAlign: TextAlign.center,
                ),
                Slider(
                  value: margenObj.clamp(5, 80),
                  min: 5,
                  max: 80,
                  divisions: 75,
                  activeColor: AnaliticaTokens.ink,
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
                  style: FilledButton.styleFrom(
                    backgroundColor: AnaliticaTokens.ink,
                  ),
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
          SnackBar(content: Text(mensajeErrorHttp(e))),
        );
      }
    }
  }

  Widget _tarjetaProducto(
    Map<String, dynamic> p,
    double umbral, {
    required bool filaAncha,
  }) {
    final id = p['id'] as String;
    final margen = num.tryParse('${p['margen_porcentaje']}');
    final sinReceta =
        p['receta_id'] == null && p['costo_calculado'] == null;
    final nivel = costeoNivelDe(
      margenPct: margen,
      sinReceta: sinReceta,
      umbral: umbral,
    );
    final costo = p['costo_calculado'] != null
        ? _moneda.format(_num(p['costo_calculado']))
        : '—';
    final precio = _moneda.format(_num(p['precio']));

    if (filaAncha) {
      return CosteoListaFilaStitch(
        nombre: p['nombre'] as String? ?? '',
        categoria: _categoriaDe(p),
        costoLabel: costo,
        precioSugLabel: _precioSugLabel(p),
        nivel: nivel,
        margenPct: margen,
        imagenUrl: p['imagen_url'] as String?,
        onTap: () => _seleccionarProducto(id),
      );
    }

    return CosteoListaCardMovil(
      nombre: p['nombre'] as String? ?? '',
      subtitulo: sinReceta ? 'Sin datos de costo' : '$precio / porción',
      nivel: nivel,
      margenPct: margen,
      sinDatos: sinReceta,
      onTap: () => _seleccionarProducto(id),
      onAjustar: sinReceta
          ? null
          : () {
              _seleccionarProducto(id);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _mostrarAjusteMargen(p);
              });
            },
    );
  }

  Widget _panelDetalle({
    required bool compacto,
    required bool enColumnaDerecha,
  }) {
    final p = _productoSeleccionado;
    if (p == null) {
      return Center(
        child: Text(
          'Selecciona un ítem del listado',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: SaaSTokens.ink(context),
          ),
        ),
      );
    }

    final precio = _num(p['precio']);
    final tipoEntidad = p['tipo_entidad'] as String? ?? 'producto';
    final esExtra = tipoEntidad == 'bebida' || tipoEntidad == 'topping';
    final esCombo = tipoEntidad == 'combo';
    final costo = p['costo_calculado'] != null
        ? num.tryParse('${p['costo_calculado']}')
        : null;
    final margenReal = num.tryParse('${p['margen_porcentaje']}');
    final foodCost = num.tryParse('${p['food_cost_porcentaje']}');
    final fcColor = _colorFoodCost(foodCost);
    final sinReceta = costo == null;
    final umbral = _umbralMargen ?? 35;
    final bajoMargen = margenReal != null && margenReal < umbral;
    final tieneCanalLlevar = !esExtra &&
        !esCombo &&
        (p['precio_sugerido_llevar'] != null ||
            (p['costo_canal_llevar'] as num? ?? 0) > 0);
    final tabMesa = esExtra || esCombo || _tabsDetalle.index == 0;
    final margenObj = _margenObjetivoActual(p);
    final precioSug = costo != null && costo > 0
        ? calcularPrecioSugeridoUi(costo.toDouble(), margenObj)
        : null;

    final children = <Widget>[
      if (!enColumnaDerecha) ...[
        ..._detalleColumnaIzquierda(umbral: umbral, compacto: compacto),
        const SizedBox(height: 12),
      ],
      if (sinReceta)
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: CosteoStitch.amber.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: CosteoStitch.amber.withValues(alpha: 0.45),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.edit_note_outlined, color: CosteoStitch.amber),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  esCombo
                      ? 'Este combo aún no tiene costo. Pulsa Recalcular.'
                      : 'Este ítem aún no tiene receta. Agrega insumos y guarda.',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: CosteoStitch.amber,
                  ),
                ),
              ),
              if (esCombo)
                TextButton(
                  onPressed: () => _recalcularProducto(p['id'] as String),
                  child: const Text('Recalcular'),
                ),
            ],
          ),
        )
      else if (bajoMargen)
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: SaaSTokens.surface(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: CosteoStitch.critico.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.trending_down,
                size: 18,
                color: CosteoStitch.critico,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Margen ${margenReal.toStringAsFixed(0)}% bajo el umbral '
                  '(${umbral.toStringAsFixed(0)}%).',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: SaaSTokens.inkMuted(context),
                  ),
                ),
              ),
              if (!esCombo)
                TextButton(
                  onPressed: () => _mostrarAjusteMargen(p),
                  style: TextButton.styleFrom(
                    foregroundColor: CosteoStitch.critico,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Ajustar'),
                ),
            ],
          ),
        ),
      if (_cargandoImpacto)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: LinearProgressIndicator(
            minHeight: 2,
            color: CosteoStitch.coral,
          ),
        )
      else if (_impactoStock != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: StockImpactoProductoCard(impacto: _impactoStock!),
        ),
      if (!esExtra && !esCombo)
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: SaaSTokens.borderSoft(context)),
            ),
          ),
          child: FoodyScrollHorizontalFade(
            child: TabBar(
              controller: _tabsDetalle,
              onTap: (_) => setState(() {}),
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: CosteoStitch.titulo(context),
              unselectedLabelColor: SaaSTokens.inkSoft(context),
              indicatorColor: CosteoStitch.coral,
              indicatorWeight: 2.5,
              dividerColor: Colors.transparent,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13.5,
              ),
              tabs: [
                const Tab(text: 'Mesa / Local'),
                Tab(
                  text: tieneCanalLlevar
                      ? 'Domicilio (Para llevar)'
                      : 'Incluidos',
                ),
              ],
            ),
          ),
        ),
      if (tabMesa || esExtra) ...[
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: SaaSTokens.surface(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: SaaSTokens.borderSoft(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (esCombo) ...[
                Text(
                  'Costo del combo',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: SaaSTokens.ink(context),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Suma los platos del combo en Menú. Aquí solo se muestra y '
                  'recalcula el costo (sin editar receta).',
                  style: TextStyle(
                    fontSize: 13,
                    color: SaaSTokens.inkMuted(context),
                  ),
                ),
                const SizedBox(height: 12),
                CosteoResumenPie(
                  tituloCosto: 'Costo calculado',
                  costoTotal:
                      costo != null ? _moneda.format(costo) : '—',
                  foodCostPct: foodCost?.toDouble(),
                  margenBruto: '—',
                  margenPct: margenReal != null
                      ? '${margenReal.toStringAsFixed(1)}%'
                      : '—',
                  colorFoodCost: fcColor,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => _recalcularProducto(p['id'] as String),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Recalcular costo del combo'),
                ),
              ] else ...[
                Text(
                  'Insumos de Receta',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: SaaSTokens.ink(context),
                  ),
                ),
                const SizedBox(height: 8),
                RecetaProductoPanel(
                  key: ValueKey('receta-$tipoEntidad-${p['id']}'),
                  productoId: p['id'] as String,
                  tipoEntidad: tipoEntidad,
                  nombreProducto: p['nombre'] as String? ?? '',
                  ingredientes: _ingredientes,
                  subrecetas: _subrecetas,
                  sucursalId: widget.sucursalId,
                  onInsumosCambiados: () => _cargar(silent: true),
                  onIrInsumos: widget.onIrInsumos,
                  onGuardado: () => _recalcularProducto(p['id'] as String),
                  precioVenta: precio,
                  costoPreparacion: costo?.toDouble(),
                  foodCostPct: foodCost?.toDouble(),
                  margenPct: margenReal?.toDouble(),
                  colorFoodCost: fcColor,
                  scrollExterno: true,
                ),
                if (!esExtra) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Ítems Incluidos',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: SaaSTokens.ink(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ProductoItemsIncluidosPanel(
                    key: ValueKey('incluye-${p['id']}'),
                    productoId: p['id'] as String,
                    nombreProducto: p['nombre'] as String? ?? '',
                    productosDisponibles: _productos
                        .where((x) =>
                            (x['tipo_entidad'] as String? ?? 'producto') ==
                            'producto')
                        .toList(),
                    onGuardado: () => _recalcularProducto(p['id'] as String),
                    onCostosActualizados: () => _cargar(silent: true),
                    precioVenta: precio,
                    costoTotalProducto: costo?.toDouble(),
                    foodCostPct: foodCost?.toDouble(),
                    margenPct: margenReal?.toDouble(),
                    scrollExterno: true,
                  ),
                ],
              ],
            ],
          ),
        ),
        if (!esExtra && !esCombo) ...[
          const SizedBox(height: 14),
          CosteoPricingActionBar(
            costoLabel: costo != null ? _moneda.format(costo) : '—',
            precioSugLabel:
                precioSug != null ? _moneda.format(precioSug) : '—',
            margenObjetivo: margenObj,
            guardando: _guardandoMargen,
            puedeAplicar: costo != null && costo > 0,
            onCambiarMargen: () => _mostrarAjusteMargen(p),
            onAplicar: () => _mostrarAjusteMargen(p),
          ),
        ],
      ] else if (tieneCanalLlevar) ...[
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: SaaSTokens.surface(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: SaaSTokens.borderSoft(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Canal para llevar',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: SaaSTokens.ink(context),
                ),
              ),
              const SizedBox(height: 12),
              _filaCanalLlevar(
                'Costo canal llevar',
                _moneda.format(_num(p['costo_canal_llevar'])),
              ),
              if (p['precio_sugerido_llevar'] != null)
                _filaCanalLlevar(
                  'Precio sugerido',
                  _moneda.format(_num(p['precio_sugerido_llevar'])),
                  destacado: true,
                ),
              _filaCanalLlevar(
                'Precio menú llevar',
                _moneda.format(_num(p['precio_para_llevar'] ?? p['precio'])),
              ),
              if (p['margen_llevar_porcentaje'] != null)
                _filaCanalLlevar(
                  'Margen llevar',
                  '${num.tryParse('${p['margen_llevar_porcentaje']}')?.toStringAsFixed(1) ?? '—'}%',
                ),
            ],
          ),
        ),
      ] else
        ProductoItemsIncluidosPanel(
          key: ValueKey('incluye-solo-${p['id']}'),
          productoId: p['id'] as String,
          nombreProducto: p['nombre'] as String? ?? '',
          productosDisponibles: _productos
              .where((x) =>
                  (x['tipo_entidad'] as String? ?? 'producto') == 'producto')
              .toList(),
          onGuardado: () => _recalcularProducto(p['id'] as String),
          onCostosActualizados: () => _cargar(silent: true),
          precioVenta: precio,
          costoTotalProducto: costo?.toDouble(),
          foodCostPct: foodCost?.toDouble(),
          margenPct: margenReal?.toDouble(),
          scrollExterno: true,
        ),
    ];

    return ListView(
      primary: false,
      padding: EdgeInsets.fromLTRB(
        compacto ? 12 : 16,
        8,
        compacto ? 12 : 20,
        32,
      ),
      children: children,
    );
  }

  Widget _filaCanalLlevar(String etiqueta, String valor, {bool destacado = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              etiqueta,
              style: const TextStyle(
                fontSize: 13,
                color: AnaliticaTokens.inkMuted,
              ),
            ),
          ),
          Text(
            valor,
            style: TextStyle(
              fontWeight: destacado ? FontWeight.w700 : FontWeight.w600,
              color: destacado ? AnaliticaTokens.ink : AnaliticaTokens.inkMuted,
            ),
          ),
        ],
      ),
    );
  }

}
