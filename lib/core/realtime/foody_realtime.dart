import 'dart:async';

import 'package:reserva_canchas/core/realtime/evento_dedup.dart';
import 'package:reserva_canchas/core/sesion/sesion_staff_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Evento sintético cuando varios broadcasts de sucursal llegan en la misma ventana.
const eventoSucursalCoalesced = 'sucursal_actualizada';

/// Suscripciones Realtime vía broadcast (backend emite con service key; RLS bloquea postgres_changes).
///
/// Staff usa topics HMAC (`realtime_canales` del login). Catálogo y seguimiento pedido
/// siguen públicos (RT-SEC-01).
class FoodyRealtime {
  FoodyRealtime._();

  static const _debounceMsDefault = 300;

  /// Cache de topics firmados (login / refresh / GET realtime-canales).
  static Map<String, String> _canalesStaff = {};

  static final _pendienteSucursal = <String, Set<String>>{};
  static final _timerSucursal = <String, Timer>{};

  static final _timerCocina = <String, Timer>{};
  static final _timerPedido = <String, Timer>{};
  static final _timerDomPlanta = <String, Timer>{};
  static final _timerDomIndep = <String, Timer>{};

  /// Eventos de sucursal que deben re-emitirse tras coalesce (pantallas con filtro).
  static const _reemitirTrasCoalesce = {
    'pedido_actualizado',
    'mesas_actualizadas',
    'caja_movimiento',
    'alerta_nueva',
    'qr_aprobacion_urgente',
    'catalogo_disponibilidad',
    'llamar_mesera',
  };

  static void aplicarCanalesStaff(Map<String, String> canales) {
    _canalesStaff = Map<String, String>.from(canales);
  }

  static void limpiarCanalesStaff() {
    _canalesStaff = {};
  }

  /// Carga topics desde prefs (hot restart / cold start).
  static Future<void> hidratarCanalesDesdeSesion() async {
    aplicarCanalesStaff(await SesionStaffService.obtenerRealtimeCanales());
  }

  static String canalCatalogo(String sucursalId) => 'sucursal_${sucursalId}_catalogo';

  static String canalPedidoSeguimiento(String pedidoId, String seguimientoToken) =>
      'pedido_${pedidoId}_$seguimientoToken';

  static String _topicStaff(String clave, String prefijo, String id) {
    final t = _canalesStaff[clave];
    if (t != null && t.startsWith('${prefijo}_${id}_')) return t;
    // No caer al topic adivinable (abriría RT-SEC-01 otra vez).
    throw StateError(
      'RT-SEC: sin canal staff "$clave" para $id — vuelve a iniciar sesión',
    );
  }

  static void _debounce(
    Map<String, Timer> timers,
    String key,
    int debounceMs,
    void Function() ejecutar,
  ) {
    timers[key]?.cancel();
    timers[key] = Timer(Duration(milliseconds: debounceMs), () {
      timers.remove(key);
      ejecutar();
    });
  }

  static void _encolarSucursal(
    String sucursalId,
    String evento,
    void Function(String evento) onEvento, {
    int debounceMs = _debounceMsDefault,
  }) {
    final lote = _pendienteSucursal.putIfAbsent(sucursalId, () => {});
    lote.add(evento);
    _timerSucursal[sucursalId]?.cancel();
    _timerSucursal[sucursalId] = Timer(Duration(milliseconds: debounceMs), () {
      final batch = _pendienteSucursal.remove(sucursalId) ?? {};
      _timerSucursal.remove(sucursalId);
      if (batch.isEmpty) return;
      if (batch.length == 1) {
        onEvento(batch.first);
        return;
      }
      onEvento(eventoSucursalCoalesced);
      for (final ev in _reemitirTrasCoalesce) {
        if (batch.contains(ev)) onEvento(ev);
      }
    });
  }

  static void _dispatchSiNuevo(
    String evento,
    Map<String, dynamic> payload,
    void Function(String evento) dispatch,
  ) {
    if (EventoDedup.esDuplicado(payload)) return;
    dispatch(evento);
  }

  /// RT-RECON: callback tras corte (error/timeout/closed) + re-subscribe.
  static void Function(RealtimeSubscribeStatus, [Object?]) _onStatus(
    void Function()? onReconectado,
  ) {
    var huboCorte = false;
    return (status, [error]) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        if (huboCorte) {
          huboCorte = false;
          onReconectado?.call();
        }
      } else if (status == RealtimeSubscribeStatus.channelError ||
          status == RealtimeSubscribeStatus.timedOut ||
          status == RealtimeSubscribeStatus.closed) {
        huboCorte = true;
      }
    };
  }

  /// Menú cliente / POS: solo disponibilidad de productos (topic público).
  static RealtimeChannel suscribirCatalogo(
    String sucursalId, {
    required void Function() onCatalogoActualizado,
    void Function()? onReconectado,
    int debounceMs = _debounceMsDefault,
  }) {
    return Supabase.instance.client
        .channel(canalCatalogo(sucursalId))
        .onBroadcast(
          event: 'catalogo_disponibilidad',
          callback: (payload) {
            if (EventoDedup.esDuplicado(Map<String, dynamic>.from(payload))) {
              return;
            }
            _debounce(
              _timerSucursal,
              'cat_$sucursalId',
              debounceMs,
              onCatalogoActualizado,
            );
          },
        )
        .subscribe(_onStatus(onReconectado));
  }

  /// Kanban admin, grid de mesas, caja, alertas, etc. (topic HMAC staff).
  static RealtimeChannel suscribirSucursal(
    String sucursalId, {
    required void Function(String evento) onEvento,
    void Function()? onReconectado,
    int debounceMs = _debounceMsDefault,
  }) {
    void dispatch(String evento) =>
        _encolarSucursal(sucursalId, evento, onEvento, debounceMs: debounceMs);

    void recibir(String evento, Map<String, dynamic> payload) =>
        _dispatchSiNuevo(evento, payload, dispatch);

    final topic = _topicStaff('sucursal', 'sucursal', sucursalId);

    return Supabase.instance.client
        .channel(topic)
        .onBroadcast(
          event: 'pedido_actualizado',
          callback: (p) =>
              recibir('pedido_actualizado', Map<String, dynamic>.from(p)),
        )
        .onBroadcast(
          event: 'mesas_actualizadas',
          callback: (p) =>
              recibir('mesas_actualizadas', Map<String, dynamic>.from(p)),
        )
        .onBroadcast(
          event: 'caja_movimiento',
          callback: (p) =>
              recibir('caja_movimiento', Map<String, dynamic>.from(p)),
        )
        .onBroadcast(
          event: 'alerta_nueva',
          callback: (p) => recibir('alerta_nueva', Map<String, dynamic>.from(p)),
        )
        .onBroadcast(
          event: 'qr_aprobacion_urgente',
          callback: (p) =>
              recibir('qr_aprobacion_urgente', Map<String, dynamic>.from(p)),
        )
        .onBroadcast(
          event: 'catalogo_disponibilidad',
          callback: (p) =>
              recibir('catalogo_disponibilidad', Map<String, dynamic>.from(p)),
        )
        .onBroadcast(
          event: 'llamar_mesera',
          callback: (p) => recibir('llamar_mesera', Map<String, dynamic>.from(p)),
        )
        .subscribe(_onStatus(onReconectado));
  }

  /// Seguimiento público del pedido (cliente) — canal opaco RT-9.
  static RealtimeChannel suscribirPedido(
    String pedidoId,
    String seguimientoToken, {
    required void Function() onEstadoActualizado,
    void Function(Map<String, dynamic> payload)? onUbicacionRepartidor,
    void Function()? onReconectado,
    int debounceMs = _debounceMsDefault,
  }) {
    return Supabase.instance.client
        .channel(canalPedidoSeguimiento(pedidoId, seguimientoToken))
        .onBroadcast(
          event: 'estado_actualizado',
          callback: (payload) {
            final map = Map<String, dynamic>.from(payload);
            if (EventoDedup.esDuplicado(map)) return;
            _debounce(
              _timerPedido,
              pedidoId,
              debounceMs,
              onEstadoActualizado,
            );
          },
        )
        .onBroadcast(
          event: 'ubicacion_repartidor',
          callback: (payload) {
            final map = Map<String, dynamic>.from(payload);
            if (EventoDedup.esDuplicado(map)) return;
            if (onUbicacionRepartidor != null) {
              onUbicacionRepartidor(map);
            }
          },
        )
        .subscribe(_onStatus(onReconectado));
  }

  /// Panel KDS — tickets e ítems de cocina.
  static RealtimeChannel suscribirCocina(
    String cocinaId, {
    required void Function() onActualizado,
    void Function()? onReconectado,
    int debounceMs = _debounceMsDefault,
  }) {
    final topic = _topicStaff('cocina', 'cocina', cocinaId);
    return Supabase.instance.client
        .channel(topic)
        .onBroadcast(
          event: 'cocina_actualizada',
          callback: (_) => _debounce(
            _timerCocina,
            cocinaId,
            debounceMs,
            onActualizado,
          ),
        )
        .subscribe(_onStatus(onReconectado));
  }

  /// Panel admin: plan/suscripción tras pago Wompi.
  static RealtimeChannel suscribirRestaurante(
    String restauranteId, {
    required void Function() onSuscripcionActualizada,
    void Function()? onReconectado,
    int debounceMs = _debounceMsDefault,
  }) {
    final topic = _topicStaff('restaurante', 'restaurante', restauranteId);
    return Supabase.instance.client
        .channel(topic)
        .onBroadcast(
          event: 'suscripcion_actualizada',
          callback: (_) => _debounce(
            _timerSucursal,
            'sus_$restauranteId',
            debounceMs,
            onSuscripcionActualizada,
          ),
        )
        .subscribe(_onStatus(onReconectado));
  }

  /// Domiciliario de planta (JWT sub = usuario staff).
  static RealtimeChannel suscribirDomiciliarioPlanta(
    String usuarioId, {
    required void Function() onActualizado,
    required void Function() onDesasignado,
    void Function()? onReconectado,
    int debounceMs = _debounceMsDefault,
  }) {
    final topic = _topicStaff('domiciliario', 'domiciliario', usuarioId);
    return Supabase.instance.client
        .channel(topic)
        .onBroadcast(
          event: 'pedido_asignado',
          callback: (_) => _debounce(
            _timerDomPlanta,
            usuarioId,
            debounceMs,
            onActualizado,
          ),
        )
        .onBroadcast(
          event: 'pedido_desasignado',
          callback: (_) => _debounce(
            _timerDomPlanta,
            '${usuarioId}_des',
            debounceMs,
            onDesasignado,
          ),
        )
        .subscribe(_onStatus(onReconectado));
  }

  /// Domiciliario independiente (JWT sub = id repartidor).
  static RealtimeChannel suscribirDomiciliarioIndep(
    String domiciliarioId, {
    required void Function() onActualizado,
    required void Function() onOfertaExpirada,
    void Function()? onReconectado,
    int debounceMs = _debounceMsDefault,
  }) {
    final topic =
        _topicStaff('domiciliario_indep', 'domiciliario_indep', domiciliarioId);
    return Supabase.instance.client
        .channel(topic)
        .onBroadcast(
          event: 'oferta_nueva',
          callback: (_) => _debounce(
            _timerDomIndep,
            domiciliarioId,
            debounceMs,
            onActualizado,
          ),
        )
        .onBroadcast(
          event: 'oferta_expirada',
          callback: (_) => _debounce(
            _timerDomIndep,
            '${domiciliarioId}_exp',
            debounceMs,
            onOfertaExpirada,
          ),
        )
        .subscribe(_onStatus(onReconectado));
  }

  /// Cierra y libera el canal (unsubscribe solo no basta — RT-LEAK-01).
  static Future<void> liberarCanal(RealtimeChannel? canal) async {
    if (canal == null) return;
    await Supabase.instance.client.removeChannel(canal);
  }
}
