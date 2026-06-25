import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
import 'package:reserva_canchas/features/costeo/presentation/widgets/costeo_ui_bloques.dart';
import 'package:reserva_canchas/features/inventario/data/costeo_repository.dart';
import 'package:reserva_canchas/features/inventario/data/inventario_repository.dart';
import 'package:reserva_canchas/features/inventario/presentation/widgets/dialogo_insumo_form.dart';
import 'package:reserva_canchas/features/inventario/presentation/widgets/dialogo_subreceta_form.dart';
import 'package:reserva_canchas/core/sesion/sesion_staff_service.dart';
import 'package:reserva_canchas/features/inventario/presentation/widgets/inventario_hermanas_panel.dart';
import 'package:reserva_canchas/features/inventario/presentation/inventario_traslados_panel.dart';
import 'package:reserva_canchas/features/inventario/presentation/widgets/stock_visual_widgets.dart';

/// Insumos admin — ingredientes, compras, movimientos y subrecetas.
class InventarioAdminScreen extends StatefulWidget {
  const InventarioAdminScreen({super.key, this.sucursalId});

  final String? sucursalId;

  @override
  State<InventarioAdminScreen> createState() => _InventarioAdminScreenState();
}

class _InventarioAdminScreenState extends State<InventarioAdminScreen>
    with SingleTickerProviderStateMixin {
  final _repo = InventarioRepository();
  final _costeoRepo = CosteoRepository();
  late final TabController _tabs;

  List<Map<String, dynamic>> _ingredientes = [];
  List<Map<String, dynamic>> _movimientos = [];
  List<Map<String, dynamic>> _subrecetas = [];
  bool _cargando = true;
  String? _error;
  final _busquedaCtrl = TextEditingController();
  String _filtroInsumos = 'todos';
  bool _puedeVerHermanas = false;
  List<Map<String, dynamic>> _sucursalesHermanas = [];

  final _moneda = NumberFormat.currency(
    locale: 'es_CO',
    symbol: r'$',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
    _cargar();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _busquedaCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final sid = widget.sucursalId;
    if (sid == null) {
      setState(() {
        _cargando = false;
        _error = 'Sin sucursal en sesión';
      });
      return;
    }
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final sesion = await SesionStaffService.cargar();
      final permisos = sesion?.permisos ?? [];
      final puedeHermanas = permisos.contains('ver_inventario_otras_sucursales') ||
          permisos.contains('gestionar_sucursales');
      final results = await Future.wait([
        _repo.ingredientes(sid),
        _repo.movimientos(sid),
        _costeoRepo.subrecetas(sid),
        if (puedeHermanas) _repo.resumenHermanas() else Future.value(<String, dynamic>{}),
      ]);
      if (!mounted) return;
      List<Map<String, dynamic>> hermanas = [];
      if (puedeHermanas && results.length > 3) {
        final resumen = results[3] as Map<String, dynamic>;
        hermanas = (resumen['sucursales'] as List<dynamic>? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
      setState(() {
        _ingredientes = List<Map<String, dynamic>>.from(results[0] as List);
        _movimientos = List<Map<String, dynamic>>.from(results[1] as List);
        _subrecetas = List<Map<String, dynamic>>.from(results[2] as List);
        _puedeVerHermanas = puedeHermanas;
        _sucursalesHermanas = hermanas;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _cargando = false;
      });
    }
  }

  void _mostrarInventarioHermanas() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SizedBox(
        height: MediaQuery.sizeOf(ctx).height * 0.88,
        child: const InventarioHermanasPanel(),
      ),
    );
  }

  Future<void> _dialogoCrearIngrediente() async {
    final sid = widget.sucursalId;
    if (sid == null) return;
    final res = await mostrarDialogoInsumo(context: context);
    if (res == null || !mounted) return;
    await _guardarInsumo(sid, res);
  }

  Future<void> _dialogoEditarIngrediente(Map<String, dynamic> ing) async {
    final sid = widget.sucursalId;
    if (sid == null) return;
    final res = await mostrarDialogoInsumo(
      context: context,
      insumoExistente: ing,
    );
    if (res == null || !mounted) return;
    try {
      if (res.esSoloCosto) {
        await _repo.actualizarIngrediente(
          ingredienteId: ing['id'] as String,
          nombre: res.nombre,
          proveedor: res.proveedor,
          categoriaInsumo: res.categoriaInsumo,
          unidadBase: res.unidadBase,
          costoUnitario: res.costoUnitario,
          descontarStock: res.descontarStock,
        );
      } else {
        await _repo.actualizarIngrediente(
          ingredienteId: ing['id'] as String,
          nombre: res.nombre,
          proveedor: res.proveedor,
          categoriaInsumo: res.categoriaInsumo,
          unidadBase: res.unidadBase,
          precioCompra: res.precioCompra,
          pesoBruto: res.pesoBruto,
          pesoNeto: res.pesoNeto,
          stockMinimo: res.stockMinimo,
        );
      }
      await _cargar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Insumo actualizado')),
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

  Future<void> _guardarInsumo(String sid, InsumoFormResultado res) async {
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
      await _cargar();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _dialogoCompra(Map<String, dynamic> ing) async {
    final sid = widget.sucursalId;
    if (sid == null) return;
    final cantidad = TextEditingController();
    final precio = TextEditingController();
    final proveedor = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Compra · ${ing['nombre']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: cantidad,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Cantidad (unidades base)'),
            ),
            TextField(
              controller: precio,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Precio total compra'),
            ),
            TextField(
              controller: proveedor,
              decoration: const InputDecoration(labelText: 'Proveedor (opcional)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Registrar')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    try {
      await _repo.registrarCompra(
        sucursalId: sid,
        ingredienteId: ing['id'] as String,
        cantidad: double.parse(cantidad.text),
        precioTotal: double.parse(precio.text),
        proveedor: proveedor.text.trim().isEmpty ? null : proveedor.text.trim(),
      );
      await _cargar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Compra registrada')),
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

  Future<void> _dialogoSubreceta({Map<String, dynamic>? existente}) async {
    final sid = widget.sucursalId;
    if (sid == null) return;
    if (_ingredientes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Carga insumos en «Lista de mercado» antes de crear subrecetas',
          ),
        ),
      );
      return;
    }

    List<Map<String, dynamic>>? itemsExistentes;
    if (existente != null) {
      try {
        final detalle = await _costeoRepo.obtenerSubrecetaDetalle(
          recetaId: existente['id'] as String,
          sucursalId: sid,
        );
        itemsExistentes = List<Map<String, dynamic>>.from(
          (detalle['items'] as List<dynamic>? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map)),
        );
        existente = Map<String, dynamic>.from(detalle);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No se pudo cargar la subreceta: $e')),
          );
        }
        return;
      }
    }

    if (!mounted) return;
    final res = await mostrarDialogoSubreceta(
      context: context,
      ingredientes: _ingredientes,
      subrecetas: _subrecetas,
      subrecetaExistente: existente,
      itemsExistentes: itemsExistentes,
    );
    if (res == null || !mounted) return;

    try {
      if (res.recetaId != null) {
        await _costeoRepo.actualizarSubreceta(
          recetaId: res.recetaId!,
          sucursalId: sid,
          nombre: res.nombre,
          cantidadResultado: res.cantidadResultado,
          unidadResultado: res.unidadResultado,
          margenError: res.margenError,
          items: res.items,
        );
      } else {
        await _costeoRepo.crearSubreceta(
          sucursalId: sid,
          nombre: res.nombre,
          cantidadResultado: res.cantidadResultado,
          unidadResultado: res.unidadResultado,
          margenError: res.margenError,
          items: res.items,
        );
      }
      await _cargar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              res.recetaId != null ? 'Subreceta actualizada' : 'Subreceta creada',
            ),
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

  Future<void> _dialogoAjuste(Map<String, dynamic> ing) async {
    final stockCtrl = TextEditingController(
      text: '${ing['stock_actual']}',
    );
    final motivo = TextEditingController(text: 'Conteo físico');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Ajustar stock · ${ing['nombre']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: stockCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Stock nuevo'),
            ),
            TextField(
              controller: motivo,
              decoration: const InputDecoration(labelText: 'Motivo'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Aplicar')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    try {
      await _repo.ajustarStock(
        ingredienteId: ing['id'] as String,
        stockNuevo: double.parse(stockCtrl.text),
        motivo: motivo.text.trim(),
      );
      await _cargar();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
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
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: _cargar, child: const Text('Reintentar')),
          ],
        ),
      );
    }

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Insumos',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        Text(
                          'Precio de compra → costo real → recetas',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey.shade600,
                              ),
                        ),
                      ],
                    ),
                  ),
                  if (_puedeVerHermanas)
                    IconButton(
                      tooltip: 'Inventario otras sucursales',
                      onPressed: _mostrarInventarioHermanas,
                      icon: const Icon(Icons.store_mall_directory_outlined),
                    ),
                  IconButton(
                    tooltip: 'Actualizar',
                    onPressed: _cargar,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),
            const GuiaPasosCompacta(
              pasos: [
                'Lista de mercado: registra ingredientes y precio de compra',
                'Subrecetas: preparaciones compartidas (arroz, salsas…)',
                'Costos y márgenes: arma la receta de cada plato',
              ],
            ),
            StockAlertaBanner(
              agotados: _ingredientes
                  .where((i) =>
                      i['descontar_stock'] != false &&
                      (num.tryParse('${i['stock_actual']}') ?? 0) <= 0)
                  .length,
              bajos: _ingredientes
                  .where((i) => i['bajo_minimo'] == true)
                  .length,
              onVerBajos: () => setState(() => _filtroInsumos = 'bajo_stock'),
            ),
            TabBar(
              controller: _tabs,
              labelColor: ColoresFoody.primario,
              onTap: (_) => setState(() {}),
              tabs: const [
                Tab(text: 'Mercado'),
                Tab(text: 'Movimientos'),
                Tab(text: 'Subrecetas'),
                Tab(text: 'Conteo'),
                Tab(text: 'Traslados'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _listaIngredientes(),
                  _listaMovimientos(),
                  _listaSubrecetas(),
                  _tabConteo(),
                  InventarioTrasladosPanel(
                    sucursalId: widget.sucursalId!,
                    sucursalesHermanas: _sucursalesHermanas,
                  ),
                ],
              ),
            ),
          ],
        ),
        if (_tabs.index == 0 || _tabs.index == 2)
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              onPressed: _tabs.index == 0
                  ? _dialogoCrearIngrediente
                  : () => _dialogoSubreceta(),
              backgroundColor: ColoresFoody.primario,
              icon: const Icon(Icons.add),
              label: Text(_tabs.index == 0 ? 'Nuevo insumo' : 'Nueva subreceta'),
            ),
          ),
      ],
    );
  }

  List<Map<String, dynamic>> get _ingredientesFiltrados {
    final q = _busquedaCtrl.text.trim().toLowerCase();
    return _ingredientes.where((ing) {
      final nombre = (ing['nombre'] as String? ?? '').toLowerCase();
      if (q.isNotEmpty && !nombre.contains(q)) return false;
      final soloCosto = ing['descontar_stock'] == false;
      final bajo = ing['bajo_minimo'] == true;
      switch (_filtroInsumos) {
        case 'mercado':
          return !soloCosto;
        case 'solo_costo':
          return soloCosto;
        case 'bajo_stock':
          return bajo;
        default:
          return true;
      }
    }).toList();
  }

  Widget _listaIngredientes() {
    final lista = _ingredientesFiltrados;

    if (_ingredientes.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text('Sin insumos aún'),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _dialogoCrearIngrediente,
              icon: const Icon(Icons.add),
              label: const Text('Crear primer insumo'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            controller: _busquedaCtrl,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Buscar insumo…',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              _chipInsumo('todos', 'Todos'),
              _chipInsumo('mercado', 'Mercado'),
              _chipInsumo('solo_costo', 'Solo costo'),
              _chipInsumo('bajo_stock', 'Bajo stock'),
            ],
          ),
        ),
        Expanded(
          child: lista.isEmpty
              ? const Center(child: Text('Ningún insumo coincide'))
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 80),
                    itemCount: lista.length,
                    itemBuilder: (_, i) => _tarjetaInsumo(lista[i]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _chipInsumo(String id, String label) {
    final sel = _filtroInsumos == id;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: sel,
        onSelected: (_) => setState(() => _filtroInsumos = id),
        selectedColor: ColoresFoody.primario.withValues(alpha: 0.15),
        checkmarkColor: ColoresFoody.primario,
      ),
    );
  }

  Widget _tarjetaInsumo(Map<String, dynamic> ing) {
    final bajo = ing['bajo_minimo'] == true;
    final stock = num.tryParse('${ing['stock_actual']}') ?? 0;
    final minimo = num.tryParse('${ing['stock_minimo']}') ?? 0;
    final costo =
        num.tryParse('${ing['costo_real'] ?? ing['costo_unitario_actual']}') ?? 0;
    final unidad = ing['unidad_base'] as String? ?? 'und';
    final soloCosto = ing['descontar_stock'] == false;
    final precioCompra = ing['precio_compra'];
    final estado = stockEstadoDesde(
      stock: stock,
      minimo: minimo,
      descontarStock: !soloCosto,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: bajo ? Colors.red.shade200 : Colors.grey.shade200,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: bajo
                    ? Colors.red.shade50
                    : ColoresFoody.secundario.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                soloCosto ? Icons.payments_outlined : Icons.shopping_basket_outlined,
                color: bajo ? Colors.red : ColoresFoody.secundario,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          ing['nombre'] as String? ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        '${_moneda.format(costo)}/$unidad',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: ColoresFoody.primario,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (soloCosto)
                        _miniBadge('Solo costo', Colors.brown.shade600)
                      else
                        _miniBadge('Mercado', ColoresFoody.secundario),
                      if (!soloCosto) StockBadge(estado: estado, compacto: true),
                      if (!soloCosto)
                        _miniBadge(
                          'Descuenta al vender',
                          ColoresFoody.primario.withValues(alpha: 0.85),
                        ),
                      if (precioCompra != null)
                        Text(
                          'Compra ${_moneda.format(num.tryParse('$precioCompra') ?? 0)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                  if (!soloCosto) ...[
                    const SizedBox(height: 8),
                    StockBarra(
                      stock: stock,
                      minimo: minimo,
                      unidad: unidad,
                    ),
                  ],
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (v) {
                if (v == 'editar') _dialogoEditarIngrediente(ing);
                if (v == 'compra') _dialogoCompra(ing);
                if (v == 'ajuste') _dialogoAjuste(ing);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'editar', child: Text('Editar')),
                if (!soloCosto)
                  const PopupMenuItem(value: 'compra', child: Text('Registrar compra')),
                if (!soloCosto)
                  const PopupMenuItem(value: 'ajuste', child: Text('Ajustar stock')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  Widget _listaMovimientos() {
    if (_movimientos.isEmpty) {
      return const Center(child: Text('Sin movimientos aún'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _movimientos.length,
      itemBuilder: (_, i) {
        final m = _movimientos[i];
        return ListTile(
          dense: true,
          title: Text('${m['tipo']} · ${m['ingrediente_nombre']}'),
          subtitle: Text(
            '${m['stock_anterior']} → ${m['stock_posterior']} · ${m['motivo'] ?? ''}',
          ),
          trailing: Text(
            m['created_at']?.toString().substring(0, 16) ?? '',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        );
      },
    );
  }

  Future<void> _ejecutarConteo() async {
    final sid = widget.sucursalId;
    if (sid == null || _ingredientes.isEmpty) return;

    final cantidades = <String, TextEditingController>{};
    for (final ing in _ingredientes) {
      cantidades[ing['id'] as String] = TextEditingController(
        text: '${ing['stock_actual']}',
      );
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Conteo físico'),
        content: SizedBox(
          width: 400,
          height: 360,
          child: ListView(
            children: _ingredientes.map((ing) {
              final id = ing['id'] as String;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  controller: cantidades[id],
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: ing['nombre'] as String? ?? '',
                    helperText:
                        'Stock teórico: ${ing['stock_actual']} ${ing['unidad_base'] ?? ''}',
                    suffixText: ing['unidad_base'] as String? ?? '',
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cerrar conteo')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final items = _ingredientes
        .map(
          (ing) => {
            'ingrediente_id': ing['id'] as String,
            'cantidad_real': double.tryParse(
                  cantidades[ing['id'] as String]!.text.replaceAll(',', '.'),
                ) ??
                0,
          },
        )
        .toList();
    for (final c in cantidades.values) {
      c.dispose();
    }

    try {
      final conteoId = await _repo.iniciarConteo(sid);
      await _repo.cerrarConteo(conteoId: conteoId, items: items);
      await _cargar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Conteo cerrado y stock actualizado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensajeErrorHttp(e, contexto: 'cerrar conteo')),
          ),
        );
      }
    }
  }

  Widget _tabConteo() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.fact_check_outlined, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Conteo físico de inventario',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Registra las cantidades reales de cada ingrediente. '
              'El sistema ajustará el stock donde haya diferencia.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _ingredientes.isEmpty ? null : _ejecutarConteo,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Iniciar conteo'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _listaSubrecetas() {
    final monedaDetalle = NumberFormat.currency(
      locale: 'es_CO',
      symbol: r'$',
      decimalDigits: 2,
    );

    if (_subrecetas.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_tree_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'Sin subrecetas aún',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Arroz, salsas, bases… reutilizables en varios platos',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _dialogoSubreceta(),
              icon: const Icon(Icons.add),
              label: const Text('Crear subreceta'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
      itemCount: _subrecetas.length,
      itemBuilder: (_, i) {
        final sr = _subrecetas[i];
        final unidad = sr['unidad_resultado'] as String? ?? 'g';
        final costoUnit = num.tryParse('${sr['costo_por_unidad']}');
        final costoTotal = num.tryParse('${sr['costo_total']}');
        final numItems = sr['num_items'] as int? ?? 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => _dialogoSubreceta(existente: sr),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: ColoresFoody.primario.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.account_tree_outlined,
                      color: ColoresFoody.primario,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sr['nombre'] as String? ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'Rinde ${sr['cantidad_resultado']} $unidad · $numItems insumo${numItems == 1 ? '' : 's'}',
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
                      if (costoUnit != null)
                        Text(
                          '${monedaDetalle.format(costoUnit)}/$unidad',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: ColoresFoody.primario,
                          ),
                        ),
                      if (costoTotal != null)
                        Text(
                          'Total ${_moneda.format(costoTotal)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    onPressed: () => _dialogoSubreceta(existente: sr),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

}
