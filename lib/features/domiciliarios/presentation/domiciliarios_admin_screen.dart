import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:reserva_canchas/core/layout/foody_breakpoints.dart';
import 'package:reserva_canchas/core/realtime/foody_realtime.dart';
import 'package:reserva_canchas/core/realtime/poll_realtime_respaldo.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';
import 'package:reserva_canchas/core/saas_ui/saas_ui.dart';
import 'package:reserva_canchas/core/widgets/foody_dialogo.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_skeleton.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_tokens.dart';
import 'package:reserva_canchas/features/domiciliarios/data/domiciliarios_repository.dart';
import 'package:reserva_canchas/features/usuarios/data/usuarios_repository.dart';
import 'package:reserva_canchas/services/app_backend.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Domiciliarios de planta + fiado/caja + guía independientes.
///
/// UX: KPIs arriba; config (fiado/caja) separada de operación (liquidar / equipo);
/// escritorio dual; diálogo crear con controllers propios.
class DomiciliariosAdminScreen extends StatefulWidget {
  const DomiciliariosAdminScreen({
    super.key,
    this.sucursalId,
    this.onIrPedidosDomicilio,
    this.repository,
  });

  final String? sucursalId;
  final VoidCallback? onIrPedidosDomicilio;
  final DomiciliariosRepository? repository;

  @override
  State<DomiciliariosAdminScreen> createState() =>
      _DomiciliariosAdminScreenState();
}

class _DomiciliariosAdminScreenState extends State<DomiciliariosAdminScreen> {
  ColorScheme get _scheme => Theme.of(context).colorScheme;

  late final DomiciliariosRepository _repo;
  final _usuariosRepo = UsuariosRepository();
  List<Map<String, dynamic>> _domiciliarios = [];
  List<Map<String, dynamic>> _comisiones = [];
  List<Map<String, dynamic>> _liquidaciones = [];
  List<Map<String, dynamic>> _domicilios = [];
  bool _permiteFiado = false;
  bool _domicilioEnCaja = false;
  bool _cargando = true;
  bool _datosInicialesCargados = false;
  bool _cargandoComisiones = false;
  bool _cargandoLiquidacion = false;
  bool _cargandoResumenDomicilios = false;
  String? _error;
  String? _errorActualizacion;
  String? _errorComisiones;
  String? _errorLiquidacion;
  String? _errorResumenDomicilios;
  RealtimeChannel? _canalRt;
  PollRealtimeRespaldo? _pollRespaldo;

  final _formato = NumberFormat.currency(
    locale: 'es_CO',
    symbol: r'$',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? DomiciliariosRepository();
    _cargar();
    _cargarComisiones();
    _cargarLiquidacion();
    _suscribirRealtime();
    _pollRespaldo = PollRealtimeRespaldo(onActualizar: () async {
      if (mounted) {
        await _cargar();
        await _cargarLiquidacion();
      }
    });
    unawaited(_pollRespaldo!.iniciar());
  }

  @override
  void dispose() {
    FoodyRealtime.liberarCanal(_canalRt);
    _pollRespaldo?.detener();
    super.dispose();
  }

  void _suscribirRealtime() {
    final sid = widget.sucursalId;
    if (sid == null || !AppBackend.supabaseReady) return;
    _canalRt = FoodyRealtime.suscribirSucursal(
      sid,
      onEvento: (evento) {
        if (evento == 'pedido_actualizado' ||
            evento == eventoSucursalCoalesced) {
          _cargar();
          _cargarLiquidacion();
        }
      },
    );
  }

  void _avisar(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? AnaliticaTokens.alertas : _scheme.onSurface,
      ),
    );
  }

  num _numero(dynamic valor) =>
      valor is num ? valor : num.tryParse('$valor') ?? 0;

  Future<void> _cargarLiquidacion() async {
    final sid = widget.sucursalId;
    if (sid == null) return;
    await Future.wait([
      _cargarResumenLiquidacion(sid),
      _cargarResumenDomicilios(sid),
    ]);
  }

  Future<void> _cargarResumenLiquidacion(String sucursalId) async {
    setState(() {
      _cargandoLiquidacion = true;
      _errorLiquidacion = null;
    });
    try {
      final data = await _repo.resumenLiquidacion(sucursalId);
      if (!mounted) return;
      setState(() {
        _permiteFiado = data['permite_fiado_domiciliario'] == true;
        _liquidaciones = (data['domiciliarios'] as List<dynamic>? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map<String, dynamic>))
            .toList();
        _cargandoLiquidacion = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargandoLiquidacion = false;
        _errorLiquidacion = mensajeErrorHttp(e, contexto: 'fiados de planta');
      });
    }
  }

  Future<void> _cargarResumenDomicilios(String sucursalId) async {
    setState(() {
      _cargandoResumenDomicilios = true;
      _errorResumenDomicilios = null;
    });
    try {
      final data = await _repo.resumenDomicilios(sucursalId);
      if (!mounted) return;
      setState(() {
        _domicilioEnCaja = data['domicilio_ingresa_a_caja'] == true;
        _domicilios = (data['domiciliarios'] as List<dynamic>? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map<String, dynamic>))
            .toList();
        _cargandoResumenDomicilios = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargandoResumenDomicilios = false;
        _errorResumenDomicilios =
            mensajeErrorHttp(e, contexto: 'resumen de entregas');
      });
    }
  }

  Future<void> _toggleDomicilioCaja(bool ingresa) async {
    final sid = widget.sucursalId;
    if (sid == null) return;
    setState(() => _domicilioEnCaja = ingresa);
    try {
      final aplicado = await _repo.configurarDomicilioEnCaja(
        sucursalId: sid,
        ingresa: ingresa,
      );
      if (mounted) setState(() => _domicilioEnCaja = aplicado);
    } catch (e) {
      if (mounted) {
        setState(() => _domicilioEnCaja = !ingresa);
        _avisar(mensajeErrorHttp(e, contexto: 'config domicilio'), error: true);
      }
    }
  }

  Future<void> _toggleFiado(bool permitir) async {
    final sid = widget.sucursalId;
    if (sid == null) return;
    setState(() => _permiteFiado = permitir);
    try {
      final aplicado = await _repo.configurarFiadoDomiciliario(
        sucursalId: sid,
        permitir: permitir,
      );
      if (mounted) setState(() => _permiteFiado = aplicado);
    } catch (e) {
      if (mounted) {
        setState(() => _permiteFiado = !permitir);
        _avisar(mensajeErrorHttp(e, contexto: 'config fiado'), error: true);
      }
    }
  }

  Future<void> _liquidar(Map<String, dynamic> domi) async {
    final sid = widget.sucursalId;
    if (sid == null) return;
    final nombre = domi['nombre']?.toString() ?? 'Domiciliario';
    final total = _numero(domi['total_pendiente']);
    final confirmar = await FoodyDialogo.mostrar<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Liquidar a $nombre'),
        content: Text(
          'Se registrará en caja ${_formato.format(total)} en efectivo '
          '(${domi['pedidos'] ?? 0} domicilios). ¿Confirmas que recibiste el dinero?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Liquidar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      final r = await _repo.liquidarDomiciliario(
        domiciliarioPlantaId: domi['domiciliario_planta_id'] as String,
        sucursalId: sid,
      );
      await _cargarLiquidacion();
      await _cargarComisiones();
      if (mounted) {
        _avisar(
          'Liquidado: ${r['liquidados']} domicilios · '
          '${_formato.format(_numero(r['total']))}',
        );
      }
    } catch (e) {
      _avisar(mensajeErrorHttp(e, contexto: 'liquidar'), error: true);
    }
  }

  Future<void> _cargarComisiones() async {
    final sid = widget.sucursalId;
    if (sid == null) return;
    setState(() {
      _cargandoComisiones = true;
      _errorComisiones = null;
    });
    try {
      final lista = await _repo.resumenComisionesIndependientes(sid);
      if (!mounted) return;
      setState(() {
        _comisiones = lista;
        _cargandoComisiones = false;
        _errorComisiones = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _cargandoComisiones = false;
          _errorComisiones =
              mensajeErrorHttp(e, contexto: 'resumen de independientes');
        });
      }
    }
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
      _cargando = !_datosInicialesCargados;
      _error = null;
      _errorActualizacion = null;
    });
    try {
      final lista = await _repo.listarDisponibles(sid);
      if (!mounted) return;
      setState(() {
        _domiciliarios = lista;
        _datosInicialesCargados = true;
        _cargando = false;
        _errorActualizacion = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        final mensaje = mensajeErrorHttp(e, contexto: 'domiciliarios');
        if (_datosInicialesCargados) {
          _errorActualizacion = mensaje;
        } else {
          _error = mensaje;
        }
        _cargando = false;
      });
    }
  }

  Future<void> _refrescarTodo() async {
    await Future.wait([
      _cargar(),
      _cargarComisiones(),
      _cargarLiquidacion(),
    ]);
  }

  Future<void> _agregarDomiciliarioPlanta() async {
    final sid = widget.sucursalId;
    if (sid == null) return;

    final datos = await FoodyDialogo.mostrar<_DatosNuevoPlanta>(
      context: context,
      builder: (ctx) => const _DialogoNuevoPlanta(),
    );
    if (datos == null) return;

    if (datos.pass.length < 6) {
      _avisar('La contraseña debe tener al menos 6 caracteres', error: true);
      return;
    }

    try {
      await _usuariosRepo.crear(
        sucursalId: sid,
        nombre: datos.nombre,
        email: datos.email,
        contrasena: datos.pass,
        rol: 'domiciliario_planta',
      );
      await _cargar();
      _avisar(
        'Domiciliario ${datos.nombre} creado. Ya puede iniciar sesión como staff.',
      );
    } catch (err) {
      _avisar(
        mensajeErrorHttp(err, contexto: 'crear domiciliario'),
        error: true,
      );
    }
  }

  void _copiarEnlaceRegistro() {
    final uri = Uri.base.replace(path: '/domiciliario/registro');
    Clipboard.setData(ClipboardData(text: uri.toString()));
    _avisar('Enlace de registro copiado');
  }

  int get _enRuta => _domiciliarios.where((d) => d['ocupado'] == true).length;

  int get _disponibles =>
      _domiciliarios.where((d) => d['ocupado'] != true).length;

  num get _totalPendienteLiquidar => _liquidaciones.fold<num>(
        0,
        (s, d) => s + _numero(d['total_pendiente']),
      );

  num get _totalPayoutIndep => _comisiones.fold<num>(
        0,
        (s, c) => s + _numero(c['por_pagar']),
      );

  @override
  Widget build(BuildContext context) {
    final ancho = FoodyBreakpoints.widthOf(context);
    final compacto = FoodyBreakpoints.esCompact(ancho);
    final dual = ancho >= 980;

    return ColoredBox(
      color: _scheme.surface,
      child: SaasScrollableShell(
        header: [
          _header(compacto),
        ],
        body: _cargando
            ? AnaliticaSkeleton.tab()
            : _error != null
                ? _estadoError()
                : RefreshIndicator(
                    onRefresh: _refrescarTodo,
                    color: _scheme.onSurface,
                    child:
                        dual ? _layoutDual(compacto) : _layoutApilado(compacto),
                  ),
      ),
    );
  }

  Widget _header(bool compacto) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        compacto ? 12 : 20,
        8,
        compacto ? 12 : 20,
        8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Admin / Domicilio',
            style: TextStyle(
              fontSize: 11,
              color: _scheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Repartidores',
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
                      _cargando
                          ? 'Cargando…'
                          : '${_domiciliarios.length} de planta · '
                              '$_disponibles libres · $_enRuta en ruta',
                      style: TextStyle(
                        color: _scheme.onSurfaceVariant,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.onIrPedidosDomicilio != null)
                TextButton(
                  onPressed: widget.onIrPedidosDomicilio,
                  style: TextButton.styleFrom(
                    foregroundColor: _scheme.onSurfaceVariant,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text(compacto ? 'Pedidos' : 'Pedidos domicilio'),
                ),
              FilledButton.icon(
                onPressed: _agregarDomiciliarioPlanta,
                style: FilledButton.styleFrom(
                  backgroundColor: _scheme.primary,
                  foregroundColor: _scheme.onPrimary,
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.person_add_outlined, size: 18),
                label: Text(compacto ? 'Planta' : 'Agregar planta'),
              ),
              IconButton(
                tooltip: 'Actualizar',
                onPressed: _refrescarTodo,
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.refresh,
                  color: _scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (!_cargando && _error == null) ...[
            const SizedBox(height: 12),
            _kpis(compacto),
          ],
        ],
      ),
    );
  }

  Widget _kpis(bool compacto) {
    final items = [
      _Kpi(
        'Disponibles',
        '$_disponibles',
        AnaliticaTokens.inventario,
        Icons.check_circle_outline,
      ),
      _Kpi(
        'En ruta',
        '$_enRuta',
        const Color(0xFFD97706),
        Icons.route_outlined,
      ),
      _Kpi(
        'Fiado por cobrar',
        _cargandoLiquidacion || _errorLiquidacion != null
            ? '—'
            : _formato.format(_totalPendienteLiquidar),
        _totalPendienteLiquidar > 0
            ? AnaliticaTokens.alertas
            : _scheme.onSurfaceVariant,
        Icons.account_balance_wallet_outlined,
      ),
      _Kpi(
        'Ganancias estimadas',
        _cargandoComisiones || _errorComisiones != null
            ? '—'
            : _formato.format(_totalPayoutIndep),
        _scheme.onSurface,
        Icons.payments_outlined,
      ),
    ];

    if (compacto) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final k in items)
            SizedBox(
                width: (FoodyBreakpoints.widthOf(context) - 40) / 2,
                child: _kpiCard(k)),
        ],
      );
    }

    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: _kpiCard(items[i])),
        ],
      ],
    );
  }

  Widget _kpiCard(_Kpi k) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: _scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _scheme.outlineVariant),
        boxShadow: AnaliticaTokens.shadowSoft,
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: k.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(k.icon, size: 16, color: k.color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  k.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _scheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  k.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: _scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _layoutDual(bool compacto) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 5,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 10, 32),
            children: [
              if (_errorActualizacion != null) ...[
                _estadoInlineError(_errorActualizacion!, _cargar),
                const SizedBox(height: 8),
              ],
              _seccionConfig(),
              const SizedBox(height: 12),
              _seccionLiquidar(),
              const SizedBox(height: 12),
              _seccionDomiciliosResumen(),
              const SizedBox(height: 12),
              _seccionIndependientes(),
              const SizedBox(height: 12),
              _seccionPayout(),
            ],
          ),
        ),
        Expanded(
          flex: 4,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(10, 4, 20, 32),
            children: [
              _encabezadoEquipo(),
              const SizedBox(height: 10),
              if (_domiciliarios.isEmpty)
                _vacioPlanta()
              else
                ..._domiciliarios.map(_tarjetaPlanta),
            ],
          ),
        ),
      ],
    );
  }

  Widget _layoutApilado(bool compacto) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        compacto ? 12 : 20,
        4,
        compacto ? 12 : 20,
        32,
      ),
      children: [
        if (_errorActualizacion != null) ...[
          _estadoInlineError(_errorActualizacion!, _cargar),
          const SizedBox(height: 8),
        ],
        if (_totalPendienteLiquidar > 0) ...[
          _seccionLiquidar(),
          const SizedBox(height: 12),
        ],
        _encabezadoEquipo(),
        const SizedBox(height: 10),
        if (_domiciliarios.isEmpty)
          _vacioPlanta()
        else
          ..._domiciliarios.map(_tarjetaPlanta),
        const SizedBox(height: 16),
        _seccionConfig(),
        const SizedBox(height: 12),
        if (_totalPendienteLiquidar == 0) ...[
          _seccionLiquidar(),
          const SizedBox(height: 12),
        ],
        _seccionDomiciliosResumen(),
        const SizedBox(height: 12),
        _seccionIndependientes(),
        const SizedBox(height: 12),
        _seccionPayout(),
      ],
    );
  }

  Widget _estadoError() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 48, 20, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
            border: Border.all(color: _scheme.outlineVariant),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.error_outline,
                size: 36,
                color: AnaliticaTokens.alertas,
              ),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  color: _scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
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
      ],
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: _scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
        border: Border.all(color: _scheme.outlineVariant),
        boxShadow: AnaliticaTokens.shadowSoft,
      ),
      padding: const EdgeInsets.all(14),
      child: child,
    );
  }

  Widget _tituloSeccion(String titulo, {Widget? trailing}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            titulo,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: _scheme.onSurface,
            ),
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _seccionConfig() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _tituloSeccion(
            'Reglas de cobro',
            trailing: _cargandoLiquidacion || _cargandoResumenDomicilios
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
          ),
          const SizedBox(height: 4),
          Text(
            'Cómo se maneja el dinero del domicilio en esta sede.',
            style: TextStyle(
              fontSize: 12.5,
              color: _scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          if (_cargandoLiquidacion)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_errorLiquidacion != null)
            _estadoInlineError(
              _errorLiquidacion!,
              () => _cargarResumenLiquidacion(widget.sucursalId!),
            )
          else
            _toggleFila(
              titulo: 'Permitir fiado',
              detalle:
                  'El repartidor puede llevar pedidos y liquidar el efectivo al volver.',
              value: _permiteFiado,
              onChanged: _toggleFiado,
            ),
          Divider(height: 20, color: _scheme.outlineVariant),
          if (_cargandoResumenDomicilios)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_errorResumenDomicilios != null)
            _estadoInlineError(
              _errorResumenDomicilios!,
              () => _cargarResumenDomicilios(widget.sucursalId!),
            )
          else
            _toggleFila(
              titulo: 'Domicilio entra a caja',
              detalle: _domicilioEnCaja
                  ? 'El costo de domicilio suma a ingresos del restaurante.'
                  : 'Solo el producto entra a caja; el domicilio va por repartidor.',
              value: _domicilioEnCaja,
              onChanged: _toggleDomicilioCaja,
            ),
        ],
      ),
    );
  }

  Widget _toggleFila({
    required String titulo,
    required String detalle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: _scheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                detalle,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.35,
                  color: _scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Switch.adaptive(
          value: value,
          activeTrackColor: _scheme.primary,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _estadoInlineError(String mensaje, VoidCallback reintentar) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.cloud_off_outlined, size: 18, color: _scheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              mensaje,
              style: TextStyle(fontSize: 12.5, color: _scheme.onSurfaceVariant),
            ),
          ),
          TextButton(onPressed: reintentar, child: const Text('Reintentar')),
        ],
      ),
    );
  }

  Widget _seccionLiquidar() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _tituloSeccion(
            'Fiados de planta por cobrar',
            trailing: Text(
              _cargandoLiquidacion || _errorLiquidacion != null
                  ? '—'
                  : _formato.format(_totalPendienteLiquidar),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _totalPendienteLiquidar > 0
                    ? AnaliticaTokens.alertas
                    : _scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (_cargandoLiquidacion)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_errorLiquidacion != null)
            _estadoInlineError(
              _errorLiquidacion!,
              () => _cargarResumenLiquidacion(widget.sucursalId!),
            )
          else if (!_permiteFiado)
            Text(
              'Fiado apagado. Actívalo arriba si quieres que lleven pedidos a crédito.',
              style: TextStyle(
                fontSize: 12.5,
                color: _scheme.onSurfaceVariant,
              ),
            )
          else if (_liquidaciones.isEmpty)
            Text(
              'Nadie debe efectivo a la sede.',
              style: TextStyle(
                fontSize: 12.5,
                color: _scheme.onSurfaceVariant,
              ),
            )
          else
            ..._liquidaciones.map((d) {
              final total = _numero(d['total_pendiente']);
              final nombre = d['nombre']?.toString() ?? 'Domiciliario';
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                  decoration: BoxDecoration(
                    color: _scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _scheme.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nombre,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: _scheme.onSurface,
                              ),
                            ),
                            Text(
                              '${d['pedidos'] ?? 0} domicilios · ${_formato.format(total)}',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: _scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      FilledButton(
                        onPressed: () => _liquidar(d),
                        style: FilledButton.styleFrom(
                          backgroundColor: _scheme.primary,
                          foregroundColor: _scheme.onPrimary,
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text('Liquidar'),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _seccionDomiciliosResumen() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _tituloSeccion('Entregas por repartidor (planta)'),
          const SizedBox(height: 8),
          if (_cargandoResumenDomicilios)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_errorResumenDomicilios != null)
            _estadoInlineError(
              _errorResumenDomicilios!,
              () => _cargarResumenDomicilios(widget.sucursalId!),
            )
          else if (_domicilios.isEmpty)
            Text(
              'Aún no hay domicilios entregados en el resumen.',
              style: TextStyle(
                fontSize: 12.5,
                color: _scheme.onSurfaceVariant,
              ),
            )
          else
            ..._domicilios.map((d) {
              final total = _numero(d['total_domicilios']);
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(
                      Icons.two_wheeler_outlined,
                      size: 18,
                      color: _scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        d['nombre']?.toString() ?? 'Domiciliario',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _scheme.onSurface,
                        ),
                      ),
                    ),
                    Text(
                      '${d['pedidos_entregados'] ?? 0} entregas',
                      style: TextStyle(
                        fontSize: 12,
                        color: _scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _formato.format(total),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _scheme.onSurface,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _seccionIndependientes() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _tituloSeccion('Repartidores independientes'),
          const SizedBox(height: 6),
          Text(
            'Se registran solos en la app. Foody aprueba documentos; '
            'deben iniciar turno para recibir ofertas de esta sede.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: _scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => context.push('/domiciliario/registro'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _scheme.onSurface,
                  side: BorderSide(color: _scheme.outlineVariant),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Ver registro'),
              ),
              OutlinedButton.icon(
                onPressed: _copiarEnlaceRegistro,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _scheme.onSurface,
                  side: BorderSide(color: _scheme.outlineVariant),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.link, size: 16),
                label: const Text('Copiar enlace'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _seccionPayout() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _tituloSeccion(
            'Resumen de independientes',
            trailing: IconButton(
              tooltip: 'Actualizar',
              onPressed: _cargandoComisiones ? null : _cargarComisiones,
              visualDensity: VisualDensity.compact,
              icon: _cargandoComisiones
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh, size: 18),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Estimaciones al aceptar ofertas; pueden incluir pedidos cancelados. Aún no confirman entrega ni pago.',
              style: TextStyle(
                fontSize: 12,
                color: _scheme.onSurfaceVariant,
              ),
            ),
          ),
          if (_cargandoComisiones)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_errorComisiones != null)
            _estadoInlineError(_errorComisiones!, _cargarComisiones)
          else if (_comisiones.isEmpty)
            Text(
              'Sin asignaciones de independientes registradas aún.',
              style: TextStyle(
                fontSize: 12.5,
                color: _scheme.onSurfaceVariant,
              ),
            )
          else
            ..._comisiones.map((c) {
              final porPagar = _numero(c['por_pagar']);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _scheme.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: _scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Icon(
                          Icons.delivery_dining_outlined,
                          size: 18,
                          color: _scheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c['nombre']?.toString() ?? 'Repartidor',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: _scheme.onSurface,
                              ),
                            ),
                            Text(
                              '${c['entregas'] ?? 0} asignaciones · '
                              'Comisión estimada Foody ${_formato.format(_numero(c['comision_foody']))}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: _scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _formato.format(porPagar),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: _scheme.onSurface,
                            ),
                          ),
                          Text(
                            'Estimado',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: _scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _encabezadoEquipo() {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Equipo de planta',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: _scheme.onSurface,
            ),
          ),
        ),
        Text(
          '${_domiciliarios.length}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _vacioPlanta() {
    return _card(
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.two_wheeler_outlined,
              color: _scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Sin domiciliarios de planta',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _scheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Crea un empleado repartidor (login staff) o invita '
            'independientes con el enlace de registro.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: _scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _agregarDomiciliarioPlanta,
            style: FilledButton.styleFrom(
              backgroundColor: _scheme.primary,
              foregroundColor: _scheme.onPrimary,
              visualDensity: VisualDensity.compact,
            ),
            icon: const Icon(Icons.person_add_outlined, size: 18),
            label: const Text('Agregar de planta'),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaPlanta(Map<String, dynamic> d) {
    final nombre = d['nombre']?.toString() ?? 'Sin nombre';
    final telefono = d['telefono']?.toString();
    final ocupado = d['ocupado'] == true;
    final statusColor =
        ocupado ? const Color(0xFFD97706) : AnaliticaTokens.inventario;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: _scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
            border: Border.all(color: _scheme.outlineVariant),
            boxShadow: AnaliticaTokens.shadowSoft,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Icon(
                    Icons.two_wheeler_outlined,
                    size: 20,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: _scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        telefono != null && telefono.isNotEmpty
                            ? telefono
                            : 'Domiciliario de planta',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: _scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        ocupado ? 'En ruta' : 'Disponible',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Kpi {
  const _Kpi(this.label, this.value, this.color, this.icon);
  final String label;
  final String value;
  final Color color;
  final IconData icon;
}

class _DatosNuevoPlanta {
  const _DatosNuevoPlanta({
    required this.nombre,
    required this.email,
    required this.pass,
  });
  final String nombre;
  final String email;
  final String pass;
}

class _DialogoNuevoPlanta extends StatefulWidget {
  const _DialogoNuevoPlanta();

  @override
  State<_DialogoNuevoPlanta> createState() => _DialogoNuevoPlantaState();
}

class _DialogoNuevoPlantaState extends State<_DialogoNuevoPlanta> {
  ColorScheme get _scheme => Theme.of(context).colorScheme;

  final _nombre = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();

  @override
  void dispose() {
    _nombre.dispose();
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  void _crear() {
    final n = _nombre.text.trim();
    final e = _email.text.trim();
    final p = _pass.text;
    if (n.isEmpty || e.isEmpty) return;
    Navigator.pop(
      context,
      _DatosNuevoPlanta(nombre: n, email: e, pass: p),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuevo domiciliario de planta'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Empleado de tu restaurante. Entrará en /admin/login con este correo.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.35,
                color: _scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nombre,
              decoration: const InputDecoration(labelText: 'Nombre'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Correo'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _pass,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Contraseña',
                helperText: 'Mínimo 6 caracteres',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _crear,
          child: const Text('Crear'),
        ),
      ],
    );
  }
}
