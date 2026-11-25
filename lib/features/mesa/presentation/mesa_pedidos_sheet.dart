import 'dart:async';

import 'package:flutter/material.dart';
import 'package:reserva_canchas/core/widgets/foody_dialogo.dart';
import 'package:reserva_canchas/core/tema/foody_formulario.dart';
import 'package:intl/intl.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_tokens.dart';
import 'package:reserva_canchas/core/layout/foody_breakpoints.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';
import 'package:reserva_canchas/core/realtime/foody_realtime.dart';
import 'package:reserva_canchas/core/realtime/poll_realtime_respaldo.dart';
import 'package:reserva_canchas/core/sesion/sesion_staff_service.dart';
import 'package:reserva_canchas/features/admin/data/pedidos_repository.dart';
import 'package:reserva_canchas/features/mesa/data/mesas_repository.dart';
import 'package:reserva_canchas/features/pedidos/presentation/widgets/aviso_items_no_disponibles.dart';
import 'package:reserva_canchas/services/app_backend.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

void _liberarControlDespuesDelDialogo(TextEditingController control) {
  unawaited(
      Future<void>.delayed(const Duration(milliseconds: 200), control.dispose));
}

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
    this.modoMesero = false,
    this.pedidosRepository,
    this.mesasRepository,
  });

  final String mesaId;
  final String mesaNombre;
  final String sucursalId;
  final VoidCallback onActualizado;
  final VoidCallback? onTransferir;
  final void Function(String? pedidoIdMesa)? onAgregarProductos;

  /// NAV-MS-20: cobro avanzado secundario; primario = presentar cuenta.
  final bool modoMesero;
  final PedidosRepository? pedidosRepository;
  final MesasRepository? mesasRepository;

  @override
  State<MesaPedidosSheet> createState() => _MesaPedidosSheetState();
}

class _MesaPedidosSheetState extends State<MesaPedidosSheet>
    with WidgetsBindingObserver {
  late final _repo = widget.pedidosRepository ?? PedidosRepository();
  late final _mesasRepo = widget.mesasRepository ?? MesasRepository();
  Color get _ink => AnaliticaTokens.inkOf(context);
  Color get _inkMuted => AnaliticaTokens.inkMutedOf(context);
  Color get _inkSoft =>
      Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.72);
  Color get _canvas => AnaliticaTokens.canvasOf(context);
  Color get _border => AnaliticaTokens.borderOf(context);
  Color get _surfaceMuted =>
      Theme.of(context).colorScheme.surfaceContainerHighest;
  Map<String, dynamic>? _datos;
  bool _cargando = true;
  bool _cobrando = false;
  String? _error;
  RealtimeChannel? _canal;
  PollRealtimeRespaldo? _pollRespaldo;
  final Set<String> _itemsCobroSeleccionados = {};
  List<String> _permisos = [];

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
    WidgetsBinding.instance.addObserver(this);
    unawaited(_cargarPermisos());
    _cargar();
    _suscribirRealtime();
    _pollRespaldo = PollRealtimeRespaldo(onActualizar: () async {
      if (mounted) await _cargar(silencioso: true);
    });
    unawaited(_pollRespaldo!.iniciar());
  }

  Future<void> _cargarPermisos() async {
    final sesion = await SesionStaffService.cargar();
    if (!mounted) return;
    setState(() => _permisos = sesion?.permisos ?? []);
  }

  bool get _puedeCobrar => _permisos.contains('cobrar_pedido');

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      unawaited(_cargar(silencioso: true));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    FoodyRealtime.liberarCanal(_canal);
    _pollRespaldo?.detener();
    super.dispose();
  }

  void _suscribirRealtime() {
    if (!AppBackend.supabaseReady) return;
    _canal = FoodyRealtime.suscribirSucursal(
      widget.sucursalId,
      onEvento: (_) => _cargar(silencioso: true),
      onReconectado: () => _cargar(silencioso: true),
    );
  }

  Future<void> _cargar({bool silencioso = false}) async {
    if (!silencioso) {
      setState(() {
        _cargando = true;
        _error = null;
      });
    }
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
          SnackBar(
            content: Text(
              widget.modoMesero
                  ? '$numeroPedido → cuenta presentada. Avisa al cajero.'
                  : '$numeroPedido → pagando (cuenta presentada)',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensajeErrorHttp(e, contexto: 'marcar pagando')),
            backgroundColor: AnaliticaTokens.alertas,
          ),
        );
      }
    }
  }

  /// NAV-MS-31: presentar todas las cuentas abiertas de la mesa.
  Future<void> _presentarCuentaMesa() async {
    final pedidos = (_datos?['pedidos'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .where((p) {
      final e = p['estado'] as String? ?? '';
      return !_estadosCerrados.contains(e) && e != 'pagando';
    }).toList();
    if (pedidos.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('No hay pedidos pendientes de presentar')),
        );
      }
      return;
    }
    for (final p in pedidos) {
      final id = p['id'] as String?;
      if (id == null) continue;
      try {
        await _repo.cambiarEstado(
          pedidoId: id,
          estado: 'pagando',
          sucursalId: widget.sucursalId,
        );
      } catch (_) {/* siguiente */}
    }
    await _cargar();
    widget.onActualizado();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cuenta presentada — avisa al cajero para cobrar',
          ),
        ),
      );
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
    final ok = await FoodyDialogo.mostrar<bool>(
      context: context,
      builder: (ctx) => FoodyDialogoShell(
        titulo: 'Eliminar ítem',
        subtitulo: '¿Quitar «$nombreProducto» del pedido?',
        maxWidth: 460,
        contenido: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
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
        acciones: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: AnaliticaTokens.alertas),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) {
      _liberarControlDespuesDelDialogo(motivoCtrl);
      return;
    }

    try {
      await _repo.eliminarItemPedido(
        pedidoId: pedidoId,
        itemId: itemId,
        sucursalId: widget.sucursalId,
        motivo: motivoCtrl.text.trim().isEmpty ? null : motivoCtrl.text.trim(),
      );
      _liberarControlDespuesDelDialogo(motivoCtrl);
      await _cargar();
      widget.onActualizado();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ítem eliminado: $nombreProducto')),
        );
      }
    } catch (e) {
      _liberarControlDespuesDelDialogo(motivoCtrl);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensajeErrorHttp(e, contexto: 'eliminar ítem')),
            backgroundColor: AnaliticaTokens.alertas,
          ),
        );
      }
    }
  }

  String? _pedidoMesaPrincipal() {
    final pedidos = (_datos?['pedidos'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    for (final p in pedidos) {
      if (p['tipo'] == 'mesa') return p['id'] as String?;
    }
    return pedidos.isNotEmpty ? pedidos.last['id'] as String? : null;
  }

  Future<void> _cobrarCuenta(
      {List<String>? itemIds,
      double? montoParcial,
      List<Map<String, dynamic>>? pagos}) async {
    if (_cobrando) return;
    final total = _datos?['total_acumulado'];
    final totalNum =
        total is num ? total.toDouble() : double.tryParse('$total') ?? 0;
    var metodoPago = 'efectivo';
    var metodoPago2 = 'tarjeta';
    final propinaCtrl = TextEditingController(text: '0');
    final parcialCtrl = TextEditingController(
      text: montoParcial?.toStringAsFixed(0) ?? '',
    );
    final mixtoMonto1Ctrl = TextEditingController();
    final mixtoMonto2Ctrl = TextEditingController();
    final recibidoCtrl = TextEditingController();
    var modo = itemIds != null
        ? 'split'
        : montoParcial != null
            ? 'parcial'
            : pagos != null
                ? 'mixto'
                : 'total';
    var cobroAvanzado =
        itemIds != null || montoParcial != null || pagos != null;
    final ok = await FoodyDialogo.mostrar<bool>(
      context: context,
      builder: (ctx) {
        final anchoDlg = MediaQuery.sizeOf(ctx).width;
        final estrecho = FoodyBreakpoints.dialogoEstrecho(anchoDlg);
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            insetPadding: EdgeInsets.symmetric(
              horizontal: estrecho ? 12 : 24,
              vertical: 24,
            ),
            actionsAlignment: MainAxisAlignment.end,
            actionsOverflowAlignment: OverflowBarAlignment.end,
            actionsOverflowDirection: VerticalDirection.down,
            actionsOverflowButtonSpacing: 8,
            title: Text(
              itemIds != null ? 'Cobrar ítems' : 'Cobrar cuenta',
            ),
            content: SizedBox(
              width: estrecho ? anchoDlg : 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Total pendiente: ${_moneda.format(totalNum)}',
                      style: TextStyle(
                        fontSize: estrecho ? 16 : 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    AvisoItemsNoDisponibles(
                      cantidad: _cantidadItemsNoDisponibles(itemIds: itemIds),
                    ),
                    if (itemIds != null && itemIds.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Cobrando ${itemIds.length} ítem(s) seleccionados',
                          style: TextStyle(
                            fontSize: 12,
                            color: _inkMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    if ((_datos?['pagos_abonos'] as List?)?.isNotEmpty ==
                            true &&
                        itemIds == null &&
                        montoParcial == null &&
                        cobroAvanzado)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Hay abonos previos. Usa Parcial para el saldo o marca ítems pendientes.',
                          style: TextStyle(fontSize: 11, color: _inkMuted),
                        ),
                      ),
                    if (cobroAvanzado) ...[
                      const SizedBox(height: 12),
                      if (estrecho)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final m in const ['total', 'parcial', 'mixto'])
                              ChoiceChip(
                                label: Text(
                                  m == 'total'
                                      ? 'Total'
                                      : m == 'parcial'
                                          ? 'Parcial'
                                          : 'Mixto',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: modo == m ? Colors.white : _inkMuted,
                                  ),
                                ),
                                selected: modo == m,
                                selectedColor: _ink,
                                backgroundColor: _surfaceMuted,
                                side: BorderSide(
                                  color: modo == m ? _ink : _border,
                                ),
                                showCheckmark: false,
                                onSelected: (_) =>
                                    setDialogState(() => modo = m),
                              ),
                          ],
                        )
                      else
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'total', label: Text('Total')),
                            ButtonSegment(
                                value: 'parcial', label: Text('Parcial')),
                            ButtonSegment(value: 'mixto', label: Text('Mixto')),
                          ],
                          selected: {modo},
                          onSelectionChanged: (s) =>
                              setDialogState(() => modo = s.first),
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
                          initialValue: metodoPago,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Pago 1 — método',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                                value: 'efectivo', child: Text('Efectivo')),
                            DropdownMenuItem(
                                value: 'tarjeta', child: Text('Tarjeta')),
                            DropdownMenuItem(
                                value: 'transferencia',
                                child: Text('Transferencia')),
                            DropdownMenuItem(
                                value: 'nequi', child: Text('Nequi')),
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
                          initialValue: metodoPago2,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Pago 2 — método',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                                value: 'efectivo', child: Text('Efectivo')),
                            DropdownMenuItem(
                                value: 'tarjeta', child: Text('Tarjeta')),
                            DropdownMenuItem(
                                value: 'transferencia',
                                child: Text('Transferencia')),
                            DropdownMenuItem(
                                value: 'nequi', child: Text('Nequi')),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              setDialogState(() => metodoPago2 = v);
                            }
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
                    ],
                    if (!cobroAvanzado && itemIds == null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () =>
                              setDialogState(() => cobroAvanzado = true),
                          child: const Text('Cobro parcial o mixto'),
                        ),
                      ),
                    if (modo != 'mixto') ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: metodoPago,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Método de pago',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'efectivo', child: Text('Efectivo')),
                          DropdownMenuItem(
                              value: 'tarjeta', child: Text('Tarjeta')),
                          DropdownMenuItem(
                            value: 'transferencia',
                            child: Text('Transferencia'),
                          ),
                          DropdownMenuItem(
                              value: 'nequi', child: Text('Nequi')),
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
                    if (_muestraCambioEfectivo(
                      modo: modo,
                      metodoPago: metodoPago,
                      metodoPago2: metodoPago2,
                    )) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: recibidoCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Efectivo recibido',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setDialogState(() {}),
                      ),
                      Builder(
                        builder: (context) {
                          final objetivo = _montoObjetivoCobro(
                            modo: modo,
                            totalNum: totalNum,
                            montoParcial: montoParcial,
                            parcialCtrl: parcialCtrl,
                            mixtoMonto1Ctrl: mixtoMonto1Ctrl,
                            mixtoMonto2Ctrl: mixtoMonto2Ctrl,
                            metodoPago: metodoPago,
                            metodoPago2: metodoPago2,
                          );
                          final recibido = double.tryParse(
                                recibidoCtrl.text.replaceAll(',', ''),
                              ) ??
                              0;
                          final cambio = recibido - objetivo;
                          if (recibido <= 0) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              cambio >= 0
                                  ? 'Cambio: ${_moneda.format(cambio)}'
                                  : 'Faltan: ${_moneda.format(-cambio)}',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: cambio >= 0
                                    ? AnaliticaTokens.inventario
                                    : AnaliticaTokens.alertas,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
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
                onPressed: () {
                  if (modo == 'mixto') {
                    final m1 = double.tryParse(
                            mixtoMonto1Ctrl.text.replaceAll(',', '')) ??
                        0;
                    final m2 = double.tryParse(
                            mixtoMonto2Ctrl.text.replaceAll(',', '')) ??
                        0;
                    final objetivo = montoParcial ?? totalNum;
                    if ((m1 + m2 - objetivo).abs() > 0.01) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Efectivo + tarjeta debe sumar ${_moneda.format(objetivo)}',
                          ),
                        ),
                      );
                      return;
                    }
                  }
                  if (modo == 'parcial') {
                    final abono =
                        double.tryParse(parcialCtrl.text.replaceAll(',', ''));
                    if (abono == null || abono <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Indica un monto de abono válido')),
                      );
                      return;
                    }
                    if (abono > totalNum + 0.01) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'El abono no puede superar ${_moneda.format(totalNum)}',
                          ),
                        ),
                      );
                      return;
                    }
                  }
                  Navigator.pop(ctx, true);
                },
                child: Text(modo == 'parcial' ? 'Registrar abono' : 'Cobrar'),
              ),
            ],
          ),
        );
      },
    );
    if (ok != true) {
      _liberarControlDespuesDelDialogo(propinaCtrl);
      _liberarControlDespuesDelDialogo(parcialCtrl);
      _liberarControlDespuesDelDialogo(mixtoMonto1Ctrl);
      _liberarControlDespuesDelDialogo(mixtoMonto2Ctrl);
      _liberarControlDespuesDelDialogo(recibidoCtrl);
      return;
    }

    try {
      List<Map<String, dynamic>>? pagosEnvio = pagos;
      double? parcialEnvio = montoParcial;
      double? propinaEnvio =
          double.tryParse(propinaCtrl.text.replaceAll(',', ''));
      if (modo == 'parcial') {
        parcialEnvio = double.tryParse(parcialCtrl.text.replaceAll(',', ''));
      } else if (modo == 'mixto') {
        final m1 =
            double.tryParse(mixtoMonto1Ctrl.text.replaceAll(',', '')) ?? 0;
        final m2 =
            double.tryParse(mixtoMonto2Ctrl.text.replaceAll(',', '')) ?? 0;
        pagosEnvio = [
          {'metodo_pago': metodoPago, 'monto': m1},
          {'metodo_pago': metodoPago2, 'monto': m2},
        ];
        parcialEnvio = null;
      }

      setState(() => _cobrando = true);
      final clave = const Uuid().v4();
      final result = await _repo.cobrarCuentaMesa(
        mesaId: widget.mesaId,
        sucursalId: widget.sucursalId,
        metodoPago: modo == 'mixto' ? null : metodoPago,
        montoParcial: parcialEnvio,
        propina: propinaEnvio,
        pagos: pagosEnvio,
        itemIds: itemIds,
        idempotencyKey: clave,
      );
      _liberarControlDespuesDelDialogo(propinaCtrl);
      _liberarControlDespuesDelDialogo(parcialCtrl);
      _liberarControlDespuesDelDialogo(mixtoMonto1Ctrl);
      _liberarControlDespuesDelDialogo(mixtoMonto2Ctrl);
      _liberarControlDespuesDelDialogo(recibidoCtrl);
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
            backgroundColor: AnaliticaTokens.inventario,
          ),
        );
      }
    } catch (e) {
      // Capturar montos antes de dispose (VIE-05 override)
      final propinaEnvioCatch =
          double.tryParse(propinaCtrl.text.replaceAll(',', ''));
      List<Map<String, dynamic>>? pagosEnvioCatch = pagos;
      double? parcialEnvioCatch = montoParcial;
      if (modo == 'parcial') {
        parcialEnvioCatch =
            double.tryParse(parcialCtrl.text.replaceAll(',', ''));
      } else if (modo == 'mixto') {
        final m1 =
            double.tryParse(mixtoMonto1Ctrl.text.replaceAll(',', '')) ?? 0;
        final m2 =
            double.tryParse(mixtoMonto2Ctrl.text.replaceAll(',', '')) ?? 0;
        pagosEnvioCatch = [
          {'metodo_pago': metodoPago, 'monto': m1},
          {'metodo_pago': metodoPago2, 'monto': m2},
        ];
        parcialEnvioCatch = null;
      }
      _liberarControlDespuesDelDialogo(propinaCtrl);
      _liberarControlDespuesDelDialogo(parcialCtrl);
      _liberarControlDespuesDelDialogo(mixtoMonto1Ctrl);
      _liberarControlDespuesDelDialogo(mixtoMonto2Ctrl);
      _liberarControlDespuesDelDialogo(recibidoCtrl);
      final msg = e.toString().toLowerCase();
      final esTimeout = msg.contains('timeout') || msg.contains('timed out');
      if (esTimeout && mounted) {
        await _cargar(silencioso: true);
        if (!mounted) return;
        final saldo = _datos?['saldo_pendiente'] ?? _datos?['total_acumulado'];
        final saldoNum =
            saldo is num ? saldo.toDouble() : double.tryParse('$saldo') ?? -1;
        if (saldoNum >= 0 && saldoNum <= 0.01) {
          widget.onActualizado();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cobro confirmado · ${widget.mesaNombre}'),
              backgroundColor: AnaliticaTokens.inventario,
            ),
          );
          Navigator.of(context).pop();
          return;
        }
      }
      // VIE-05 C: admin/gerente puede forzar pagado con motivo
      if (codigoErrorApi(e) == 'COCINA_INCOMPLETA_PARA_PAGADO' && mounted) {
        final forzado = await _intentarForzarCobroCocinaIncompleta(
          metodoPago: modo == 'mixto' ? null : metodoPago,
          montoParcial: parcialEnvioCatch,
          propina: propinaEnvioCatch,
          pagos: pagosEnvioCatch,
          itemIds: itemIds,
        );
        if (!mounted) return;
        if (forzado) return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensajeErrorHttp(e, contexto: 'cobrar cuenta')),
            backgroundColor: AnaliticaTokens.alertas,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _cobrando = false);
    }
  }

  /// Override admin/gerente cuando cocina incompleta (VIE-05 C).
  Future<bool> _intentarForzarCobroCocinaIncompleta({
    String? metodoPago,
    double? montoParcial,
    double? propina,
    List<Map<String, dynamic>>? pagos,
    List<String>? itemIds,
  }) async {
    final sesion = await SesionStaffService.cargar();
    final rol = sesion?.rol ?? '';
    final puede = rol == 'admin' || rol == 'gerente' || rol == 'gerente_cadena';
    if (!puede || !mounted) return false;

    final motivoCtrl = TextEditingController();
    final ok = await FoodyDialogo.mostrar<bool>(
      context: context,
      builder: (ctx) => FoodyDialogoShell(
        titulo: 'Cocina incompleta',
        subtitulo: 'Confirma el cierre con un motivo registrado.',
        maxWidth: 460,
        contenido: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Hay ítems aún en cocina. Puedes forzar el cierre con un motivo.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: motivoCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Motivo (obligatorio)',
                border: OutlineInputBorder(),
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
            child: const Text('Forzar cobro'),
          ),
        ],
      ),
    );
    final motivo = motivoCtrl.text.trim();
    _liberarControlDespuesDelDialogo(motivoCtrl);
    if (ok != true || motivo.isEmpty) {
      if (mounted && ok == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Indica un motivo para forzar')),
        );
      }
      return false;
    }

    try {
      setState(() => _cobrando = true);
      final result = await _repo.cobrarCuentaMesa(
        mesaId: widget.mesaId,
        sucursalId: widget.sucursalId,
        metodoPago: metodoPago,
        montoParcial: montoParcial,
        propina: propina,
        pagos: pagos,
        itemIds: itemIds,
        idempotencyKey: const Uuid().v4(),
        motivo: motivo,
      );
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
                  : 'Cuenta cobrada (forzado) · ${widget.mesaNombre}',
            ),
            backgroundColor: AnaliticaTokens.inventario,
          ),
        );
      }
      return true;
    } catch (e2) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensajeErrorHttp(e2, contexto: 'forzar cobro')),
            backgroundColor: AnaliticaTokens.alertas,
          ),
        );
      }
      return true; // ya mostramos error; no repetir snackbar del catch padre
    }
  }

  Future<void> _salioSinPagar() async {
    final nombreCtrl = TextEditingController();
    final telCtrl = TextEditingController();
    final motivoCtrl = TextEditingController();
    final ok = await FoodyDialogo.mostrar<bool>(
      context: context,
      builder: (ctx) => FoodyDialogoShell(
        titulo: 'Cliente salió sin pagar',
        subtitulo: 'Registra quién queda pendiente y el motivo.',
        maxWidth: 460,
        contenido: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
        acciones: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: AnaliticaTokens.alertas),
            child: const Text('Registrar CxC'),
          ),
        ],
      ),
    );
    if (ok != true) {
      _liberarControlDespuesDelDialogo(nombreCtrl);
      _liberarControlDespuesDelDialogo(telCtrl);
      _liberarControlDespuesDelDialogo(motivoCtrl);
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
      _liberarControlDespuesDelDialogo(nombreCtrl);
      _liberarControlDespuesDelDialogo(telCtrl);
      _liberarControlDespuesDelDialogo(motivoCtrl);
      widget.onActualizado();
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cuenta por cobrar registrada · mesa liberada'),
            backgroundColor: AnaliticaTokens.inventario,
          ),
        );
      }
    } catch (e) {
      _liberarControlDespuesDelDialogo(nombreCtrl);
      _liberarControlDespuesDelDialogo(telCtrl);
      _liberarControlDespuesDelDialogo(motivoCtrl);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensajeErrorHttp(e, contexto: 'salió sin pagar')),
            backgroundColor: AnaliticaTokens.alertas,
          ),
        );
      }
    }
  }

  Future<void> _cobrarItemsSeleccionados(List<String> itemIds) async {
    await _cobrarCuenta(itemIds: itemIds);
  }

  /// Agrupa ítems pendientes de cobro por etiqueta de comensal.
  Map<String, ({double total, List<String> itemIds})> _agruparPorComensal() {
    final pedidos = (_datos?['pedidos'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final mapa = <String, ({double total, List<String> itemIds})>{};

    for (final pedido in pedidos) {
      if (_estadosCerrados.contains(pedido['estado'] as String? ?? '')) {
        continue;
      }
      final items = (pedido['items'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
      for (final item in items) {
        if ((item['estado_cobro'] as String? ?? 'pendiente') != 'pendiente') {
          continue;
        }
        final itemId = item['id'] as String?;
        if (itemId == null) continue;
        final etiquetaRaw = item['comensal_etiqueta'] as String?;
        final etiqueta = (etiquetaRaw != null && etiquetaRaw.trim().isNotEmpty)
            ? etiquetaRaw.trim()
            : 'Sin etiqueta';
        final subtotal = item['subtotal_linea'];
        final monto = subtotal is num
            ? subtotal.toDouble()
            : double.tryParse('$subtotal') ?? 0;
        final prev = mapa[etiqueta];
        mapa[etiqueta] = (
          total: (prev?.total ?? 0) + monto,
          itemIds: [...(prev?.itemIds ?? []), itemId],
        );
      }
    }
    return mapa;
  }

  Future<void> _cobrarSoloTicket(Map<String, dynamic> pedido) async {
    final items =
        (pedido['items'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final ids = <String>[];
    for (final item in items) {
      if ((item['estado_cobro'] as String? ?? 'pendiente') != 'pendiente') {
        continue;
      }
      final id = item['id'] as String?;
      if (id != null) ids.add(id);
    }
    if (ids.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Este ticket no tiene ítems pendientes de cobro')),
        );
      }
      return;
    }
    await _cobrarItemsSeleccionados(ids);
  }

  void _mostrarAyudaCuenta() {
    FoodyDialogo.mostrar<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cuenta unificada vs ticket separado'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Cuenta unificada',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(
                'El total de la mesa suma todos los tickets activos. '
                '«Cobrar cuenta» liquida todo lo pendiente de una vez.',
              ),
              SizedBox(height: 16),
              Text(
                'Ticket separado',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(
                'Cada bloque con número de pedido es un ticket distinto '
                '(QR, mesero o para llevar en mesa). Para cobrar solo uno: '
                'usa «Cobrar este ticket», marca ítems o split por comensal.',
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Widget? _bannerModoCuenta({required bool compacto}) {
    final pedidos = (_datos?['pedidos'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    if (pedidos.isEmpty) return null;

    final cuenta = _datos?['cuenta'] as Map<String, dynamic>?;
    final cantidadTickets =
        cuenta?['cantidad_tickets'] as int? ?? pedidos.length;
    final grupo = cuenta?['mesa_grupo'] as Map<String, dynamic>?;
    final mesasGrupo =
        (grupo?['mesas'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final multiTicket = cantidadTickets > 1;
    final total = _datos?['total_acumulado'];

    // Compacto: una línea + ayuda; menos densidad en móvil.
    if (compacto) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
        child: Row(
          children: [
            Icon(
              multiTicket
                  ? Icons.receipt_long
                  : Icons.account_balance_wallet_outlined,
              color: _ink,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                multiTicket
                    ? '$cantidadTickets tickets · ${_moneda.format(total ?? 0)}'
                    : 'Cuenta · ${_moneda.format(total ?? 0)}',
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              tooltip: 'Ayuda cuenta',
              onPressed: _mostrarAyudaCuenta,
              icon: const Icon(Icons.help_outline, size: 20),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Material(
        color: multiTicket
            ? Color(0xFFD97706).withValues(alpha: 0.35)
            : AnaliticaTokens.inventario.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    multiTicket
                        ? Icons.receipt_long
                        : Icons.account_balance_wallet_outlined,
                    color: _ink,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          multiTicket
                              ? '$cantidadTickets tickets · cuenta unificada'
                              : '1 ticket · cuenta unificada al cobrar',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          multiTicket
                              ? 'Total pendiente mesa: ${_moneda.format(total ?? 0)}. '
                                  '«Cobrar cuenta» paga todos; usa «Cobrar este ticket» o ítems para pagar uno solo.'
                              : '«Cobrar cuenta» liquida el ticket completo de esta mesa.',
                          style: TextStyle(
                            fontSize: 12,
                            color: _ink,
                            height: 1.35,
                          ),
                        ),
                        if (mesasGrupo.length > 1) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Mesas unidas: ${mesasGrupo.map((m) => m['nombre'] ?? '').join(', ')}',
                            style: TextStyle(
                              fontSize: 11,
                              color: _inkMuted,
                            ),
                          ),
                        ],
                        AvisoItemsNoDisponibles(
                          cantidad: _cantidadItemsNoDisponibles(),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Ayuda',
                    onPressed: _mostrarAyudaCuenta,
                    icon: const Icon(Icons.help_outline),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _atribucionMesaResumen() {
    final pedidos = (_datos?['pedidos'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    if (pedidos.isEmpty) return 'Mesa ${widget.mesaNombre}';
    final p = pedidos.first;
    final partes = <String>['Mesa ${widget.mesaNombre}'];
    final mesera = p['mesera_nombre'] as String?;
    if (mesera?.trim().isNotEmpty == true) {
      partes.add('Mesera: ${mesera!.trim()}');
    }
    final cliente = p['cliente_nombre'] as String?;
    if (cliente?.trim().isNotEmpty == true) {
      partes.add('Cliente: ${cliente!.trim()}');
    }
    return partes.join(' · ');
  }

  String _etiquetaTipoPedido(String tipo) {
    switch (tipo) {
      case 'mesa':
        return 'Mesa';
      case 'para_llevar':
        return 'Para llevar';
      case 'domicilio':
        return 'Domicilio';
      default:
        return tipo.replaceAll('_', ' ');
    }
  }

  Future<void> _cobrarPorComensal(String etiqueta) async {
    final grupo = _agruparPorComensal()[etiqueta];
    if (grupo == null || grupo.itemIds.isEmpty) return;
    setState(() {
      _itemsCobroSeleccionados
        ..clear()
        ..addAll(grupo.itemIds);
    });
    await _cobrarItemsSeleccionados(grupo.itemIds.toList());
    if (mounted) {
      setState(_itemsCobroSeleccionados.clear);
    }
  }

  Future<void> _mostrarSelectorComensal() async {
    final grupos = _agruparPorComensal();
    if (grupos.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No hay ítems pendientes de cobro'),
          ),
        );
      }
      return;
    }
    final etiquetas = grupos.keys.toList()
      ..sort((a, b) {
        if (a == 'Sin etiqueta') return 1;
        if (b == 'Sin etiqueta') return -1;
        return a.compareTo(b);
      });

    final elegido = await FoodyDialogo.mostrar<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cobrar por comensal'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: etiquetas.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final et = etiquetas[i];
              final g = grupos[et]!;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      AnaliticaTokens.inventario.withValues(alpha: 0.2),
                  child: Text(
                    et.isNotEmpty ? et[0].toUpperCase() : '?',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(et),
                subtitle: Text('${g.itemIds.length} ítem(s)'),
                trailing: Text(
                  _moneda.format(g.total),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                onTap: () => Navigator.pop(ctx, et),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
    if (elegido != null) await _cobrarPorComensal(elegido);
  }

  Widget? _panelSplitComensales() {
    final grupos = _agruparPorComensal();
    if (grupos.isEmpty) return null;

    final etiquetas = grupos.keys.toList()
      ..sort((a, b) {
        if (a == 'Sin etiqueta') return 1;
        if (b == 'Sin etiqueta') return -1;
        return a.compareTo(b);
      });

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Split por comensal',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _mostrarSelectorComensal,
                icon: const Icon(Icons.people_outline, size: 18),
                label: const Text('Cobrar uno'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final et in etiquetas) ...[
                  ActionChip(
                    avatar: Icon(
                      Icons.person_outline,
                      size: 18,
                      color: AnaliticaTokens.inventario,
                    ),
                    label: Text('$et · ${_moneda.format(grupos[et]!.total)}'),
                    onPressed: () => _cobrarPorComensal(et),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: Text(
              'Mantén pulsado un ítem para asignar comensal',
              style: TextStyle(fontSize: 11, color: _inkMuted),
            ),
          ),
        ],
      ),
    );
  }

  int _cantidadItemsNoDisponibles({List<String>? itemIds}) {
    final pedidos = _datos?['pedidos'] as List<dynamic>? ?? const [];
    var cantidad = 0;
    for (final pedidoRaw in pedidos) {
      if (pedidoRaw is! Map) continue;
      final items = pedidoRaw['items'] as List<dynamic>? ?? const [];
      for (final itemRaw in items) {
        if (itemRaw is! Map || itemRaw['estado_cocina'] != 'no_disponible') {
          continue;
        }
        if (itemIds != null && !itemIds.contains('${itemRaw['id']}')) continue;
        final rawCantidad = itemRaw['cantidad'];
        cantidad += rawCantidad is num
            ? rawCantidad.toInt()
            : int.tryParse('$rawCantidad') ?? 1;
      }
    }
    return cantidad;
  }

  @override
  Widget build(BuildContext context) {
    final ancho = FoodyBreakpoints.widthOf(context);
    final compacto = FoodyBreakpoints.esCompact(ancho);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: compacto ? 0.82 : 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Material(
          color: _canvas,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(20, compacto ? 8 : 14, 12, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.mesaNombre,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                              color: _ink,
                            ),
                          ),
                          if (_datos != null)
                            Text(
                              'Total mesa: ${_moneda.format(_datos!['total_acumulado'] ?? 0)}',
                              style: TextStyle(
                                color: _ink,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          if (_datos != null && !compacto) ...[
                            const SizedBox(height: 2),
                            Text(
                              _atribucionMesaResumen(),
                              style: TextStyle(
                                fontSize: 12,
                                color: _inkMuted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Actualizar',
                      onPressed: _cargar,
                      icon: Icon(
                        Icons.refresh,
                        color: _inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (_datos != null && !_cargando && _error == null)
                _bannerModoCuenta(compacto: compacto) ??
                    const SizedBox.shrink(),
              const Divider(height: 1),
              if (_datos != null && !_cargando && _error == null && !compacto)
                _panelSplitComensales() ?? const SizedBox.shrink(),
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
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (widget.modoMesero) ...[
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                              backgroundColor: _ink,
                            ),
                            onPressed: _presentarCuentaMesa,
                            icon:
                                const Icon(Icons.notifications_active_outlined),
                            label:
                                const Text('Listo para cobrar (avisar caja)'),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Presenta la cuenta al cliente y avisa al cajero',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              color: _inkMuted,
                            ),
                          ),
                          if (widget.onAgregarProductos != null) ...[
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _ink,
                                side: BorderSide(
                                  color: _border,
                                ),
                                minimumSize: const Size.fromHeight(46),
                              ),
                              onPressed: () {
                                Navigator.pop(context);
                                widget.onAgregarProductos!(
                                  _pedidoMesaPrincipal(),
                                );
                              },
                              icon: const Icon(Icons.add_shopping_cart),
                              label: const Text('Agregar productos'),
                            ),
                          ],
                        ] else ...[
                          if (_puedeCobrar) ...[
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(52),
                                backgroundColor: _ink,
                              ),
                              onPressed: _cobrando
                                  ? null
                                  : () {
                                      if (_itemsCobroSeleccionados.isNotEmpty) {
                                        _cobrarItemsSeleccionados(
                                          _itemsCobroSeleccionados.toList(),
                                        );
                                      } else {
                                        _cobrarCuenta();
                                      }
                                    },
                              icon: _cobrando
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.payments),
                              label: Text(
                                _cobrando
                                    ? 'Procesando cobro…'
                                    : _itemsCobroSeleccionados.isEmpty
                                        ? 'Cobrar todo · ${_moneda.format(_datos!['total_acumulado'] ?? 0)}'
                                        : 'Cobrar ${_itemsCobroSeleccionados.length} ítems',
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _itemsCobroSeleccionados.isEmpty
                                  ? 'Liquida la cuenta unificada de la mesa'
                                  : 'Solo los ítems marcados en la lista',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                color: _inkMuted,
                              ),
                            ),
                          ] else ...[
                            Text(
                              'Sin permiso para cobrar. Pide a un cajero o activa «Cobrar pedidos» en Usuarios.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: _inkMuted,
                              ),
                            ),
                          ],
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight:
                                  (MediaQuery.sizeOf(context).height * 0.35)
                                      .clamp(140.0, 280.0),
                            ),
                            child: SingleChildScrollView(
                              child: ExpansionTile(
                                tilePadding: EdgeInsets.zero,
                                title: const Text(
                                  'Opciones avanzadas',
                                  style: TextStyle(fontSize: 14),
                                ),
                                children: [
                                  if (compacto)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: _panelSplitComensales() ??
                                          const SizedBox.shrink(),
                                    ),
                                  if (widget.onAgregarProductos != null)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: OutlinedButton.icon(
                                        onPressed: () {
                                          Navigator.pop(context);
                                          widget.onAgregarProductos!(
                                            _pedidoMesaPrincipal(),
                                          );
                                        },
                                        icon: const Icon(
                                          Icons.add_shopping_cart,
                                        ),
                                        label: const Text('Agregar productos'),
                                      ),
                                    ),
                                  Text(
                                    'Marca ítems en la lista, usa «Cobrar este ticket» '
                                    'o split por comensal para cobros parciales.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _inkMuted,
                                      height: 1.35,
                                    ),
                                  ),
                                  if (!widget.modoMesero) ...[
                                    const SizedBox(height: 8),
                                    TextButton.icon(
                                      onPressed: _salioSinPagar,
                                      icon: Icon(
                                        Icons.logout,
                                        color: AnaliticaTokens.alertas,
                                      ),
                                      label: Text(
                                        'Salió sin pagar',
                                        style: TextStyle(
                                          color: AnaliticaTokens.alertas,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              if (widget.onTransferir != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: OutlinedButton.icon(
                    onPressed: widget.onTransferir,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _ink,
                      side: BorderSide(color: _border),
                    ),
                    icon: const Icon(Icons.swap_horiz),
                    label: const Text('Transferir pedido a otra mesa'),
                  ),
                ),
              // «Salió sin pagar» vive en Opciones avanzadas (menos ruido en footer).
            ],
          ),
        );
      },
    );
  }

  Widget _listaPedidos(ScrollController scrollController) {
    final pedidos = (_datos!['pedidos'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
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
    final tipo = pedido['tipo'] as String? ?? 'mesa';
    final items =
        (pedido['items'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final total = pedido['total'];
    final saldo = pedido['saldo_pendiente'] as num? ?? total;
    final puedePagando = estado == 'listo';
    final pedidoId = pedido['id'] as String;
    final puedeEliminar = !_estadosCerrados.contains(estado);
    final itemsPendientesCobro = items
        .where(
          (i) => (i['estado_cobro'] as String? ?? 'pendiente') == 'pendiente',
        )
        .length;
    final pedidosMesa = (_datos?['pedidos'] as List<dynamic>? ?? []).length;
    final multiTicket = pedidosMesa > 1;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Row(
          children: [
            Expanded(
              child: Text(
                pedido['numero_pedido'] as String? ?? '',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Chip(
              label: Text(
                _etiquetaTipoPedido(tipo),
                style: const TextStyle(fontSize: 11),
              ),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_etiquetaEstado(estado)),
            if ((pedido['mesera_nombre'] as String?)?.trim().isNotEmpty == true)
              Text(
                'Mesera: ${pedido['mesera_nombre']}',
                style: TextStyle(fontSize: 12, color: _inkMuted),
              ),
            if ((pedido['cliente_nombre'] as String?)?.trim().isNotEmpty ==
                true)
              Text(
                'Cliente: ${pedido['cliente_nombre']}',
                style: TextStyle(fontSize: 12, color: _inkMuted),
              ),
            if ((pedido['saldo_pendiente'] as num?) != null &&
                (pedido['saldo_pendiente'] as num) <
                    (pedido['total'] as num? ?? 0))
              Text(
                'Saldo: ${_moneda.format(pedido['saldo_pendiente'])}',
                style: TextStyle(
                  color: _ink,
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
          if (multiTicket &&
              !widget.modoMesero &&
              itemsPendientesCobro > 0 &&
              !_estadosCerrados.contains(estado))
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _cobrarSoloTicket(pedido),
                  icon: const Icon(Icons.receipt_outlined, size: 18),
                  label: Text(
                    'Cobrar este ticket (${_moneda.format(saldo)})',
                  ),
                ),
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
    final yaCobrado = estadoCobro == 'cobrado';
    final puedeCobrarItem =
        _puedeCobrar && puedeEliminar && itemId != null && !yaCobrado;
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
      title: Text(
        '$cantidad× $producto',
        style: yaCobrado
            ? TextStyle(
                decoration: TextDecoration.lineThrough,
                color: _inkSoft,
              )
            : null,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (yaCobrado)
            Text(
              'Cobrado',
              style: TextStyle(
                color: AnaliticaTokens.inventario,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          Text(
            _etiquetaEstadoCocina(estadoCocina),
            style: TextStyle(
              color: yaCobrado ? _inkSoft : color,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (cocina != null && cocina.isNotEmpty)
            Text(cocina, style: TextStyle(fontSize: 11, color: _inkMuted)),
          if (obs != null && obs.trim().isNotEmpty)
            Text('Obs: $obs', style: TextStyle(fontSize: 11, color: _inkMuted)),
          if (item['comensal_etiqueta'] != null &&
              (item['comensal_etiqueta'] as String).isNotEmpty)
            Text(
              '👤 ${item['comensal_etiqueta']}',
              style: TextStyle(fontSize: 11, color: AnaliticaTokens.inventario),
            ),
        ],
      ),
      trailing: (itemId != null && puedeEliminar)
          ? PopupMenuButton<String>(
              tooltip: 'Más acciones',
              icon: const Icon(Icons.more_vert, size: 20),
              onSelected: (a) {
                if (a == 'comensal') {
                  unawaited(_asignarComensal(
                    pedidoId,
                    itemId,
                    item['comensal_etiqueta'] as String?,
                  ));
                } else if (a == 'eliminar') {
                  unawaited(_eliminarItem(
                    pedidoId: pedidoId,
                    itemId: itemId,
                    nombreProducto: producto,
                    pedidoEstado: pedidoEstado,
                  ));
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'comensal',
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.person_outline),
                    title: Text('Asignar comensal'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'eliminar',
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.delete_outline, color: Colors.red),
                    title: Text('Eliminar ítem'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            )
          : null,
    );
  }

  Widget _historialAbonos() {
    final abonos = (_datos!['pagos_abonos'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Abonos registrados',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: _inkMuted,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          ...abonos.take(5).map(
                (a) => Text(
                  '${_moneda.format(a['monto'])} · ${a['metodo_pago']}'
                  '${(a['responsable_nombre'] as String?)?.trim().isNotEmpty == true ? ' · ${a['responsable_nombre']}' : ''}'
                  ' · ${DateFormat('HH:mm').format(DateTime.parse(a['created_at'].toString()).toLocal())}',
                  style: TextStyle(fontSize: 12, color: _inkMuted),
                ),
              ),
          const SizedBox(height: 4),
          Text(
            'Tras un abono sin ítems, los platos se marcan en orden. '
            'Para cobrar por comensal, usa ítems aún pendientes.',
            style: TextStyle(fontSize: 11, color: _inkMuted),
          ),
        ],
      ),
    );
  }

  Future<void> _asignarComensal(
      String pedidoId, String itemId, String? actual) async {
    final ctrl = TextEditingController(text: actual ?? '');
    final etiqueta = await FoodyDialogo.mostrar<String?>(
      context: context,
      builder: (ctx) => FoodyDialogoShell(
        titulo: 'Comensal / etiqueta',
        maxWidth: 440,
        contenido: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Nombre o referencia',
            hintText: 'Ej: Juan, Mesa A',
            border: OutlineInputBorder(),
          ),
        ),
        acciones: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    _liberarControlDespuesDelDialogo(ctrl);
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
      'listo' => AnaliticaTokens.inventario,
      'no_disponible' => AnaliticaTokens.alertas,
      _ => _inkSoft,
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

  bool _muestraCambioEfectivo({
    required String modo,
    required String metodoPago,
    required String metodoPago2,
  }) {
    if (modo == 'mixto') {
      return metodoPago == 'efectivo' || metodoPago2 == 'efectivo';
    }
    return metodoPago == 'efectivo';
  }

  double _montoObjetivoCobro({
    required String modo,
    required double totalNum,
    required double? montoParcial,
    required TextEditingController parcialCtrl,
    required TextEditingController mixtoMonto1Ctrl,
    required TextEditingController mixtoMonto2Ctrl,
    required String metodoPago,
    required String metodoPago2,
  }) {
    if (modo == 'parcial') {
      return double.tryParse(parcialCtrl.text.replaceAll(',', '')) ??
          montoParcial ??
          0;
    }
    if (modo == 'mixto') {
      if (metodoPago == 'efectivo') {
        return double.tryParse(mixtoMonto1Ctrl.text.replaceAll(',', '')) ?? 0;
      }
      return double.tryParse(
            mixtoMonto2Ctrl.text.replaceAll(',', ''),
          ) ??
          0;
    }
    return totalNum;
  }
}
