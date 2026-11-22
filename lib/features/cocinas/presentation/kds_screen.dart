import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';
import 'package:reserva_canchas/core/realtime/foody_realtime.dart';
import 'package:reserva_canchas/core/realtime/poll_realtime_respaldo.dart';
import 'package:reserva_canchas/core/rutas/redireccion_staff.dart';
import 'package:reserva_canchas/core/sesion/sesion_staff_service.dart';
import 'package:reserva_canchas/core/widgets/foody_dialogo.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_tokens.dart';
import 'package:reserva_canchas/features/cocinas/data/cocinas_repository.dart';

/// Panel de cocina (KDS). Realtime + poll de respaldo.
///
/// Dos vistas: **Cocina** (pendientes) y **Listos** (ítems ya preparados).
/// Al marcar listo el ticket sale de Cocina y pasa a Listos.
class KdsScreen extends StatefulWidget {
  const KdsScreen({
    super.key,
    this.standalone = false,
    this.sucursalId,
    this.onIrConfigCocinas,
  });

  /// Si es true se muestra como pantalla completa (rol cocina). Dentro del
  /// panel admin se incrusta sin AppBar propia.
  final bool standalone;

  /// Sucursal activa en panel admin (multi-sede). Si es null, usa la del JWT.
  final String? sucursalId;

  /// NAV-ADM2-09: desde embed admin → config cocinas.
  final VoidCallback? onIrConfigCocinas;

  @override
  State<KdsScreen> createState() => _KdsScreenState();
}

class _KdsScreenState extends State<KdsScreen> with WidgetsBindingObserver {
  final _repo = CocinasRepository();
  List<Map<String, dynamic>> _cocinas = [];
  String? _cocinaId;
  List<Map<String, dynamic>> _tickets = [];
  bool _cargandoInicial = true;
  bool _refrescando = false;
  String? _error;
  Timer? _timerUi;
  PollRealtimeRespaldo? _pollRespaldo;
  final Set<String> _ticketsConocidos = {};
  RealtimeChannel? _canalCocina;
  final Set<String> _marcandoTodo = {};
  /// Lock UI por ítem (INFRA-EXT-UI-03): evita doble tap en Listo/Prep/etc.
  final Set<String> _itemsEnVuelo = {};
  /// false = Cocina (activos) · true = Listos
  bool _pestanaListos = false;

  static const _amber = Color(0xFFD97706);
  static const _rojo = Color(0xFFDC2626);
  static const _verde = Color(0xFF16A34A);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _inicializar();
    // ponytail: tick UI 30s para minutos en vivo sin martillar API
    _timerUi = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && _tickets.isNotEmpty) setState(() {});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      unawaited(_cargarTickets(silencioso: true));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollRespaldo?.detener();
    _timerUi?.cancel();
    if (_canalCocina != null) {
      Supabase.instance.client.removeChannel(_canalCocina!);
    }
    super.dispose();
  }

  Future<void> _inicializar() async {
    setState(() {
      _cargandoInicial = true;
      _error = null;
    });
    try {
      final sesion = await SesionStaffService.cargar();
      final forzarKds =
          widget.standalone || sesion?.dashboard == 'cocina';
      final cocinas = forzarKds || widget.sucursalId == null
          ? await _repo.cocinasParaKds()
          : await _repo.listarCocinas(widget.sucursalId!);
      if (!mounted) return;
      setState(() {
        _cocinas = cocinas;
        _cocinaId = cocinas.isNotEmpty ? cocinas.first['id'] as String : null;
        _cargandoInicial = false;
      });
      if (_cocinaId != null) {
        await _cargarTickets(silencioso: true);
        _suscribirRealtime(_cocinaId!);
        _pollRespaldo?.detener();
        _pollRespaldo = PollRealtimeRespaldo(
          onActualizar: () => _cargarTickets(silencioso: true),
        );
        unawaited(_pollRespaldo!.iniciar());
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargandoInicial = false;
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
      onReconectado: () => _cargarTickets(silencioso: true),
    );
  }

  Future<void> _cargarTickets({bool silencioso = false}) async {
    final cocinaId = _cocinaId;
    if (cocinaId == null) return;
    if (!silencioso && mounted) {
      setState(() => _refrescando = true);
    }
    try {
      final tickets = await _repo.tickets(cocinaId);
      if (!mounted) return;
      tickets.sort((a, b) {
        final ua = _prioridadSort(a);
        final ub = _prioridadSort(b);
        if (ua != ub) return ua.compareTo(ub);
        final ca = _cocinaDesde(a) ?? DateTime(2100);
        final cb = _cocinaDesde(b) ?? DateTime(2100);
        return ca.compareTo(cb);
      });
      final ids = tickets
          .map((t) =>
              t['pedido_id'] as String? ?? t['numero_pedido'] as String? ?? '')
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
        _refrescando = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _refrescando = false;
        if (!silencioso) {
          _error = mensajeErrorHttp(e, contexto: 'cargar tickets');
        }
      });
    }
  }

  /// 0 = urgente tag, 1 = demorado ≥20, 2 = avisado ≥10, 3 = resto
  int _prioridadSort(Map<String, dynamic> t) {
    if (_ticketUrgente(t)) return 0;
    final m = _minutosTicket(t);
    if (m >= 20) return 1;
    if (m >= 10) return 2;
    return 3;
  }

  Future<T?> _conLockItem<T>(
    String itemId,
    Future<T> Function() accion,
  ) async {
    if (_itemsEnVuelo.contains(itemId)) return null;
    setState(() => _itemsEnVuelo.add(itemId));
    try {
      return await accion();
    } finally {
      if (mounted) setState(() => _itemsEnVuelo.remove(itemId));
    }
  }

  Future<void> _cambiarEstado(
    String itemId,
    String estado, {
    String? motivo,
  }) async {
    await _conLockItem(itemId, () async {
      try {
        await _repo.cambiarEstadoItem(
          itemId: itemId,
          estadoCocina: estado,
          motivo: motivo,
        );
        await _cargarTickets(silencioso: true);
        if (!mounted) return;
        // Solo avisar si el ticket completo salió de Cocina.
        if (estado == 'listo' && !_pestanaListos) {
          Map<String, dynamic>? ticket;
          for (final t in _tickets) {
            if (_itemsDe(t).any((i) => i['item_id'] == itemId)) {
              ticket = t;
              break;
            }
          }
          if (ticket != null && _todoListo(ticket)) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Listo — pasó a la pestaña Listos'),
                action: SnackBarAction(
                  label: 'Ver',
                  onPressed: () => setState(() => _pestanaListos = true),
                ),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensajeErrorHttp(e, contexto: 'actualizar ítem')),
            backgroundColor: AnaliticaTokens.alertas,
          ),
        );
      }
    });
  }

  Future<void> _togglePrioridad(String itemId, bool urgente) async {
    await _conLockItem(itemId, () async {
      try {
        await _repo.marcarPrioridadItem(itemId: itemId, urgente: urgente);
        await _cargarTickets(silencioso: true);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensajeErrorHttp(e, contexto: 'prioridad')),
            backgroundColor: AnaliticaTokens.alertas,
          ),
        );
      }
    });
  }

  Future<void> _editarObservacionesItem(
    String itemId,
    String obsActual,
  ) async {
    final urgente = obsActual.contains('[URGENTE]');
    final base = obsActual.replaceFirst(RegExp(r'^\[URGENTE\]\s*'), '');
    final resultado = await FoodyDialogo.mostrar<String>(
      context: context,
      builder: (ctx) => _DialogoObservacionItem(inicial: base),
    );
    if (resultado == null) return;
    final nota = resultado.trim();
    final texto = urgente
        ? (nota.isEmpty ? '[URGENTE]' : '[URGENTE] $nota')
        : nota;
    await _conLockItem(itemId, () async {
      try {
        await _repo.actualizarObservacionesItem(
          itemId: itemId,
          observaciones: texto,
        );
        await _cargarTickets(silencioso: true);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensajeErrorHttp(e, contexto: 'observaciones')),
            backgroundColor: AnaliticaTokens.alertas,
          ),
        );
      }
    });
  }

  Future<void> _reimprimir(Map<String, dynamic> ticket) async {
    final pedidoId = ticket['pedido_id'] as String?;
    if (pedidoId == null || pedidoId.isEmpty) return;
    try {
      await _repo.reimprimirPedido(
        pedidoId: pedidoId,
        sucursalId: widget.sucursalId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comanda enviada a reimprimir')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensajeErrorHttp(e, contexto: 'reimprimir')),
          backgroundColor: AnaliticaTokens.alertas,
        ),
      );
    }
  }

  Future<void> _marcarTodoListo(Map<String, dynamic> ticket) async {
    final pedidoId = ticket['pedido_id'] as String? ??
        ticket['numero_pedido'] as String? ??
        '';
    if (pedidoId.isEmpty || _marcandoTodo.contains(pedidoId)) return;
    setState(() => _marcandoTodo.add(pedidoId));
    try {
      for (final item in _itemsDe(ticket)) {
        final estado = item['estado_cocina'] as String? ?? 'pendiente';
        if (estado == 'listo' || estado == 'no_disponible') continue;
        final itemId = item['item_id'] as String?;
        if (itemId == null) continue;
        if (_itemsEnVuelo.contains(itemId)) continue;
        setState(() => _itemsEnVuelo.add(itemId));
        try {
          await _repo.cambiarEstadoItem(
            itemId: itemId,
            estadoCocina: 'listo',
          );
        } finally {
          if (mounted) setState(() => _itemsEnVuelo.remove(itemId));
        }
      }
      await _cargarTickets(silencioso: true);
      if (!mounted) return;
      if (!_pestanaListos) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Ticket listo — pasó a Listos'),
            action: SnackBarAction(
              label: 'Ver',
              onPressed: () => setState(() => _pestanaListos = true),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensajeErrorHttp(e, contexto: 'marcar todo listo')),
          backgroundColor: AnaliticaTokens.alertas,
        ),
      );
    } finally {
      if (mounted) setState(() => _marcandoTodo.remove(pedidoId));
    }
  }

  Future<void> _cerrarSesion() async {
    await cerrarSesionStaff(context);
  }

  String? get _nombreEstacion {
    if (_cocinaId == null) return null;
    for (final c in _cocinas) {
      if (c['id'] == _cocinaId) return c['nombre'] as String?;
    }
    return null;
  }

  int get _demorados =>
      _tickets.where((t) => _minutosTicket(t) >= 20 && !_todoListo(t)).length;

  List<Map<String, dynamic>> get _ticketsCocina =>
      _tickets.where((t) => !_todoListo(t)).toList();

  List<Map<String, dynamic>> get _ticketsListos {
    final listos = _tickets.where((t) => _todoListo(t)).toList();
    listos.sort((a, b) {
      final ca = _cocinaDesde(a) ?? DateTime(1970);
      final cb = _cocinaDesde(b) ?? DateTime(1970);
      return cb.compareTo(ca);
    });
    return listos;
  }

  List<Map<String, dynamic>> get _ticketsVista =>
      _pestanaListos ? _ticketsListos : _ticketsCocina;

  @override
  Widget build(BuildContext context) {
    final cuerpo = _cuerpo();
    if (!widget.standalone) return cuerpo;
    final estacion = _nombreEstacion;
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Panel de cocina', style: TextStyle(fontSize: 18)),
            if (estacion != null && estacion.isNotEmpty)
              Text(
                'Estación: $estacion',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w400,
                ),
              ),
          ],
        ),
        actions: [
          if (_refrescando)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white70,
                ),
              ),
            )
          else
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
    final canvas = widget.standalone
        ? const Color(0xFF0F172A)
        : AnaliticaTokens.canvas;

    if (_cargandoInicial) {
      return ColoredBox(
        color: canvas,
        child: const Center(
          child: CircularProgressIndicator(color: AnaliticaTokens.inkMuted),
        ),
      );
    }
    if (_error != null) {
      return ColoredBox(
        color: canvas,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_off_outlined,
                  size: 48,
                  color: widget.standalone
                      ? Colors.white38
                      : AnaliticaTokens.inkSoft,
                ),
                const SizedBox(height: 16),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.4,
                    color: widget.standalone ? Colors.white : AnaliticaTokens.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Si no tienes estación asignada, pide al administrador que te vincule a una cocina.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: widget.standalone
                        ? Colors.white70
                        : AnaliticaTokens.inkMuted,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _inicializar,
                  style: FilledButton.styleFrom(
                    backgroundColor: AnaliticaTokens.ink,
                  ),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (_cocinas.isEmpty) {
      return ColoredBox(
        color: canvas,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.soup_kitchen_outlined,
                  size: 48,
                  color: widget.standalone
                      ? Colors.white38
                      : AnaliticaTokens.inkSoft,
                ),
                const SizedBox(height: 16),
                Text(
                  widget.standalone
                      ? 'Sin estación de cocina asignada'
                      : 'No hay cocinas activas en esta sucursal',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: widget.standalone
                        ? Colors.white
                        : AnaliticaTokens.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.standalone
                      ? 'Contacta al administrador para que te asigne una cocina en Usuarios.'
                      : 'Crea al menos una cocina (y asígnala a productos) para ver tickets aquí.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: widget.standalone
                        ? Colors.white70
                        : AnaliticaTokens.inkMuted,
                  ),
                ),
                const SizedBox(height: 20),
                if (!widget.standalone && widget.onIrConfigCocinas != null)
                  FilledButton.icon(
                    onPressed: widget.onIrConfigCocinas,
                    style: FilledButton.styleFrom(
                      backgroundColor: AnaliticaTokens.ink,
                    ),
                    icon: const Icon(Icons.settings_outlined),
                    label: const Text('Configurar cocinas'),
                  )
                else
                  FilledButton(
                    onPressed: _inicializar,
                    style: FilledButton.styleFrom(
                      backgroundColor: AnaliticaTokens.ink,
                    ),
                    child: const Text('Reintentar'),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return ColoredBox(
      color: canvas,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _barraSuperior(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _cargarTickets(),
              color: AnaliticaTokens.ink,
              child: _ticketsVista.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.sizeOf(context).height * 0.4,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _pestanaListos
                                      ? Icons.dinner_dining_outlined
                                      : Icons.check_circle_outline,
                                  size: 56,
                                  color: widget.standalone
                                      ? Colors.white38
                                      : (_pestanaListos
                                          ? AnaliticaTokens.inkSoft
                                          : AnaliticaTokens.inventario),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _pestanaListos
                                      ? 'Sin platos listos'
                                      : 'Nada en cocina',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: widget.standalone
                                        ? Colors.white
                                        : AnaliticaTokens.ink,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _pestanaListos
                                      ? 'Cuando marques Listo, aparecerán aquí'
                                      : 'Esperando pedidos — desliza para refrescar',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: widget.standalone
                                        ? Colors.white70
                                        : AnaliticaTokens.inkMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final w = constraints.maxWidth;
                        final gap = 12.0;
                        final cols = w >= 1400
                            ? 4
                            : w >= 1000
                                ? 3
                                : w >= 640
                                    ? 2
                                    : 1;
                        final pad = 12.0;
                        final cardW =
                            (w - pad * 2 - gap * (cols - 1)) / cols;
                        return SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                          child: Wrap(
                            spacing: gap,
                            runSpacing: gap,
                            children: [
                              for (final t in _ticketsVista)
                                SizedBox(
                                  width: cardW,
                                  child: _ticketCard(
                                    t,
                                    narrow: cols == 1 || cardW < 300,
                                    modoListos: _pestanaListos,
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _barraSuperior() {
    final overDark = widget.standalone;
    final nCocina = _ticketsCocina.length;
    final nListos = _ticketsListos.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _pestanasCocinaListos(
                  overDark: overDark,
                  nCocina: nCocina,
                  nListos: nListos,
                ),
              ),
              IconButton(
                tooltip: 'Refrescar',
                onPressed: _refrescando ? null : () => _cargarTickets(),
                visualDensity: VisualDensity.compact,
                icon: _refrescando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        Icons.refresh,
                        color: overDark
                            ? Colors.white70
                            : AnaliticaTokens.inkMuted,
                      ),
              ),
            ],
          ),
          if (!_pestanaListos && _demorados > 0) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: _pillStat(
                '$_demorados demorados (≥20 min)',
                _rojo,
                overDark,
              ),
            ),
          ],
          if (_cocinas.length > 1) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in _cocinas)
                  FilterChip(
                    label: Text(
                      c['nombre'] as String? ?? '—',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: _cocinaId == c['id']
                            ? Colors.white
                            : (overDark
                                ? Colors.white70
                                : AnaliticaTokens.inkMuted),
                      ),
                    ),
                    selected: _cocinaId == c['id'],
                    selectedColor: AnaliticaTokens.ink,
                    backgroundColor: overDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : AnaliticaTokens.surface,
                    showCheckmark: false,
                    side: BorderSide(
                      color: _cocinaId == c['id']
                          ? AnaliticaTokens.ink
                          : (overDark
                              ? Colors.white24
                              : AnaliticaTokens.border),
                    ),
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) {
                      final id = c['id'] as String;
                      setState(() => _cocinaId = id);
                      _suscribirRealtime(id);
                      _cargarTickets(silencioso: true);
                    },
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _pestanasCocinaListos({
    required bool overDark,
    required int nCocina,
    required int nListos,
  }) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: overDark
            ? Colors.white.withValues(alpha: 0.08)
            : AnaliticaTokens.surfaceMuted,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: overDark ? Colors.white24 : AnaliticaTokens.border,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _pestanaBtn(
              label: 'Cocina',
              count: nCocina,
              selected: !_pestanaListos,
              overDark: overDark,
              accent: AnaliticaTokens.ink,
              onTap: () => setState(() => _pestanaListos = false),
            ),
          ),
          Expanded(
            child: _pestanaBtn(
              label: 'Listos',
              count: nListos,
              selected: _pestanaListos,
              overDark: overDark,
              accent: _verde,
              onTap: () => setState(() => _pestanaListos = true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pestanaBtn({
    required String label,
    required int count,
    required bool selected,
    required bool overDark,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected
          ? (overDark ? accent.withValues(alpha: 0.85) : Colors.white)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? (overDark ? Colors.white : AnaliticaTokens.ink)
                      : (overDark ? Colors.white60 : AnaliticaTokens.inkMuted),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: selected
                      ? (overDark
                          ? Colors.white.withValues(alpha: 0.2)
                          : accent.withValues(alpha: 0.12))
                      : (overDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : AnaliticaTokens.border.withValues(alpha: 0.5)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'monospace',
                    color: selected
                        ? (overDark ? Colors.white : accent)
                        : (overDark
                            ? Colors.white54
                            : AnaliticaTokens.inkMuted),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pillStat(String texto, Color color, bool overDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: overDark
            ? Colors.white.withValues(alpha: 0.08)
            : AnaliticaTokens.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: overDark ? Colors.white24 : AnaliticaTokens.border,
        ),
      ),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _itemsDe(Map<String, dynamic> t) {
    final raw = t['items'];
    if (raw is! List) return const [];
    final out = <Map<String, dynamic>>[];
    for (final e in raw) {
      if (e is! Map) continue;
      out.add(Map<String, dynamic>.from(e));
    }
    return out;
  }

  bool _todoListo(Map<String, dynamic> t) {
    final items = _itemsDe(t);
    if (items.isEmpty) return false;
    // Fuera de cocina: todos listos o no_disponible (ya no hay que preparar).
    return items.every((i) {
      final e = i['estado_cocina'] as String? ?? 'pendiente';
      return e == 'listo' || e == 'no_disponible';
    });
  }

  int _minutosTicket(Map<String, dynamic> t) {
    final desde = _cocinaDesde(t);
    if (desde == null) return 0;
    return DateTime.now().difference(desde.toLocal()).inMinutes;
  }

  Color _franjaUrgencia({
    required int minutos,
    required bool urgente,
    required bool todosListos,
  }) {
    if (todosListos) return _verde;
    if (urgente) return _amber;
    if (minutos >= 20) return _rojo;
    if (minutos >= 10) return _amber;
    return AnaliticaTokens.ink;
  }

  Widget _ticketCard(
    Map<String, dynamic> t, {
    required bool narrow,
    bool modoListos = false,
  }) {
    final items = _itemsDe(t);
    final mesa = t['mesa_nombre'] as String?;
    final tipo = t['tipo'] as String? ?? '';
    final cliente = t['cliente_nombre'] as String?;
    final obsPedido = t['observaciones'] as String?;
    final estadoPedido = t['estado'] as String? ?? '';
    final etiqueta = mesa != null
        ? 'Mesa $mesa'
        : (cliente?.trim().isNotEmpty == true
            ? cliente!.trim()
            : _tipoTexto(tipo));
    final todosListos = _todoListo(t);
    final minutos = _minutosTicket(t);
    final demorado = minutos >= 20 && !todosListos;
    final avisado = minutos >= 10 && minutos < 20 && !todosListos;
    final urgente = _ticketUrgente(t) && !todosListos;
    final pagado = estadoPedido == 'pagado';
    final franja = _franjaUrgencia(
      minutos: minutos,
      urgente: urgente,
      todosListos: todosListos,
    );
    final pendientes = items
        .where((i) {
          final e = i['estado_cocina'] as String? ?? 'pendiente';
          return e != 'listo' && e != 'no_disponible';
        })
        .length;
    final pedidoKey = t['pedido_id'] as String? ??
        t['numero_pedido'] as String? ??
        '';
    final marcando = _marcandoTodo.contains(pedidoKey);

    return Material(
      color: AnaliticaTokens.surface,
      borderRadius: BorderRadius.circular(12),
      elevation: 0,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: demorado
                ? _rojo.withValues(alpha: 0.45)
                : AnaliticaTokens.border,
            width: demorado ? 1.5 : 1,
          ),
          boxShadow: AnaliticaTokens.shadowSoft,
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 5,
                decoration: BoxDecoration(
                  color: franja,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(12),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              t['numero_pedido'] as String? ?? '—',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                fontFamily: 'monospace',
                                letterSpacing: -0.3,
                                color: AnaliticaTokens.ink,
                              ),
                            ),
                          ),
                          if (modoListos)
                            const Icon(Icons.check_circle,
                                color: _verde, size: 20)
                          else
                            _badgeTiempo(minutos, demorado: demorado),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (!modoListos && urgente) _chip('URGENTE', _amber),
                          if (!modoListos && demorado)
                            _chip('Demorado', _rojo),
                          if (!modoListos && avisado && !urgente)
                            _chip('Atención', _amber),
                          if (pagado) _chip('Cobrado', AnaliticaTokens.pedidos),
                          if (modoListos || todosListos)
                            _chip('Listo', _verde),
                          _chip(etiqueta, AnaliticaTokens.inkMuted),
                        ],
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => _reimprimir(t),
                          icon: const Icon(Icons.print_outlined, size: 18),
                          label: const Text('Reimprimir'),
                        ),
                      ),
                      if (obsPedido?.trim().isNotEmpty == true) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Nota: ${obsPedido!.trim()}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontStyle: FontStyle.italic,
                            color: AnaliticaTokens.inkMuted,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      for (final item in items) ...[
                        _itemFila(
                          item,
                          narrow: narrow,
                          modoListos: modoListos,
                        ),
                        const SizedBox(height: 6),
                      ],
                      if (!modoListos && pendientes > 1) ...[
                        const SizedBox(height: 4),
                        FilledButton.icon(
                          onPressed: marcando
                              ? null
                              : () => _marcarTodoListo(t),
                          style: FilledButton.styleFrom(
                            backgroundColor: _verde,
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: marcando
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.done_all, size: 18),
                          label: Text('Todo listo ($pendientes)'),
                        ),
                      ],
                      if (modoListos) ...[
                        const SizedBox(height: 2),
                        TextButton.icon(
                          onPressed: () async {
                            for (final item in items) {
                              if (item['estado_cocina'] != 'listo') continue;
                              final id = item['item_id'] as String?;
                              if (id == null) continue;
                              await _repo.cambiarEstadoItem(
                                itemId: id,
                                estadoCocina: 'preparando',
                              );
                            }
                            await _cargarTickets(silencioso: true);
                            if (!mounted) return;
                            setState(() => _pestanaListos = false);
                          },
                          icon: const Icon(Icons.undo, size: 16),
                          label: const Text('Volver a cocina'),
                          style: TextButton.styleFrom(
                            foregroundColor: AnaliticaTokens.inkMuted,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badgeTiempo(int minutos, {required bool demorado}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: demorado
            ? _rojo.withValues(alpha: 0.12)
            : AnaliticaTokens.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: demorado
              ? _rojo.withValues(alpha: 0.35)
              : AnaliticaTokens.border,
        ),
      ),
      child: Text(
        _fmtMinutos(minutos),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          fontFamily: 'monospace',
          color: demorado ? _rojo : AnaliticaTokens.inkMuted,
        ),
      ),
    );
  }

  Widget _chip(String texto, Color color) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 160),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        texto,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _itemFila(
    Map<String, dynamic> item, {
    required bool narrow,
    bool modoListos = false,
  }) {
    final estado = item['estado_cocina'] as String? ?? 'pendiente';
    final color = switch (estado) {
      'preparando' => _amber,
      'listo' => _verde,
      'no_disponible' => _rojo,
      _ => AnaliticaTokens.inkSoft,
    };
    final itemId = item['item_id']?.toString();
    if (itemId == null || itemId.isEmpty) {
      return const SizedBox.shrink();
    }
    final cerrado = estado == 'listo' || estado == 'no_disponible';
    final obsItem = item['observaciones'] as String? ?? '';
    final itemUrgente = obsItem.contains('[URGENTE]');
    final enVuelo = _itemsEnVuelo.contains(itemId);

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 6, 8),
      decoration: BoxDecoration(
        color: AnaliticaTokens.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AnaliticaTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 5),
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${item['cantidad']}× ${item['producto'] ?? ''}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        decoration: cerrado ? TextDecoration.lineThrough : null,
                        color: cerrado
                            ? AnaliticaTokens.inkSoft
                            : AnaliticaTokens.ink,
                      ),
                    ),
                    if (item['incluidos'] is List &&
                        (item['incluidos'] as List).isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '+ ${(item['incluidos'] as List).map((inc) {
                            final m =
                                Map<String, dynamic>.from(inc as Map);
                            return '${m['cantidad']}× ${m['nombre']}';
                          }).join(', ')}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AnaliticaTokens.inkMuted,
                          ),
                        ),
                      ),
                    if ((item['observaciones'] as String?)?.isNotEmpty == true)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          item['observaciones'] as String,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontStyle: FontStyle.italic,
                            fontSize: 12,
                            color: AnaliticaTokens.inkMuted,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (modoListos)
                Text(
                  estado == 'no_disponible' ? 'N/D' : 'OK',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: estado == 'no_disponible' ? _rojo : _verde,
                  ),
                ),
            ],
          ),
          if (!modoListos && !cerrado) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: FilledButton(
                    onPressed: enVuelo
                        ? null
                        : () => _cambiarEstado(itemId, 'listo'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _verde,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: enVuelo
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Listo',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton.outlined(
                  tooltip: 'Preparando',
                  onPressed: enVuelo || estado == 'preparando'
                      ? null
                      : () => _cambiarEstado(itemId, 'preparando'),
                  icon: Icon(
                    Icons.local_fire_department,
                    color: estado == 'preparando'
                        ? _amber
                        : AnaliticaTokens.inkMuted,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                IconButton.outlined(
                  tooltip: itemUrgente ? 'Quitar urgente' : 'Marcar urgente',
                  onPressed: enVuelo
                      ? null
                      : () => _togglePrioridad(itemId, !itemUrgente),
                  icon: Icon(
                    Icons.priority_high,
                    color: itemUrgente ? _amber : AnaliticaTokens.inkMuted,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                IconButton.outlined(
                  tooltip: 'Nota cocina',
                  onPressed: enVuelo
                      ? null
                      : () => _editarObservacionesItem(itemId, obsItem),
                  icon: Icon(
                    Icons.sticky_note_2_outlined,
                    color: obsItem.replaceFirst(RegExp(r'^\[URGENTE\]\s*'), '').isNotEmpty
                        ? AnaliticaTokens.pedidos
                        : AnaliticaTokens.inkMuted,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                IconButton.outlined(
                  tooltip: 'Fallo / No se pudo',
                  onPressed: enVuelo ? null : () => _dialogoNoDisponible(itemId),
                  icon: const Icon(Icons.block, color: _rojo),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ] else if (!modoListos && estado == 'listo') ...[
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: enVuelo
                    ? null
                    : () => _cambiarEstado(itemId, 'pendiente'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: AnaliticaTokens.inkMuted,
                ),
                child: const Text('Reabrir'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _dialogoNoDisponible(String itemId) async {
    final motivo = await FoodyDialogo.mostrar<String>(
      context: context,
      builder: (ctx) => const _DialogoNoDisponible(),
    );
    if (motivo == null) return;
    await _conLockItem(itemId, () async {
      try {
        await _repo.falloPreparacion(itemId: itemId, motivo: motivo);
        await _cargarTickets(silencioso: true);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensajeErrorHttp(e, contexto: 'fallo preparación')),
            backgroundColor: AnaliticaTokens.alertas,
          ),
        );
      }
    });
  }

  /// Tiempo desde que el ítem entró a esta cocina (no desde crear el pedido).
  DateTime? _cocinaDesde(Map<String, dynamic> ticket) {
    final raw = ticket['cocina_desde'];
    if (raw != null) {
      final d = DateTime.tryParse('$raw');
      if (d != null) return d;
    }
    DateTime? min;
    for (final rawItem in ticket['items'] as List<dynamic>? ?? []) {
      final m = Map<String, dynamic>.from(rawItem as Map);
      final ca = DateTime.tryParse('${m['created_at']}');
      if (ca == null) continue;
      if (min == null || ca.isBefore(min)) min = ca;
    }
    if (min != null) return min;
    final legacy = ticket['created_at'];
    return legacy != null ? DateTime.tryParse('$legacy') : null;
  }

  String _fmtMinutos(int minutos) {
    if (minutos < 0) return '0 min';
    if (minutos < 60) return '$minutos min';
    final h = minutos ~/ 60;
    final m = minutos % 60;
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  String _tipoTexto(String tipo) => switch (tipo) {
        'mesa' => 'Mesa',
        'domicilio' => 'Domicilio',
        'para_llevar' => 'Para llevar',
        'encargo' => 'Encargo',
        _ => tipo,
      };

  bool _ticketUrgente(Map<String, dynamic> ticket) {
    final items = ticket['items'] as List<dynamic>? ?? [];
    for (final raw in items) {
      final obs = (raw as Map)['observaciones'] as String? ?? '';
      if (obs.contains('[URGENTE]')) return true;
    }
    return false;
  }
}

class _DialogoNoDisponible extends StatefulWidget {
  const _DialogoNoDisponible();

  @override
  State<_DialogoNoDisponible> createState() => _DialogoNoDisponibleState();
}

class _DialogoNoDisponibleState extends State<_DialogoNoDisponible> {
  final _motivo = TextEditingController();

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Fallo de preparación'),
      content: TextField(
        controller: _motivo,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Motivo (obligatorio)',
          hintText: 'Sin ingrediente, se quemó, agotado…',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _motivo.text.trim()),
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}

class _DialogoObservacionItem extends StatefulWidget {
  const _DialogoObservacionItem({required this.inicial});

  final String inicial;

  @override
  State<_DialogoObservacionItem> createState() =>
      _DialogoObservacionItemState();
}

class _DialogoObservacionItemState extends State<_DialogoObservacionItem> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.inicial);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nota de cocina'),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        maxLines: 3,
        decoration: const InputDecoration(
          labelText: 'Observación del ítem',
          hintText: 'Sin cebolla, bien asado…',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _ctrl.text),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
