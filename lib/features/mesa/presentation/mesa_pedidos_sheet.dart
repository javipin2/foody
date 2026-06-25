import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';
import 'package:reserva_canchas/core/realtime/foody_realtime.dart';
import 'package:reserva_canchas/features/admin/data/pedidos_repository.dart';
import 'package:reserva_canchas/features/mesa/data/mesas_repository.dart';
import 'package:reserva_canchas/services/app_backend.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Detalle de pedidos activos de una mesa con estado de cocina por ítem (A-MES-3).
class MesaPedidosSheet extends StatefulWidget {
  const MesaPedidosSheet({
    super.key,
    required this.mesaId,
    required this.mesaNombre,
    required this.sucursalId,
    required this.onActualizado,
    this.onTransferir,
    this.onAgregarProductos,
  });

  final String mesaId;
  final String mesaNombre;
  final String sucursalId;
  final VoidCallback onActualizado;
  final VoidCallback? onTransferir;
  final void Function(String? pedidoIdMesa)? onAgregarProductos;

  @override
  State<MesaPedidosSheet> createState() => _MesaPedidosSheetState();
}

class _MesaPedidosSheetState extends State<MesaPedidosSheet> {
  final _repo = PedidosRepository();
  final _mesasRepo = MesasRepository();
  Map<String, dynamic>? _datos;
  bool _cargando = true;
  String? _error;
  RealtimeChannel? _canal;
  final Set<String> _itemsCobroSeleccionados = {};

  final _moneda = NumberFormat.currency(
    locale: 'es_CO',
    symbol: r'$',
    decimalDigits: 0,
  );

  static const _estadosCerrados = {
    'entregado',
    'cancelado',
    'rechazado',
    'pagado',
  };

  @override
  void initState() {
    super.initState();
    _cargar();
    _suscribirRealtime();
  }

  @override
  void dispose() {
    _canal?.unsubscribe();
    super.dispose();
  }

  void _suscribirRealtime() {
    if (!AppBackend.supabaseReady) return;
    _canal = FoodyRealtime.suscribirSucursal(
      widget.sucursalId,
      onEvento: (_) => _cargar(),
    );
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final d = await _repo.obtenerPedidosMesa(
        mesaId: widget.mesaId,
        sucursalId: widget.sucursalId,
      );
      if (mounted) {
        setState(() {
          _datos = d;
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = mensajeErrorHttp(e, contexto: 'pedidos de mesa');
          _cargando = false;
        });
      }
    }
  }

  Future<void> _marcarPagando(String pedidoId, String numeroPedido) async {
    try {
      await _repo.cambiarEstado(
        pedidoId: pedidoId,
        estado: 'pagando',
        sucursalId: widget.sucursalId,
      );
      await _cargar();
      widget.onActualizado();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$numeroPedido → pagando (cuenta presentada)')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensajeErrorHttp(e, contexto: 'marcar pagando')),
            backgroundColor: ColoresFoody.error,
          ),
        );
      }
    }
  }

  Future<void> _eliminarItem({
    required String pedidoId,
    required String itemId,
    required String nombreProducto,
    required String pedidoEstado,
  }) async {
    if (_estadosCerrados.contains(pedidoEstado)) return;

    final motivoCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar ítem'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('¿Quitar «$nombreProducto» del pedido?'),
            const SizedBox(height: 12),
            TextField(
              controller: motivoCtrl,
              decoration: const InputDecoration(
                labelText: 'Motivo (opcional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
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
            style: FilledButton.styleFrom(backgroundColor: ColoresFoody.error),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) {
      motivoCtrl.dispose();
      return;
    }

    try {
      await _repo.eliminarItemPedido(
        pedidoId: pedidoId,
        itemId: itemId,
        sucursalId: widget.sucursalId,
        motivo: motivoCtrl.text.trim().isEmpty ? null : motivoCtrl.text.trim(),
      );
      motivoCtrl.dispose();
      await _cargar();
      widget.onActualizado();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ítem eliminado: $nombreProducto')),
        );
      }
    } catch (e) {
      motivoCtrl.dispose();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensajeErrorHttp(e, contexto: 'eliminar ítem')),
            backgroundColor: ColoresFoody.error,
          ),
        );
      }
    }
  }

  String? _pedidoMesaPrincipal() {
    final pedidos =
        (_datos?['pedidos'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    for (final p in pedidos) {
      if (p['tipo'] == 'mesa') return p['id'] as String?;
    }
    return pedidos.isNotEmpty ? pedidos.last['id'] as String? : null;
  }

  Future<void> _cobrarCuenta({List<String>? itemIds, double? montoParcial, List<Map<String, dynamic>>? pagos}) async {
    final total = _datos?['total_acumulado'];
    var metodoPago = 'efectivo';
    var metodoPago2 = 'tarjeta';
    final propinaCtrl = TextEditingController(text: '0');
    final parcialCtrl = TextEditingController(
      text: montoParcial?.toStringAsFixed(0) ?? '',
    );
    final mixtoMonto1Ctrl = TextEditingController();
    final mixtoMonto2Ctrl = TextEditingController();
    var modo = itemIds != null
        ? 'split'
        : montoParcial != null
            ? 'parcial'
            : pagos != null
                ? 'mixto'
                : 'total';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Cobrar cuenta'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Total pendiente: ${_moneda.format(total is num ? total : num.tryParse('$total') ?? 0)}',
                ),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'total', label: Text('Total')),
                    ButtonSegment(value: 'parcial', label: Text('Parcial')),
                    ButtonSegment(value: 'mixto', label: Text('Mixto')),
                  ],
                  selected: {modo},
                  onSelectionChanged: (s) => setDialogState(() => modo = s.first),
                ),
                if (modo == 'parcial') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: parcialCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Monto abono',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                if (modo == 'mixto') ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: metodoPago,
                    decoration: const InputDecoration(
                      labelText: 'Pago 1 — método',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'efectivo', child: Text('Efectivo')),
                      DropdownMenuItem(value: 'tarjeta', child: Text('Tarjeta')),
                      DropdownMenuItem(value: 'transferencia', child: Text('Transferencia')),
                      DropdownMenuItem(value: 'nequi', child: Text('Nequi')),
                    ],
                    onChanged: (v) {
                      if (v != null) setDialogState(() => metodoPago = v);
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: mixtoMonto1Ctrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Pago 1 — monto',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: metodoPago2,
                    decoration: const InputDecoration(
                      labelText: 'Pago 2 — método',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'efectivo', child: Text('Efectivo')),
                      DropdownMenuItem(value: 'tarjeta', child: Text('Tarjeta')),
                      DropdownMenuItem(value: 'transferencia', child: Text('Transferencia')),
                      DropdownMenuItem(value: 'nequi', child: Text('Nequi')),
                    ],
                    onChanged: (v) {
                      if (v != null) setDialogState(() => metodoPago2 = v);
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: mixtoMonto2Ctrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Pago 2 — monto',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                if (modo != 'mixto') ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: metodoPago,
                    decoration: const InputDecoration(
                      labelText: 'Método de pago',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'efectivo', child: Text('Efectivo')),
                      DropdownMenuItem(value: 'tarjeta', child: Text('Tarjeta')),
                      DropdownMenuItem(
                        value: 'transferencia',
                        child: Text('Transferencia'),
                      ),
                      DropdownMenuItem(value: 'nequi', child: Text('Nequi')),
                    ],
                    onChanged: (v) {
                      if (v != null) setDialogState(() => metodoPago = v);
                    },
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: propinaCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Propina (opcional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(modo == 'parcial' ? 'Registrar abono' : 'Cobrar'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) {
      propinaCtrl.dispose();
      parcialCtrl.dispose();
      mixtoMonto1Ctrl.dispose();
      mixtoMonto2Ctrl.dispose();
      return;
    }

    try {
      List<Map<String, dynamic>>? pagosEnvio = pagos;
      double? parcialEnvio = montoParcial;
      if (modo == 'parcial') {
        parcialEnvio = double.tryParse(parcialCtrl.text.replaceAll(',', ''));
      } else if (modo == 'mixto') {
        final m1 = double.tryParse(mixtoMonto1Ctrl.text.replaceAll(',', '')) ?? 0;
        final m2 = double.tryParse(mixtoMonto2Ctrl.text.replaceAll(',', '')) ?? 0;
        pagosEnvio = [
          {'metodo_pago': metodoPago, 'monto': m1},
          {'metodo_pago': metodoPago2, 'monto': m2},
        ];
        parcialEnvio = null;
      }

      final result = await _repo.cobrarCuentaMesa(
        mesaId: widget.mesaId,
        sucursalId: widget.sucursalId,
        metodoPago: modo == 'mixto' ? null : metodoPago,
        montoParcial: parcialEnvio,
        propina: double.tryParse(propinaCtrl.text.replaceAll(',', '')),
        pagos: pagosEnvio,
        itemIds: itemIds,
      );
      propinaCtrl.dispose();
      parcialCtrl.dispose();
      mixtoMonto1Ctrl.dispose();
      mixtoMonto2Ctrl.dispose();
      await _cargar();
      widget.onActualizado();
      if (mounted) {
        final parcial = result['parcial'] == true;
        if (!parcial) Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              parcial
                  ? 'Abono registrado · saldo ${_moneda.format(result['saldo_restante'] ?? 0)}'
                  : 'Cuenta cobrada · ${widget.mesaNombre} libre',
            ),
            backgroundColor: ColoresFoody.exito,
          ),
        );
      }
    } catch (e) {
      propinaCtrl.dispose();
      parcialCtrl.dispose();
      mixtoMonto1Ctrl.dispose();
      mixtoMonto2Ctrl.dispose();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensajeErrorHttp(e, contexto: 'cobrar cuenta')),
            backgroundColor: ColoresFoody.error,
          ),
        );
      }
    }
  }

  Future<void> _salioSinPagar() async {
    final nombreCtrl = TextEditingController();
    final telCtrl = TextEditingController();
    final motivoCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cliente salió sin pagar'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nombreCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre cliente',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: telCtrl,
              decoration: const InputDecoration(
                labelText: 'Teléfono (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: motivoCtrl,
              decoration: const InputDecoration(
                labelText: 'Motivo',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: ColoresFoody.error),
            child: const Text('Registrar CxC'),
          ),
        ],
      ),
    );
    if (ok != true) {
      nombreCtrl.dispose();
      telCtrl.dispose();
      motivoCtrl.dispose();
      return;
    }
    try {
      await _mesasRepo.salioSinPagar(
        mesaId: widget.mesaId,
        sucursalId: widget.sucursalId,
        clienteNombre: nombreCtrl.text.trim(),
        motivo: motivoCtrl.text.trim(),
        clienteTelefono: telCtrl.text.trim(),
      );
      nombreCtrl.dispose();
      telCtrl.dispose();
      motivoCtrl.dispose();
      widget.onActualizado();
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cuenta por cobrar registrada · mesa liberada'),
            backgroundColor: ColoresFoody.exito,
          ),
        );
      }
    } catch (e) {
      nombreCtrl.dispose();
      telCtrl.dispose();
      motivoCtrl.dispose();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensajeErrorHttp(e, contexto: 'salió sin pagar')),
            backgroundColor: ColoresFoody.error,
          ),
        );
      }
    }
  }

  Future<void> _cobrarItemsSeleccionados(List<String> itemIds) async {
    await _cobrarCuenta(itemIds: itemIds);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Material(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.mesaNombre,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          if (_datos != null)
                            Text(
                              'Total mesa: ${_moneda.format(_datos!['total_acumulado'] ?? 0)}',
                              style: TextStyle(
                                color: ColoresFoody.primario,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Actualizar',
                      onPressed: _cargar,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _cargando
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(_error!, textAlign: TextAlign.center),
                                const SizedBox(height: 12),
                                FilledButton(
                                  onPressed: _cargar,
                                  child: const Text('Reintentar'),
                                ),
                              ],
                            ),
                          )
                        : _listaPedidos(scrollController),
              ),
              if (_datos != null &&
                  (_datos!['pagos_abonos'] as List<dynamic>? ?? []).isNotEmpty)
                _historialAbonos(),
              if (_datos != null &&
                  (_datos!['pedidos'] as List<dynamic>? ?? []).isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Row(
                    children: [
                      if (widget.onAgregarProductos != null)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              widget.onAgregarProductos!(_pedidoMesaPrincipal());
                            },
                            icon: const Icon(Icons.add_shopping_cart),
                            label: const Text('Agregar'),
                          ),
                        ),
                      if (widget.onAgregarProductos != null)
                        const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            if (_itemsCobroSeleccionados.isNotEmpty) {
                              _cobrarItemsSeleccionados(
                                _itemsCobroSeleccionados.toList(),
                              );
                            } else {
                              _cobrarCuenta();
                            }
                          },
                          icon: const Icon(Icons.payments),
                          label: Text(
                            _itemsCobroSeleccionados.isEmpty
                                ? 'Cobrar cuenta'
                                : 'Cobrar ${_itemsCobroSeleccionados.length} ítems',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (widget.onTransferir != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: OutlinedButton.icon(
                    onPressed: widget.onTransferir,
                    icon: const Icon(Icons.swap_horiz),
                    label: const Text('Transferir pedido a otra mesa'),
                  ),
                ),
              if (_datos != null &&
                  (_datos!['pedidos'] as List<dynamic>? ?? []).isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: TextButton.icon(
                    onPressed: _salioSinPagar,
                    icon: Icon(Icons.logout, color: ColoresFoody.error),
                    label: Text(
                      'Salió sin pagar',
                      style: TextStyle(color: ColoresFoody.error),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _listaPedidos(ScrollController scrollController) {
    final pedidos =
        (_datos!['pedidos'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    if (pedidos.isEmpty) {
      return const Center(child: Text('Sin pedidos activos en esta mesa'));
    }

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView.separated(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: pedidos.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _tarjetaPedido(pedidos[i]),
      ),
    );
  }

  Widget _tarjetaPedido(Map<String, dynamic> pedido) {
    final estado = pedido['estado'] as String? ?? '';
    final items = (pedido['items'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final total = pedido['total'];
    final puedePagando = estado == 'listo';
    final pedidoId = pedido['id'] as String;
    final puedeEliminar = !_estadosCerrados.contains(estado);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Text(
          pedido['numero_pedido'] as String? ?? '',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_etiquetaEstado(estado)),
            if ((pedido['saldo_pendiente'] as num?) != null &&
                (pedido['saldo_pendiente'] as num) <
                    (pedido['total'] as num? ?? 0))
              Text(
                'Saldo: ${_moneda.format(pedido['saldo_pendiente'])}',
                style: TextStyle(
                  color: ColoresFoody.primario,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
          ],
        ),
        trailing: Text(
          _moneda.format(total is num ? total : num.tryParse('$total') ?? 0),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        children: [
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Sin ítems registrados'),
            )
          else
            ...items.map(
              (item) => _filaItem(
                item,
                pedidoId: pedidoId,
                pedidoEstado: estado,
                puedeEliminar: puedeEliminar,
              ),
            ),
          if (puedePagando)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _marcarPagando(
                    pedidoId,
                    pedido['numero_pedido'] as String? ?? '',
                  ),
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text('Presentar cuenta (pagando)'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _filaItem(
    Map<String, dynamic> item, {
    required String pedidoId,
    required String pedidoEstado,
    required bool puedeEliminar,
  }) {
    final estadoCocina = item['estado_cocina'] as String? ?? 'pendiente';
    final color = _colorEstadoCocina(estadoCocina);
    final cantidad = item['cantidad'];
    final producto = item['producto'] as String? ?? 'Producto';
    final cocina = item['cocina_nombre'] as String?;
    final obs = item['observaciones'] as String?;
    final itemId = item['id'] as String?;

    final estadoCobro = item['estado_cobro'] as String? ?? 'pendiente';
    final puedeCobrarItem =
        puedeEliminar && itemId != null && estadoCobro == 'pendiente';
    final seleccionado =
        itemId != null && _itemsCobroSeleccionados.contains(itemId);

    return ListTile(
      dense: true,
      onLongPress: itemId != null
          ? () => _asignarComensal(
                pedidoId,
                itemId,
                item['comensal_etiqueta'] as String?,
              )
          : null,
      leading: puedeCobrarItem
          ? Checkbox(
              value: seleccionado,
              onChanged: (_) {
                setState(() {
                  if (seleccionado) {
                    _itemsCobroSeleccionados.remove(itemId);
                  } else {
                    _itemsCobroSeleccionados.add(itemId);
                  }
                });
              },
            )
          : Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      title: Text('$cantidad× $producto'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _etiquetaEstadoCocina(estadoCocina),
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
          if (cocina != null && cocina.isNotEmpty)
            Text(cocina, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          if (obs != null && obs.trim().isNotEmpty)
            Text('Obs: $obs', style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
          if (item['comensal_etiqueta'] != null &&
              (item['comensal_etiqueta'] as String).isNotEmpty)
            Text(
              '👤 ${item['comensal_etiqueta']}',
              style: TextStyle(fontSize: 11, color: ColoresFoody.secundario),
            ),
        ],
      ),
      trailing: puedeEliminar && itemId != null
          ? IconButton(
              tooltip: 'Eliminar ítem',
              icon: Icon(Icons.delete_outline, color: ColoresFoody.error, size: 20),
              onPressed: () => _eliminarItem(
                pedidoId: pedidoId,
                itemId: itemId,
                nombreProducto: producto,
                pedidoEstado: pedidoEstado,
              ),
            )
          : null,
    );
  }

  Widget _historialAbonos() {
    final abonos =
        (_datos!['pagos_abonos'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Abonos registrados',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          ...abonos.take(5).map(
            (a) => Text(
              '${_moneda.format(a['monto'])} · ${a['metodo_pago']} · '
              '${DateFormat('HH:mm').format(DateTime.parse(a['created_at'].toString()).toLocal())}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _asignarComensal(String pedidoId, String itemId, String? actual) async {
    final ctrl = TextEditingController(text: actual ?? '');
    final etiqueta = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Comensal / etiqueta'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'Ej: Juan, Mesa A'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (etiqueta == null || !mounted) return;
    try {
      await _repo.actualizarComensalItem(
        pedidoId: pedidoId,
        itemId: itemId,
        sucursalId: widget.sucursalId,
        comensalEtiqueta: etiqueta.isEmpty ? null : etiqueta,
      );
      await _cargar();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensajeErrorHttp(e, contexto: 'comensal'))),
        );
      }
    }
  }

  Color _colorEstadoCocina(String estado) {
    return switch (estado) {
      'preparando' => const Color(0xFFF59E0B),
      'listo' => ColoresFoody.exito,
      'no_disponible' => ColoresFoody.error,
      _ => Colors.grey,
    };
  }

  String _etiquetaEstadoCocina(String estado) {
    return switch (estado) {
      'preparando' => 'Preparando',
      'listo' => 'Listo',
      'no_disponible' => 'No disponible',
      _ => 'Pendiente',
    };
  }

  String _etiquetaEstado(String estado) {
    return switch (estado) {
      'pendiente_aprobacion' => 'Esperando aprobación',
      'en_cocina' => 'En cocina',
      'listo' => 'Listo para servir',
      'pagando' => 'Cuenta presentada',
      'pagado' => 'Pagado (cobrado)',
      _ => estado.replaceAll('_', ' '),
    };
  }
}
