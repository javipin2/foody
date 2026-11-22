import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:reserva_canchas/core/layout/foody_breakpoints.dart';
import 'package:reserva_canchas/core/realtime/foody_realtime.dart';
import 'package:reserva_canchas/core/realtime/poll_realtime_respaldo.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';
import 'package:reserva_canchas/core/saas_ui/saas_ui.dart';
import 'package:reserva_canchas/features/alertas/data/alertas_repository.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_skeleton.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_tokens.dart';
import 'package:reserva_canchas/services/app_backend.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Alertas de riesgo (Sprint 9).
class AlertasAdminScreen extends StatefulWidget {
  const AlertasAdminScreen({
    super.key,
    this.sucursalId,
    this.onNavegarReferencia,
  });

  final String? sucursalId;
  final void Function(String referenciaTipo, String referenciaId)?
      onNavegarReferencia;

  @override
  State<AlertasAdminScreen> createState() => _AlertasAdminScreenState();
}

class _AlertasAdminScreenState extends State<AlertasAdminScreen> {
  final _repo = AlertasRepository();
  List<Map<String, dynamic>> _alertas = [];
  bool _soloPendientes = true;
  bool _cargando = true;
  bool _evaluando = false;
  String? _error;
  RealtimeChannel? _canal;
  PollRealtimeRespaldo? _pollRespaldo;

  final _fecha = DateFormat('d MMM HH:mm', 'es_CO');

  @override
  void initState() {
    super.initState();
    _cargar();
    _suscribirRealtime();
    _pollRespaldo = PollRealtimeRespaldo(onActualizar: () async {
      if (mounted) await _cargar(silencioso: true);
    });
    unawaited(_pollRespaldo!.iniciar());
  }

  void _suscribirRealtime() {
    final sid = widget.sucursalId;
    if (!AppBackend.supabaseReady || sid == null) return;
    _canal = FoodyRealtime.suscribirSucursal(
      sid,
      onEvento: (evento) {
        if (evento == 'alerta_nueva') {
          _cargar();
        }
      },
    );
  }

  @override
  void dispose() {
    FoodyRealtime.liberarCanal(_canal);
    _pollRespaldo?.detener();
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
      final lista = await _repo.listar(sid, soloPendientes: _soloPendientes);
      if (mounted) {
        setState(() {
          _alertas = lista;
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = mensajeErrorHttp(e, contexto: 'alertas');
          _cargando = false;
        });
      }
    }
  }

  Future<void> _revisar(String id) async {
    try {
      await _repo.revisar(id, sucursalId: widget.sucursalId);
      await _cargar();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensajeErrorHttp(e, contexto: 'revisión'))),
        );
      }
    }
  }

  Color _colorNivel(String? nivel) {
    switch (nivel) {
      case 'critico':
      case 'alto':
        return AnaliticaTokens.alertas;
      case 'medio':
        return const Color(0xFFD97706);
      default:
        return AnaliticaTokens.inkSoft;
    }
  }

  String _etiquetaNivel(String? nivel) {
    switch (nivel) {
      case 'critico':
        return 'Crítico';
      case 'alto':
        return 'Alto';
      case 'medio':
        return 'Medio';
      case 'bajo':
        return 'Bajo';
      default:
        return nivel ?? '—';
    }
  }

  Future<void> _evaluarReglas() async {
    final sid = widget.sucursalId;
    if (sid == null) return;
    setState(() => _evaluando = true);
    try {
      final n = await _repo.evaluarReglas(sid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            n > 0
                ? 'Se generaron $n alertas nuevas'
                : 'Sin alertas nuevas por reglas programadas',
          ),
          backgroundColor: AnaliticaTokens.ink,
        ),
      );
      await _cargar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensajeErrorHttp(e, contexto: 'evaluar alertas')),
          backgroundColor: AnaliticaTokens.alertas,
        ),
      );
    } finally {
      if (mounted) setState(() => _evaluando = false);
    }
  }

  void _abrirReferencia(Map<String, dynamic> alerta) {
    final tipo = alerta['referencia_tipo'] as String?;
    final id = alerta['referencia_id'] as String?;
    if (tipo == null || id == null || id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Esta alerta no tiene un enlace a pedido, mesa o inventario',
          ),
        ),
      );
      return;
    }
    widget.onNavegarReferencia?.call(tipo, id);
  }

  String _etiquetaTipo(String? tipo) {
    switch (tipo) {
      case 'item_eliminado_post_cocina':
        return 'Ítem eliminado en cocina';
      case 'item_no_disponible_cocina':
        return 'Plato no disponible (cocina)';
      case 'mesa_salio_sin_pagar':
      case 'salio_sin_pagar':
        return 'Mesa sin pago';
      case 'intento_pedido_sin_stock':
        return 'Pedido sin stock';
      case 'stock_minimo_alcanzado':
        return 'Stock bajo';
      case 'producto_sin_stock':
        return 'Producto sin stock';
      case 'merma_cancelacion_pedido':
        return 'Merma por cancelación';
      case 'cancelaciones_frecuentes':
        return 'Cancelaciones frecuentes';
      case 'pedido_sin_domiciliario':
        return 'Sin domiciliario';
      case 'cuadre_caja_diferencia':
      case 'cuadre_caja_negativo':
        return 'Cuadre de caja';
      case 'descuento_manual_excesivo':
        return 'Descuento excesivo';
      case 'transferencia_mesa_multiple':
        return 'Traslado entre mesas';
      case 'demora_excesiva_entrega':
        return 'Demora en entrega';
      case 'costo_ingrediente_sube':
        return 'Costo de insumo';
      case 'margen_bajo_prolongado':
        return 'Margen bajo';
      case 'caida_ventas_producto':
        return 'Caída de ventas';
      default:
        // ponytail: slug → etiqueta legible si no hay mapa.
        if (tipo == null || tipo.isEmpty) return 'Alerta';
        return tipo.replaceAll('_', ' ');
    }
  }

  IconData _iconoTipo(String? tipo) {
    switch (tipo) {
      case 'stock_minimo_alcanzado':
      case 'producto_sin_stock':
      case 'intento_pedido_sin_stock':
        return Icons.inventory_2_outlined;
      case 'pedido_sin_domiciliario':
        return Icons.delivery_dining;
      case 'cuadre_caja_diferencia':
      case 'cuadre_caja_negativo':
        return Icons.point_of_sale;
      case 'descuento_manual_excesivo':
        return Icons.discount_outlined;
      case 'cancelaciones_frecuentes':
        return Icons.cancel_outlined;
      case 'transferencia_mesa_multiple':
        return Icons.table_restaurant_outlined;
      case 'demora_excesiva_entrega':
        return Icons.timer_off_outlined;
      case 'costo_ingrediente_sube':
        return Icons.trending_up;
      case 'margen_bajo_prolongado':
      case 'caida_ventas_producto':
        return Icons.analytics_outlined;
      case 'mesa_salio_sin_pagar':
      case 'salio_sin_pagar':
        return Icons.logout;
      case 'merma_cancelacion_pedido':
        return Icons.delete_outline;
      default:
        return Icons.warning_amber_rounded;
    }
  }

  int get _pendientes =>
      _alertas.where((a) => a['revisada'] != true).length;

  @override
  Widget build(BuildContext context) {
    final ancho = FoodyBreakpoints.widthOf(context);
    final compacto = FoodyBreakpoints.esCompact(ancho);

    return ColoredBox(
      color: AnaliticaTokens.canvas,
      child: SaasScrollableShell(
        header: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              compacto ? 12 : 20,
              8,
              compacto ? 12 : 20,
              8,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Admin / Sistema',
                  style: TextStyle(
                    fontSize: 11,
                    color: AnaliticaTokens.inkSoft,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Alertas',
                  style: TextStyle(
                    fontSize: compacto ? 18 : 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                    color: AnaliticaTokens.ink,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _cargando
                      ? 'Cargando…'
                      : _soloPendientes
                          ? '$_pendientes pendientes · toca una alerta para ir al origen'
                          : '${_alertas.length} en total · $_pendientes pendientes',
                  style: const TextStyle(
                    color: AnaliticaTokens.inkMuted,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilterChip(
                      label: Text(
                        'Solo pendientes',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: _soloPendientes
                              ? Colors.white
                              : AnaliticaTokens.inkMuted,
                        ),
                      ),
                      selected: _soloPendientes,
                      selectedColor: AnaliticaTokens.ink,
                      backgroundColor: AnaliticaTokens.surface,
                      side: BorderSide(
                        color: _soloPendientes
                            ? AnaliticaTokens.ink
                            : AnaliticaTokens.border,
                      ),
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                      onSelected: (v) {
                        setState(() => _soloPendientes = v);
                        _cargar();
                      },
                    ),
                    FilledButton.icon(
                      onPressed: _evaluando ? null : _evaluarReglas,
                      style: FilledButton.styleFrom(
                        backgroundColor: AnaliticaTokens.ink,
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: _evaluando
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.bolt_outlined, size: 18),
                      label: const Text('Evaluar reglas'),
                    ),
                    IconButton(
                      tooltip: 'Actualizar',
                      onPressed: _cargar,
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(
                        Icons.refresh,
                        color: AnaliticaTokens.inkMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        body: _cargando
            ? AnaliticaSkeleton.tab()
            : _error != null
                ? _estadoError()
                : _alertas.isEmpty
                    ? _vacio()
                    : RefreshIndicator(
                        onRefresh: _cargar,
                        color: AnaliticaTokens.ink,
                        child: ListView.separated(
                          padding: EdgeInsets.fromLTRB(
                            compacto ? 12 : 20,
                            4,
                            compacto ? 12 : 20,
                            32,
                          ),
                          itemCount: _alertas.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, i) => _tarjetaAlerta(_alertas[i]),
                        ),
                      ),
      ),
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
            color: AnaliticaTokens.surface,
            borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
            border: Border.all(color: AnaliticaTokens.border),
            boxShadow: AnaliticaTokens.shadowSoft,
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
                style: const TextStyle(
                  fontSize: 13.5,
                  color: AnaliticaTokens.inkMuted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: _cargar,
                style: FilledButton.styleFrom(
                  backgroundColor: AnaliticaTokens.ink,
                ),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _vacio() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
          decoration: BoxDecoration(
            color: AnaliticaTokens.surface,
            borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
            border: Border.all(color: AnaliticaTokens.border),
            boxShadow: AnaliticaTokens.shadowSoft,
          ),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AnaliticaTokens.surfaceMuted,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.notifications_none_outlined,
                  size: 24,
                  color: AnaliticaTokens.inkMuted,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                _soloPendientes ? 'Sin alertas pendientes' : 'Sin alertas',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AnaliticaTokens.ink,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Cuando ocurra un riesgo operativo (stock, mesa sin pago, merma…), '
                'aparecerá aquí para revisarlo.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: AnaliticaTokens.inkMuted,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _evaluando ? null : _evaluarReglas,
                style: FilledButton.styleFrom(
                  backgroundColor: AnaliticaTokens.ink,
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.bolt_outlined, size: 18),
                label: const Text('Evaluar reglas ahora'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tarjetaAlerta(Map<String, dynamic> a) {
    final nivel = a['nivel'] as String?;
    final revisada = a['revisada'] == true;
    final creado = DateTime.tryParse('${a['created_at']}');
    final tipo = a['tipo'] as String?;
    final color = _colorNivel(nivel);
    final tieneEnlace = (a['referencia_tipo'] as String?) != null &&
        (a['referencia_id'] as String?)?.isNotEmpty == true;

    return Material(
      color: AnaliticaTokens.surface,
      borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
      child: InkWell(
        onTap: tieneEnlace ? () => _abrirReferencia(a) : null,
        borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
            border: Border.all(color: AnaliticaTokens.border),
            boxShadow: AnaliticaTokens.shadowSoft,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withValues(alpha: 0.25)),
                  ),
                  child: Icon(
                    _iconoTipo(tipo),
                    size: 18,
                    color: color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a['descripcion'] as String? ?? '',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                          color: revisada
                              ? AnaliticaTokens.inkSoft
                              : AnaliticaTokens.ink,
                          decoration: revisada
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _badge(_etiquetaTipo(tipo), AnaliticaTokens.inkMuted),
                          _badge(_etiquetaNivel(nivel), color),
                          if (creado != null)
                            _badge(
                              _fecha.format(creado),
                              AnaliticaTokens.inkSoft,
                            ),
                          if (tieneEnlace)
                            _badge('Ver origen', AnaliticaTokens.pedidos),
                        ],
                      ),
                    ],
                  ),
                ),
                if (revisada)
                  const Padding(
                    padding: EdgeInsets.only(left: 4, top: 6),
                    child: Icon(
                      Icons.check_circle_outline,
                      size: 20,
                      color: AnaliticaTokens.inventario,
                    ),
                  )
                else
                  IconButton(
                    tooltip: 'Marcar revisada',
                    onPressed: () => _revisar(a['id'] as String),
                    icon: const Icon(
                      Icons.done_all,
                      size: 20,
                      color: AnaliticaTokens.inkSoft,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _badge(String texto, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
