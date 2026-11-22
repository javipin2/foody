import 'dart:async';

import 'package:flutter/material.dart';
import 'package:reserva_canchas/core/widgets/foody_dialogo.dart';
import 'package:intl/intl.dart';
import 'package:reserva_canchas/core/layout/foody_breakpoints.dart';
import 'package:reserva_canchas/core/red/dialogo_stock_insuficiente.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';
import 'package:reserva_canchas/core/realtime/poll_realtime_respaldo.dart';
import 'package:reserva_canchas/core/widgets/foody_scroll_horizontal_fade.dart';
import 'package:reserva_canchas/features/admin/presentation/widgets/operacion_ui.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_skeleton.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_tokens.dart';
import 'package:reserva_canchas/features/caja/data/caja_repository.dart';
import 'package:reserva_canchas/features/admin/data/pedidos_repository.dart';
import 'package:reserva_canchas/features/mesa/data/mesas_repository.dart';
import 'package:reserva_canchas/features/menu/data/menu_repository.dart';
import 'package:reserva_canchas/features/menu/domain/menu_model.dart';
import 'package:reserva_canchas/features/menu/presentation/widgets/detalle_combo_sheet.dart';
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
    this.itemIdReemplazar,
    this.onPedidoModificado,
    this.ocultarCabecera = false,
    this.onIrCaja,
  });

  final String? sucursalId;
  final String? mesaIdFija;
  final String? mesaNombreFija;
  final bool modoMesero;

  /// Si se indica, los ítems se suman a este pedido (consumo en mesa).
  final String? pedidoIdAgregar;

  /// Si se indica junto a [pedidoIdAgregar], tras agregar se elimina este ítem.
  final String? itemIdReemplazar;

  /// Tras agregar (y opcional reemplazo). Panel limpia sticky y vuelve a pedidos.
  final VoidCallback? onPedidoModificado;

  /// NAV-CJ-01: shell cajero ya muestra el título.
  final bool ocultarCabecera;

  /// NAV-ADM2-10: saltar a Caja cuando no hay turno abierto.
  final VoidCallback? onIrCaja;

  @override
  State<PedidoCajeroScreen> createState() => _PedidoCajeroScreenState();
}

class _PedidoCajeroScreenState extends State<PedidoCajeroScreen> {
  ColorScheme get _scheme => Theme.of(context).colorScheme;

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
  final _propinaCtrl = TextEditingController(text: '0');
  final _clienteNombreCtrl = TextEditingController();
  final _clienteTelCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();
  String _categoriaId = 'todo';
  RealtimeChannel? _canalCatalogo;
  PollRealtimeRespaldo? _pollRespaldo;

  final _moneda = NumberFormat.currency(
    locale: 'es_CO',
    symbol: r'$',
    decimalDigits: 0,
  );

  /// Hint local; cobro real vía API. Preview POS: preferir /pedidos/estimar (F4).
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
          if (mounted) _cargar(silencioso: true);
        },
        onReconectado: () {
          if (mounted) _cargar(silencioso: true);
        },
      );
    }
    // RT-FALL-01: POS sin poll → menú stale si cae RT.
    _pollRespaldo = PollRealtimeRespaldo(onActualizar: () async {
      if (mounted) await _cargar(silencioso: true);
    });
    unawaited(_pollRespaldo!.iniciar());
  }

  @override
  void dispose() {
    _pollRespaldo?.detener();
    FoodyRealtime.liberarCanal(_canalCatalogo);
    _busquedaCtrl.dispose();
    _notaCtrl.dispose();
    _montoMixto1Ctrl.dispose();
    _montoMixto2Ctrl.dispose();
    _propinaCtrl.dispose();
    _clienteNombreCtrl.dispose();
    _clienteTelCtrl.dispose();
    _direccionCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar({bool silencioso = false}) async {
    final sid = widget.sucursalId;
    if (sid == null) {
      setState(() {
        _cargando = false;
        _error = 'Sin sucursal en sesión';
      });
      return;
    }
    if (!silencioso) {
      setState(() {
        _cargando = true;
        _error = null;
      });
    }
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
      if (silencioso) return;
      setState(() {
        _error = mensajeErrorHttp(e, contexto: 'cargar POS');
        _cargando = false;
      });
    }
  }

  void _agregarProducto(ProductoMenuModel producto) {
    if (!producto.disponible) return;
    final menu = _menu;
    DetalleProductoSheet.mostrar(
      context,
      producto: producto,
      sugerenciasBebidas:
          menu == null || menu.productoEsDeCategoriaBebidas(producto)
              ? const []
              : menu.productosBebidasVendibles(excluirId: producto.id),
      onAgregar: (lineas) => setState(() => _carrito.addAll(lineas)),
    );
  }

  void _agregarCombo(ComboMenuModel combo) {
    if (!combo.disponible) return;
    final menu = _menu;
    final tops = <OpcionMenuModel>[];
    final seenT = <String>{};
    if (menu != null) {
      for (final ci in combo.items) {
        if (ci.tipoItem != 'producto' || ci.itemId == null) continue;
        for (final p in menu.todosLosProductos) {
          if (p.id != ci.itemId) continue;
          for (final t in p.toppings) {
            if (seenT.add(t.id)) tops.add(t);
          }
        }
      }
    }
    DetalleComboSheet.mostrar(
      context,
      combo: combo,
      toppingsDisponibles: tops,
      sugerenciasBebidas: menu?.productosBebidasVendibles() ?? const [],
      onAgregar: (lineas) => setState(() => _carrito.addAll(lineas)),
    );
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

    if (!widget.modoMesero && !_cajaAbierta) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Abre la caja antes de registrar ventas.'),
          action: widget.onIrCaja == null
              ? null
              : SnackBarAction(
                  label: 'Ir a caja',
                  onPressed: widget.onIrCaja!,
                ),
        ),
      );
      return;
    }

    if (_tipoPedido == 'mesa' &&
        widget.pedidoIdAgregar == null &&
        (_mesaId == null || _mesaId!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una mesa')),
      );
      return;
    }

    if (_tipoPedido == 'domicilio' && widget.pedidoIdAgregar == null) {
      final nombre = _clienteNombreCtrl.text.trim();
      final tel = _clienteTelCtrl.text.trim();
      final dir = _direccionCtrl.text.trim();
      if (nombre.isEmpty || tel.isEmpty || dir.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Domicilio: nombre, teléfono y dirección son obligatorios',
            ),
          ),
        );
        return;
      }
    }

    setState(() => _enviando = true);
    try {
      final agregarAPedido =
          widget.pedidoIdAgregar != null && widget.pedidoIdAgregar!.isNotEmpty;
      final mesaVinculada =
          widget.mesaIdFija ?? (_tipoPedido == 'mesa' ? _mesaId : null);

      List<Map<String, dynamic>>? pagos;
      if (!widget.modoMesero &&
          _tipoPedido == 'para_llevar' &&
          _pagoMixto &&
          _metodoPago != 'pendiente') {
        final total = _totalVisual;
        final m1 = double.tryParse(_montoMixto1Ctrl.text.replaceAll(',', '')) ??
            total / 2;
        final m2 = double.tryParse(_montoMixto2Ctrl.text.replaceAll(',', '')) ??
            total - m1;
        pagos = [
          {'metodo_pago': _metodoPago, 'monto': m1},
          {'metodo_pago': _metodoPago2, 'monto': m2},
        ];
      }

      final nota = _notaCtrl.text.trim();
      final propina = double.tryParse(_propinaCtrl.text.replaceAll(',', ''));
      final datos = await _pedidosRepo.crearPedidoStaff(
        sucursalId: sid,
        tipo: _tipoPedido,
        lineas: _carrito,
        metodoPago: pagos != null ? null : _metodoPago,
        pagos: pagos,
        propina: (!widget.modoMesero &&
                _tipoPedido == 'para_llevar' &&
                _metodoPago != 'pendiente' &&
                propina != null &&
                propina > 0)
            ? propina
            : null,
        mesaId: widget.modoMesero && widget.mesaIdFija != null
            ? widget.mesaIdFija
            : mesaVinculada,
        pedidoIdAgregar: agregarAPedido ? widget.pedidoIdAgregar : null,
        clienteNombre:
            _tipoPedido == 'domicilio' ? _clienteNombreCtrl.text.trim() : null,
        clienteTelefono:
            _tipoPedido == 'domicilio' ? _clienteTelCtrl.text.trim() : null,
        direccionEntrega:
            _tipoPedido == 'domicilio' ? _direccionCtrl.text.trim() : null,
        observaciones: nota.isNotEmpty ? nota : null,
      );
      if (!mounted) return;
      final pendiente = _metodoPago == 'pendiente' &&
          !widget.modoMesero &&
          _tipoPedido == 'para_llevar';
      setState(() {
        _carrito.clear();
        _notaCtrl.clear();
        _propinaCtrl.text = '0';
        if (_tipoPedido == 'domicilio') {
          _clienteNombreCtrl.clear();
          _clienteTelCtrl.clear();
          _direccionCtrl.clear();
        }
        _enviando = false;
      });

      final reemplazarId = widget.itemIdReemplazar;
      if (agregarAPedido && reemplazarId != null && reemplazarId.isNotEmpty) {
        try {
          await _pedidosRepo.eliminarItemPedido(
            pedidoId: widget.pedidoIdAgregar!,
            itemId: reemplazarId,
            sucursalId: sid,
            motivo: 'Cambio de producto',
          );
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Se agregó el nuevo, pero no se pudo quitar el anterior: '
                  '${mensajeErrorHttp(e, contexto: 'cambiar producto')}',
                ),
                backgroundColor: Colors.orange.shade800,
              ),
            );
          }
        }
      }

      if (!mounted) return;
      final numPedido = datos['numero_pedido'] ?? datos['id'];
      if (widget.modoMesero) {
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.itemIdReemplazar != null && agregarAPedido
                  ? 'Producto cambiado · $numPedido'
                  : agregarAPedido
                      ? 'Ítems agregados · $numPedido'
                      : 'Pedido creado · $numPedido',
            ),
            backgroundColor: AnaliticaTokens.inventario,
          ),
        );
        if (agregarAPedido) {
          widget.onPedidoModificado?.call();
        }
        if (pendiente) {
          await _ofrecerRegistrarFiado(
            sucursalId: sid,
            pedido: datos,
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _enviando = false);
      final mostrado = await mostrarDialogoStockSiAplica(context, e);
      if (!mostrado && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensajeErrorHttp(e, contexto: 'crear pedido')),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  /// «Pendiente» no mueve caja: ofrece CxC vinculada al pedido (auditoría caja).
  Future<void> _ofrecerRegistrarFiado({
    required String sucursalId,
    required Map<String, dynamic> pedido,
  }) async {
    final totalRaw = pedido['total'] ?? pedido['total_pedido'];
    final monto = totalRaw is num
        ? totalRaw.toDouble()
        : double.tryParse('$totalRaw') ?? 0;
    if (monto <= 0) return;

    final nombreCtrl = TextEditingController(text: 'Cliente mostrador');
    final telCtrl = TextEditingController();
    final ok = await FoodyDialogo.mostrar<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Registrar fiado'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Pago pendiente · ${_moneda.format(monto)}. '
              '¿Crear cuenta por cobrar?',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nombreCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre cliente',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: telCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Teléfono (opcional)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Ahora no'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Registrar'),
          ),
        ],
      ),
    );
    if (ok != true) {
      nombreCtrl.dispose();
      telCtrl.dispose();
      return;
    }
    try {
      await _cajaRepo.crearCuentaPorCobrar(
        sucursalId: sucursalId,
        clienteNombre: nombreCtrl.text.trim().isEmpty
            ? 'Cliente mostrador'
            : nombreCtrl.text.trim(),
        monto: monto,
        clienteTelefono:
            telCtrl.text.trim().isEmpty ? null : telCtrl.text.trim(),
        pedidoId: pedido['id'] as String?,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fiado registrado en caja')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensajeErrorHttp(e, contexto: 'registrar fiado')),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      nombreCtrl.dispose();
      telCtrl.dispose();
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
      return ColoredBox(
        color: _scheme.surface,
        child: AnaliticaSkeleton.tab(),
      );
    }
    if (_error != null) {
      return ColoredBox(
        color: _scheme.surface,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: _scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _cargar,
                  style: FilledButton.styleFrom(
                    backgroundColor: _scheme.primary,
                    foregroundColor: _scheme.onPrimary,
                  ),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final menu = _menu!;
    final ancho = FoodyBreakpoints.widthOf(context);
    final dosColumnas = FoodyBreakpoints.splitOperacion(ancho);
    final productos = _productosFiltrados(menu);
    final compacto = FoodyBreakpoints.esCompact(ancho);
    final titulo = widget.modoMesero
        ? 'Pedido · ${widget.mesaNombreFija ?? 'Mesa'}'
        : widget.itemIdReemplazar != null
            ? 'Cambiar producto'
            : widget.pedidoIdAgregar != null
                ? 'Agregar al pedido'
                : 'Nuevo pedido';

    return ColoredBox(
      color: _scheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!widget.ocultarCabecera)
            Padding(
              padding: EdgeInsets.fromLTRB(
                compacto ? 12 : 16,
                8,
                compacto ? 12 : 16,
                4,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Admin / Operación',
                    style: TextStyle(
                      fontSize: 11,
                      color: _scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    titulo,
                    style: TextStyle(
                      fontSize: compacto ? 18 : 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                      color: _scheme.onSurface,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${productos.length} disponibles · total lo calcula el servidor',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: _scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          if (!widget.modoMesero && !_cajaAbierta)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OperacionAviso(
                mensaje: 'No hay caja abierta. Abre turno en la pestaña Caja.',
                color: const Color(0xFFD97706).withValues(alpha: 0.12),
                colorTexto: const Color(0xFF92400E),
                accion: widget.onIrCaja != null ? 'Ir a Caja' : null,
                onAccion: widget.onIrCaja,
              ),
            ),
          if (widget.itemIdReemplazar != null && widget.pedidoIdAgregar != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: OperacionAviso(
                mensaje: 'Elige el producto o combo de reemplazo y confirma. '
                    'Se agrega al pedido y se quita el ítem anterior.',
                color: AnaliticaTokens.pedidos.withValues(alpha: 0.1),
                colorTexto: AnaliticaTokens.pedidos,
              ),
            ),
          if (!menu.sucursal.horarioActivo && !_ocultarAvisoHorario)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: OperacionAviso(
                mensaje:
                    'Sucursal fuera de horario. El servidor puede rechazar el pedido.',
                color: const Color(0xFFD97706).withValues(alpha: 0.12),
                colorTexto: const Color(0xFF92400E),
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
                      SizedBox(
                        width: ancho >= 1200 ? 340 : 300,
                        child: _panelCarrito(),
                      ),
                    ],
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final altoCarrito =
                          (constraints.maxHeight * 0.42).clamp(240.0, 380.0);
                      return Column(
                        children: [
                          Expanded(child: _panelMenu(menu, productos)),
                          SizedBox(height: altoCarrito, child: _panelCarrito()),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _panelMenu(MenuModel menu, List<ProductoMenuModel> productos) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: _campoBusqueda(),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 34,
          child: FoodyScrollHorizontalFade(
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _chipCategoria('todo', 'Todo'),
                for (final c in menu.categorias) _chipCategoria(c.id, c.nombre),
              ],
            ),
          ),
        ),
        if (menu.combos.isNotEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 34,
            child: FoodyScrollHorizontalFade(
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: menu.combos.where((c) => c.disponible).map((combo) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ActionChip(
                      label: Text(
                        '${combo.nombre} · ${_moneda.format(combo.precioFijo)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _scheme.onSurface,
                        ),
                      ),
                      backgroundColor: _scheme.surfaceContainerLow,
                      side: BorderSide(color: _scheme.outlineVariant),
                      onPressed: () => _agregarCombo(combo),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
        Expanded(
          child: RefreshIndicator(
            onRefresh: _cargar,
            color: _scheme.onSurface,
            child: productos.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 32,
                        ),
                        decoration: BoxDecoration(
                          color: _scheme.surfaceContainerLow,
                          borderRadius:
                              BorderRadius.circular(AnaliticaTokens.r12),
                          border: Border.all(color: _scheme.outlineVariant),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.restaurant_menu_outlined,
                              size: 32,
                              color: _scheme.onSurfaceVariant,
                            ),
                            SizedBox(height: 10),
                            Text(
                              'Sin productos en esta categoría',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: _scheme.onSurface,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Cambia el filtro o publica ítems en Menú.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: _scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      // ponytail: 3 cols en ~360px → overflow; 2 cols en compact.
                      crossAxisCount:
                          MediaQuery.sizeOf(context).width < 400 ? 2 : 3,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: productos.length,
                    itemBuilder: (_, i) {
                      final p = productos[i];
                      return Material(
                        color: _scheme.surfaceContainerLow,
                        borderRadius:
                            BorderRadius.circular(AnaliticaTokens.r10),
                        child: InkWell(
                          onTap: () => _agregarProducto(p),
                          borderRadius:
                              BorderRadius.circular(AnaliticaTokens.r10),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              borderRadius:
                                  BorderRadius.circular(AnaliticaTokens.r10),
                              border: Border.all(
                                color: _scheme.outlineVariant,
                                width: 0.5,
                              ),
                              boxShadow: AnaliticaTokens.shadowSoft,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  height: 48,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: _scheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Icon(
                                    Icons.restaurant,
                                    color: _scheme.onSurfaceVariant,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  p.nombre,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _scheme.onSurface,
                                    height: 1.25,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  _moneda.format(p.precio),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _scheme.onSurface,
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

  Widget _campoBusqueda() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: _scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _scheme.outlineVariant),
        boxShadow: AnaliticaTokens.shadowSoft,
      ),
      child: Row(
        children: [
          Icon(Icons.search, size: 18, color: _scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: _busquedaCtrl,
              onChanged: (_) => setState(() {}),
              style: TextStyle(
                fontSize: 13,
                color: _scheme.onSurface,
              ),
              decoration: InputDecoration(
                hintText: 'Buscar plato, combo…',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: _scheme.onSurfaceVariant,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          if (_busquedaCtrl.text.isNotEmpty)
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close, size: 16),
              color: _scheme.onSurfaceVariant,
              onPressed: () {
                _busquedaCtrl.clear();
                setState(() {});
              },
            ),
        ],
      ),
    );
  }

  Widget _chipCategoria(String id, String nombre) {
    final activa = _categoriaId == id;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(
          nombre,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: activa ? _scheme.onPrimary : _scheme.onSurfaceVariant,
          ),
        ),
        selected: activa,
        onSelected: (_) => setState(() => _categoriaId = id),
        selectedColor: _scheme.primary,
        backgroundColor: _scheme.surfaceContainerLow,
        side: BorderSide(
          color: activa ? _scheme.onSurface : _scheme.outlineVariant,
        ),
        showCheckmark: false,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
    );
  }

  Widget _panelCarrito() {
    // Todo el carrito scrollea: evita BOTTOM OVERFLOW en móvil (alto fijo).
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
        border: Border.all(color: _scheme.outlineVariant),
        boxShadow: AnaliticaTokens.shadowSoft,
      ),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      'Carrito · ',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: _scheme.onSurface,
                      ),
                    ),
                    Text(
                      '${_carrito.length} items',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: _scheme.onSurfaceVariant,
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
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        'Se suma al pedido de mesa abierto',
                        style: TextStyle(
                          fontSize: 11,
                          color: _scheme.onSurfaceVariant,
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
          if (!widget.modoMesero &&
              _tipoPedido == 'domicilio' &&
              widget.pedidoIdAgregar == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Column(
                children: [
                  TextField(
                    controller: _clienteNombreCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre cliente *',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _clienteTelCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Teléfono *',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _direccionCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Dirección de entrega *',
                      hintText: 'Calle, barrio, referencias',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Sin mapa: ubicación solo cuando el cliente pide por la app',
                      style: TextStyle(
                        fontSize: 11,
                        color: _scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
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
                      title: const Text(
                        'Pago mixto (CAJ-005)',
                        style: TextStyle(fontSize: 13),
                      ),
                      value: _pagoMixto,
                      onChanged: (v) => setState(() {
                        _pagoMixto = v;
                        if (v) {
                          final t = _totalVisual;
                          _montoMixto1Ctrl.text = (t / 2).round().toString();
                          _montoMixto2Ctrl.text =
                              (t - t / 2).round().toString();
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
                            decoration: const InputDecoration(
                              labelText: 'Método 1',
                              isDense: true,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'efectivo',
                                child: Text('Efectivo'),
                              ),
                              DropdownMenuItem(
                                value: 'tarjeta',
                                child: Text('Tarjeta'),
                              ),
                            ],
                            onChanged: (v) => setState(
                              () => _metodoPago = v ?? _metodoPago,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _montoMixto1Ctrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Monto 1',
                              isDense: true,
                            ),
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
                            decoration: const InputDecoration(
                              labelText: 'Método 2',
                              isDense: true,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'tarjeta',
                                child: Text('Tarjeta'),
                              ),
                              DropdownMenuItem(
                                value: 'efectivo',
                                child: Text('Efectivo'),
                              ),
                            ],
                            onChanged: (v) => setState(
                              () => _metodoPago2 = v ?? _metodoPago2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _montoMixto2Ctrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Monto 2',
                              isDense: true,
                            ),
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
                        DropdownMenuItem(
                          value: 'efectivo',
                          child: Text('Efectivo'),
                        ),
                        DropdownMenuItem(
                          value: 'tarjeta',
                          child: Text('Tarjeta'),
                        ),
                        DropdownMenuItem(
                          value: 'transferencia',
                          child: Text('Transferencia'),
                        ),
                        DropdownMenuItem(
                          value: 'nequi',
                          child: Text('Nequi'),
                        ),
                        DropdownMenuItem(
                          value: 'pendiente',
                          child: Text('Pendiente'),
                        ),
                      ],
                      onChanged: (v) =>
                          setState(() => _metodoPago = v ?? _metodoPago),
                    ),
                  if (_tipoPedido == 'para_llevar' &&
                      _metodoPago != 'pendiente') ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: _propinaCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Propina (opcional)',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          Divider(height: 1, color: _scheme.outlineVariant),
          if (_carrito.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Column(
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 32,
                    color: _scheme.onSurfaceVariant,
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Agrega productos',
                    style: TextStyle(
                      fontSize: 13,
                      color: _scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          else
            ...List.generate(_carrito.length, (i) {
              final l = _carrito[i];
              return Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l.nombre,
                        style: TextStyle(
                          fontSize: 13,
                          color: _scheme.onSurface,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _btnQty(Icons.remove, () => _cambiarCantidad(i, -1)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        '${l.cantidad}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _scheme.onSurface,
                        ),
                      ),
                    ),
                    _btnQty(Icons.add, () => _cambiarCantidad(i, 1)),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 64,
                      child: Text(
                        _moneda.format(l.subtotalPara(_tipoPedido)),
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _scheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _notaCtrl,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Nota para cocina…',
                    hintStyle: TextStyle(
                      fontSize: 12,
                      color: _scheme.onSurfaceVariant,
                    ),
                    prefixIcon: Icon(
                      Icons.notes,
                      size: 18,
                      color: _scheme.onSurfaceVariant,
                    ),
                    filled: true,
                    fillColor: _scheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: TextStyle(
                    fontSize: 12,
                    color: _scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _scheme.onSurface,
                      ),
                    ),
                    Text(
                      _moneda.format(_totalVisual),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _scheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'El total final lo calcula el servidor.',
                  style: TextStyle(
                    fontSize: 11,
                    color: _scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed:
                      _carrito.isEmpty || _enviando ? null : _confirmarPedido,
                  style: FilledButton.styleFrom(
                    backgroundColor: _scheme.primary,
                    foregroundColor: _scheme.onPrimary,
                    disabledBackgroundColor: _scheme.outlineVariant,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: _enviando
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
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
          border: Border.all(color: _scheme.outlineVariant),
          borderRadius: BorderRadius.circular(4),
          color: _scheme.surfaceContainerHighest,
        ),
        child: Icon(icon, size: 14, color: _scheme.onSurfaceVariant),
      ),
    );
  }
}
