import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';
import 'package:reserva_canchas/features/catalogo/data/catalogo_admin_repository.dart';
import 'package:reserva_canchas/features/cocinas/data/cocinas_repository.dart';

/// CRUD menú (Sprint 5) — productos, toppings y bebidas.
class MenuAdminScreen extends StatefulWidget {
  const MenuAdminScreen({
    super.key,
    this.sucursalId,
    this.onVerCostos,
  });

  final String? sucursalId;
  final void Function(String productoId)? onVerCostos;

  @override
  State<MenuAdminScreen> createState() => _MenuAdminScreenState();
}

class _MenuAdminScreenState extends State<MenuAdminScreen>
    with SingleTickerProviderStateMixin {
  final _repo = CatalogoAdminRepository();
  final _cocinasRepo = CocinasRepository();
  late final TabController _tabs;

  List<Map<String, dynamic>> _categorias = [];
  List<Map<String, dynamic>> _productos = [];
  List<Map<String, dynamic>> _toppings = [];
  List<Map<String, dynamic>> _bebidas = [];
  List<Map<String, dynamic>> _combos = [];
  List<Map<String, dynamic>> _cocinas = [];
  bool _cargando = true;

  final _moneda = NumberFormat.currency(
    locale: 'es_CO',
    symbol: r'$',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _cargar();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final sid = widget.sucursalId;
    if (sid == null) return;
    setState(() => _cargando = true);
    final avisos = <String>[];

    Future<List<Map<String, dynamic>>> intentar(
      Future<List<Map<String, dynamic>>> future,
      String etiqueta,
    ) async {
      try {
        return await future;
      } catch (e) {
        avisos.add(mensajeErrorHttp(e, contexto: etiqueta));
        return [];
      }
    }

    final categorias = await intentar(_repo.categorias(sid), 'categorías');
    final productos = await intentar(_repo.productos(sid), 'productos');
    final toppings = await intentar(_repo.toppings(sid), 'toppings');
    final bebidas = await intentar(_repo.bebidas(sid), 'bebidas');
    final combos = await intentar(_repo.combos(sid), 'combos');
    final cocinas =
        await intentar(_cocinasRepo.listarCocinas(sid), 'cocinas');

    if (mounted) {
      setState(() {
        _categorias = categorias;
        _productos = productos;
        _toppings = toppings;
        _bebidas = bebidas;
        _combos = combos;
        _cocinas = cocinas.where((c) => c['activa'] == true).toList();
        _cargando = false;
      });
      if (avisos.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(avisos.first)),
        );
      }
    }
  }

  Future<void> _nuevaCategoria() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nueva categoría'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Nombre'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Crear')),
        ],
      ),
    );
    final nombre = ctrl.text.trim();
    ctrl.dispose();
    if (ok == true && nombre.isNotEmpty) {
      await _repo.crearCategoria(sucursalId: widget.sucursalId!, nombre: nombre);
      await _cargar();
    }
  }

  Future<void> _nuevoProducto() async {
    if (_categorias.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Crea una categoría primero')),
      );
      return;
    }
    final nombreCtrl = TextEditingController();
    final precioCtrl = TextEditingController();
    String? catId = _categorias.first['id'] as String?;
    String? cocinaId = _cocinas.isNotEmpty ? _cocinas.first['id'] as String : null;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Nuevo producto'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreCtrl,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              TextField(
                controller: precioCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Precio'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: catId,
                decoration: const InputDecoration(labelText: 'Categoría'),
                items: _categorias
                    .map(
                      (c) => DropdownMenuItem(
                        value: c['id'] as String,
                        child: Text(c['nombre'] as String),
                      ),
                    )
                    .toList(),
                onChanged: (v) => catId = v,
              ),
              const SizedBox(height: 8),
              if (_cocinas.isEmpty)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Sin cocinas. Crea una en «Cocinas e impresoras» para enrutar este plato.',
                    style: TextStyle(fontSize: 12, color: Colors.orange),
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  initialValue: cocinaId,
                  decoration: const InputDecoration(labelText: 'Cocina (envío del ticket)'),
                  items: _cocinas
                      .map(
                        (c) => DropdownMenuItem(
                          value: c['id'] as String,
                          child: Text(c['nombre'] as String? ?? '—'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setDlg(() => cocinaId = v),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Crear')),
          ],
        ),
      ),
    );
    final nombre = nombreCtrl.text.trim();
    final precio = double.tryParse(precioCtrl.text.replaceAll(',', '.')) ?? 0;
    nombreCtrl.dispose();
    precioCtrl.dispose();
    if (ok == true && nombre.isNotEmpty && catId != null) {
      await _repo.crearProducto(
        sucursalId: widget.sucursalId!,
        categoriaId: catId!,
        nombre: nombre,
        precio: precio,
        cocinaId: cocinaId,
      );
      await _cargar();
    }
  }

  Future<void> _reasignarCocina(Map<String, dynamic> producto) async {
    if (_cocinas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Crea una cocina primero')),
      );
      return;
    }
    String cocinaId = (producto['cocina_id'] as String?) ??
        _cocinas.first['id'] as String;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text('Cocina · ${producto['nombre']}'),
          content: DropdownButtonFormField<String>(
            initialValue: _cocinas.any((c) => c['id'] == cocinaId)
                ? cocinaId
                : _cocinas.first['id'] as String,
            decoration: const InputDecoration(labelText: 'Cocina'),
            items: _cocinas
                .map(
                  (c) => DropdownMenuItem(
                    value: c['id'] as String,
                    child: Text(c['nombre'] as String? ?? '—'),
                  ),
                )
                .toList(),
            onChanged: (v) => setDlg(() => cocinaId = v ?? cocinaId),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await _repo.asignarCocina(producto['id'] as String, cocinaId);
      await _cargar();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensajeErrorHttp(e, contexto: 'asignar cocina'))),
        );
      }
    }
  }

  Future<void> _editarPrecios(Map<String, dynamic> producto) async {
    final localCtrl = TextEditingController(
      text: _num(producto['precio']).toStringAsFixed(0),
    );
    final llevarRaw = producto['precio_para_llevar'];
    final llevarCtrl = TextEditingController(
      text: llevarRaw != null ? _num(llevarRaw).toStringAsFixed(0) : '',
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Precios · ${producto['nombre']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: localCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Precio local / mesa (COP)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: llevarCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Precio para llevar / domicilio',
                hintText: 'Vacío = mismo que local',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
        ],
      ),
    );
    final localTxt = localCtrl.text;
    final llevarTxt = llevarCtrl.text.trim();
    localCtrl.dispose();
    llevarCtrl.dispose();
    if (ok != true) return;
    final local = double.tryParse(localTxt.replaceAll(',', '.'));
    if (local == null || local < 0) return;
    final llevar = llevarTxt.isEmpty
        ? null
        : double.tryParse(llevarTxt.replaceAll(',', '.'));
    if (llevarTxt.isNotEmpty && (llevar == null || llevar < 0)) return;
    try {
      await _repo.actualizarPreciosCanal(
        productoId: producto['id'] as String,
        precioLocal: local,
        precioParaLlevar: llevar,
      );
      await _cargar();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _vincularExtras(Map<String, dynamic> producto) async {
    if (_toppings.isEmpty && _bebidas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Crea toppings o bebidas primero')),
      );
      return;
    }
    final opciones = <MapEntry<String, String>>[
      for (final t in _toppings)
        MapEntry('t:${t['id']}', 'Topping · ${t['nombre']}'),
      for (final b in _bebidas)
        MapEntry('b:${b['id']}', 'Bebida · ${b['nombre']}'),
    ];
    String? seleccion = opciones.first.key;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text('Extras · ${producto['nombre']}'),
          content: DropdownButtonFormField<String>(
            initialValue: seleccion,
            decoration: const InputDecoration(labelText: 'Extra a vincular'),
            items: opciones
                .map(
                  (o) => DropdownMenuItem(value: o.key, child: Text(o.value)),
                )
                .toList(),
            onChanged: (v) => setDlg(() => seleccion = v),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Vincular')),
          ],
        ),
      ),
    );
    final sel = seleccion;
    if (ok != true || sel == null) return;
    final partes = sel.split(':');
    try {
      await _repo.vincularExtra(
        productoId: producto['id'] as String,
        extraId: partes[1],
        esBebida: partes[0] == 'b',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Extra vinculado al producto')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _nuevoExtra({required bool esBebida}) async {
    final nombre = TextEditingController();
    final precio = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(esBebida ? 'Nueva bebida' : 'Nuevo topping'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nombre, decoration: const InputDecoration(labelText: 'Nombre')),
            TextField(
              controller: precio,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Precio'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Crear')),
        ],
      ),
    );
    final n = nombre.text.trim();
    final p = double.tryParse(precio.text.replaceAll(',', '.')) ?? 0;
    nombre.dispose();
    precio.dispose();
    if (ok != true || n.isEmpty) return;
    await _repo.crearExtra(
      sucursalId: widget.sucursalId!,
      nombre: n,
      precio: p,
      esBebida: esBebida,
    );
    await _cargar();
  }

  Future<void> _nuevoCombo() async {
    if (_productos.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Necesitas al menos 2 productos')),
      );
      return;
    }
    final nombre = TextEditingController();
    final precio = TextEditingController();
    final seleccionados = <String>{_productos.first['id'] as String};

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Nuevo combo'),
          content: SizedBox(
            width: 360,
            height: 320,
            child: Column(
              children: [
                TextField(
                  controller: nombre,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                ),
                TextField(
                  controller: precio,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Precio fijo'),
                ),
                const SizedBox(height: 8),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Incluye:', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: ListView(
                    children: _productos.map((p) {
                      final id = p['id'] as String;
                      return CheckboxListTile(
                        value: seleccionados.contains(id),
                        title: Text(p['nombre'] as String? ?? ''),
                        onChanged: (v) {
                          setDlg(() {
                            if (v == true) {
                              seleccionados.add(id);
                            } else if (seleccionados.length > 1) {
                              seleccionados.remove(id);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Crear')),
          ],
        ),
      ),
    );
    final n = nombre.text.trim();
    final p = double.tryParse(precio.text.replaceAll(',', '.')) ?? 0;
    nombre.dispose();
    precio.dispose();
    if (ok != true || n.isEmpty || seleccionados.length < 2) return;
    await _repo.crearCombo(
      sucursalId: widget.sucursalId!,
      nombre: n,
      precioFijo: p,
      productoIds: seleccionados.toList(),
    );
    await _cargar();
  }

  double _num(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

  String _subtituloPrecios(Map<String, dynamic> p) {
    final cat = p['categoria_nombre'] as String? ?? '';
    final llevar = p['precio_para_llevar'];
    if (llevar == null) return cat;
    final diff = (_num(llevar) - _num(p['precio'])).abs() > 0.01;
    if (!diff) return cat;
    return '$cat · Llevar ${_moneda.format(_num(llevar))}';
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
          child: Row(
            children: [
              Text('Menú', style: Theme.of(context).textTheme.headlineSmall),
              const Spacer(),
              IconButton(
                tooltip: 'Nueva categoría',
                onPressed: _nuevaCategoria,
                icon: const Icon(Icons.create_new_folder_outlined),
              ),
              IconButton(
                tooltip: 'Nuevo producto',
                onPressed: _nuevoProducto,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
        ),
        TabBar(
          controller: _tabs,
          labelColor: ColoresFoody.primario,
          tabs: [
            Tab(text: 'Productos (${_productos.length})'),
            Tab(text: 'Toppings (${_toppings.length})'),
            Tab(text: 'Bebidas (${_bebidas.length})'),
            Tab(text: 'Combos (${_combos.length})'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _tabProductos(),
              _tabExtras(_toppings, esBebida: false),
              _tabExtras(_bebidas, esBebida: true),
              _tabCombos(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tabProductos() {
    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _productos.length,
        itemBuilder: (_, i) {
          final p = _productos[i];
          final disponible = p['disponible'] as bool? ?? true;
          final precioNum = _num(p['precio']);
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(
                p['nombre'] as String? ?? '',
                style: TextStyle(
                  decoration: disponible ? null : TextDecoration.lineThrough,
                ),
              ),
              subtitle: Text(
                _subtituloPrecios(p),
              ),
              onTap: () => _editarPrecios(p),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Cocina',
                    icon: Icon(
                      Icons.soup_kitchen_outlined,
                      size: 20,
                      color: p['cocina_id'] == null
                          ? ColoresFoody.error
                          : ColoresFoody.secundario,
                    ),
                    onPressed: () => _reasignarCocina(p),
                  ),
                  IconButton(
                    tooltip: 'Vincular extra',
                    icon: const Icon(Icons.link, size: 20),
                    onPressed: () => _vincularExtras(p),
                  ),
                  if (widget.onVerCostos != null)
                    IconButton(
                      tooltip: 'Ver costos',
                      icon: const Icon(Icons.pie_chart_outline, size: 20),
                      color: ColoresFoody.primario,
                      onPressed: () =>
                          widget.onVerCostos!(p['id'] as String),
                    ),
                  Text(_moneda.format(precioNum), style: const TextStyle(fontWeight: FontWeight.bold)),
                  Switch(
                    value: disponible,
                    activeTrackColor: ColoresFoody.primario.withValues(alpha: 0.4),
                    onChanged: (v) async {
                      await _repo.toggleDisponible(p['id'] as String, v);
                      await _cargar();
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _tabExtras(List<Map<String, dynamic>> items, {required bool esBebida}) {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => _nuevoExtra(esBebida: esBebida),
            icon: const Icon(Icons.add),
            label: Text(esBebida ? 'Nueva bebida' : 'Nuevo topping'),
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? const Center(child: Text('Sin registros'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final e = items[i];
                    final disponible = e['disponible'] as bool? ?? true;
                    return ListTile(
                      title: Text(e['nombre'] as String? ?? ''),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_moneda.format(_num(e['precio']))),
                          Switch(
                            value: disponible,
                            onChanged: (v) async {
                              await _repo.toggleExtra(
                                id: e['id'] as String,
                                disponible: v,
                                esBebida: esBebida,
                              );
                              await _cargar();
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _tabCombos() {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _nuevoCombo,
            icon: const Icon(Icons.add),
            label: const Text('Nuevo combo'),
          ),
        ),
        Expanded(
          child: _combos.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Combo = paquete que el cliente elige en el menú '
                      '(ej. hígado + huevo + jugo con precio total).\n\n'
                      'Si el plato ya trae rosquetes incluidos, configúralo en '
                      'Costos → «Qué va incluido», no aquí.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _combos.length,
                  itemBuilder: (_, i) {
                    final c = _combos[i];
                    final items = c['items'];
                    final nItems = items is List ? items.length : 0;
                    return ListTile(
                      title: Text(c['nombre'] as String? ?? ''),
                      subtitle: Text('$nItems ítems'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_moneda.format(_num(c['precio_fijo']))),
                          Switch(
                            value: c['disponible'] as bool? ?? true,
                            onChanged: (v) async {
                              await _repo.toggleCombo(
                                id: c['id'] as String,
                                disponible: v,
                              );
                              await _cargar();
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
