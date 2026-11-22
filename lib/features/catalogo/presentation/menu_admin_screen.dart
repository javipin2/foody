import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:reserva_canchas/core/layout/foody_breakpoints.dart';
import 'package:reserva_canchas/core/tema/foody_formulario.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';
import 'package:reserva_canchas/core/red/mostrar_error_snackbar.dart';
import 'package:reserva_canchas/core/saas_ui/saas_ui.dart';
import 'package:reserva_canchas/core/widgets/foody_estado_ui.dart';
import 'package:reserva_canchas/core/widgets/foody_scroll_horizontal_fade.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_skeleton.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_tokens.dart';
import 'package:reserva_canchas/features/almacenamiento/data/almacenamiento_repository.dart';
import 'package:reserva_canchas/features/catalogo/data/catalogo_admin_repository.dart';
import 'package:reserva_canchas/features/cocinas/data/cocinas_repository.dart';
import 'package:reserva_canchas/features/costeo/presentation/widgets/costeo_ui_bloques.dart';
import 'package:reserva_canchas/features/inventario/data/costeo_repository.dart';

/// CRUD menú (Sprint 5) — productos, toppings y bebidas.
class MenuAdminScreen extends StatefulWidget {
  const MenuAdminScreen({
    super.key,
    this.sucursalId,
    this.sucursalesOrigen = const [],
    this.onVerCostos,
  });

  final String? sucursalId;
  /// Otras sedes del restaurante (copiar menú maestro).
  final List<Map<String, dynamic>> sucursalesOrigen;
  final void Function(String productoId)? onVerCostos;

  @override
  State<MenuAdminScreen> createState() => _MenuAdminScreenState();
}

class _MenuAdminScreenState extends State<MenuAdminScreen>
    with SingleTickerProviderStateMixin {
  final _repo = CatalogoAdminRepository();
  final _almacenamiento = AlmacenamientoRepository();
  final _picker = ImagePicker();
  final _cocinasRepo = CocinasRepository();
  final _costeoRepo = CosteoRepository();
  late final TabController _tabs;

  List<Map<String, dynamic>> _categorias = [];
  List<Map<String, dynamic>> _productos = [];
  List<Map<String, dynamic>> _toppings = [];
  List<Map<String, dynamic>> _bebidas = [];
  List<Map<String, dynamic>> _combos = [];
  List<Map<String, dynamic>> _cocinas = [];
  /// NAV-MC-07: id → {costo_calculado, margen_porcentaje} desde /costeo/resumen.
  Map<String, Map<String, dynamic>> _costeoPorProducto = {};
  double _umbralMargen = 35;
  bool _cargando = true;
  String? _errorCarga;
  final _busquedaCtrl = TextEditingController();
  String _filtroProductos = 'todos';

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
    _busquedaCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final sid = widget.sucursalId;
    if (sid == null) {
      if (mounted) setState(() => _cargando = false);
      return;
    }
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

    // NAV-MC-07: resumen costeo en paralelo (fallo no bloquea el menú).
    Map<String, Map<String, dynamic>> costeoMap = {};
    var umbral = 35.0;
    try {
      final resumen = await _costeoRepo.resumen(sid);
      umbral = (resumen['umbral_margen'] as num?)?.toDouble() ?? 35;
      void indexar(dynamic lista) {
        if (lista is! List) return;
        for (final e in lista) {
          if (e is! Map) continue;
          final m = Map<String, dynamic>.from(e);
          final id = m['id'] as String?;
          if (id != null) costeoMap[id] = m;
        }
      }
      indexar(resumen['productos']);
      indexar(resumen['bebidas']);
      indexar(resumen['toppings']);
    } catch (_) {
      // Plan Free u error: badges quedan ocultos.
    }

    if (mounted) {
      setState(() {
        _categorias = categorias;
        _productos = productos;
        _toppings = toppings;
        _bebidas = bebidas;
        _combos = combos;
        _cocinas = cocinas.where((c) => c['activa'] == true).toList();
        _costeoPorProducto = costeoMap;
        _umbralMargen = umbral;
        _errorCarga = avisos.isEmpty ? null : avisos.join(' · ');
        _cargando = false;
      });
    }
  }

  Future<void> _copiarMenuDesde() async {
    final opciones = widget.sucursalesOrigen;
    if (opciones.isEmpty || widget.sucursalId == null) return;

    String? origenId = opciones.first['id'] as String?;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Copiar menú desde otra sede'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Se copian categorías, productos, toppings y bebidas. '
                'Los nombres ya existentes en esta sede no se duplican.',
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: origenId,
                decoration: const InputDecoration(
                  labelText: 'Sede origen',
                  border: OutlineInputBorder(),
                ),
                items: opciones
                    .map(
                      (s) => DropdownMenuItem(
                        value: s['id'] as String,
                        child: Text(s['nombre'] as String? ?? 'Sede'),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setDialog(() => origenId = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Copiar'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || origenId == null) return;

    try {
      final res = await _repo.copiarMenuDesde(
        sucursalDestinoId: widget.sucursalId!,
        sucursalOrigenId: origenId!,
      );
      await _cargar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Menú copiado: ${res['productos_nuevos'] ?? 0} productos nuevos',
            ),
            backgroundColor: AnaliticaTokens.inventario,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensajeErrorHttp(e, contexto: 'copiar menú'))),
        );
      }
    }
  }

  Future<void> _nuevaCategoria() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => FoodyDialogoShell(
        titulo: 'Nueva categoría',
        maxWidth: 400,
        contenido: FoodyFormSeccion(
          titulo: 'Datos',
          icono: Icons.category_outlined,
          hijo: TextField(
            controller: ctrl,
            decoration: FoodyFormEstilo.campo(label: 'Nombre'),
          ),
        ),
        acciones: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AnaliticaTokens.ink,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Crear'),
          ),
        ],
      ),
    );
    final nombre = ctrl.text.trim();
    ctrl.dispose();
    if (ok == true && nombre.isNotEmpty) {
      try {
        await _repo.crearCategoria(sucursalId: widget.sucursalId!, nombre: nombre);
        await _cargar();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(mensajeErrorHttp(e, contexto: 'categoría'))),
          );
        }
      }
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
        builder: (ctx, setDlg) => FoodyDialogoShell(
          titulo: 'Nuevo producto',
          subtitulo: 'Precio y categoría del plato que ve el cliente.',
          maxWidth: 440,
          contenido: Column(
            children: [
              FoodyFormSeccion(
                titulo: 'Plato',
                icono: Icons.restaurant_outlined,
                hijo: Column(
                  children: [
                    TextField(
                      controller: nombreCtrl,
                      decoration: FoodyFormEstilo.campo(label: 'Nombre'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: precioCtrl,
                      keyboardType: TextInputType.number,
                      decoration: FoodyFormEstilo.campo(label: 'Precio'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: catId,
                      decoration: FoodyFormEstilo.campo(label: 'Categoría'),
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
                  ],
                ),
              ),
              FoodyFormSeccion(
                titulo: 'Cocina',
                icono: Icons.soup_kitchen_outlined,
                acento: AnaliticaTokens.pedidos,
                hijo: _cocinas.isEmpty
                    ? Text(
                        'Sin cocinas. Crea una en «Cocinas e impresoras».',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade800,
                        ),
                      )
                    : DropdownButtonFormField<String>(
                        initialValue: cocinaId,
                        decoration: FoodyFormEstilo.campo(
                          label: 'Cocina (ticket)',
                        ),
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
              ),
            ],
          ),
          acciones: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: AnaliticaTokens.ink,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Crear'),
            ),
          ],
        ),
      ),
    );
    final nombre = nombreCtrl.text.trim();
    final precio = double.tryParse(precioCtrl.text.replaceAll(',', '.')) ?? 0;
    nombreCtrl.dispose();
    precioCtrl.dispose();
    if (ok == true && nombre.isNotEmpty && catId != null) {
      try {
        await _repo.crearProducto(
          sucursalId: widget.sucursalId!,
          categoriaId: catId!,
          nombre: nombre,
          precio: precio,
          cocinaId: cocinaId,
        );
        await _cargar();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(mensajeErrorHttp(e, contexto: 'producto'))),
          );
        }
      }
    }
  }

  Future<void> _subirFotoProducto(Map<String, dynamic> producto) async {
    final sid = widget.sucursalId;
    if (sid == null) return;

    final pick = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (pick == null) return;

    try {
      final bytes = await pick.readAsBytes();
      await _almacenamiento.subirImagenProducto(
        productoId: producto['id'] as String,
        sucursalId: sid,
        bytes: bytes,
        nombreArchivo: pick.name,
      );
      await _cargar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto del producto actualizada')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensajeErrorHttp(e, contexto: 'imagen'))),
        );
      }
    }
  }

  Future<void> _subirFotoCombo(Map<String, dynamic> combo) async {
    final sid = widget.sucursalId;
    if (sid == null) return;

    final pick = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (pick == null) return;

    try {
      await _almacenamiento.subirImagenCombo(
        comboId: combo['id'] as String,
        sucursalId: sid,
        bytes: await pick.readAsBytes(),
        nombreArchivo: pick.name,
      );
      await _cargar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto del combo actualizada')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensajeErrorHttp(e, contexto: 'imagen'))),
        );
      }
    }
  }

  Future<void> _subirFotoCategoria(Map<String, dynamic> categoria) async {
    final sid = widget.sucursalId;
    if (sid == null) return;

    final pick = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (pick == null) return;

    try {
      await _almacenamiento.subirImagenCategoria(
        categoriaId: categoria['id'] as String,
        sucursalId: sid,
        bytes: await pick.readAsBytes(),
        nombreArchivo: pick.name,
      );
      await _cargar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto de categoría actualizada')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensajeErrorHttp(e, contexto: 'imagen'))),
        );
      }
    }
  }

  Future<void> _gestionarCategorias() async {
    if (_categorias.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay categorías. Crea una primero.')),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Categorías'),
        content: SizedBox(
          width: 360,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _categorias.length,
            itemBuilder: (_, i) {
              final cat = _categorias[i];
              final imagenUrl = cat['imagen_url'] as String?;
              return ListTile(
                leading: imagenUrl != null && imagenUrl.isNotEmpty
                    ? CircleAvatar(backgroundImage: NetworkImage(imagenUrl))
                    : const CircleAvatar(child: Icon(Icons.category)),
                title: Text(cat['nombre'] as String? ?? ''),
                trailing: IconButton(
                  tooltip: 'Subir foto',
                  icon: const Icon(Icons.photo_camera_outlined),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _subirFotoCategoria(cat);
                    if (mounted) await _gestionarCategorias();
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
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
    final costeo = _costeoPorProducto[producto['id'] as String];
    final costo = costeo != null ? _num(costeo['costo_calculado']) : null;
    final margen = costeo != null
        ? num.tryParse('${costeo['margen_porcentaje']}')
        : null;
    final sugerido = costeo != null ? _num(costeo['precio_sugerido']) : null;
    final sinReceta = costeo != null && costeo['costo_calculado'] == null;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => FoodyDialogoShell(
        titulo: 'Precios',
        subtitulo: producto['nombre'] as String? ?? '',
        maxWidth: 420,
        contenido: FoodyFormSeccion(
          titulo: 'Canales de venta',
          icono: Icons.sell_outlined,
          hijo: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // NAV-MC-13: costo/margen visible al fijar precio.
              if (widget.onVerCostos != null && costeo != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sinReceta
                            ? 'Sin receta — arma el costo en Costos'
                            : [
                                if (costo != null)
                                  'Costo ${_moneda.format(costo)}',
                                if (margen != null)
                                  'margen ${margen.toStringAsFixed(0)}%',
                                if (sugerido != null && sugerido > 0)
                                  'sugerido ${_moneda.format(sugerido)}',
                              ].join(' · '),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx, false);
                          widget.onVerCostos!(producto['id'] as String);
                        },
                        child: Text(
                          sinReceta ? 'Ir a Costos' : 'Ver / ajustar costos',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
              TextField(
                controller: localCtrl,
                keyboardType: TextInputType.number,
                decoration: FoodyFormEstilo.campo(
                  label: 'Precio local / mesa (COP)',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: llevarCtrl,
                keyboardType: TextInputType.number,
                decoration: FoodyFormEstilo.campo(
                  label: 'Precio para llevar / domicilio',
                  hint: 'Vacío = mismo que local',
                ),
              ),
            ],
          ),
        ),
        acciones: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AnaliticaTokens.ink,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Guardar'),
          ),
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
        mostrarErrorSnackBar(context, e, contexto: 'guardar producto');
      }
    }
  }

  Future<void> _configurarToppingsProducto(Map<String, dynamic> producto) async {
    if (_toppings.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Crea toppings primero (pestaña Toppings)')),
      );
      return;
    }
    final productoId = producto['id'] as String;
    Set<String> seleccionados = {};
    try {
      final ligados = await _repo.toppingsDeProducto(productoId);
      seleccionados = {
        for (final t in ligados) t['id'] as String,
      };
    } catch (e) {
      if (mounted) {
        mostrarErrorSnackBar(context, e, contexto: 'cargar toppings');
      }
      return;
    }
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text('Toppings · ${producto['nombre']}'),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Marca los toppings que aplican a este plato. '
                    'Los no marcados no aparecen al cliente.',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 12),
                  for (final t in _toppings)
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: seleccionados.contains(t['id'] as String),
                      title: Text(t['nombre'] as String? ?? ''),
                      subtitle: Text(_moneda.format(_num(t['precio']))),
                      activeColor: AnaliticaTokens.ink,
                      onChanged: (v) => setDlg(() {
                        final id = t['id'] as String;
                        if (v == true) {
                          seleccionados = {...seleccionados, id};
                        } else {
                          seleccionados = {...seleccionados}..remove(id);
                        }
                      }),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await _repo.configurarToppingsProducto(
        productoId: productoId,
        toppingIds: seleccionados.toList(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${seleccionados.length} topping(s) asignados a ${producto['nombre']}',
            ),
          ),
        );
      }
      await _cargar();
    } catch (e) {
      if (mounted) {
        mostrarErrorSnackBar(context, e, contexto: 'guardar toppings');
      }
    }
  }

  Future<void> _nuevoExtra({required bool esBebida}) async {
    final nombre = TextEditingController();
    final precio = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => FoodyDialogoShell(
        titulo: esBebida ? 'Nueva bebida' : 'Nuevo topping',
        maxWidth: 400,
        contenido: FoodyFormSeccion(
          titulo: 'Datos',
          icono: esBebida ? Icons.local_drink_outlined : Icons.spa_outlined,
          hijo: Column(
            children: [
              TextField(
                controller: nombre,
                decoration: FoodyFormEstilo.campo(label: 'Nombre'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: precio,
                keyboardType: TextInputType.number,
                decoration: FoodyFormEstilo.campo(label: 'Precio'),
              ),
            ],
          ),
        ),
        acciones: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AnaliticaTokens.ink,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Crear'),
          ),
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
    if (_productos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Necesitas al menos 1 producto en el menú')),
      );
      return;
    }
    final nombre = TextEditingController();
    final precio = TextEditingController();
    // clave = "producto:uuid" | "bebida:uuid" | "topping:uuid"
    final seleccionados = <String>{'producto:${_productos.first['id']}'};

    Widget chipLista({
      required String titulo,
      required String tipo,
      required List<Map<String, dynamic>> filas,
      required void Function(void Function()) setDlg,
    }) {
      if (filas.isEmpty) return const SizedBox.shrink();
      return FoodyFormSeccion(
        titulo: titulo,
        icono: tipo == 'bebida'
            ? Icons.local_drink_outlined
            : tipo == 'topping'
                ? Icons.add_circle_outline
                : Icons.restaurant_outlined,
        acento: AnaliticaTokens.pedidos,
        hijo: SizedBox(
          height: filas.length > 4 ? 160 : null,
          child: ListView(
            shrinkWrap: true,
            physics: filas.length > 4
                ? const AlwaysScrollableScrollPhysics()
                : const NeverScrollableScrollPhysics(),
            children: filas.map((p) {
              final id = p['id'] as String;
              final clave = '$tipo:$id';
              return CheckboxListTile(
                value: seleccionados.contains(clave),
                title: Text(p['nombre'] as String? ?? ''),
                contentPadding: EdgeInsets.zero,
                dense: true,
                activeColor: AnaliticaTokens.ink,
                onChanged: (v) {
                  setDlg(() {
                    if (v == true) {
                      seleccionados.add(clave);
                    } else {
                      final esUnicoProducto = tipo == 'producto' &&
                          seleccionados
                                  .where((c) => c.startsWith('producto:'))
                                  .length <=
                              1 &&
                          seleccionados.contains(clave);
                      if (!esUnicoProducto) seleccionados.remove(clave);
                    }
                  });
                },
              );
            }).toList(),
          ),
        ),
      );
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => FoodyDialogoShell(
          titulo: 'Nuevo combo',
          subtitulo:
              'Paquete con precio fijo. Incluye productos, bebidas y/o toppings.',
          maxWidth: 440,
          contenido: Column(
            children: [
              FoodyFormSeccion(
                titulo: 'Combo',
                icono: Icons.layers_outlined,
                hijo: Column(
                  children: [
                    TextField(
                      controller: nombre,
                      decoration: FoodyFormEstilo.campo(label: 'Nombre'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: precio,
                      keyboardType: TextInputType.number,
                      decoration: FoodyFormEstilo.campo(label: 'Precio fijo'),
                    ),
                  ],
                ),
              ),
              chipLista(
                titulo: 'Productos (mín. 1)',
                tipo: 'producto',
                filas: _productos,
                setDlg: setDlg,
              ),
              chipLista(
                titulo: 'Bebidas incluidas',
                tipo: 'bebida',
                filas: _bebidas,
                setDlg: setDlg,
              ),
              chipLista(
                titulo: 'Toppings incluidos',
                tipo: 'topping',
                filas: _toppings,
                setDlg: setDlg,
              ),
            ],
          ),
          acciones: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: AnaliticaTokens.ink,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Crear'),
            ),
          ],
        ),
      ),
    );
    final n = nombre.text.trim();
    final p = double.tryParse(precio.text.replaceAll(',', '.')) ?? 0;
    nombre.dispose();
    precio.dispose();
    final nProductos =
        seleccionados.where((c) => c.startsWith('producto:')).length;
    if (ok != true || n.isEmpty || nProductos < 1 || seleccionados.length < 2) {
      if (ok == true && (nProductos < 1 || seleccionados.length < 2)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'El combo necesita ≥1 producto y al menos 2 ítems en total',
              ),
            ),
          );
        }
      }
      return;
    }
    final items = seleccionados.map((clave) {
      final i = clave.indexOf(':');
      return {
        'tipo_item': clave.substring(0, i),
        'item_id': clave.substring(i + 1),
        'cantidad': 1,
      };
    }).toList();
    await _repo.crearCombo(
      sucursalId: widget.sucursalId!,
      nombre: n,
      precioFijo: p,
      items: items,
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
    if (widget.sucursalId == null) {
      return const ColoredBox(
        color: AnaliticaTokens.canvas,
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No hay sucursal activa en tu sesión. Cierra sesión e ingresa de nuevo.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AnaliticaTokens.inkMuted),
            ),
          ),
        ),
      );
    }

    if (_cargando) {
      return ColoredBox(
        color: AnaliticaTokens.canvas,
        child: AnaliticaSkeleton.tab(),
      );
    }

    final ancho = FoodyBreakpoints.widthOf(context);
    final compacto = FoodyBreakpoints.esCompact(ancho);
    final sinRecetaN = _productos.where((p) {
      final c = _costeoPorProducto[p['id'] as String];
      return c != null && c['costo_calculado'] == null;
    }).length;
    final noDispN =
        _productos.where((p) => p['disponible'] == false).length;

    return ColoredBox(
      color: AnaliticaTokens.canvas,
      child: SaasScrollableShell(
        header: [
          Padding(
            padding: EdgeInsets.fromLTRB(compacto ? 12 : 16, 8, 8, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Admin / Menú e Inventario',
                        style: TextStyle(
                          fontSize: 11,
                          color: AnaliticaTokens.inkSoft,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Menú',
                        style: TextStyle(
                          fontSize: compacto ? 18 : 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                          color: AnaliticaTokens.ink,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Carta → insumos → costos y márgenes',
                        style: TextStyle(
                          fontSize: 12,
                          color: AnaliticaTokens.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (compacto)
                  PopupMenuButton<String>(
                    tooltip: 'Acciones del menú',
                    icon: const Icon(
                      Icons.more_vert,
                      color: AnaliticaTokens.inkMuted,
                    ),
                    onSelected: (a) {
                      switch (a) {
                        case 'copiar':
                          unawaited(_copiarMenuDesde());
                        case 'categorias':
                          unawaited(_gestionarCategorias());
                        case 'nueva_cat':
                          unawaited(_nuevaCategoria());
                        case 'nuevo':
                          unawaited(_nuevoProducto());
                      }
                    },
                    itemBuilder: (_) => [
                      if (widget.sucursalesOrigen.isNotEmpty)
                        const PopupMenuItem(
                          value: 'copiar',
                          child: ListTile(
                            dense: true,
                            leading: Icon(Icons.copy_all_outlined),
                            title: Text('Copiar menú desde otra sede'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      const PopupMenuItem(
                        value: 'categorias',
                        child: ListTile(
                          dense: true,
                          leading: Icon(Icons.category_outlined),
                          title: Text('Gestionar categorías'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'nueva_cat',
                        child: ListTile(
                          dense: true,
                          leading: Icon(Icons.create_new_folder_outlined),
                          title: Text('Nueva categoría'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'nuevo',
                        child: ListTile(
                          dense: true,
                          leading: Icon(Icons.add_circle_outline),
                          title: Text('Nuevo producto'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  )
                else ...[
                  if (widget.sucursalesOrigen.isNotEmpty)
                    IconButton(
                      tooltip: 'Copiar menú desde otra sede',
                      onPressed: _copiarMenuDesde,
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.copy_all_outlined, size: 20),
                      color: AnaliticaTokens.inkMuted,
                    ),
                  IconButton(
                    tooltip: 'Gestionar categorías',
                    onPressed: _gestionarCategorias,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.category_outlined, size: 20),
                    color: AnaliticaTokens.inkMuted,
                  ),
                  IconButton(
                    tooltip: 'Nueva categoría',
                    onPressed: _nuevaCategoria,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.create_new_folder_outlined, size: 20),
                    color: AnaliticaTokens.inkMuted,
                  ),
                  FilledButton.icon(
                    onPressed: _nuevoProducto,
                    style: FilledButton.styleFrom(
                      backgroundColor: AnaliticaTokens.ink,
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Nuevo producto'),
                  ),
                ],
              ],
            ),
          ),
          if (_errorCarga != null)
            esMensajeSuscripcion(_errorCarga!)
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: FoodyEstadoUi.desdeMensaje(
                      mensaje: _errorCarga!,
                      onReintentar: _cargar,
                    ),
                  )
                : Padding(
                    padding: EdgeInsets.fromLTRB(
                      compacto ? 12 : 16,
                      8,
                      compacto ? 12 : 16,
                      0,
                    ),
                    child: Material(
                      color: AnaliticaTokens.surface,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color:
                                AnaliticaTokens.alertas.withValues(alpha: 0.35),
                          ),
                        ),
                        child: ListTile(
                          dense: true,
                          leading: const Icon(
                            Icons.error_outline,
                            color: AnaliticaTokens.alertas,
                            size: 20,
                          ),
                          title: Text(
                            _errorCarga!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AnaliticaTokens.inkMuted,
                            ),
                          ),
                          trailing: TextButton(
                            onPressed: _cargar,
                            style: TextButton.styleFrom(
                              foregroundColor: AnaliticaTokens.alertas,
                            ),
                            child: const Text('Reintentar'),
                          ),
                        ),
                      ),
                    ),
                  ),
          const GuiaPasosCompacta(
            preferenciaKey: 'guia_pasos_menu',
            pasos: [
              'Crea platos y categorías de la carta',
              'Registra insumos en Insumos › Mercado',
              'Arma recetas y márgenes en Costos',
            ],
          ),
          if (sinRecetaN > 0 || noDispN > 0)
            Padding(
              padding: EdgeInsets.fromLTRB(
                compacto ? 12 : 16,
                0,
                compacto ? 12 : 16,
                8,
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (sinRecetaN > 0)
                    _alertaChip(
                      '$sinRecetaN sin receta',
                      const Color(0xFFD97706),
                      () => setState(() {
                        _filtroProductos = 'sin_receta';
                        _tabs.index = 0;
                      }),
                    ),
                  if (noDispN > 0)
                    _alertaChip(
                      '$noDispN no disponibles',
                      AnaliticaTokens.inkMuted,
                      () => setState(() {
                        _filtroProductos = 'no_disponible';
                        _tabs.index = 0;
                      }),
                    ),
                ],
              ),
            ),
        ],
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Container(
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AnaliticaTokens.borderSoft),
                  ),
                ),
                child: FoodyScrollHorizontalFade(
                  child: TabBar(
                    controller: _tabs,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelColor: AnaliticaTokens.ink,
                    unselectedLabelColor: AnaliticaTokens.inkSoft,
                    indicatorColor: AnaliticaTokens.ink,
                    indicatorWeight: 2,
                    dividerColor: Colors.transparent,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 12.5,
                    ),
                    tabs: [
                      Tab(text: 'Productos (${_productos.length})'),
                      Tab(text: 'Toppings (${_toppings.length})'),
                      Tab(text: 'Bebidas (${_bebidas.length})'),
                      Tab(text: 'Combos (${_combos.length})'),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _tabProductos(compacto: compacto),
                  _tabExtras(_toppings, esBebida: false, compacto: compacto),
                  _tabExtras(_bebidas, esBebida: true, compacto: compacto),
                  _tabCombos(compacto: compacto),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _alertaChip(String text, Color color, VoidCallback onTap) {
    return Material(
      color: AnaliticaTokens.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.filter_alt_outlined, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                text,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> get _productosFiltrados {
    final q = _busquedaCtrl.text.trim().toLowerCase();
    return _productos.where((p) {
      final nombre = (p['nombre'] as String? ?? '').toLowerCase();
      if (q.isNotEmpty && !nombre.contains(q)) return false;
      final disponible = p['disponible'] as bool? ?? true;
      final costeo = _costeoPorProducto[p['id'] as String];
      final sinReceta = costeo != null && costeo['costo_calculado'] == null;
      final margen = costeo != null
          ? num.tryParse('${costeo['margen_porcentaje']}')
          : null;
      final bajoMargen =
          margen != null && margen < _umbralMargen && !sinReceta;
      switch (_filtroProductos) {
        case 'sin_receta':
          return sinReceta;
        case 'bajo_margen':
          return bajoMargen;
        case 'no_disponible':
          return !disponible;
        default:
          return true;
      }
    }).toList();
  }

  Widget _chipFiltro(String id, String label) {
    final sel = _filtroProductos == id;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: sel ? AnaliticaTokens.ink : AnaliticaTokens.surface,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: () => setState(() => _filtroProductos = id),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: sel ? AnaliticaTokens.ink : AnaliticaTokens.border,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: sel ? Colors.white : AnaliticaTokens.inkMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _badgeCosteo({
    required String texto,
    required bool sinReceta,
    required bool bajoMargen,
    required VoidCallback onTap,
  }) {
    final color = sinReceta
        ? const Color(0xFFD97706)
        : bajoMargen
            ? AnaliticaTokens.alertas
            : AnaliticaTokens.inventario;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(
          texto,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _tabProductos({required bool compacto}) {
    if (_productos.isEmpty) {
      // NAV-MG-02: gerente (sin copiar menú) necesita bootstrap claro.
      final puedeCopiar = widget.sucursalesOrigen.isNotEmpty;
      return RefreshIndicator(
        onRefresh: _cargar,
        child: ListView(
          padding: EdgeInsets.all(compacto ? 20 : 28),
          children: [
            const SizedBox(height: 40),
            const Icon(
              Icons.restaurant_menu_outlined,
              size: 40,
              color: AnaliticaTokens.inkSoft,
            ),
            const SizedBox(height: 12),
            const Text(
              'Sin productos aún',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AnaliticaTokens.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              puedeCopiar
                  ? 'Crea el primer plato o copia el menú desde otra sede'
                  : 'En esta sede no puedes copiar el menú de otra. '
                      'Pide al admin o gerente de cadena que copie desde la matriz, '
                      'o crea los platos aquí.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AnaliticaTokens.inkMuted,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: FilledButton.icon(
                onPressed: _nuevoProducto,
                style: FilledButton.styleFrom(
                  backgroundColor: AnaliticaTokens.ink,
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Crear primer producto'),
              ),
            ),
            if (puedeCopiar) ...[
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: _copiarMenuDesde,
                  style: TextButton.styleFrom(
                    foregroundColor: AnaliticaTokens.inkMuted,
                  ),
                  icon: const Icon(Icons.copy_all_outlined),
                  label: const Text('Copiar menú desde otra sede'),
                ),
              ),
            ],
          ],
        ),
      );
    }

    final lista = _productosFiltrados;

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            compacto ? 12 : 16,
            10,
            compacto ? 12 : 16,
            4,
          ),
          child: TextField(
            controller: _busquedaCtrl,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Buscar producto…',
              hintStyle: const TextStyle(color: AnaliticaTokens.inkSoft),
              prefixIcon: const Icon(
                Icons.search,
                size: 18,
                color: AnaliticaTokens.inkSoft,
              ),
              isDense: true,
              filled: true,
              fillColor: AnaliticaTokens.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AnaliticaTokens.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AnaliticaTokens.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AnaliticaTokens.ink),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
          ),
        ),
        FoodyScrollHorizontalFade(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(
              horizontal: compacto ? 12 : 16,
              vertical: 4,
            ),
            child: Row(
              children: [
                _chipFiltro('todos', 'Todos'),
                _chipFiltro('sin_receta', 'Sin receta'),
                _chipFiltro('bajo_margen', 'Bajo margen'),
                _chipFiltro('no_disponible', 'No disponible'),
              ],
            ),
          ),
        ),
        Expanded(
          child: lista.isEmpty
              ? const Center(
                  child: Text(
                    'Ningún producto coincide',
                    style: TextStyle(color: AnaliticaTokens.inkSoft),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: ListView.builder(
                    padding: EdgeInsets.fromLTRB(
                      compacto ? 12 : 16,
                      4,
                      compacto ? 12 : 16,
                      24,
                    ),
                    itemCount: lista.length,
                    itemBuilder: (_, i) =>
                        _tarjetaProducto(lista[i], compacto: compacto),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _tarjetaProducto(
    Map<String, dynamic> p, {
    required bool compacto,
  }) {
    final disponible = p['disponible'] as bool? ?? true;
    final precioNum = _num(p['precio']);
    final imagenUrl = p['imagen_url'] as String?;
    final costeo = _costeoPorProducto[p['id'] as String];
    final sinReceta = costeo != null && costeo['costo_calculado'] == null;
    final margen = costeo != null
        ? num.tryParse('${costeo['margen_porcentaje']}')
        : null;
    final bajoMargen = margen != null && margen < _umbralMargen && !sinReceta;
    final sinCocina = p['cocina_id'] == null;
    String? etiquetaCosteo;
    if (sinReceta) {
      etiquetaCosteo = 'Sin receta · ver costos';
    } else if (margen != null) {
      etiquetaCosteo = bajoMargen
          ? 'Margen ${margen.toStringAsFixed(0)}% · ajustar'
          : 'Margen ${margen.toStringAsFixed(0)}%';
    }
    final colorRiesgo = !disponible
        ? AnaliticaTokens.inkSoft
        : sinReceta
            ? const Color(0xFFD97706)
            : bajoMargen
                ? AnaliticaTokens.alertas
                : sinCocina
                    ? AnaliticaTokens.alertas
                    : AnaliticaTokens.border;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: AnaliticaTokens.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: (sinReceta || bajoMargen || !disponible)
              ? colorRiesgo.withValues(alpha: 0.4)
              : AnaliticaTokens.border,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A111827),
            blurRadius: 6,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _editarPrecios(p),
          child: Padding(
            padding: EdgeInsets.fromLTRB(compacto ? 10 : 12, 10, 4, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: imagenUrl != null && imagenUrl.isNotEmpty
                      ? Image.network(
                          imagenUrl,
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                          cacheWidth:
                              (44 * MediaQuery.devicePixelRatioOf(context))
                                  .round(),
                          cacheHeight:
                              (44 * MediaQuery.devicePixelRatioOf(context))
                                  .round(),
                          errorBuilder: (_, __, ___) => Container(
                            width: 44,
                            height: 44,
                            color: AnaliticaTokens.surfaceMuted,
                            child: const Icon(
                              Icons.broken_image_outlined,
                              size: 18,
                              color: AnaliticaTokens.inkSoft,
                            ),
                          ),
                        )
                      : Container(
                          width: 44,
                          height: 44,
                          color: AnaliticaTokens.surfaceMuted,
                          child: Icon(
                            Icons.restaurant,
                            size: 20,
                            color: !disponible
                                ? AnaliticaTokens.inkSoft
                                : AnaliticaTokens.inkMuted,
                          ),
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p['nombre'] as String? ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AnaliticaTokens.ink,
                          decoration:
                              disponible ? null : TextDecoration.lineThrough,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_moneda.format(precioNum)} · ${_subtituloPrecios(p)}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AnaliticaTokens.inkMuted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (!disponible)
                            _badgeCosteo(
                              texto: 'No disponible',
                              sinReceta: false,
                              bajoMargen: true,
                              onTap: () async {
                                await _repo.toggleDisponible(
                                  p['id'] as String,
                                  true,
                                );
                                await _cargar();
                              },
                            ),
                          if (sinCocina)
                            _badgeCosteo(
                              texto: 'Sin cocina',
                              sinReceta: false,
                              bajoMargen: true,
                              onTap: () => unawaited(_reasignarCocina(p)),
                            ),
                          if (widget.onVerCostos != null &&
                              etiquetaCosteo != null)
                            _badgeCosteo(
                              texto: etiquetaCosteo,
                              sinReceta: sinReceta,
                              bajoMargen: bajoMargen,
                              onTap: () =>
                                  widget.onVerCostos!(p['id'] as String),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Switch.adaptive(
                      value: disponible,
                      activeTrackColor:
                          AnaliticaTokens.ink.withValues(alpha: 0.35),
                      onChanged: (v) async {
                        await _repo.toggleDisponible(p['id'] as String, v);
                        await _cargar();
                      },
                    ),
                    // NAV-ADM-05: acciones secundarias en menú (evita overflow móvil).
                    PopupMenuButton<String>(
                      tooltip: 'Más acciones',
                      icon: const Icon(
                        Icons.more_vert,
                        size: 20,
                        color: AnaliticaTokens.inkSoft,
                      ),
                      onSelected: (accion) {
                        switch (accion) {
                          case 'foto':
                            unawaited(_subirFotoProducto(p));
                          case 'cocina':
                            unawaited(_reasignarCocina(p));
                          case 'extras':
                            unawaited(_configurarToppingsProducto(p));
                          case 'costos':
                            widget.onVerCostos?.call(p['id'] as String);
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'foto',
                          child: ListTile(
                            dense: true,
                            leading: Icon(Icons.photo_camera_outlined),
                            title: Text('Subir foto'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        PopupMenuItem(
                          value: 'cocina',
                          child: ListTile(
                            dense: true,
                            leading: Icon(
                              Icons.soup_kitchen_outlined,
                              color: p['cocina_id'] == null
                                  ? AnaliticaTokens.alertas
                                  : AnaliticaTokens.pedidos,
                            ),
                            title: Text(
                              p['cocina_id'] == null
                                  ? 'Asignar cocina'
                                  : 'Cambiar cocina',
                            ),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'extras',
                          child: ListTile(
                            dense: true,
                            leading: Icon(Icons.link),
                            title: Text('Toppings del plato'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        if (widget.onVerCostos != null)
                          const PopupMenuItem(
                            value: 'costos',
                            child: ListTile(
                              dense: true,
                              leading: Icon(Icons.pie_chart_outline),
                              title: Text('Ver costos'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// NAV-MC-16: misma barra de creación en Toppings / Bebidas / Combos.
  Widget _barraCrear({
    required String etiqueta,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Align(
        alignment: Alignment.centerRight,
        child: FilledButton.icon(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: AnaliticaTokens.ink,
            visualDensity: VisualDensity.compact,
          ),
          icon: const Icon(Icons.add, size: 18),
          label: Text(etiqueta),
        ),
      ),
    );
  }

  Widget _tabExtras(
    List<Map<String, dynamic>> items, {
    required bool esBebida,
    required bool compacto,
  }) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            compacto ? 12 : 16,
            8,
            compacto ? 12 : 16,
            0,
          ),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AnaliticaTokens.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AnaliticaTokens.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  esBebida
                      ? Icons.local_drink_outlined
                      : Icons.add_circle_outline,
                  size: 18,
                  color: AnaliticaTokens.inkMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    esBebida
                        ? 'Al crear aquí también se publica como producto en el '
                            'menú (categoría Bebidas). El cliente la ve en la carta '
                            'y al personalizar un plato.'
                        : 'Los toppings son extras por plato. Asígnanos con '
                            '«Toppings del plato» en cada producto (checkboxes).',
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: AnaliticaTokens.inkMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        _barraCrear(
          etiqueta: esBebida ? 'Nueva bebida' : 'Nuevo topping',
          onPressed: () => _nuevoExtra(esBebida: esBebida),
        ),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          esBebida
                              ? Icons.local_drink_outlined
                              : Icons.restaurant_outlined,
                          size: 40,
                          color: AnaliticaTokens.inkSoft,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          esBebida ? 'Sin bebidas aún' : 'Sin toppings aún',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AnaliticaTokens.ink,
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () => _nuevoExtra(esBebida: esBebida),
                          style: FilledButton.styleFrom(
                            backgroundColor: AnaliticaTokens.ink,
                          ),
                          icon: const Icon(Icons.add, size: 18),
                          label: Text(
                            esBebida ? 'Crear bebida' : 'Crear topping',
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.fromLTRB(
                    compacto ? 12 : 16,
                    8,
                    compacto ? 12 : 16,
                    24,
                  ),
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final e = items[i];
                    final disponible = e['disponible'] as bool? ?? true;
                    final costeo = _costeoPorProducto[e['id'] as String];
                    final sinReceta = costeo != null
                        ? costeo['costo_calculado'] == null
                        : (e['receta_id'] == null &&
                            e['costo_calculado'] == null);
                    final margen = costeo != null
                        ? num.tryParse('${costeo['margen_porcentaje']}')
                        : null;
                    final bajoMargen = margen != null &&
                        margen < _umbralMargen &&
                        !sinReceta;
                    String? etiquetaCosteo;
                    if (widget.onVerCostos != null) {
                      if (sinReceta) {
                        etiquetaCosteo = 'Sin receta · ver costos';
                      } else if (margen != null) {
                        etiquetaCosteo = bajoMargen
                            ? 'Margen ${margen.toStringAsFixed(0)}% · ajustar'
                            : 'Margen ${margen.toStringAsFixed(0)}%';
                      } else if (e['costo_calculado'] != null) {
                        etiquetaCosteo =
                            'Costo ${_moneda.format(_num(e['costo_calculado']))}';
                      }
                    }
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: AnaliticaTokens.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: sinReceta || bajoMargen
                              ? (sinReceta
                                      ? const Color(0xFFD97706)
                                      : AnaliticaTokens.alertas)
                                  .withValues(alpha: 0.35)
                              : AnaliticaTokens.border,
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.fromLTRB(12, 4, 8, 4),
                        title: Text(
                          e['nombre'] as String? ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13.5,
                            color: AnaliticaTokens.ink,
                            decoration: disponible
                                ? null
                                : TextDecoration.lineThrough,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _moneda.format(_num(e['precio'])),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AnaliticaTokens.inkMuted,
                              ),
                            ),
                            if (etiquetaCosteo != null) ...[
                              const SizedBox(height: 4),
                              _badgeCosteo(
                                texto: etiquetaCosteo,
                                sinReceta: sinReceta,
                                bajoMargen: bajoMargen,
                                onTap: () =>
                                    widget.onVerCostos!(e['id'] as String),
                              ),
                            ],
                          ],
                        ),
                        isThreeLine: etiquetaCosteo != null,
                        trailing: Switch.adaptive(
                          value: disponible,
                          activeTrackColor:
                              AnaliticaTokens.ink.withValues(alpha: 0.35),
                          onChanged: (v) async {
                            await _repo.toggleExtra(
                              id: e['id'] as String,
                              disponible: v,
                              esBebida: esBebida,
                            );
                            await _cargar();
                          },
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _tabCombos({required bool compacto}) {
    return Column(
      children: [
        _barraCrear(
          etiqueta: 'Nuevo combo',
          onPressed: _nuevoCombo,
        ),
        Expanded(
          child: _combos.isEmpty
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(compacto ? 20 : 28),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AnaliticaTokens.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AnaliticaTokens.border),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.layers_outlined,
                              size: 36,
                              color: AnaliticaTokens.inkSoft,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Sin combos aún',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AnaliticaTokens.ink,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Combo = paquete que el cliente elige en el menú '
                              '(ej. hígado + huevo + jugo con precio total).\n\n'
                              'Si el plato ya trae rosquetes incluidos, configúralo en '
                              'Costos → «Incluidos», no aquí.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: AnaliticaTokens.inkMuted,
                                height: 1.4,
                              ),
                            ),
                            if (widget.onVerCostos != null) ...[
                              const SizedBox(height: 16),
                              TextButton.icon(
                                onPressed: () {
                                  final id = _productos.isNotEmpty
                                      ? _productos.first['id'] as String?
                                      : null;
                                  if (id != null) {
                                    widget.onVerCostos!(id);
                                  }
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: AnaliticaTokens.inkMuted,
                                ),
                                icon: const Icon(Icons.pie_chart_outline),
                                label: const Text('Abrir Costos (incluidos)'),
                              ),
                            ],
                            const SizedBox(height: 8),
                            FilledButton.icon(
                              onPressed: _nuevoCombo,
                              style: FilledButton.styleFrom(
                                backgroundColor: AnaliticaTokens.ink,
                              ),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Crear combo'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.fromLTRB(
                    compacto ? 12 : 16,
                    8,
                    compacto ? 12 : 16,
                    24,
                  ),
                  itemCount: _combos.length,
                  itemBuilder: (_, i) {
                    final c = _combos[i];
                    final items = c['items'];
                    final nItems = items is List ? items.length : 0;
                    final imagenUrl = c['imagen_url'] as String?;
                    final disponible = c['disponible'] as bool? ?? true;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: AnaliticaTokens.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AnaliticaTokens.border),
                      ),
                      child: ListTile(
                        contentPadding:
                            const EdgeInsets.fromLTRB(12, 6, 8, 6),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: imagenUrl != null && imagenUrl.isNotEmpty
                              ? Image.network(
                                  imagenUrl,
                                  width: 44,
                                  height: 44,
                                  fit: BoxFit.cover,
                                  cacheWidth:
                                      (44 * MediaQuery.devicePixelRatioOf(context))
                                          .round(),
                                  cacheHeight:
                                      (44 * MediaQuery.devicePixelRatioOf(context))
                                          .round(),
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 44,
                                    height: 44,
                                    color: AnaliticaTokens.surfaceMuted,
                                    child: const Icon(
                                      Icons.layers_outlined,
                                      size: 18,
                                      color: AnaliticaTokens.inkSoft,
                                    ),
                                  ),
                                )
                              : Container(
                                  width: 44,
                                  height: 44,
                                  color: AnaliticaTokens.surfaceMuted,
                                  child: const Icon(
                                    Icons.layers_outlined,
                                    size: 18,
                                    color: AnaliticaTokens.inkMuted,
                                  ),
                                ),
                        ),
                        title: Text(
                          c['nombre'] as String? ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AnaliticaTokens.ink,
                            decoration: disponible
                                ? null
                                : TextDecoration.lineThrough,
                          ),
                        ),
                        subtitle: Text(
                          '${_moneda.format(_num(c['precio_fijo']))} · $nItems ítems',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AnaliticaTokens.inkMuted,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            PopupMenuButton<String>(
                              tooltip: 'Más acciones',
                              icon: const Icon(
                                Icons.more_vert,
                                size: 20,
                                color: AnaliticaTokens.inkSoft,
                              ),
                              onSelected: (a) {
                                if (a == 'foto') {
                                  unawaited(_subirFotoCombo(c));
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'foto',
                                  child: ListTile(
                                    dense: true,
                                    leading: Icon(Icons.photo_camera_outlined),
                                    title: Text('Subir foto'),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              ],
                            ),
                            Switch.adaptive(
                              value: disponible,
                              activeTrackColor:
                                  AnaliticaTokens.ink.withValues(alpha: 0.35),
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
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
