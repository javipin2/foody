import 'dart:async';

import 'package:flutter/material.dart';
import 'package:reserva_canchas/core/widgets/foody_dialogo.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:reserva_canchas/core/layout/foody_breakpoints.dart';
import 'package:reserva_canchas/core/realtime/foody_realtime.dart';
import 'package:reserva_canchas/core/realtime/poll_realtime_respaldo.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';
import 'package:reserva_canchas/core/red/mostrar_error_snackbar.dart';
import 'package:reserva_canchas/core/saas_ui/saas_ui.dart';
import 'package:reserva_canchas/core/widgets/foody_estado_ui.dart';
import 'package:reserva_canchas/features/admin/presentation/widgets/operacion_ui.dart';
import 'package:reserva_canchas/features/admin/providers/operacion_sucursal_provider.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_skeleton.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_tokens.dart';
import 'package:reserva_canchas/features/caja/data/caja_repository.dart';
import 'package:reserva_canchas/services/app_backend.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Panel caja (Sprint 5) — abrir turno, movimientos, cerrar.
class CajaAdminScreen extends ConsumerStatefulWidget {
  const CajaAdminScreen({
    super.key,
    this.sucursalId,
    this.onIrPedido,
    this.onCajaEstadoCambiado,
    this.ocultarCabecera = false,
    this.permitirArqueoCiego = true,
  });

  final String? sucursalId;
  final ValueChanged<String>? onIrPedido;

  /// NAV-CJ-02: notifica al shell cajero tras abrir/cerrar turno.
  final ValueChanged<bool>? onCajaEstadoCambiado;

  /// NAV-CJ-01: el shell ya tiene AppBar.
  final bool ocultarCabecera;

  /// NAV-CJ-14: el cajero no debería auto-activar arqueo ciego.
  final bool permitirArqueoCiego;

  @override
  ConsumerState<CajaAdminScreen> createState() => _CajaAdminScreenState();
}

class _CajaAdminScreenState extends ConsumerState<CajaAdminScreen>
    with WidgetsBindingObserver {
  ColorScheme get _scheme => Theme.of(context).colorScheme;

  final _repo = CajaRepository();
  final _montoApertura = TextEditingController(text: '0');
  final _montoCierre = TextEditingController();
  final _conceptoGasto = TextEditingController();
  final _montoGasto = TextEditingController();
  final _montoRetiro = TextEditingController();
  final _montoDevolucion = TextEditingController();
  final _motivoDevolucion = TextEditingController();
  bool _arqueoCiego = false;

  Map<String, dynamic>? _caja;
  List<Map<String, dynamic>> _movimientos = [];
  List<Map<String, dynamic>> _fiados = [];
  Map<String, dynamic>? _resumenCxC;
  bool _verHistorialFiados = false;
  bool _cargando = true;
  String? _error;
  RealtimeChannel? _canal;
  PollRealtimeRespaldo? _pollRespaldo;

  final _moneda = NumberFormat.currency(
    locale: 'es_CO',
    symbol: r'$',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cargar();
    _suscribirRealtime();
    _pollRespaldo = PollRealtimeRespaldo(onActualizar: () async {
      if (mounted) await _cargar(silencioso: true);
    });
    unawaited(_pollRespaldo!.iniciar());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      unawaited(_cargar(silencioso: true));
    }
  }

  void _suscribirRealtime() {
    final sid = widget.sucursalId;
    if (!AppBackend.supabaseReady || sid == null) return;
    _canal = FoodyRealtime.suscribirSucursal(
      sid,
      onEvento: (evento) {
        if (evento == 'caja_movimiento' || evento == eventoSucursalCoalesced) {
          _cargar(silencioso: true);
        }
      },
      onReconectado: () => _cargar(silencioso: true),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    FoodyRealtime.liberarCanal(_canal);
    _pollRespaldo?.detener();
    _montoApertura.dispose();
    _montoCierre.dispose();
    _conceptoGasto.dispose();
    _montoGasto.dispose();
    _montoRetiro.dispose();
    _montoDevolucion.dispose();
    _motivoDevolucion.dispose();
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
      final caja = await _repo.cajaActiva(sid);
      List<Map<String, dynamic>> movs = [];
      List<Map<String, dynamic>> fiados = [];
      Map<String, dynamic>? resumenCxC;
      try {
        resumenCxC = await _repo.resumenCuentasPorCobrar(sid);
        fiados = await _repo.cuentasPorCobrar(
          sid,
          incluirPagadas: _verHistorialFiados,
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(mensajeErrorHttp(e, contexto: 'fiados'))),
          );
        }
      }
      if (caja != null) {
        movs = await _repo.movimientos(caja['id'] as String);
        if (caja['arqueo_ciego'] != true) {
          _montoCierre.text = '${caja['saldo_sistema'] ?? 0}';
        } else {
          _montoCierre.clear();
        }
      }
      if (mounted) {
        setState(() {
          _caja = caja;
          _movimientos = movs.length > 80 ? movs.take(80).toList() : movs;
          _fiados = fiados;
          _resumenCxC = resumenCxC;
          _cargando = false;
        });
        ref.read(operacionSucursalProvider.notifier).publicarCaja(caja);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = mensajeErrorHttp(e, contexto: 'caja');
          _cargando = false;
        });
      }
    }
  }

  Future<void> _abrir() async {
    final sid = widget.sucursalId!;
    final monto =
        double.tryParse(_montoApertura.text.replaceAll(',', '.')) ?? 0;
    try {
      await _repo.abrir(
        sucursalId: sid,
        montoInicial: monto,
        arqueoCiego: widget.permitirArqueoCiego ? _arqueoCiego : false,
      );
      await _cargar();
      widget.onCajaEstadoCambiado?.call(true);
      ref.read(operacionSucursalProvider.notifier).invalidarPedidos();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Caja abierta')),
        );
      }
    } catch (e) {
      if (mounted) {
        mostrarErrorSnackBar(context, e, contexto: 'abrir caja');
      }
    }
  }

  Future<void> _cerrar() async {
    final cajaId = _caja!['id'] as String;
    final arqueoCiego = _caja!['arqueo_ciego'] == true;
    final monto = double.tryParse(_montoCierre.text.replaceAll(',', '.')) ?? 0;
    try {
      final res = await _repo.cerrar(
        cajaId: cajaId,
        montoContado: monto,
      );
      if (!mounted) return;
      final diff = (res['diferencia'] as num?)?.toDouble() ?? 0;
      final alertaArqueo = diff.abs() > 5000;
      FoodyDialogo.mostrar<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
              alertaArqueo ? 'Caja cerrada — revisar arqueo' : 'Caja cerrada'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (alertaArqueo)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AnaliticaTokens.alertas.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AnaliticaTokens.alertas),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber, color: AnaliticaTokens.alertas),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Diferencia superior a \$5.000. Informa al administrador.',
                          style: TextStyle(
                            color: AnaliticaTokens.alertas,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Text(
                arqueoCiego
                    ? 'Contado: ${_moneda.format(res['monto_final_contado'])}\n'
                        'Diferencia: ${_moneda.format(res['diferencia'])}\n'
                        '(Arqueo ciego — saldo sistema oculto)'
                    : 'Sistema: ${_moneda.format(res['monto_final_sistema'])}\n'
                        'Contado: ${_moneda.format(res['monto_final_contado'])}\n'
                        'Diferencia: ${_moneda.format(res['diferencia'])}\n'
                        'Propinas turno: ${_moneda.format(res['propinas_turno'] ?? 0)}',
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Entendido')),
          ],
        ),
      );
      await _cargar();
      widget.onCajaEstadoCambiado?.call(false);
      ref.read(operacionSucursalProvider.notifier).invalidarPedidos();
    } catch (e) {
      if (mounted) {
        mostrarErrorSnackBar(context, e, contexto: 'cerrar caja');
      }
    }
  }

  Future<void> _nuevoFiado() async {
    final sid = widget.sucursalId!;
    final nombre = TextEditingController();
    final tel = TextEditingController();
    final monto = TextEditingController();
    final formulario = GlobalKey<FormState>();
    final ok = await FoodyDialogo.mostrar<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: const Text('Registrar fiado'),
        content: Form(
            key: formulario,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: nombre,
                  decoration: const InputDecoration(labelText: 'Cliente'),
                  validator: (valor) => (valor?.trim().isEmpty ?? true)
                      ? 'Escribe el nombre del cliente'
                      : null,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: tel,
                  keyboardType: TextInputType.phone,
                  decoration:
                      const InputDecoration(labelText: 'Teléfono (opcional)'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: monto,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Monto', prefixText: r'$ '),
                  validator: (texto) {
                    final valor = double.tryParse(
                        (texto ?? '').trim().replaceAll(',', '.'));
                    return valor == null || !valor.isFinite || valor <= 0
                        ? 'Escribe un monto mayor a cero'
                        : null;
                  },
                ),
              ],
            )),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () {
                if (formulario.currentState?.validate() ?? false) {
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text('Guardar')),
        ],
      ),
    );
    final nombreTxt = nombre.text.trim();
    final telTxt = tel.text.trim();
    final m = double.tryParse(monto.text.replaceAll(',', '.'));
    nombre.dispose();
    tel.dispose();
    monto.dispose();
    if (ok != true || !mounted || m == null || nombreTxt.isEmpty) return;
    try {
      await _repo.crearCuentaPorCobrar(
        sucursalId: sid,
        clienteNombre: nombreTxt,
        clienteTelefono: telTxt.isEmpty ? null : telTxt,
        monto: m,
      );
      await _cargar();
    } catch (e) {
      if (mounted) {
        mostrarErrorSnackBar(context, e, contexto: 'registrar fiado');
      }
    }
  }

  Future<void> _pagarFiado(Map<String, dynamic> cuenta) async {
    var metodo = 'efectivo';
    final ok = await FoodyDialogo.mostrar<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          scrollable: true,
          title: const Text('Cobrar cuenta por cobrar'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${cuenta['cliente_nombre']} · ${_moneda.format(_num(cuenta['monto']))}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: metodo,
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
                  if (v != null) setSt(() => metodo = v);
                },
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
              child: const Text('Confirmar cobro'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await _repo.pagarCuenta(cuenta['id'] as String, metodoPago: metodo);
      await _cargar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cuenta cobrada')),
        );
      }
    } catch (e) {
      if (mounted) {
        mostrarErrorSnackBar(context, e, contexto: 'cobrar fiado');
      }
    }
  }

  Future<void> _gasto() async {
    try {
      await _repo.registrarGasto(
        cajaId: _caja!['id'] as String,
        concepto: _conceptoGasto.text.trim(),
        monto: double.tryParse(_montoGasto.text.replaceAll(',', '.')) ?? 0,
      );
      _conceptoGasto.clear();
      _montoGasto.clear();
      await _cargar();
    } catch (e) {
      if (mounted) {
        mostrarErrorSnackBar(context, e, contexto: 'registrar gasto');
      }
    }
  }

  Future<void> _devolucion() async {
    final monto =
        double.tryParse(_montoDevolucion.text.replaceAll(',', '.')) ?? 0;
    final motivo = _motivoDevolucion.text.trim();
    if (monto < 0.01 || motivo.length < 3) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Indica monto y motivo (mín. 3 caracteres)'),
          ),
        );
      }
      return;
    }

    final confirmar = await FoodyDialogo.mostrar<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Devolver efectivo'),
        content: Text(
          'Vas a registrar una devolución de ${_moneda.format(monto)} de una venta cobrada en este turno.\n\n'
          'Motivo: $motivo',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Registrar devolución'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    final sid = widget.sucursalId!;
    try {
      await _repo.registrarDevolucion(
        cajaId: _caja!['id'] as String,
        sucursalId: sid,
        monto: monto,
        motivo: motivo,
      );
      _montoDevolucion.clear();
      _motivoDevolucion.clear();
      await _cargar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Devolución registrada')),
        );
      }
    } catch (e) {
      if (mounted) {
        mostrarErrorSnackBar(context, e, contexto: 'registrar devolución');
      }
    }
  }

  Future<void> _retiroParcial() async {
    try {
      await _repo.retiro(
        cajaId: _caja!['id'] as String,
        monto: double.tryParse(_montoRetiro.text.replaceAll(',', '.')) ?? 0,
        descripcion: 'Retiro parcial',
      );
      _montoRetiro.clear();
      await _cargar();
    } catch (e) {
      if (mounted) {
        mostrarErrorSnackBar(context, e, contexto: 'retiro parcial');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canvas = AnaliticaTokens.canvasOf(context);
    if (_cargando) {
      return ColoredBox(
        color: canvas,
        child: AnaliticaSkeleton.tab(),
      );
    }
    if (_error != null) {
      return ColoredBox(
        color: canvas,
        child: FoodyEstadoUi.errorUi(
          mensaje: _error!,
          onReintentar: _cargar,
        ),
      );
    }

    if (_caja == null) {
      return ColoredBox(
        color: canvas,
        child: _pantallaApertura(),
      );
    }

    final ancho = FoodyBreakpoints.widthOf(context);
    final compacto = FoodyBreakpoints.esCompact(ancho);

    final contenido = LayoutBuilder(
      builder: (context, constraints) {
        final dosColumnas = constraints.maxWidth >= FoodyBreakpoints.large;
        return RefreshIndicator(
          onRefresh: _cargar,
          child: dosColumnas
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _panelPrincipalCaja()),
                    SizedBox(
                      width: 320,
                      child: _panelLateralCaja(scrollPropio: true),
                    ),
                  ],
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    _metricasCaja(),
                    const SizedBox(height: 12),
                    _panelLateralCaja(scrollPropio: false),
                    const SizedBox(height: 16),
                    _listaMovimientos(),
                  ],
                ),
        );
      },
    );

    // NAV-CJ-01: shell cajero ya trae AppBar — sin NestedScrollView de cabecera.
    if (widget.ocultarCabecera) {
      return ColoredBox(
        color: canvas,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: 'Actualizar',
                onPressed: _cargar,
                icon: Icon(
                  Icons.refresh,
                  color: AnaliticaTokens.inkMutedOf(context),
                ),
              ),
            ),
            Expanded(child: contenido),
          ],
        ),
      );
    }

    return ColoredBox(
      color: canvas,
      child: SaasScrollableShell(
        header: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              compacto ? 12 : 16,
              8,
              compacto ? 12 : 16,
              4,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Admin / Operación',
                        style: TextStyle(
                          fontSize: 11,
                          color: AnaliticaTokens.inkMutedOf(context),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Caja',
                        style: TextStyle(
                          fontSize: compacto ? 18 : 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                          color: AnaliticaTokens.inkOf(context),
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_movimientos.length} movimientos · turno abierto',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AnaliticaTokens.inkMutedOf(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(top: 4, right: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AnaliticaTokens.inventario.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AnaliticaTokens.inventario.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 14,
                        color: AnaliticaTokens.inventario,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Turno activo',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AnaliticaTokens.inventario,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Actualizar',
                  onPressed: _cargar,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.refresh,
                    color: AnaliticaTokens.inkMutedOf(context),
                  ),
                ),
              ],
            ),
          ),
        ],
        body: contenido,
      ),
    );
  }

  BoxDecoration _decoTarjeta() {
    return BoxDecoration(
      color: AnaliticaTokens.surfaceOf(context),
      borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
      border: Border.all(color: AnaliticaTokens.borderOf(context)),
    );
  }

  Widget _panelPrincipalCaja() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        _metricasCaja(),
        const SizedBox(height: 12),
        _listaMovimientos(),
      ],
    );
  }

  Widget _metricasCaja() {
    final ventas = _num(_caja!['total_ventas']);
    final gastos = _num(_caja!['total_gastos']);
    final saldo = _num(_caja!['saldo_sistema']);
    final ciego = _caja!['arqueo_ciego'] == true;
    final horas = _num(_caja!['horas_abierta']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (horas >= 12) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AnaliticaTokens.alertas.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Turno abierto ${horas.toStringAsFixed(1)} h. Cierra caja o haz arqueo.',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AnaliticaTokens.alertas,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(
              child: OperacionMetricCard(
                etiqueta: 'Saldo sistema',
                valor: ciego ? '—' : _moneda.format(saldo),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OperacionMetricCard(
                etiqueta: 'Ventas',
                valor: _moneda.format(ventas),
                colorValor: AnaliticaTokens.inventario,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OperacionMetricCard(
                etiqueta: 'Gastos',
                valor: _moneda.format(gastos),
                colorValor: AnaliticaTokens.alertas,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _listaMovimientos() {
    return Container(
      decoration: _decoTarjeta(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Text(
                  'Movimientos',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _scheme.onSurface,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_movimientos.length} registros',
                  style: TextStyle(
                    fontSize: 11,
                    color: _scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: _scheme.outlineVariant),
          if (_movimientos.isEmpty)
            Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Sin movimientos aún',
                  style: TextStyle(color: _scheme.onSurfaceVariant),
                ),
              ),
            )
          else
            ConstrainedBox(
              // PERF-FL-LIST-07: evita ListView shrinkWrap unbounded en scroll padre.
              constraints: const BoxConstraints(maxHeight: 420),
              child: ListView.separated(
                itemCount: _movimientos.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: _scheme.outlineVariant),
                itemBuilder: (_, i) => _filaMovimiento(_movimientos[i]),
              ),
            ),
          // PERF-FL-MEM-06: la lista en memoria ya está topeada a 80 al cargar.
        ],
      ),
    );
  }

  Widget _panelLateralCaja({bool scrollPropio = true}) {
    final kids = <Widget>[
      _seccionFiados(),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: _decoTarjeta(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Registrar gasto',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: _scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _conceptoGasto,
              decoration: InputDecoration(
                hintText: 'Concepto',
                filled: true,
                fillColor: _scheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide.none,
                ),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _montoGasto,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Monto',
                filled: true,
                fillColor: _scheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide.none,
                ),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _gasto,
              style: FilledButton.styleFrom(
                  backgroundColor: _scheme.primary,
                  foregroundColor: _scheme.onPrimary),
              child: const Text('Guardar gasto'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: _decoTarjeta(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Retiro parcial',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: _scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _montoRetiro,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Monto retiro',
                filled: true,
                fillColor: _scheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide.none,
                ),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _retiroParcial,
              child: const Text('Registrar retiro'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: _decoTarjeta(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Devolución',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: _scheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Solo efectivo ya cobrado en este turno. Cancelar pedido no cobrado no requiere esto.',
              style: TextStyle(fontSize: 11, color: _scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _montoDevolucion,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Monto',
                filled: true,
                fillColor: _scheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide.none,
                ),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _motivoDevolucion,
              decoration: InputDecoration(
                hintText: 'Motivo',
                filled: true,
                fillColor: _scheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide.none,
                ),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _devolucion,
              style: FilledButton.styleFrom(
                  backgroundColor: AnaliticaTokens.inventario),
              child: const Text('Registrar devolución'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: _decoTarjeta(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Cerrar turno',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: _scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _montoCierre,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Monto contado',
                prefixText: r'$ ',
                filled: true,
                fillColor: _scheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide.none,
                ),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Material(
              color: AnaliticaTokens.alertas.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: _cerrar,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AnaliticaTokens.alertas.withValues(alpha: 0.35),
                    ),
                  ),
                  child: const Text(
                    'Cerrar caja',
                    style: TextStyle(
                      color: AnaliticaTokens.alertas,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ];
    if (!scrollPropio) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: kids,
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 0, 16, 16),
      children: kids,
    );
  }

  Widget _filaMovimiento(Map<String, dynamic> m) {
    final tipo = m['tipo'] as String? ?? '';
    final monto = _num(m['monto']);
    final metodo = m['metodo_pago'] as String?;
    final responsable = m['responsable'] as String?;
    final pedidoId = m['pedido_id']?.toString();
    final esNeg = tipo == 'gasto' || tipo == 'retiro';
    final iconData = _iconoTipo(tipo);
    final iconBg = tipo == 'venta'
        ? AnaliticaTokens.inventario.withValues(alpha: 0.12)
        : tipo == 'gasto'
            ? AnaliticaTokens.alertas.withValues(alpha: 0.12)
            : const Color(0xFFD97706).withValues(alpha: 0.12);
    final iconColor = tipo == 'venta'
        ? AnaliticaTokens.inventario
        : tipo == 'gasto'
            ? AnaliticaTokens.alertas
            : const Color(0xFFD97706);

    return InkWell(
      onTap: pedidoId != null &&
              pedidoId.isNotEmpty &&
              pedidoId != 'null' &&
              widget.onIrPedido != null
          ? () => widget.onIrPedido!(pedidoId)
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(iconData, size: 16, color: iconColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tipo,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    m['descripcion'] as String? ?? '',
                    style: TextStyle(
                        fontSize: 11, color: _scheme.onSurfaceVariant),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (responsable != null && responsable.isNotEmpty ||
                      metodo != null && metodo.isNotEmpty)
                    Text(
                      [
                        if (responsable != null && responsable.isNotEmpty)
                          responsable,
                        if (metodo != null && metodo.isNotEmpty) metodo,
                      ].join(' · '),
                      style: TextStyle(
                        fontSize: 10,
                        color: _scheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (pedidoId != null &&
                pedidoId.isNotEmpty &&
                pedidoId != 'null' &&
                widget.onIrPedido != null)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(
                  Icons.receipt_long_outlined,
                  size: 16,
                  color: _scheme.onSurfaceVariant,
                ),
              ),
            Text(
              _moneda.format(monto),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: esNeg
                    ? AnaliticaTokens.alertas
                    : AnaliticaTokens.inventario,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pantallaApertura() {
    final compacto = FoodyBreakpoints.esCompact(
      FoodyBreakpoints.widthOf(context),
    );
    return ListView(
      padding: EdgeInsets.fromLTRB(
        compacto ? 12 : 20,
        8,
        compacto ? 12 : 20,
        32,
      ),
      children: [
        if (!widget.ocultarCabecera) ...[
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
            'Caja',
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
            'Sin turno abierto · indica el efectivo inicial',
            style: TextStyle(
              fontSize: 12.5,
              color: _scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
        ],
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: _decoTarjeta(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.point_of_sale,
                      size: 26,
                      color: _scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Abrir turno de caja',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _scheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Indica el monto inicial en efectivo para comenzar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: _scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (widget.permitirArqueoCiego)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Arqueo ciego',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: _scheme.onSurface,
                        ),
                      ),
                      subtitle: Text(
                        'El cajero no verá el saldo del sistema',
                        style: TextStyle(
                          fontSize: 12,
                          color: _scheme.onSurfaceVariant,
                        ),
                      ),
                      activeTrackColor: _scheme.primary,
                      value: _arqueoCiego,
                      onChanged: (v) => setState(() => _arqueoCiego = v),
                    ),
                  if (widget.permitirArqueoCiego) const SizedBox(height: 8),
                  TextField(
                    controller: _montoApertura,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: _scheme.onSurface),
                    decoration: InputDecoration(
                      labelText: 'Monto inicial',
                      labelStyle: TextStyle(
                        color: _scheme.onSurfaceVariant,
                      ),
                      prefixText: r'$ ',
                      filled: true,
                      fillColor: _scheme.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: _scheme.outlineVariant,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: _scheme.outlineVariant,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: _scheme.onSurface,
                          width: 1.2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: _abrir,
                    style: FilledButton.styleFrom(
                      backgroundColor: _scheme.primary,
                      foregroundColor: _scheme.onPrimary,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text('Abrir caja'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  double _num(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

  Widget _seccionFiados() {
    final resumen = _resumenCxC;
    final lista = _verHistorialFiados
        ? _fiados
        : _fiados.where((f) => f['estado'] == 'pendiente').toList();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _decoTarjeta(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Cuentas por cobrar',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: _scheme.onSurface,
                  ),
                ),
              ),
              IconButton(
                onPressed: _nuevoFiado,
                tooltip: 'Registrar fiado',
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.add, color: _scheme.onSurfaceVariant),
              ),
            ],
          ),
          if (resumen != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AnaliticaTokens.inventario.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AnaliticaTokens.inventario.withValues(alpha: 0.25),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Pendiente: ${_moneda.format(_num(resumen['total_pendiente']))}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _scheme.onSurface,
                    ),
                  ),
                  Text(
                    '${resumen['cantidad_pendiente'] ?? 0} cuenta(s)',
                    style: TextStyle(
                      fontSize: 12,
                      color: _scheme.onSurfaceVariant,
                    ),
                  ),
                  if ((_num(resumen['antiguas_7d'])) > 0) ...[
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Chip(
                        label: Text(
                          '${resumen['antiguas_7d']} +7 días',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AnaliticaTokens.alertas,
                          ),
                        ),
                        backgroundColor:
                            AnaliticaTokens.alertas.withValues(alpha: 0.12),
                        side: BorderSide(
                          color: AnaliticaTokens.alertas.withValues(alpha: 0.3),
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              ChoiceChip(
                label: const Text('Pendientes'),
                selected: !_verHistorialFiados,
                selectedColor: _scheme.primary,
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: !_verHistorialFiados
                      ? _scheme.onPrimary
                      : _scheme.onSurfaceVariant,
                ),
                side: BorderSide(
                  color: !_verHistorialFiados
                      ? _scheme.onSurface
                      : _scheme.outlineVariant,
                ),
                onSelected: (_) {
                  setState(() => _verHistorialFiados = false);
                  _cargar(silencioso: true);
                },
              ),
              ChoiceChip(
                label: const Text('Historial'),
                selected: _verHistorialFiados,
                selectedColor: _scheme.primary,
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _verHistorialFiados
                      ? _scheme.onPrimary
                      : _scheme.onSurfaceVariant,
                ),
                side: BorderSide(
                  color: _verHistorialFiados
                      ? _scheme.onSurface
                      : _scheme.outlineVariant,
                ),
                onSelected: (_) {
                  setState(() => _verHistorialFiados = true);
                  _cargar(silencioso: true);
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (lista.isEmpty)
            Text(
              _verHistorialFiados
                  ? 'Sin cuentas registradas'
                  : 'Sin cuentas pendientes',
              style: TextStyle(color: _scheme.onSurfaceVariant),
            ),
          for (final f in lista)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      f['cliente_nombre'] as String? ?? '',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _scheme.onSurface,
                      ),
                    ),
                  ),
                  if (f['estado'] == 'pagada')
                    Chip(
                      label: const Text(
                        'Pagada',
                        style: TextStyle(
                          fontSize: 10,
                          color: AnaliticaTokens.inventario,
                        ),
                      ),
                      backgroundColor:
                          AnaliticaTokens.inventario.withValues(alpha: 0.12),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    ),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    [
                      _moneda.format(_num(f['monto'])),
                      if (f['numero_pedido'] != null)
                        'Pedido #${f['numero_pedido']}',
                      if (f['creada_por'] != null &&
                          '${f['creada_por']}'.isNotEmpty)
                        'Registró: ${f['creada_por']}',
                      if (f['estado'] == 'pagada' &&
                          f['pagada_por'] != null &&
                          '${f['pagada_por']}'.isNotEmpty)
                        'Cobró: ${f['pagada_por']}',
                      if (f['estado'] == 'pendiente' &&
                          (f['dias_pendiente'] as num? ?? 0) > 0)
                        '${f['dias_pendiente']} días pendiente',
                      if (f['cliente_telefono'] != null &&
                          '${f['cliente_telefono']}'.isNotEmpty)
                        '${f['cliente_telefono']}',
                    ].where((s) => s.isNotEmpty).join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: f['alerta_antigua'] == true
                          ? AnaliticaTokens.alertas
                          : _scheme.onSurfaceVariant,
                    ),
                  ),
                  if (f['estado'] == 'pendiente') ...[
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton(
                        onPressed: () => _pagarFiado(f),
                        style: FilledButton.styleFrom(
                          backgroundColor: _scheme.primary,
                          foregroundColor: _scheme.onPrimary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Cobrar'),
                      ),
                    ),
                  ],
                ],
              ),
              isThreeLine: f['estado'] == 'pendiente',
            ),
        ],
      ),
    );
  }

  IconData _iconoTipo(String tipo) {
    switch (tipo) {
      case 'venta':
        return Icons.payments;
      case 'gasto':
        return Icons.money_off;
      case 'retiro':
        return Icons.savings;
      case 'apertura':
        return Icons.lock_open;
      default:
        return Icons.receipt;
    }
  }
}
