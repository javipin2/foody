import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';
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
  });

  final String planActual;
  final Map<String, dynamic>? suscripcion;
  final String? planSugerido;
  final String? pagoIdInicial;
  final VoidCallback? onPlanActualizado;

  @override
  State<MejorarPlanScreen> createState() => _MejorarPlanScreenState();
}

class _MejorarPlanScreenState extends State<MejorarPlanScreen> {
  final _repo = PagosRepository();
  final _moneda = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$',
    decimalDigits: 0,
  );

  bool _cargandoEstado = true;
  bool _procesandoPago = false;
  bool _sincronizando = false;
  String? _error;
  Map<String, dynamic>? _estado;
  String? _planSeleccionado;
  String? _ultimoPagoId;
  final _transaccionCtrl = TextEditingController();

  @override
  void dispose() {
    _transaccionCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _planSeleccionado = _planInicial();
    _ultimoPagoId = widget.pagoIdInicial;
    _cargarEstado();
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

  Future<void> _cargarEstado() async {
    setState(() {
      _cargandoEstado = true;
      _error = null;
    });
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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargandoEstado = false;
        _error = mensajeErrorHttp(e);
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
      setState(() => _ultimoPagoId = datos['pago_id'] as String?);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Completa el pago en Wompi. Luego usa «Activar plan» con el número de transacción del comprobante.',
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

  Future<void> _sincronizarPago() async {
    final txId = _transaccionCtrl.text.trim();
    if (txId.isEmpty) {
      setState(() => _error = 'Pega el número de transacción del comprobante Wompi');
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
      if (!mounted) return;
      await _cargarEstado();
      widget.onPlanActualizado?.call();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Plan activado correctamente'),
          backgroundColor: ColoresFoody.exito,
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

  @override
  Widget build(BuildContext context) {
    final sus = widget.suscripcion;
    final dias = sus?['dias_restantes'] as int?;
    final estadoSus = sus?['estado'] as String?;

    return RefreshIndicator(
      onRefresh: _cargarEstado,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Mejorar plan',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: ColoresFoody.texto,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Plan actual: ${PlanesComercialesFoody.nombre(widget.planActual)}'
            '${estadoSus != null ? ' · $estadoSus' : ''}'
            '${dias != null ? ' · $dias días restantes' : ''}',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            'El costeo y el control de márgenes están en Pro. '
            'Paga en línea y desbloquea al instante cuando Wompi confirme.',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Material(
              color: ColoresFoody.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _error!,
                  style: const TextStyle(color: ColoresFoody.error, fontSize: 13),
                ),
              ),
            ),
          ],
          if (_hayPagoPendiente) ...[
            const SizedBox(height: 16),
            _tarjetaActivarPlan(),
          ],
          const SizedBox(height: 20),
          if (_cargandoEstado)
            const Center(child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ))
          else
            ...PlanesComercialesFoody.planesPago.map(_tarjetaPlan),
          const SizedBox(height: 16),
          Text(
            'Pago seguro con Wompi · COP · renovación mensual 30 días',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaActivarPlan() {
    return Material(
      color: ColoresFoody.acento.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '¿Ya pagaste en Wompi?',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 6),
            Text(
              'En local el webhook no llega solo. Copia el «Número de transacción» '
              'del comprobante (ej. 1969957-1782290934-46563) y activa tu plan.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade800, height: 1.35),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _transaccionCtrl,
              decoration: const InputDecoration(
                labelText: 'Número de transacción Wompi',
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(),
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
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.verified_outlined),
                label: const Text('Activar plan'),
                style: FilledButton.styleFrom(
                  backgroundColor: ColoresFoody.secundario,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tarjetaPlan(String plan) {
    final seleccionado = _planSeleccionado == plan;
    final esActual = PlanesComercialesFoody.nivel(widget.planActual) >=
        PlanesComercialesFoody.nivel(plan);
    final destacado = plan == 'pro';
    final modulos = PlanesComercialesFoody.modulosPorPlan[plan] ?? [];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        elevation: seleccionado ? 2 : 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: seleccionado
                ? ColoresFoody.primario
                : destacado
                    ? ColoresFoody.secundario.withValues(alpha: 0.5)
                    : Colors.grey.shade200,
            width: seleccionado ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: esActual ? null : () => setState(() => _planSeleccionado = plan),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            PlanesComercialesFoody.nombre(plan),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (destacado) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: ColoresFoody.acento,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'Recomendado',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Text(
                      '${_moneda.format(_precioCop(plan))}/mes',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: ColoresFoody.primario,
                        fontSize: 15,
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
                        Icon(
                          Icons.check_circle_outline,
                          size: 16,
                          color: ColoresFoody.secundario,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            m,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade800,
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
                      backgroundColor: ColoresFoody.primario,
                      disabledBackgroundColor: Colors.grey.shade300,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _procesandoPago && seleccionado
                        ? const SizedBox(
                            height: 20,
                            width: 20,
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
