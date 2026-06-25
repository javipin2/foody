import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
import 'package:reserva_canchas/core/realtime/foody_realtime.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';
import 'package:reserva_canchas/features/alertas/data/alertas_repository.dart';
import 'package:reserva_canchas/services/app_backend.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Alertas de riesgo (Sprint 9).
class AlertasAdminScreen extends StatefulWidget {
  const AlertasAdminScreen({super.key, this.sucursalId});

  final String? sucursalId;

  @override
  State<AlertasAdminScreen> createState() => _AlertasAdminScreenState();
}

class _AlertasAdminScreenState extends State<AlertasAdminScreen> {
  final _repo = AlertasRepository();
  List<Map<String, dynamic>> _alertas = [];
  bool _soloPendientes = true;
  bool _cargando = true;
  String? _error;
  RealtimeChannel? _canal;

  final _fecha = DateFormat('d MMM HH:mm', 'es_CO');

  @override
  void initState() {
    super.initState();
    _cargar();
    _suscribirRealtime();
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
    _canal?.unsubscribe();
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
        return ColoresFoody.error;
      case 'alto':
        return ColoresFoody.error.withValues(alpha: 0.85);
      case 'medio':
        return ColoresFoody.acento;
      default:
        return Colors.grey;
    }
  }

  Future<void> _evaluarReglas() async {
    final sid = widget.sucursalId;
    if (sid == null) return;
    try {
      final n = await _repo.evaluarReglas(sid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            n > 0 ? 'Se generaron $n alertas nuevas' : 'Sin alertas nuevas por reglas programadas',
          ),
        ),
      );
      await _cargar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensajeErrorHttp(e, contexto: 'evaluar alertas'))),
      );
    }
  }

  String _etiquetaTipo(String? tipo) {
    switch (tipo) {
      case 'item_eliminado_post_cocina':
        return 'Ítem eliminado en cocina';
      case 'item_no_disponible_cocina':
        return 'Plato no disponible (cocina)';
      case 'mesa_salio_sin_pagar':
        return 'Mesa salió sin pagar';
      case 'intento_pedido_sin_stock':
        return 'Pedido sin stock';
      case 'stock_minimo_alcanzado':
        return 'Stock bajo';
      case 'producto_sin_stock':
        return 'Producto sin stock';
      default:
        return tipo ?? '—';
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
      default:
        return Icons.warning_amber_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
          child: Row(
            children: [
              Text('Alertas', style: Theme.of(context).textTheme.headlineSmall),
              const Spacer(),
              FilterChip(
                label: const Text('Solo pendientes'),
                selected: _soloPendientes,
                onSelected: (v) {
                  setState(() => _soloPendientes = v);
                  _cargar();
                },
              ),
              FilledButton.tonalIcon(
                onPressed: _evaluarReglas,
                icon: const Icon(Icons.rule, size: 18),
                label: const Text('Evaluar reglas'),
              ),
              IconButton(
                tooltip: 'Actualizar',
                onPressed: _cargar,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        Expanded(
          child: _cargando
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: _cargar,
                            child: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    )
                  : _alertas.isEmpty
                      ? const Center(child: Text('Sin alertas en este filtro'))
                      : RefreshIndicator(
                          onRefresh: _cargar,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: _alertas.length,
                            itemBuilder: (_, i) {
                              final a = _alertas[i];
                              final nivel = a['nivel'] as String?;
                              final revisada = a['revisada'] == true;
                              final creado = DateTime.tryParse(
                                '${a['created_at']}',
                              );
                              final tipo = a['tipo'] as String?;
                              final esSinStock = tipo == 'intento_pedido_sin_stock';
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                color: esSinStock
                                    ? ColoresFoody.error.withValues(alpha: 0.06)
                                    : null,
                                shape: esSinStock
                                    ? RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: BorderSide(
                                          color: ColoresFoody.error
                                              .withValues(alpha: 0.35),
                                        ),
                                      )
                                    : null,
                                child: ListTile(
                                  leading: Icon(
                                    _iconoTipo(a['tipo'] as String?),
                                    color: _colorNivel(nivel),
                                  ),
                                  title: Text(
                                    a['descripcion'] as String? ?? '',
                                    style: TextStyle(
                                      decoration: revisada
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${_etiquetaTipo(a['tipo'] as String?)} · ${nivel ?? '—'}'
                                    '${creado != null ? ' · ${_fecha.format(creado)}' : ''}',
                                  ),
                                  trailing: revisada
                                      ? const Icon(Icons.check, color: Colors.green)
                                      : IconButton(
                                          tooltip: 'Marcar revisada',
                                          icon: const Icon(Icons.done_all),
                                          onPressed: () =>
                                              _revisar(a['id'] as String),
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
}
