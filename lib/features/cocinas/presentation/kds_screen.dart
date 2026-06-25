import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';
import 'package:reserva_canchas/core/realtime/foody_realtime.dart';
import 'package:reserva_canchas/features/auth/data/auth_repository.dart';
import 'package:reserva_canchas/features/cocinas/data/cocinas_repository.dart';

/// Panel de cocina (KDS). Realtime + poll de respaldo cada 60 s.
class KdsScreen extends StatefulWidget {
  const KdsScreen({super.key, this.standalone = false, this.sucursalId});

  /// Si es true se muestra como pantalla completa (rol cocina). Dentro del
  /// panel admin se incrusta sin AppBar propia.
  final bool standalone;

  /// Sucursal activa en panel admin (multi-sede). Si es null, usa la del JWT.
  final String? sucursalId;

  @override
  State<KdsScreen> createState() => _KdsScreenState();
}

class _KdsScreenState extends State<KdsScreen> {
  final _repo = CocinasRepository();
  List<Map<String, dynamic>> _cocinas = [];
  String? _cocinaId;
  List<Map<String, dynamic>> _tickets = [];
  bool _cargando = true;
  String? _error;
  Timer? _timer;
  final Set<String> _ticketsConocidos = {};
  RealtimeChannel? _canalCocina;

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_canalCocina != null) {
      Supabase.instance.client.removeChannel(_canalCocina!);
    }
    super.dispose();
  }

  Future<void> _inicializar() async {
    try {
      final cocinas = widget.sucursalId != null
          ? await _repo.listarCocinas(widget.sucursalId!)
          : await _repo.cocinasParaKds();
      if (!mounted) return;
      setState(() {
        _cocinas = cocinas;
        _cocinaId = cocinas.isNotEmpty ? cocinas.first['id'] as String : null;
        _cargando = false;
      });
      if (_cocinaId != null) {
        await _cargarTickets();
        _suscribirRealtime(_cocinaId!);
        _timer = Timer.periodic(
          const Duration(seconds: 60),
          (_) => _cargarTickets(silencioso: true),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = mensajeErrorHttp(e, contexto: 'cargar cocinas');
      });
    }
  }

  void _suscribirRealtime(String cocinaId) {
    if (_canalCocina != null) {
      Supabase.instance.client.removeChannel(_canalCocina!);
      _canalCocina = null;
    }
    _canalCocina = FoodyRealtime.suscribirCocina(
      cocinaId,
      onActualizado: () => _cargarTickets(silencioso: true),
    );
  }

  Future<void> _cargarTickets({bool silencioso = false}) async {
    final cocinaId = _cocinaId;
    if (cocinaId == null) return;
    if (!silencioso) setState(() => _cargando = true);
    try {
      final tickets = await _repo.tickets(cocinaId);
      if (!mounted) return;
      final ids = tickets
          .map((t) => t['pedido_id'] as String? ?? t['numero_pedido'] as String? ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();
      final nuevos = ids.difference(_ticketsConocidos);
      if (nuevos.isNotEmpty && _ticketsConocidos.isNotEmpty) {
        HapticFeedback.heavyImpact();
        SystemSound.play(SystemSoundType.alert);
      }
      _ticketsConocidos
        ..clear()
        ..addAll(ids);
      setState(() {
        _tickets = tickets;
        _cargando = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        if (!silencioso) {
          _error = mensajeErrorHttp(e, contexto: 'cargar tickets');
        }
      });
    }
  }

  Future<void> _cambiarEstado(String itemId, String estado, {String? motivo}) async {
    try {
      await _repo.cambiarEstadoItem(
        itemId: itemId,
        estadoCocina: estado,
        motivo: motivo,
      );
      await _cargarTickets(silencioso: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensajeErrorHttp(e, contexto: 'actualizar ítem')),
          backgroundColor: ColoresFoody.error,
        ),
      );
    }
  }

  Future<void> _cerrarSesion() async {
    await AuthRepository().logout();
    if (mounted) context.go('/splash');
  }

  @override
  Widget build(BuildContext context) {
    final cuerpo = _cuerpo();
    if (!widget.standalone) return cuerpo;
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        title: const Text('Panel de cocina'),
        actions: [
          IconButton(
            tooltip: 'Refrescar',
            icon: const Icon(Icons.refresh),
            onPressed: () => _cargarTickets(),
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: _cerrarSesion,
          ),
        ],
      ),
      body: cuerpo,
    );
  }

  Widget _cuerpo() {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _inicializar,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }
    if (_cocinas.isEmpty) {
      return const Center(
        child: Text('No hay cocinas configuradas en esta sucursal.'),
      );
    }

    return Column(
      children: [
        if (_cocinas.length > 1)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              children: [
                for (final c in _cocinas)
                  ChoiceChip(
                    label: Text(c['nombre'] as String? ?? '—'),
                    selected: _cocinaId == c['id'],
                    onSelected: (_) {
                      final id = c['id'] as String;
                      setState(() => _cocinaId = id);
                      _suscribirRealtime(id);
                      _cargarTickets();
                    },
                  ),
              ],
            ),
          ),
        Expanded(
          child: _tickets.isEmpty
              ? const Center(
                  child: Text(
                    'Sin pedidos en preparación',
                    style: TextStyle(color: Colors.white70, fontSize: 18),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _cargarTickets,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 360,
                      childAspectRatio: 0.82,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: _tickets.length,
                    itemBuilder: (_, i) => _ticketCard(_tickets[i]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _ticketCard(Map<String, dynamic> t) {
    final items = (t['items'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map<String, dynamic>))
        .toList();
    final mesa = t['mesa_nombre'] as String?;
    final tipo = t['tipo'] as String? ?? '';
    final etiqueta = mesa ?? _tipoTexto(tipo);
    final todosListos =
        items.isNotEmpty && items.every((i) => i['estado_cocina'] == 'listo');
    final creadoRaw = t['created_at'];
    final creado = creadoRaw != null ? DateTime.tryParse('$creadoRaw') : null;
    final minutos = creado != null
        ? DateTime.now().difference(creado.toLocal()).inMinutes
        : 0;
    final demorado = minutos >= 20;

    return Card(
      color: demorado
          ? const Color(0xFF7F1D1D)
          : (todosListos ? const Color(0xFF14532D) : Colors.white),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: demorado
            ? const BorderSide(color: Color(0xFFEF4444), width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    t['numero_pedido'] as String? ?? '—',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: (todosListos || demorado)
                          ? Colors.white
                          : ColoresFoody.texto,
                    ),
                  ),
                ),
                if (creado != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: demorado
                          ? Colors.white.withValues(alpha: 0.2)
                          : Colors.black.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      demorado ? '⚠ $minutos min' : '$minutos min',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: demorado
                            ? Colors.white
                            : ColoresFoody.texto.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: ColoresFoody.primario.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    etiqueta,
                    style: const TextStyle(
                      color: ColoresFoody.primario,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            Expanded(
              child: ListView(
                children: [
                  for (final item in items) _itemFila(item, todosListos),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemFila(Map<String, dynamic> item, bool ticketListo) {
    final estado = item['estado_cocina'] as String? ?? 'pendiente';
    final color = switch (estado) {
      'preparando' => const Color(0xFFF59E0B),
      'listo' => const Color(0xFF22C55E),
      'no_disponible' => const Color(0xFFEF4444),
      _ => Colors.grey,
    };
    final itemId = item['item_id'] as String;
    final blanco = ticketListo;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(
                color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${item['cantidad']}× ${item['producto'] ?? ''}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    decoration:
                        estado == 'listo' || estado == 'no_disponible'
                            ? TextDecoration.lineThrough
                            : null,
                    color: blanco ? Colors.white : ColoresFoody.texto,
                  ),
                ),
              ),
            ],
          ),
          if (item['incluidos'] is List && (item['incluidos'] as List).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 18, top: 2),
              child: Text(
                '+ ${(item['incluidos'] as List).map((inc) {
                  final m = Map<String, dynamic>.from(inc as Map);
                  return '${m['cantidad']}× ${m['nombre']}';
                }).join(', ')}',
                style: TextStyle(
                  fontSize: 12,
                  color: blanco ? Colors.white70 : ColoresFoody.secundario,
                ),
              ),
            ),
          if ((item['observaciones'] as String?)?.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.only(left: 18, top: 2),
              child: Text(
                item['observaciones'] as String,
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  fontSize: 12,
                  color: blanco ? Colors.white70 : Colors.grey.shade700,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(left: 18, top: 4),
            child: Wrap(
              spacing: 6,
              children: [
                if (estado != 'preparando')
                  OutlinedButton(
                    onPressed: () => _cambiarEstado(itemId, 'preparando'),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('Preparando'),
                  ),
                if (estado != 'listo' && estado != 'no_disponible')
                  FilledButton(
                    onPressed: () => _cambiarEstado(itemId, 'listo'),
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      backgroundColor: const Color(0xFF22C55E),
                    ),
                    child: const Text('Listo'),
                  ),
                if (estado != 'no_disponible' && estado != 'listo')
                  OutlinedButton(
                    onPressed: () async {
                      final motivoCtrl = TextEditingController();
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('No disponible'),
                          content: TextField(
                            controller: motivoCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Motivo (sin ingrediente, etc.)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancelar'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Confirmar'),
                            ),
                          ],
                        ),
                      );
                      if (ok == true) {
                        await _cambiarEstado(
                          itemId,
                          'no_disponible',
                          motivo: motivoCtrl.text.trim(),
                        );
                      }
                      motivoCtrl.dispose();
                    },
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: const Color(0xFFEF4444),
                    ),
                    child: const Text('No disp.'),
                  ),
                if (estado == 'listo')
                  TextButton(
                    onPressed: () => _cambiarEstado(itemId, 'pendiente'),
                    child: Text(
                      'Reabrir',
                      style: TextStyle(
                        color: blanco ? Colors.white70 : Colors.grey,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _tipoTexto(String tipo) => switch (tipo) {
        'mesa' => 'Mesa',
        'domicilio' => 'Domicilio',
        'para_llevar' => 'Para llevar',
        'encargo' => 'Encargo',
        _ => tipo,
      };
}
