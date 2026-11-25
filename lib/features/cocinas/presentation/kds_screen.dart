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
import 'package:reserva_canchas/services/app_backend.dart';

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
    this.repository,
  });

  /// Si es true se muestra como pantalla completa (rol cocina). Dentro del
  /// panel admin se incrusta sin AppBar propia.
  final bool standalone;

  /// Sucursal activa en panel admin (multi-sede). Si es null, usa la del JWT.
  final String? sucursalId;

  /// NAV-ADM2-09: desde embed admin → config cocinas.
  final VoidCallback? onIrConfigCocinas;
  final CocinasRepository? repository;

  @override
  State<KdsScreen> createState() => _KdsScreenState();
}

class _KdsScreenState extends State<KdsScreen> with WidgetsBindingObserver {
  ColorScheme get _scheme => Theme.of(context).colorScheme;

  late final _repo = widget.repository ?? CocinasRepository();
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
      final forzarKds = widget.standalone || sesion?.dashboard == 'cocina';
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
        // En la primera lectura no ocultar un error: una cocina vacía y una
        // API que no respondió deben tener estados visuales distintos.
        await _cargarTickets();
        await _suscribirRealtime(_cocinaId!);
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

  Future<void> _suscribirRealtime(String cocinaId) async {
    if (!AppBackend.supabaseReady) return;
    if (_canalCocina != null) {
      Supabase.instance.client.removeChannel(_canalCocina!);
      _canalCocina = null;
    }
    try {
      await _repo.prepararCanalRealtimeCocina(
        cocinaId: cocinaId,
        sucursalId: widget.sucursalId,
      );
      if (!mounted || _cocinaId != cocinaId || !AppBackend.supabaseReady) {
        return;
      }
      _canalCocina = FoodyRealtime.suscribirCocina(
        cocinaId,
        onActualizado: () => _cargarTickets(silencioso: true),
        onReconectado: () => _cargarTickets(silencioso: true),
      );
    } catch (_) {
      // El sondeo de respaldo mantiene operativo el KDS si el canal firmado
      // aún no está disponible o Supabase no puede abrir la suscripción.
      _canalCocina = null;
    }
  }

  Future<void> _cargarTickets({bool silencioso = false}) async {
    final cocinaId = _cocinaId;
    if (cocinaId == null) return;
    if (!silencioso && mounted) {
      setState(() => _refrescando = true);
    }
    try {
      final tickets = (await _repo.tickets(cocinaId)).toList();
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
    final texto =
        urgente ? (nota.isEmpty ? '[URGENTE]' : '[URGENTE] $nota') : nota;
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
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Reimprimir esta comanda?'),
        content: const Text(
          'Se enviará una copia física adicional a cocina. Verifica que la '
          'impresión anterior no esté en proceso para evitar duplicados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reimprimir'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
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
    final itemsPendientes = _itemsDe(ticket).where((item) {
      final estado = item['estado_cocina'] as String? ?? 'pendiente';
      return estado != 'listo' && estado != 'no_disponible';
    }).toList();
    var actualizados = 0;
    var omitidos = 0;
    Object? error;
    setState(() => _marcandoTodo.add(pedidoId));
    try {
      for (final item in itemsPendientes) {
        final itemId = item['item_id'] as String?;
        if (itemId == null || _itemsEnVuelo.contains(itemId)) {
          omitidos++;
          continue;
        }
        setState(() => _itemsEnVuelo.add(itemId));
        try {
          await _repo.cambiarEstadoItem(
            itemId: itemId,
            estadoCocina: 'listo',
          );
          actualizados++;
        } catch (e) {
          error = e;
          break;
        } finally {
          if (mounted) setState(() => _itemsEnVuelo.remove(itemId));
        }
      }
    } catch (e) {
      error = e;
    } finally {
      if (mounted) {
        await _cargarTickets();
        if (mounted) setState(() => _marcandoTodo.remove(pedidoId));
      }
    }
    if (!mounted) return;
    if (error != null || omitidos > 0) {
      final detalle = error == null
          ? 'Algunos ítems ya estaban en proceso o no tienen identificador.'
          : mensajeErrorHttp(error, contexto: 'marcar todo listo');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Se confirmaron $actualizados de ${itemsPendientes.length} ítems. '
            'Revisa los pendientes. $detalle',
          ),
          backgroundColor: AnaliticaTokens.alertas,
        ),
      );
      return;
    }
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
  }

  Future<void> _volverACocina(Map<String, dynamic> ticket) async {
    final pedidoId = ticket['pedido_id'] as String? ??
        ticket['numero_pedido'] as String? ??
        '';
    if (pedidoId.isEmpty || _marcandoTodo.contains(pedidoId)) return;
    final itemsListos = _itemsDe(ticket)
        .where((item) => item['estado_cocina'] == 'listo')
        .toList();
    var actualizados = 0;
    var omitidos = 0;
    Object? error;
    setState(() => _marcandoTodo.add(pedidoId));
    try {
      for (final item in itemsListos) {
        final itemId = item['item_id'] as String?;
        if (itemId == null || _itemsEnVuelo.contains(itemId)) {
          omitidos++;
          continue;
        }
        setState(() => _itemsEnVuelo.add(itemId));
        try {
          await _repo.cambiarEstadoItem(
            itemId: itemId,
            estadoCocina: 'preparando',
          );
          actualizados++;
        } catch (e) {
          error = e;
          break;
        } finally {
          if (mounted) setState(() => _itemsEnVuelo.remove(itemId));
        }
      }
    } catch (e) {
      error = e;
    } finally {
      if (mounted) {
        await _cargarTickets();
        if (mounted) setState(() => _marcandoTodo.remove(pedidoId));
      }
    }
    if (!mounted) return;
    if (error != null || omitidos > 0) {
      setState(() => _pestanaListos = false);
      final detalle = error == null
          ? 'Algunos ítems ya estaban en proceso o no tienen identificador.'
          : mensajeErrorHttp(error, contexto: 'volver a cocina');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Se devolvieron $actualizados de ${itemsListos.length} ítems. '
            'Revisa los pendientes. $detalle',
          ),
          backgroundColor: AnaliticaTokens.alertas,
        ),
      );
      return;
    }
    setState(() => _pestanaListos = false);
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
    final canvas =
        widget.standalone ? const Color(0xFF0F172A) : _scheme.surface;

    if (_cargandoInicial) {
      return ColoredBox(
        color: canvas,
        child: Center(
          child: CircularProgressIndicator(color: _scheme.onSurfaceVariant),
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
                      : _scheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.4,
                    color: widget.standalone ? Colors.white : _scheme.onSurface,
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
                        : _scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _inicializar,
                  style: FilledButton.styleFrom(
                    backgroundColor: _scheme.primary,
                    foregroundColor: _scheme.onPrimary,
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
                      : _scheme.onSurfaceVariant,
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
                    color: widget.standalone ? Colors.white : _scheme.onSurface,
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
                        : _scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                if (!widget.standalone && widget.onIrConfigCocinas != null)
                  FilledButton.icon(
                    onPressed: widget.onIrConfigCocinas,
                    style: FilledButton.styleFrom(
                      backgroundColor: _scheme.primary,
                      foregroundColor: _scheme.onPrimary,
                    ),
                    icon: const Icon(Icons.settings_outlined),
                    label: const Text('Configurar cocinas'),
                  )
                else
                  FilledButton(
                    onPressed: _inicializar,
                    style: FilledButton.styleFrom(
                      backgroundColor: _scheme.primary,
                      foregroundColor: _scheme.onPrimary,
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
              color: _scheme.onSurface,
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
                                          ? _scheme.onSurfaceVariant
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
                                        : _scheme.onSurface,
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
                                        : _scheme.onSurfaceVariant,
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
                        final cardW = (w - pad * 2 - gap * (cols - 1)) / cols;
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
                            : _scheme.onSurfaceVariant,
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
                                : _scheme.onSurfaceVariant),
                      ),
                    ),
                    selected: _cocinaId == c['id'],
                    selectedColor: _scheme.primary,
                    backgroundColor: overDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : _scheme.surfaceContainerLow,
                    showCheckmark: false,
                    side: BorderSide(
                      color: _cocinaId == c['id']
                          ? _scheme.onSurface
                          : (overDark
                              ? Colors.white24
                              : _scheme.outlineVariant),
                    ),
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) {
                      final id = c['id'] as String;
                      setState(() => _cocinaId = id);
                      unawaited(_suscribirRealtime(id));
                      unawaited(_cargarTickets(silencioso: true));
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
            : _scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: overDark ? Colors.white24 : _scheme.outlineVariant,
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
              accent: _scheme.onSurface,
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
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? (overDark ? Colors.white : _scheme.onSurface)
                        : (overDark
                            ? Colors.white60
                            : _scheme.onSurfaceVariant),
                  ),
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
                          : _scheme.outlineVariant.withValues(alpha: 0.5)),
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
                            : _scheme.onSurfaceVariant),
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
            : _scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: overDark ? Colors.white24 : _scheme.outlineVariant,
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
    return _scheme.onSurface;
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
    final pendientes = items.where((i) {
      final e = i['estado_cocina'] as String? ?? 'pendiente';
      return e != 'listo' && e != 'no_disponible';
    }).length;
    final pedidoKey =
        t['pedido_id'] as String? ?? t['numero_pedido'] as String? ?? '';
    final marcando = _marcandoTodo.contains(pedidoKey);

    return Material(
      color: _scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      elevation: 0,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: demorado
                ? _rojo.withValues(alpha: 0.45)
                : _scheme.outlineVariant,
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
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                fontFamily: 'monospace',
                                letterSpacing: -0.3,
                                color: _scheme.onSurface,
                              ),
                            ),
                          ),
                          if (modoListos)
                            _badgeAntiguedadPedido(t)
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
                          if (!modoListos && demorado) _chip('Demorado', _rojo),
                          if (!modoListos && avisado && !urgente)
                            _chip('Atención', _amber),
                          if (pagado) _chip('Cobrado', AnaliticaTokens.pedidos),
                          if (modoListos || todosListos) _chip('Listo', _verde),
                          _chip(etiqueta, _scheme.onSurfaceVariant),
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
                          style: TextStyle(
                            fontSize: 12.5,
                            fontStyle: FontStyle.italic,
                            color: _scheme.onSurfaceVariant,
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
                          key: const ValueKey<String>('kds-mark-all-ready'),
                          onPressed:
                              marcando ? null : () => _marcarTodoListo(t),
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
                          key: const ValueKey<String>('kds-return-to-kitchen'),
                          onPressed: marcando ? null : () => _volverACocina(t),
                          icon: marcando
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.undo, size: 16),
                          label: Text(
                            marcando ? 'Actualizando…' : 'Volver a cocina',
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: _scheme.onSurfaceVariant,
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
            : _scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color:
              demorado ? _rojo.withValues(alpha: 0.35) : _scheme.outlineVariant,
        ),
      ),
      child: Text(
        _fmtMinutos(minutos),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          fontFamily: 'monospace',
          color: demorado ? _rojo : _scheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _badgeAntiguedadPedido(Map<String, dynamic> ticket) {
    final creado = DateTime.tryParse('${ticket['created_at']}');
    if (creado == null) {
      return const Icon(Icons.check_circle, color: _verde, size: 20);
    }
    final minutos = DateTime.now().difference(creado.toLocal()).inMinutes;
    final revisar = minutos >= 24 * 60;
    final muyAntiguo = minutos >= 30 * 24 * 60;
    final color = muyAntiguo ? _rojo : (revisar ? _amber : _verde);
    final etiqueta = 'Pedido ${_fmtMinutos(minutos)}';
    final pedidoKey = ticket['numero_pedido']?.toString() ??
        ticket['pedido_id']?.toString() ??
        'sin-id';
    return Tooltip(
      message: revisar
          ? 'Antigüedad desde la creación; no indica cuánto lleva listo. Verifica el estado del pedido antes de reimprimir o devolverlo a cocina.'
          : 'Antigüedad desde la creación del pedido; no indica cuánto lleva listo.',
      child: Container(
        key: ValueKey<String>('kds-ready-order-age-$pedidoKey'),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              revisar ? Icons.schedule : Icons.check_circle,
              color: color,
              size: 16,
            ),
            const SizedBox(width: 5),
            Text(
              etiqueta,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
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
      _ => _scheme.onSurfaceVariant,
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
        color: _scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _scheme.outlineVariant),
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
                            ? _scheme.onSurfaceVariant
                            : _scheme.onSurface,
                      ),
                    ),
                    if (item['incluidos'] is List &&
                        (item['incluidos'] as List).isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '+ ${(item['incluidos'] as List).map((inc) {
                            final m = Map<String, dynamic>.from(inc as Map);
                            return '${m['cantidad']}× ${m['nombre']}';
                          }).join(', ')}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: _scheme.onSurfaceVariant,
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
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            fontSize: 12,
                            color: _scheme.onSurfaceVariant,
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
            Builder(
              builder: (context) {
                final botonListo = FilledButton(
                  onPressed:
                      enVuelo ? null : () => _cambiarEstado(itemId, 'listo'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _verde,
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(vertical: 12),
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
                          'Marcar listo',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                );
                final acciones = <Widget>[
                  IconButton.outlined(
                    tooltip: 'Preparando',
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    onPressed: enVuelo || estado == 'preparando'
                        ? null
                        : () => _cambiarEstado(itemId, 'preparando'),
                    icon: Icon(
                      Icons.local_fire_department,
                      color: estado == 'preparando'
                          ? _amber
                          : _scheme.onSurfaceVariant,
                    ),
                  ),
                  IconButton.outlined(
                    tooltip: itemUrgente ? 'Quitar urgente' : 'Marcar urgente',
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    onPressed: enVuelo
                        ? null
                        : () => _togglePrioridad(itemId, !itemUrgente),
                    icon: Icon(
                      Icons.priority_high,
                      color: itemUrgente ? _amber : _scheme.onSurfaceVariant,
                    ),
                  ),
                  IconButton.outlined(
                    tooltip: 'Nota cocina',
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    onPressed: enVuelo
                        ? null
                        : () => _editarObservacionesItem(itemId, obsItem),
                    icon: Icon(
                      Icons.sticky_note_2_outlined,
                      color: obsItem
                              .replaceFirst(RegExp(r'^\[URGENTE\]\s*'), '')
                              .isNotEmpty
                          ? AnaliticaTokens.pedidos
                          : _scheme.onSurfaceVariant,
                    ),
                  ),
                  IconButton.outlined(
                    tooltip: 'Fallo / No se pudo',
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    onPressed:
                        enVuelo ? null : () => _dialogoNoDisponible(itemId),
                    icon: const Icon(Icons.block, color: _rojo),
                  ),
                ];
                if (narrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      botonListo,
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Wrap(spacing: 4, children: acciones),
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(flex: 3, child: botonListo),
                    const SizedBox(width: 6),
                    ...acciones,
                  ],
                );
              },
            ),
          ] else if (!modoListos && estado == 'listo') ...[
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed:
                    enVuelo ? null : () => _cambiarEstado(itemId, 'pendiente'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: _scheme.onSurfaceVariant,
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
    if (h >= 24) {
      final dias = h ~/ 24;
      final horas = h % 24;
      return horas == 0 ? '${dias}d' : '${dias}d ${horas}h';
    }
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
  final _formKey = GlobalKey<FormState>();
  final _motivo = TextEditingController();
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  void _confirmar() {
    if (!_formKey.currentState!.validate()) {
      setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
      return;
    }
    Navigator.pop(context, _motivo.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Fallo de preparación'),
      content: Form(
        key: _formKey,
        autovalidateMode: _autovalidateMode,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Se registrará una alerta, una posible merma si el inventario '
              'ya se descontó y el producto dejará de ofrecerse en el menú.',
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey<String>('kds-motivo-fallo'),
              controller: _motivo,
              autofocus: true,
              maxLines: 2,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _confirmar(),
              validator: (value) => value?.trim().isNotEmpty == true
                  ? null
                  : 'Escribe el motivo para continuar.',
              decoration: const InputDecoration(
                labelText: 'Motivo (obligatorio)',
                hintText: 'Sin ingrediente, se quemó, agotado…',
                helperText: ' ',
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
          onPressed: _confirmar,
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
