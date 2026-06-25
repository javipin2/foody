import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';
import 'package:reserva_canchas/core/utilidades/parsear_numero.dart';
import 'package:reserva_canchas/features/pedidos/data/historial_pedidos_service.dart';
import 'package:reserva_canchas/features/pedidos/data/pedidos_cliente_repository.dart';

/// Historial de pedidos del dispositivo (API + cache local).
class MisPedidosScreen extends StatefulWidget {
  const MisPedidosScreen({super.key});

  @override
  State<MisPedidosScreen> createState() => _MisPedidosScreenState();
}

class _MisPedidosScreenState extends State<MisPedidosScreen> {
  final _repo = PedidosClienteRepository();
  List<Map<String, dynamic>> _pedidos = [];
  bool _cargando = true;
  String? _error;

  final _formatoMoneda = NumberFormat.currency(
    locale: 'es_CO',
    symbol: r'$',
    decimalDigits: 0,
  );
  final _formatoFecha = DateFormat('d MMM yyyy · HH:mm', 'es_CO');

  static const _etiquetasEstado = {
    'pendiente_aprobacion': 'Esperando mesera',
    'pendiente': 'Recibido',
    'confirmado': 'En preparación',
    'en_cocina': 'En preparación',
    'listo': 'Listo',
    'en_camino': 'En camino',
    'entregado': 'Entregado',
    'pagado': 'Pagado',
    'cancelado': 'Cancelado',
    'rechazado': 'Rechazado',
  };

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final api = await _repo.listarMios();
      final local = await HistorialPedidosService.listarLocal();
      final fusion = _fusionar(api, local);
      if (!mounted) return;
      setState(() {
        _pedidos = fusion;
        _cargando = false;
      });
    } catch (e) {
      final local = await HistorialPedidosService.listarLocal();
      if (!mounted) return;
      setState(() {
        _pedidos = local;
        _cargando = false;
        _error = local.isEmpty ? mensajeErrorHttp(e, contexto: 'cargar pedidos') : null;
      });
    }
  }

  List<Map<String, dynamic>> _fusionar(
    List<Map<String, dynamic>> api,
    List<Map<String, dynamic>> local,
  ) {
    final mapa = <String, Map<String, dynamic>>{};
    for (final p in local) {
      final id = p['pedido_id'] as String?;
      if (id != null) mapa[id] = Map<String, dynamic>.from(p);
    }
    for (final p in api) {
      final id = p['id'] as String?;
      if (id == null) continue;
      mapa[id] = {
        'pedido_id': id,
        'numero_pedido': p['numero_pedido'],
        'estado': p['estado'],
        'tipo': p['tipo'],
        'total': p['total'],
        'sucursal_nombre': p['sucursal_nombre'],
        'created_at': p['created_at'],
      };
    }
    final lista = mapa.values.toList();
    lista.sort((a, b) {
      final da = DateTime.tryParse('${a['created_at']}') ?? DateTime(1970);
      final db = DateTime.tryParse('${b['created_at']}') ?? DateTime(1970);
      return db.compareTo(da);
    });
    return lista;
  }

  String _etiquetaEstado(String? estado) =>
      _etiquetasEstado[estado] ?? (estado ?? '').replaceAll('_', ' ');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis pedidos'),
        actions: [
          IconButton(onPressed: _cargar, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _cargar,
        child: _cargando
            ? const Center(child: CircularProgressIndicator())
            : _pedidos.isEmpty
                ? ListView(
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                      Icon(Icons.receipt_long_outlined,
                          size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Center(
                        child: Text(
                          _error ?? 'Aún no tienes pedidos en este dispositivo',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _pedidos.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final p = _pedidos[i];
                      final id = p['pedido_id'] as String;
                      final numero = p['numero_pedido'] as String? ?? id;
                      final estado = p['estado'] as String?;
                      final total = p['total'];
                      final fecha = DateTime.tryParse('${p['created_at']}');
                      return Card(
                        child: ListTile(
                          onTap: () => context.push('/pedidos/$id/seguimiento'),
                          title: Text(numero),
                          subtitle: Text(
                            [
                              if (p['sucursal_nombre'] != null)
                                p['sucursal_nombre'],
                              if (fecha != null) _formatoFecha.format(fecha),
                            ].join(' · '),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (total != null)
                                Text(
                                  _formatoMoneda.format(parsearNumero(total)),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: ColoresFoody.primario,
                                  ),
                                ),
                              Text(
                                _etiquetaEstado(estado),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
