import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';
import 'package:reserva_canchas/features/admin/data/pedidos_repository.dart';
import 'package:reserva_canchas/features/admin/domain/pedido_admin_model.dart';
import 'package:reserva_canchas/features/pedidos/domain/pedido_item_resumen.dart';
import 'package:reserva_canchas/features/pedidos/presentation/widgets/editar_pedido_item_sheet.dart';
import 'package:reserva_canchas/features/pedidos/presentation/widgets/pedido_estado_pill.dart';

/// Modal/sheet de detalle administrable (Fase 1: acciones existentes).
Future<void> mostrarPedidoDetalleSheet({
  required BuildContext context,
  required PedidoAdminModel pedidoInicial,
  required String? sucursalId,
  required bool modoMesero,
  required List<String> permisos,
  required NumberFormat formatoMoneda,
  VoidCallback? onCambiado,
  ValueChanged<String>? onVerMesa,
  VoidCallback? onIrCaja,
  void Function(String pedidoId, String numeroPedido)? onIrFacturacion,
  VoidCallback? onIrCocinaKds,
  void Function(PedidoAdminModel pedido, {String? itemIdReemplazar})?
      onAgregarItems,
  Future<void> Function(PedidoAdminModel)? onCobrarParaLlevar,
  Future<void> Function(PedidoAdminModel)? onAprobar,
  Future<void> Function(PedidoAdminModel)? onRechazar,
  Future<void> Function(PedidoAdminModel, String)? onCambiarEstado,
  Future<void> Function(PedidoAdminModel)? onCancelar,
  Future<void> Function(PedidoAdminModel)? onDescuento,
  Widget? asignarDomiciliarioSlot,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => PedidoDetalleSheet(
      pedidoInicial: pedidoInicial,
      sucursalId: sucursalId,
      modoMesero: modoMesero,
      permisos: permisos,
      formatoMoneda: formatoMoneda,
      onCambiado: onCambiado,
      onVerMesa: onVerMesa,
      onIrCaja: onIrCaja,
      onIrFacturacion: onIrFacturacion,
      onIrCocinaKds: onIrCocinaKds,
      onAgregarItems: onAgregarItems,
      onCobrarParaLlevar: onCobrarParaLlevar,
      onAprobar: onAprobar,
      onRechazar: onRechazar,
      onCambiarEstado: onCambiarEstado,
      onCancelar: onCancelar,
      onDescuento: onDescuento,
      asignarDomiciliarioSlot: asignarDomiciliarioSlot,
    ),
  );
}

class PedidoDetalleSheet extends StatefulWidget {
  const PedidoDetalleSheet({
    super.key,
    required this.pedidoInicial,
    required this.sucursalId,
    required this.modoMesero,
    required this.permisos,
    required this.formatoMoneda,
    this.onCambiado,
    this.onVerMesa,
    this.onIrCaja,
    this.onIrFacturacion,
    this.onIrCocinaKds,
    this.onAgregarItems,
    this.onCobrarParaLlevar,
    this.onAprobar,
    this.onRechazar,
    this.onCambiarEstado,
    this.onCancelar,
    this.onDescuento,
    this.asignarDomiciliarioSlot,
  });

  final PedidoAdminModel pedidoInicial;
  final String? sucursalId;
  final bool modoMesero;
  final List<String> permisos;
  final NumberFormat formatoMoneda;
  final VoidCallback? onCambiado;
  final ValueChanged<String>? onVerMesa;
  final VoidCallback? onIrCaja;
  final void Function(String pedidoId, String numeroPedido)? onIrFacturacion;
  final VoidCallback? onIrCocinaKds;
  final void Function(PedidoAdminModel pedido, {String? itemIdReemplazar})?
      onAgregarItems;
  final Future<void> Function(PedidoAdminModel)? onCobrarParaLlevar;
  final Future<void> Function(PedidoAdminModel)? onAprobar;
  final Future<void> Function(PedidoAdminModel)? onRechazar;
  final Future<void> Function(PedidoAdminModel, String)? onCambiarEstado;
  final Future<void> Function(PedidoAdminModel)? onCancelar;
  final Future<void> Function(PedidoAdminModel)? onDescuento;
  final Widget? asignarDomiciliarioSlot;

  @override
  State<PedidoDetalleSheet> createState() => _PedidoDetalleSheetState();
}

class _PedidoDetalleSheetState extends State<PedidoDetalleSheet> {
  final _repo = PedidosRepository();
  late PedidoAdminModel _pedido;
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _pedido = widget.pedidoInicial;
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final det = await _repo.obtenerDetalle(
        pedidoId: _pedido.id,
        sucursalId: widget.sucursalId,
      );
      if (mounted) {
        setState(() {
          _pedido = det;
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = mensajeErrorHttp(e, contexto: 'detalle pedido');
          _cargando = false;
        });
      }
    }
  }

  Future<void> _eliminarItem(PedidoItemResumen item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quitar ítem'),
        content: Text('¿Quitar ${item.cantidad}× ${item.nombre}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.eliminarItemPedido(
        pedidoId: _pedido.id,
        itemId: item.itemId,
        sucursalId: widget.sucursalId,
      );
      widget.onCambiado?.call();
      await _cargar();
      if (mounted) {
        final enCocina = ['en_cocina', 'listo', 'confirmado']
            .contains(_pedido.estado);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              enCocina
                  ? 'Ítem quitado · se reimprime comanda'
                  : 'Ítem eliminado',
            ),
          ),
        );
      }
    } catch (e) {
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

  Future<void> _editarItem(PedidoItemResumen item) async {
    final sid = widget.sucursalId;
    if (sid == null) return;
    final ok = await mostrarEditarPedidoItemSheet(
      context: context,
      pedidoId: _pedido.id,
      sucursalId: sid,
      item: item,
    );
    if (ok != true) return;
    widget.onCambiado?.call();
    await _cargar();
    if (mounted) {
      final enCocina =
          ['en_cocina', 'listo', 'confirmado'].contains(_pedido.estado);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enCocina
                ? 'Ítem actualizado · cocina recibe nueva comanda'
                : 'Ítem actualizado',
          ),
          backgroundColor: ColoresFoody.secundario,
        ),
      );
    }
  }

  Future<void> _cambiarProducto(PedidoItemResumen item) async {
    if (widget.onAgregarItems == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cambiar producto'),
        content: const Text(
          'Abre el menú, elige el producto nuevo y confirma. '
          'Se agrega primero y luego se quita el actual '
          '(funciona aunque sea el único ítem). Cocina recibe Copia N.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ir al menú'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!mounted) return;
    Navigator.pop(context);
    widget.onAgregarItems!(_pedido, itemIdReemplazar: item.itemId);
  }

  @override
  Widget build(BuildContext context) {
    final alto = MediaQuery.sizeOf(context).height * 0.88;
    final cerrado = _pedido.esTerminal;
    final mesaConCuenta = _pedido.mesaId != null &&
        _pedido.tipo == 'mesa' &&
        _pedido.saldoPendiente > 0.01 &&
        !cerrado;
    final enCocina = ['confirmado', 'en_cocina', 'listo', 'pagando']
        .contains(_pedido.estado);
    final puedeEditarItems = !widget.modoMesero ||
        widget.permisos.contains('crear_pedido');

    return SafeArea(
      child: SizedBox(
        height: alto,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '#${_pedido.numeroPedido}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        PedidoEstadoPill(estado: _pedido.estado),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _cargar,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),
            if (_cargando)
              const LinearProgressIndicator(minHeight: 2)
            else
              const SizedBox(height: 2),
            Expanded(
              child: _error != null
                  ? Center(child: Text(_error!))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      children: [
                        _metaFila('Canal', _labelTipo(_pedido.tipo)),
                        if (_pedido.mesaNombre != null)
                          _metaFila('Mesa', _pedido.mesaNombre!),
                        if (_pedido.clienteNombre != null)
                          _metaFila('Cliente', _pedido.clienteNombre!),
                        if (_pedido.clienteTelefono != null)
                          _metaFila('Teléfono', _pedido.clienteTelefono!),
                        if (_pedido.direccionEntrega != null)
                          _metaFila('Dirección', _pedido.direccionEntrega!),
                        if (_pedido.meseraNombre != null)
                          _metaFila('Mesera', _pedido.meseraNombre!),
                        if (_pedido.domiciliarioNombre != null)
                          _metaFila(
                            'Domiciliario',
                            _pedido.domiciliarioNombre!,
                          ),
                        _metaFila(
                          'Total',
                          widget.formatoMoneda.format(_pedido.total),
                          bold: true,
                        ),
                        if (_pedido.saldoPendiente > 0.01)
                          _metaFila(
                            'Saldo',
                            widget.formatoMoneda.format(_pedido.saldoPendiente),
                          ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Productos',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            if (puedeEditarItems &&
                                !cerrado &&
                                widget.onAgregarItems != null)
                              TextButton.icon(
                                onPressed: () {
                                  Navigator.pop(context);
                                  widget.onAgregarItems!(_pedido);
                                },
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Agregar'),
                              ),
                          ],
                        ),
                        if (_pedido.itemsResumen.isEmpty)
                          Text(
                            'Sin ítems',
                            style: TextStyle(color: Colors.grey.shade600),
                          )
                        else
                          ..._pedido.itemsResumen.map((it) {
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(color: Color(0xFFE8EAF0)),
                              ),
                              child: ListTile(
                                title: Text('${it.cantidad}× ${it.nombre}'),
                                subtitle: Text(
                                  [
                                    if (it.toppingsNombres?.isNotEmpty == true)
                                      'Toppings: ${it.toppingsNombres}',
                                    if (it.bebidasNombres?.isNotEmpty == true)
                                      'Bebidas: ${it.bebidasNombres}',
                                    if (it.observaciones?.trim().isNotEmpty ==
                                        true)
                                      it.observaciones!,
                                  ].join('\n'),
                                ),
                                isThreeLine: (it.toppingsNombres != null) ||
                                    (it.bebidasNombres != null) ||
                                    (it.observaciones?.isNotEmpty == true),
                                trailing: puedeEditarItems && !cerrado
                                    ? PopupMenuButton<String>(
                                        onSelected: (v) {
                                          if (v == 'editar') {
                                            _editarItem(it);
                                          } else if (v == 'cambiar') {
                                            _cambiarProducto(it);
                                          } else if (v == 'quitar') {
                                            _eliminarItem(it);
                                          }
                                        },
                                        itemBuilder: (_) => [
                                          const PopupMenuItem(
                                            value: 'editar',
                                            child: Text('Editar'),
                                          ),
                                          if (widget.onAgregarItems != null)
                                            const PopupMenuItem(
                                              value: 'cambiar',
                                              child: Text('Cambiar producto'),
                                            ),
                                          const PopupMenuItem(
                                            value: 'quitar',
                                            child: Text('Quitar'),
                                          ),
                                        ],
                                      )
                                    : null,
                              ),
                            );
                          }),
                        const SizedBox(height: 12),
                        const Text(
                          'Acciones',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_pedido.mesaId != null && widget.onVerMesa != null)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              mesaConCuenta
                                  ? Icons.point_of_sale_outlined
                                  : Icons.table_restaurant,
                            ),
                            title: Text(
                              mesaConCuenta
                                  ? 'Cobrar mesa ${_pedido.mesaNombre ?? ''}'
                                  : 'Ver mesa',
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              widget.onVerMesa!(_pedido.mesaId!);
                            },
                          ),
                        if (_pedido.requiereCobroCaja &&
                            widget.onCobrarParaLlevar != null &&
                            widget.permisos.contains('cobrar_pedido'))
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.payments_outlined),
                            title: Text(
                              'Cobrar (${widget.formatoMoneda.format(_pedido.saldoPendiente)})',
                            ),
                            onTap: () async {
                              Navigator.pop(context);
                              await widget.onCobrarParaLlevar!(_pedido);
                            },
                          ),
                        if (_pedido.estado == 'pendiente_aprobacion') ...[
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.check_circle_outline,
                              color: ColoresFoody.exito,
                            ),
                            title: const Text('Aprobar (asignar mesera)'),
                            onTap: () async {
                              Navigator.pop(context);
                              await widget.onAprobar?.call(_pedido);
                            },
                          ),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              Icons.cancel_outlined,
                              color: ColoresFoody.error,
                            ),
                            title: const Text('Rechazar'),
                            onTap: () async {
                              Navigator.pop(context);
                              // El padre abre diálogo de motivo.
                              await widget.onRechazar?.call(_pedido);
                            },
                          ),
                        ],
                        if (_pedido.accionRapida != null &&
                            _pedido.accionRapida != 'aprobar')
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.play_arrow_outlined),
                            title: Text(_pedido.etiquetaAccionRapida),
                            onTap: () async {
                              final dest = _pedido.accionRapida!;
                              Navigator.pop(context);
                              await widget.onCambiarEstado?.call(_pedido, dest);
                            },
                          ),
                        if (_pedido.estado == 'listo' &&
                            _pedido.tipo == 'domicilio' &&
                            widget.asignarDomiciliarioSlot != null)
                          widget.asignarDomiciliarioSlot!,
                        if (widget.onIrCaja != null && !widget.modoMesero)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.account_balance_wallet_outlined,
                            ),
                            title: const Text('Ir a caja'),
                            onTap: () {
                              Navigator.pop(context);
                              widget.onIrCaja!();
                            },
                          ),
                        if (widget.onIrFacturacion != null &&
                            !widget.modoMesero &&
                            !cerrado)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.receipt_long_outlined),
                            title: const Text('Factura / borrador'),
                            onTap: () {
                              Navigator.pop(context);
                              widget.onIrFacturacion!(
                                _pedido.id,
                                _pedido.numeroPedido,
                              );
                            },
                          ),
                        if (widget.onIrCocinaKds != null &&
                            !widget.modoMesero &&
                            enCocina)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.soup_kitchen_outlined),
                            title: const Text('Abrir cocina (KDS)'),
                            onTap: () {
                              Navigator.pop(context);
                              widget.onIrCocinaKds!();
                            },
                          ),
                        if (!widget.modoMesero && !cerrado)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              Icons.cancel,
                              color: ColoresFoody.error,
                            ),
                            title: const Text('Cancelar pedido'),
                            onTap: () async {
                              Navigator.pop(context);
                              await widget.onCancelar?.call(_pedido);
                            },
                          ),
                        if (widget.permisos.contains('aplicar_descuento') &&
                            !cerrado)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.discount_outlined),
                            title: const Text('Aplicar descuento'),
                            onTap: () async {
                              Navigator.pop(context);
                              await widget.onDescuento?.call(_pedido);
                            },
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaFila(String k, String v, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              k,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(
              v,
              style: TextStyle(
                fontSize: 13,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _labelTipo(String t) => switch (t) {
        'mesa' => 'Mesa',
        'para_llevar' => 'Para llevar / Recoger',
        'domicilio' => 'Domicilio',
        _ => t,
      };
}
