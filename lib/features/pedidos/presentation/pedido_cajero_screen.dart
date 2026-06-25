import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
import 'package:reserva_canchas/core/red/dialogo_stock_insuficiente.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';
import 'package:reserva_canchas/features/admin/presentation/widgets/operacion_ui.dart';
import 'package:reserva_canchas/features/caja/data/caja_repository.dart';
import 'package:reserva_canchas/features/admin/data/pedidos_repository.dart';
import 'package:reserva_canchas/features/mesa/data/mesas_repository.dart';
import 'package:reserva_canchas/features/menu/data/menu_repository.dart';
import 'package:reserva_canchas/features/menu/domain/menu_model.dart';
import 'package:reserva_canchas/features/menu/presentation/widgets/detalle_producto_sheet.dart';
import 'package:reserva_canchas/features/pedidos/domain/linea_carrito.dart';
import 'package:reserva_canchas/core/realtime/foody_realtime.dart';
import 'package:reserva_canchas/services/app_backend.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Constructor de pedido staff — layout POS (ref. foody_redesign_complete.html).
class PedidoCajeroScreen extends StatefulWidget {
  const PedidoCajeroScreen({
    super.key,
    this.sucursalId,
    this.mesaIdFija,
    this.mesaNombreFija,
    this.modoMesero = false,
    this.pedidoIdAgregar,
  });

  final String? sucursalId;
  final String? mesaIdFija;
  final String? mesaNombreFija;
  final bool modoMesero;
  /// Si se indica, los ítems se suman a este pedido (consumo en mesa).
  final String? pedidoIdAgregar;

  @override
  State<PedidoCajeroScreen> createState() => _PedidoCajeroScreenState();
}

class _PedidoCajeroScreenState extends State<PedidoCajeroScreen> {
  final _menuRepo = MenuRepository();
  final _pedidosRepo = PedidosRepository();
  final _mesasRepo = MesasRepository();
  final _cajaRepo = CajaRepository();
  final _busquedaCtrl = TextEditingController();
  final _notaCtrl = TextEditingController();

  MenuModel? _menu;
  List<Map<String, dynamic>> _mesas = [];
  final List<LineaCarrito> _carrito = [];
  bool _cargando = true;
  bool _enviando = false;
  String? _error;
  bool _cajaAbierta = true;
  bool _ocultarAvisoHorario = false;

  String _tipoPedido = 'mesa';
  String? _mesaId;
  String _metodoPago = 'efectivo';
  String _metodoPago2 = 'tarjeta';
  bool _pagoMixto = false;
  final _montoMixto1Ctrl = TextEditingController();
  final _montoMixto2Ctrl = TextEditingController();
  String _categoriaId = 'todo';
  RealtimeChannel? _canalCatalogo;

  final _moneda = NumberFormat.currency(
    locale: 'es_CO',
    symbol: r'$',
    decimalDigits: 0,
  );

  double get _totalVisual =>
      _carrito.fold<double>(0, (s, l) => s + l.subtotalPara(_tipoPedido));

  @override
  void initState() {
    super.initState();
    _tipoPedido = widget.modoMesero ? 'mesa' : 'para_llevar';
    _mesaId = widget.mesaIdFija;
    _cargar();
    final sid = widget.sucursalId;
    if (sid != null && AppBackend.supabaseReady) {
      _canalCatalogo = FoodyRealtime.suscribirCatalogo(
        sid,
        onCatalogoActualizado: () {
          if (mounted) _cargar();
        },
      );
    }
  }

  @override
  void dispose() {
    _canalCatalogo?.unsubscribe();
    _busquedaCtrl.dispose();
    _notaCtrl.dispose();
    _montoMixto1Ctrl.dispose();
    _montoMixto2Ctrl.dispose();
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
      final menu = await _menuRepo.obtenerPorSucursal(sid);
      final mesas = await _mesasRepo.listar(sid);
      Map<String, dynamic>? caja;
      try {
        caja = await _cajaRepo.cajaActiva(sid);
      } catch (_) {
        caja = null;
      }
      if (!mounted) return;
      setState(() {
        _menu = menu;
        _mesas = mesas.where((m) => m['activa'] != false).toList();
        if (_mesaId == null && _mesas.isNotEmpty && _tipoPedido == 'mesa') {
          _mesaId = _mesas.first['id'] as String?;
        }
        _cajaAbierta = caja != null;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = mensajeErrorHttp(e, contexto: 'cargar POS');
        _cargando = false;
      });
    }
  }

  void _agregarProducto(ProductoMenuModel producto) {
    if (!producto.disponible) return;
    if (producto.tienePersonalizacion) {
      DetalleProductoSheet.mostrar(
        context,
        producto: producto,
        onAgregar: (linea) => setState(() => _carrito.add(linea)),
      );
      return;
    }
    setState(() {
      final clave = LineaCarrito.generarClave(productoId: producto.id);
      final idx = _carrito.indexWhere((l) => l.clave == clave);
      if (idx >= 0) {
        final l = _carrito[idx];
        _carrito[idx] = LineaCarrito(
          clave: l.clave,
          productoId: l.productoId,
          comboId: l.comboId,
          nombre: l.nombre,
          precioUnitario: l.precioUnitario,
          precioUnitarioLlevar: l.precioUnitarioLlevar,
          cantidad: l.cantidad + 1,
          toppings: l.toppings,
          bebidas: l.bebidas,
          observaciones: l.observaciones,
          imagenUrl: l.imagenUrl,
        );
      } else {
        _carrito.add(
          LineaCarrito(
            clave: clave,
            productoId: producto.id,
            nombre: producto.nombre,
            precioUnitario: producto.precio.toDouble(),
            precioUnitarioLlevar: producto.precioParaLlevar?.toDouble(),
            imagenUrl: producto.imagenUrl,
          ),
        );
      }
    });
  }

  void _cambiarCantidad(int index, int delta) {
    final l = _carrito[index];
    final nueva = l.cantidad + delta;
    if (nueva <= 0) {
      setState(() => _carrito.removeAt(index));
      return;
    }
    setState(() {
      _carrito[index] = LineaCarrito(
        clave: l.clave,
        productoId: l.productoId,
        comboId: l.comboId,
        nombre: l.nombre,
        precioUnitario: l.precioUnitario,
        precioUnitarioLlevar: l.precioUnitarioLlevar,
        cantidad: nueva,
        toppings: l.toppings,
        bebidas: l.bebidas,
        observaciones: l.observaciones,
        imagenUrl: l.imagenUrl,
      );
    });
  }

  Future<void> _confirmarPedido() async {
    final sid = widget.sucursalId;
    if (sid == null || _carrito.isEmpty) return;

    if (_tipoPedido == 'mesa' && (_mesaId == null || _mesaId!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una mesa')),
      );
      return;
    }

    setState(() => _enviando = true);
    try {
      final agregarAMesa = widget.pedidoIdAgregar != null &&
          widget.pedidoIdAgregar!.isNotEmpty &&
          _tipoPedido == 'mesa';
      final mesaVinculada = widget.mesaIdFija ??
          (_tipoPedido == 'mesa' ? _mesaId : null);

      List<Map<String, dynamic>>? pagos;
      if (!widget.modoMesero &&
          _tipoPedido == 'para_llevar' &&
          _pagoMixto &&
          _metodoPago != 'pendiente') {
        final total = _totalVisual;
        final m1 = double.tryParse(_montoMixto1Ctrl.text.replaceAll(',', '')) ?? total / 2;
        final m2 = double.tryParse(_montoMixto2Ctrl.text.replaceAll(',', '')) ?? total - m1;
        pagos = [
          {'metodo_pago': _metodoPago, 'monto': m1},
          {'metodo_pago': _metodoPago2, 'monto': m2},
        ];
      }

      final datos = await _pedidosRepo.crearPedidoStaff(
        sucursalId: sid,
        tipo: _tipoPedido,
        lineas: _carrito,
        metodoPago: pagos != null ? null : _metodoPago,
        pagos: pagos,
        mesaId: widget.modoMesero && widget.mesaIdFija != null
            ? widget.mesaIdFija
            : mesaVinculada,
        pedidoIdAgregar: agregarAMesa ? widget.pedidoIdAgregar : null,
        direccionEntrega: _tipoPedido == 'domicilio' ? 'Por confirmar' : null,
      );
      if (!mounted) return;
      setState(() {
        _carrito.clear();
        _notaCtrl.clear();
        _enviando = false;
      });
      final numPedido = datos['numero_pedido'] ?? datos['id'];
      if (widget.modoMesero) {
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              agregarAMesa
                  ? 'Ítems agregados · $numPedido'
                  : 'Pedido creado · $numPedido',
            ),
            backgroundColor: ColoresFoody.secundario,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _enviando = false);
      final mostrado = await mostrarDialogoStockSiAplica(context, e);
      if (!mostrado) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensajeErrorHttp(e, contexto: 'crear pedido')),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  List<ProductoMenuModel> _productosFiltrados(MenuModel menu) {
    final q = _busquedaCtrl.text.trim().toLowerCase();
    return menu.categorias
        .where((c) => _categoriaId == 'todo' || c.id == _categoriaId)
        .expand((c) => c.productos.map((p) => p.conCategoria(c.id)))
        .where((p) => p.disponible)
        .where((p) => q.isEmpty || p.nombre.toLowerCase().contains(q))
        .toList();
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

    final menu = _menu!;
    final ancho = MediaQuery.sizeOf(context).width;
    final dosColumnas = ancho >= 900;
    final productos = _productosFiltrados(menu);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OperacionPageHeader(
          titulo: widget.modoMesero
              ? 'Pedido · ${widget.mesaNombreFija ?? 'Mesa'}'
              : 'Nuevo pedido',
        ),
        if (!widget.modoMesero && !_cajaAbierta)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OperacionAviso(
              mensaje: 'No hay caja abierta. El pedido se creará igual.',
              color: Colors.orange.shade50,
              colorTexto: const Color(0xFF854F0B),
            ),
          ),
        if (!menu.sucursal.horarioActivo && !_ocultarAvisoHorario)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: OperacionAviso(
              mensaje: 'Sucursal fuera de horario. El servidor puede rechazar el pedido.',
              accion: 'Ignorar',
              onAccion: () => setState(() => _ocultarAvisoHorario = true),
            ),
          ),
        Expanded(
          child: dosColumnas
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _panelMenu(menu, productos)),
                    SizedBox(width: 300, child: _panelCarrito()),
                  ],
                )
              : Column(
                  children: [
                    Expanded(child: _panelMenu(menu, productos)),
                    SizedBox(height: 280, child: _panelCarrito()),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _panelMenu(MenuModel menu, List<ProductoMenuModel> productos) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: OperacionBusqueda(
            controller: _busquedaCtrl,
            hint: 'Buscar plato, combo…',
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _chipCategoria('todo', 'Todo'),
              for (final c in menu.categorias) _chipCategoria(c.id, c.nombre),
            ],
          ),
        ),
        if (menu.combos.isNotEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: menu.combos.where((c) => c.disponible).map((combo) {
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ActionChip(
                    label: Text(
                      '${combo.nombre} · ${_moneda.format(combo.precioFijo)}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    onPressed: () {
                      setState(() {
                        _carrito.add(
                          LineaCarrito(
                            clave: LineaCarrito.generarClaveCombo(combo.id),
                            comboId: combo.id,
                            nombre: combo.nombre,
                            precioUnitario: combo.precioFijo.toDouble(),
                          ),
                        );
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ],
        Expanded(
          child: RefreshIndicator(
            onRefresh: _cargar,
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.85,
              ),
              itemCount: productos.length,
              itemBuilder: (_, i) {
                final p = productos[i];
                return Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    onTap: () => _agregarProducto(p),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: OperacionUi.borde, width: 0.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 48,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: OperacionUi.primarioSuave,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.restaurant,
                              color: ColoresFoody.primario,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            p.nombre,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _moneda.format(p.precio),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: ColoresFoody.primario,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _chipCategoria(String id, String nombre) {
    final activa = _categoriaId == id;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(nombre, style: const TextStyle(fontSize: 12)),
        selected: activa,
        onSelected: (_) => setState(() => _categoriaId = id),
        selectedColor: ColoresFoody.primario,
        labelStyle: TextStyle(
          color: activa ? Colors.white : OperacionUi.textoSecundario,
        ),
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
    );
  }

  Widget _panelCarrito() {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: OperacionUi.tarjeta(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Text(
                      'Carrito · ',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${_carrito.length} items',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: ColoresFoody.primario,
                      ),
                    ),
                  ],
                ),
                if (!widget.modoMesero || widget.mesaIdFija != null) ...[
                  if (!widget.modoMesero || widget.pedidoIdAgregar == null) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OperacionTipoToggle(
                        opciones: widget.modoMesero
                            ? const [
                                ('mesa', 'En mesa'),
                                ('para_llevar', 'Llevar'),
                                ('domicilio', 'Domi'),
                              ]
                            : const [
                                ('mesa', 'Mesa'),
                                ('domicilio', 'Domi'),
                                ('para_llevar', 'Llevar'),
                              ],
                        seleccionada: _tipoPedido,
                        onCambio: (v) => setState(() => _tipoPedido = v),
                      ),
                    ),
                  ],
                  if (widget.modoMesero && widget.pedidoIdAgregar != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Se suma al pedido de mesa abierto',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
          if (!widget.modoMesero && _tipoPedido == 'mesa')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: DropdownButtonFormField<String>(
                initialValue: _mesaId,
                isDense: true,
                decoration: const InputDecoration(
                  labelText: 'Mesa',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: _mesas
                    .map(
                      (m) => DropdownMenuItem(
                        value: m['id'] as String,
                        child: Text(
                          '${m['nombre']} ${m['pedido_id'] == null ? '(libre)' : '(ocupada)'}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _mesaId = v),
              ),
            ),
          if (!widget.modoMesero)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_tipoPedido == 'para_llevar')
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text('Pago mixto (CAJ-005)', style: TextStyle(fontSize: 13)),
                      value: _pagoMixto,
                      onChanged: (v) => setState(() {
                        _pagoMixto = v;
                        if (v) {
                          final t = _totalVisual;
                          _montoMixto1Ctrl.text = (t / 2).round().toString();
                          _montoMixto2Ctrl.text = (t - t / 2).round().toString();
                        }
                      }),
                    ),
                  if (_pagoMixto && _tipoPedido == 'para_llevar') ...[
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _metodoPago,
                            isDense: true,
                            decoration: const InputDecoration(labelText: 'Método 1', isDense: true),
                            items: const [
                              DropdownMenuItem(value: 'efectivo', child: Text('Efectivo')),
                              DropdownMenuItem(value: 'tarjeta', child: Text('Tarjeta')),
                            ],
                            onChanged: (v) => setState(() => _metodoPago = v ?? _metodoPago),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _montoMixto1Ctrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Monto 1', isDense: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _metodoPago2,
                            isDense: true,
                            decoration: const InputDecoration(labelText: 'Método 2', isDense: true),
                            items: const [
                              DropdownMenuItem(value: 'tarjeta', child: Text('Tarjeta')),
                              DropdownMenuItem(value: 'efectivo', child: Text('Efectivo')),
                            ],
                            onChanged: (v) => setState(() => _metodoPago2 = v ?? _metodoPago2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _montoMixto2Ctrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Monto 2', isDense: true),
                          ),
                        ),
                      ],
                    ),
                  ] else
                    DropdownButtonFormField<String>(
                      initialValue: _metodoPago,
                      isDense: true,
                      decoration: const InputDecoration(
                        labelText: 'Pago',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'efectivo', child: Text('Efectivo')),
                        DropdownMenuItem(value: 'tarjeta', child: Text('Tarjeta')),
                        DropdownMenuItem(value: 'transferencia', child: Text('Transferencia')),
                        DropdownMenuItem(value: 'nequi', child: Text('Nequi')),
                        DropdownMenuItem(value: 'pendiente', child: Text('Pendiente')),
                      ],
                      onChanged: (v) => setState(() => _metodoPago = v ?? _metodoPago),
                    ),
                ],
              ),
            ),
          const Divider(height: 1),
          Expanded(
            child: _carrito.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shopping_cart_outlined, size: 32, color: OperacionUi.textoTerciario),
                        SizedBox(height: 6),
                        Text('Agrega productos', style: TextStyle(color: OperacionUi.textoTerciario)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    itemCount: _carrito.length,
                    itemBuilder: (_, i) {
                      final l = _carrito[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                l.nombre,
                                style: const TextStyle(fontSize: 13),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            _btnQty(Icons.remove, () => _cambiarCantidad(i, -1)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Text(
                                '${l.cantidad}',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            _btnQty(Icons.add, () => _cambiarCantidad(i, 1)),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 64,
                              child: Text(
                                _moneda.format(l.subtotalPara(_tipoPedido)),
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _notaCtrl,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Nota para cocina…',
                    prefixIcon: const Icon(Icons.notes, size: 18),
                    filled: true,
                    fillColor: OperacionUi.fondoPagina,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    Text(
                      _moneda.format(_totalVisual),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'El total final lo calcula el servidor.',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _carrito.isEmpty || _enviando ? null : _confirmarPedido,
                  style: FilledButton.styleFrom(
                    backgroundColor: ColoresFoody.primario,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: _enviando
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Confirmar pedido →'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _btnQty(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          border: Border.all(color: OperacionUi.borde),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(icon, size: 14, color: OperacionUi.textoSecundario),
      ),
    );
  }
}
