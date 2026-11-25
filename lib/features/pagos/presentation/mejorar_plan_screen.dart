import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:reserva_canchas/core/layout/foody_breakpoints.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_skeleton.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_tokens.dart';
import 'package:reserva_canchas/features/pagos/data/pagos_repository.dart';
import 'package:reserva_canchas/features/pagos/domain/planes_comerciales.dart';
import 'package:url_launcher/url_launcher.dart';

/// Comparativa de planes + checkout Wompi (F6 self-service).
class MejorarPlanScreen extends StatefulWidget {
  const MejorarPlanScreen({
    super.key,
    required this.planActual,
    this.suscripcion,
    this.planSugerido,
    this.pagoIdInicial,
    this.onPlanActualizado,
    this.onPagoIniciado,
    this.repository,
  });

  final String planActual;
  final Map<String, dynamic>? suscripcion;
  final String? planSugerido;
  final String? pagoIdInicial;
  final VoidCallback? onPlanActualizado;

  /// Avisa al panel para poll en paralelo (tiempo real al volver de Wompi).
  final ValueChanged<String>? onPagoIniciado;

  /// Permite probar la presentación sin invocar la API de pagos.
  final PagosRepository? repository;

  @override
  State<MejorarPlanScreen> createState() => _MejorarPlanScreenState();
}

class _MejorarPlanScreenState extends State<MejorarPlanScreen>
    with WidgetsBindingObserver {
  ColorScheme get _scheme => Theme.of(context).colorScheme;

  late final PagosRepository _repo;
  final _moneda = NumberFormat.currency(
    locale: 'es_CO',
    symbol: r'$',
    decimalDigits: 0,
  );

  bool _cargandoEstado = true;
  bool _procesandoPago = false;
  bool _procesandoRenovacion = false;
  bool _sincronizando = false;
  bool _yaNotificoActivacion = false;
  String? _error;
  Map<String, dynamic>? _estado;
  String? _planSeleccionado;
  String? _ultimoPagoId;
  final _transaccionCtrl = TextEditingController();

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _transaccionCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? PagosRepository();
    WidgetsBinding.instance.addObserver(this);
    _planSeleccionado = _planInicial();
    _ultimoPagoId = widget.pagoIdInicial;
    // Carga única. Activación en vivo = Realtime del backend (sin poll).
    unawaited(_cargarEstado());
    if (widget.pagoIdInicial != null) {
      unawaited(_verificarActivacionAutomatica());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Un sync puntual al volver de Wompi (no timer).
      unawaited(_alVolverDeWompi());
    }
  }

  Future<void> _alVolverDeWompi() async {
    await _verificarActivacionAutomatica();
    if (!mounted) return;
    await _cargarEstado(silencioso: true);
  }

  Future<void> _verificarActivacionAutomatica() async {
    if (_yaNotificoActivacion) return;
    try {
      final resultado = await _repo.sincronizar(pagoId: _ultimoPagoId);
      if (resultado['sincronizado'] != true) return;

      _yaNotificoActivacion = true;
      if (!mounted) return;
      await _cargarEstado(silencioso: true);
      widget.onPlanActualizado?.call();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '¡Plan activado! Ya puedes usar los módulos desbloqueados.',
          ),
          backgroundColor: AnaliticaTokens.inventario,
          duration: Duration(seconds: 4),
        ),
      );
    } catch (_) {
      // Pendiente: el webhook + Realtime avisan sin recargar la UI en bucle.
    }
  }

  String _planInicial() {
    if (widget.planSugerido != null &&
        PlanesComercialesFoody.planesPago.contains(widget.planSugerido)) {
      return widget.planSugerido!;
    }
    final actual = widget.planActual;
    if (actual == 'gratis' || actual == 'basico') return 'pro';
    if (actual == 'pro') return 'enterprise';
    return 'pro';
  }

  /// Plan mostrado: API primero (tras webhook/sync), no el JWT stale del panel.
  String get _planVista {
    final deApi = _suscripcionVista?['plan'] as String?;
    if (deApi != null && deApi.isNotEmpty) return deApi;
    return widget.planActual;
  }

  Future<void> _cargarEstado({bool silencioso = false}) async {
    if (!silencioso) {
      setState(() {
        _cargandoEstado = true;
        _error = null;
      });
    }
    try {
      final estado = await _repo.estado();
      if (!mounted) return;
      setState(() {
        _estado = estado;
        _cargandoEstado = false;
        final ultimo = estado['ultimo_pago'] as Map<String, dynamic>?;
        if (ultimo != null) {
          _ultimoPagoId ??= ultimo['id'] as String?;
        }
      });
      final planApi =
          (estado['suscripcion'] as Map<String, dynamic>?)?['plan'] as String?;
      if (planApi != null &&
          !_yaNotificoActivacion &&
          PlanesComercialesFoody.nivel(planApi) >
              PlanesComercialesFoody.nivel(widget.planActual)) {
        _yaNotificoActivacion = true;
        widget.onPlanActualizado?.call();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargandoEstado = false;
        if (!silencioso) _error = mensajeErrorHttp(e);
      });
    }
  }

  int _precioCop(String plan) {
    final preciosApi = _estado?['precios'] as Map<String, dynamic>?;
    final centavos = preciosApi?[plan];
    if (centavos is num) return (centavos / 100).round();
    return PlanesComercialesFoody.preciosCop[plan] ?? 0;
  }

  Future<void> _pagarPlan(String plan) async {
    setState(() {
      _procesandoPago = true;
      _error = null;
    });
    try {
      final datos = await _repo.crearCheckout(plan);
      final url = datos['checkout_url'] as String?;
      if (url == null || url.isEmpty) {
        throw Exception('No se recibió enlace de pago');
      }
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('No se pudo abrir el checkout de pago');
      }
      if (!mounted) return;
      final pagoId = datos['pago_id'] as String?;
      setState(() => _ultimoPagoId = pagoId);
      _yaNotificoActivacion = false;
      if (pagoId != null) widget.onPagoIniciado?.call(pagoId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Completa el pago en Wompi. Al confirmar, el plan se activa solo.',
          ),
          duration: Duration(seconds: 6),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = mensajeErrorHttp(e));
    } finally {
      if (mounted) setState(() => _procesandoPago = false);
    }
  }

  Future<void> _renovarPlan() async {
    setState(() {
      _procesandoRenovacion = true;
      _error = null;
    });
    try {
      final datos = await _repo.renovar();
      final modo = datos['modo'] as String?;
      if (!mounted) return;

      if (modo == 'checkout') {
        final url = datos['checkout_url'] as String?;
        if (url == null || url.isEmpty) {
          throw Exception('No se recibió enlace de pago');
        }
        final uri = Uri.parse(url);
        if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          throw Exception('No se pudo abrir el checkout de pago');
        }
        if (!mounted) return;
        setState(() => _ultimoPagoId = datos['pago_id'] as String?);
        _yaNotificoActivacion = false;
        final pagoIdRen = datos['pago_id'] as String?;
        if (pagoIdRen != null) widget.onPagoIniciado?.call(pagoIdRen);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Sin tarjeta guardada: completa el pago en Wompi. Al confirmar se activa solo.',
            ),
            duration: Duration(seconds: 6),
          ),
        );
      } else if (modo == 'recurrente') {
        final motivo = datos['motivo'] as String?;
        await _cargarEstado(silencioso: true);
        widget.onPlanActualizado?.call();
        if (!mounted) return;
        if (motivo == 'cobro_aprobado') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Plan renovado con tu método de pago guardado.'),
              backgroundColor: AnaliticaTokens.inventario,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Cobro de renovación iniciado. Se confirmará en unos segundos.',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = mensajeErrorHttp(e));
    } finally {
      if (mounted) setState(() => _procesandoRenovacion = false);
    }
  }

  Future<void> _sincronizarPago() async {
    final txId = _transaccionCtrl.text.trim();
    if (txId.isEmpty) {
      setState(
        () => _error = 'Pega el número de transacción del comprobante Wompi',
      );
      return;
    }
    setState(() {
      _sincronizando = true;
      _error = null;
    });
    try {
      await _repo.sincronizar(
        pagoId: _ultimoPagoId,
        transaccionWompiId: txId,
      );
      _yaNotificoActivacion = true;
      if (!mounted) return;
      await _cargarEstado(silencioso: true);
      widget.onPlanActualizado?.call();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Plan activado correctamente'),
          backgroundColor: AnaliticaTokens.inventario,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = mensajeErrorHttp(e));
    } finally {
      if (mounted) setState(() => _sincronizando = false);
    }
  }

  bool get _hayPagoPendiente {
    final ultimo = _estado?['ultimo_pago'] as Map<String, dynamic>?;
    return ultimo?['estado'] == 'pendiente';
  }

  Map<String, dynamic>? get _fuentePago =>
      _estado?['fuente_pago'] as Map<String, dynamic>?;

  bool get _renovacionAutomaticaActiva =>
      _fuentePago?['renovacion_automatica'] == true &&
      _fuentePago?['activa'] == true;

  Map<String, dynamic>? get _suscripcionVista {
    final api = _estado?['suscripcion'] as Map<String, dynamic>?;
    return api ?? widget.suscripcion;
  }

  List<Map<String, dynamic>> get _historialPagos {
    final raw = _estado?['historial'];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  String _etiquetaEstadoSuscripcion(String? estado) {
    switch (estado) {
      case 'activa':
        return 'Activa';
      case 'prueba':
        return 'Prueba';
      case 'vencida':
        return 'Vencida';
      case 'bloqueada':
        return 'Bloqueada';
      default:
        return estado ?? '—';
    }
  }

  String _etiquetaEstadoPago(String? estado) {
    switch (estado) {
      case 'aprobado':
        return 'Aprobado';
      case 'pendiente':
        return 'Pendiente';
      case 'rechazado':
        return 'Rechazado';
      case 'error':
        return 'Error';
      default:
        return estado ?? '—';
    }
  }

  Color _colorEstadoPago(String? estado) {
    switch (estado) {
      case 'aprobado':
        return AnaliticaTokens.inventario;
      case 'pendiente':
        return const Color(0xFFD97706);
      case 'rechazado':
      case 'error':
        return AnaliticaTokens.alertas;
      default:
        return _scheme.onSurfaceVariant;
    }
  }

  Color _colorEstadoSuscripcion(String? estado) {
    switch (estado) {
      case 'activa':
      case 'prueba':
        return AnaliticaTokens.inventario;
      case 'vencida':
      case 'bloqueada':
        return AnaliticaTokens.alertas;
      default:
        return _scheme.onSurfaceVariant;
    }
  }

  String? _formatearFecha(dynamic valor) {
    if (valor == null) return null;
    final dt = DateTime.tryParse(valor.toString());
    if (dt == null) return null;
    return DateFormat('d MMM y', 'es_CO').format(dt.toLocal());
  }

  Widget _avisoBanner({
    required IconData icono,
    required Color color,
    required String texto,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: _scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sus = _suscripcionVista;
    final dias = sus?['dias_restantes'] as int?;
    final estadoSus = sus?['estado'] as String?;
    final vence = _formatearFecha(sus?['fecha_vencimiento']);
    final ancho = FoodyBreakpoints.widthOf(context);
    final compacto = FoodyBreakpoints.esCompact(ancho);
    final tresColumnas = ancho >= 980;

    return ColoredBox(
      color: _scheme.surface,
      child: RefreshIndicator(
        onRefresh: _cargarEstado,
        color: _scheme.onSurface,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            compacto ? 12 : 20,
            8,
            compacto ? 12 : 20,
            32,
          ),
          children: [
            Text(
              'Admin / Finanzas',
              style: TextStyle(
                fontSize: 11,
                color: _scheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Plan y pagos',
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
              'Plan actual: ${PlanesComercialesFoody.nombre(_planVista)}'
              '${estadoSus != null ? ' · ${_etiquetaEstadoSuscripcion(estadoSus)}' : ''}'
              '${dias != null ? ' · $dias días restantes' : ''}'
              '${vence != null ? ' · vence $vence' : ''}',
              style: TextStyle(
                color: _scheme.onSurfaceVariant,
                fontSize: 12.5,
              ),
            ),
            const SizedBox(height: 14),
            if (_cargandoEstado)
              SizedBox(
                height: 180,
                child: AnaliticaSkeleton.tab(),
              )
            else ...[
              if (sus != null) ...[
                _tarjetaEstadoSuscripcion(sus),
                if (_renovacionAutomaticaActiva) ...[
                  const SizedBox(height: 8),
                  _tarjetaRenovacionAutomatica(),
                ],
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: (_procesandoRenovacion || _procesandoPago)
                        ? null
                        : _renovarPlan,
                    style: FilledButton.styleFrom(
                      backgroundColor: _scheme.primary,
                      foregroundColor: _scheme.onPrimary,
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: _procesandoRenovacion
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.autorenew, size: 18),
                    label: Text(
                      _renovacionAutomaticaActiva
                          ? 'Renovar ahora (cobro automático)'
                          : 'Renovar plan ahora',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Text(
                'El costeo y el control de márgenes viven en Pro. '
                'Paga en línea y desbloquea al instante cuando Wompi confirme.',
                style: TextStyle(
                  color: _scheme.onSurfaceVariant,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              if (_hayPagoPendiente)
                _avisoBanner(
                  icono: Icons.hourglass_top,
                  color: const Color(0xFFD97706),
                  texto:
                      'Pago pendiente. Cuando Wompi confirme, el plan se activa solo (sin recargar).',
                ),
              if (_error != null)
                _avisoBanner(
                  icono: Icons.error_outline,
                  color: AnaliticaTokens.alertas,
                  texto: _error!,
                ),
              if (_hayPagoPendiente) ...[
                _tarjetaActivarPlan(),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 4),
              Text(
                'Planes',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: _scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              if (tresColumnas)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final plan in PlanesComercialesFoody.planesPago) ...[
                      Expanded(child: _tarjetaPlan(plan)),
                      if (plan != PlanesComercialesFoody.planesPago.last)
                        const SizedBox(width: 12),
                    ],
                  ],
                )
              else
                ...PlanesComercialesFoody.planesPago.map(_tarjetaPlan),
              if (_historialPagos.isNotEmpty) ...[
                const SizedBox(height: 16),
                _seccionHistorialPagos(),
              ],
              const SizedBox(height: 16),
              Text(
                'Pago seguro con Wompi · COP · renovación mensual 30 días',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: _scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tarjetaEstadoSuscripcion(Map<String, dynamic> sus) {
    final estado = sus['estado'] as String?;
    final plan = sus['plan'] as String? ?? _planVista;
    final vence = _formatearFecha(sus['fecha_vencimiento']);
    final dias = sus['dias_restantes'] as int?;
    final color = _colorEstadoSuscripcion(estado);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        boxShadow: AnaliticaTokens.shadowSoft,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child:
                Icon(Icons.workspace_premium_outlined, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tu suscripción',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: _scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${PlanesComercialesFoody.nombre(plan)} · ${_etiquetaEstadoSuscripcion(estado)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: _scheme.onSurfaceVariant,
                  ),
                ),
                if (vence != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    dias != null
                        ? 'Vence el $vence ($dias días restantes)'
                        : 'Vence el $vence',
                    style: TextStyle(
                      fontSize: 12,
                      color: _scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Text(
              _etiquetaEstadoSuscripcion(estado),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaRenovacionAutomatica() {
    final fuente = _fuentePago;
    final marca = fuente?['marca'] as String?;
    final ult4 = fuente?['ultimos_cuatro'] as String?;
    final metodo = marca != null && ult4 != null
        ? '$marca ···· $ult4'
        : 'Método de pago guardado en Wompi';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(
            Icons.credit_card,
            size: 18,
            color: _scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Renovación automática activa\n$metodo',
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                color: _scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _seccionHistorialPagos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'HISTORIAL DE PAGOS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: _scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        ..._historialPagos.map((pago) {
          final plan = pago['plan'] as String? ?? '—';
          final estado = pago['estado'] as String?;
          final centavos = pago['monto_centavos'];
          final monto = centavos is num ? (centavos / 100).round() : 0;
          final fecha = _formatearFecha(pago['created_at']) ?? '—';
          final color = _colorEstadoPago(estado);

          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: _scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: estado == 'rechazado' || estado == 'error'
                    ? color.withValues(alpha: 0.35)
                    : _scheme.outlineVariant,
              ),
            ),
            child: ListTile(
              dense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              title: Text(
                '${PlanesComercialesFoody.nombre(plan)} · ${_moneda.format(monto)}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _scheme.onSurface,
                ),
              ),
              subtitle: Text(
                fecha,
                style: TextStyle(
                  fontSize: 12,
                  color: _scheme.onSurfaceVariant,
                ),
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Text(
                  _etiquetaEstadoPago(estado),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _tarjetaActivarPlan() {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFD97706).withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '¿Ya pagaste en Wompi?',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: _scheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'En local el webhook no llega solo. Copia el «Número de transacción» '
            'del comprobante (ej. 1969957-1782290934-46563) y activa tu plan.',
            style: TextStyle(
              fontSize: 12,
              color: _scheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _transaccionCtrl,
            decoration: InputDecoration(
              labelText: 'Número de transacción Wompi',
              isDense: true,
              filled: true,
              fillColor: _scheme.surfaceContainerLow,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: _scheme.outlineVariant),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: _scheme.outlineVariant),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: _scheme.onSurface),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _sincronizando ? null : _sincronizarPago,
              icon: _sincronizando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.verified_outlined, size: 18),
              label: const Text('Activar plan'),
              style: FilledButton.styleFrom(
                backgroundColor: _scheme.primary,
                foregroundColor: _scheme.onPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaPlan(String plan) {
    final seleccionado = _planSeleccionado == plan;
    final esActual = PlanesComercialesFoody.nivel(_planVista) >=
        PlanesComercialesFoody.nivel(plan);
    final destacado = plan == 'pro';
    final modulos = PlanesComercialesFoody.modulosPorPlan[plan] ?? [];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: _scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: seleccionado
                ? _scheme.onSurface
                : destacado
                    ? _scheme.onSurface.withValues(alpha: 0.25)
                    : _scheme.outlineVariant,
            width: seleccionado ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap:
              esActual ? null : () => setState(() => _planSeleccionado = plan),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                PlanesComercialesFoody.nombre(plan),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: _scheme.onSurface,
                                ),
                              ),
                              if (destacado)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _scheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: _scheme.outlineVariant,
                                    ),
                                  ),
                                  child: Text(
                                    'Recomendado',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: _scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${_moneda.format(_precioCop(plan))}/mes',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _scheme.onSurface,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                for (final m in modulos)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.check,
                          size: 15,
                          color: AnaliticaTokens.inventario,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            m,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: _scheme.onSurfaceVariant,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: esActual || _procesandoPago
                        ? null
                        : () => _pagarPlan(plan),
                    style: FilledButton.styleFrom(
                      backgroundColor: _scheme.primary,
                      foregroundColor: _scheme.onPrimary,
                      disabledBackgroundColor: _scheme.surfaceContainerHighest,
                      disabledForegroundColor: _scheme.onSurfaceVariant,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _procesandoPago && seleccionado
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            esActual
                                ? 'Plan actual o superior'
                                : 'Pagar con Wompi',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
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
