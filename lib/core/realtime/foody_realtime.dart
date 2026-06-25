import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Evento sintético cuando varios broadcasts de sucursal llegan en la misma ventana.
const eventoSucursalCoalesced = 'sucursal_actualizada';

/// Suscripciones Realtime vía broadcast (backend emite con service key; RLS bloquea postgres_changes).
class FoodyRealtime {
  FoodyRealtime._();

  static const _debounceMsDefault = 300;

  static final _pendienteSucursal = <String, Set<String>>{};
  static final _timerSucursal = <String, Timer>{};

  static final _timerCocina = <String, Timer>{};
  static final _timerPedido = <String, Timer>{};
  static final _timerDomPlanta = <String, Timer>{};
  static final _timerDomIndep = <String, Timer>{};

  static String canalSucursal(String sucursalId) => 'sucursal_$sucursalId';

  static String canalPedido(String pedidoId) => 'pedido_$pedidoId';

  static String canalCocina(String cocinaId) => 'cocina_$cocinaId';

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
      if (batch.contains('caja_movimiento')) onEvento('caja_movimiento');
      if (batch.contains('alerta_nueva')) onEvento('alerta_nueva');
      if (batch.contains('qr_aprobacion_urgente')) {
        onEvento('qr_aprobacion_urgente');
      }
      if (batch.contains('catalogo_disponibilidad')) {
        onEvento('catalogo_disponibilidad');
      }
    });
  }

  /// Menú cliente / POS: solo disponibilidad de productos.
  static RealtimeChannel suscribirCatalogo(
    String sucursalId, {
    required void Function() onCatalogoActualizado,
    int debounceMs = _debounceMsDefault,
  }) {
    return Supabase.instance.client
        .channel('${canalSucursal(sucursalId)}_catalogo')
        .onBroadcast(
          event: 'catalogo_disponibilidad',
          callback: (_) => _debounce(
            _timerSucursal,
            'cat_$sucursalId',
            debounceMs,
            onCatalogoActualizado,
          ),
        )
        .subscribe();
  }

  /// Kanban admin, grid de mesas, caja, alertas, etc.
  static RealtimeChannel suscribirSucursal(
    String sucursalId, {
    required void Function(String evento) onEvento,
    int debounceMs = _debounceMsDefault,
  }) {
    void dispatch(String evento) =>
        _encolarSucursal(sucursalId, evento, onEvento, debounceMs: debounceMs);

    return Supabase.instance.client
        .channel(canalSucursal(sucursalId))
        .onBroadcast(
          event: 'pedido_actualizado',
          callback: (_) => dispatch('pedido_actualizado'),
        )
        .onBroadcast(
          event: 'mesas_actualizadas',
          callback: (_) => dispatch('mesas_actualizadas'),
        )
        .onBroadcast(
          event: 'caja_movimiento',
          callback: (_) => dispatch('caja_movimiento'),
        )
        .onBroadcast(
          event: 'alerta_nueva',
          callback: (_) => dispatch('alerta_nueva'),
        )
        .onBroadcast(
          event: 'qr_aprobacion_urgente',
          callback: (_) => dispatch('qr_aprobacion_urgente'),
        )
        .onBroadcast(
          event: 'catalogo_disponibilidad',
          callback: (_) => dispatch('catalogo_disponibilidad'),
        )
        .subscribe();
  }

  /// Seguimiento público del pedido (cliente).
  static RealtimeChannel suscribirPedido(
    String pedidoId, {
    required void Function() onEstadoActualizado,
    int debounceMs = _debounceMsDefault,
  }) {
    return Supabase.instance.client
        .channel(canalPedido(pedidoId))
        .onBroadcast(
          event: 'estado_actualizado',
          callback: (_) => _debounce(
            _timerPedido,
            pedidoId,
            debounceMs,
            onEstadoActualizado,
          ),
        )
        .subscribe();
  }

  /// Panel KDS — tickets e ítems de cocina.
  static RealtimeChannel suscribirCocina(
    String cocinaId, {
    required void Function() onActualizado,
    int debounceMs = _debounceMsDefault,
  }) {
    return Supabase.instance.client
        .channel(canalCocina(cocinaId))
        .onBroadcast(
          event: 'cocina_actualizada',
          callback: (_) => _debounce(
            _timerCocina,
            cocinaId,
            debounceMs,
            onActualizado,
          ),
        )
        .subscribe();
  }

  /// Domiciliario de planta (JWT sub = usuario staff).
  static RealtimeChannel suscribirDomiciliarioPlanta(
    String usuarioId, {
    required void Function() onActualizado,
    int debounceMs = _debounceMsDefault,
  }) {
    return Supabase.instance.client
        .channel('domiciliario_$usuarioId')
        .onBroadcast(
          event: 'pedido_asignado',
          callback: (_) => _debounce(
            _timerDomPlanta,
            usuarioId,
            debounceMs,
            onActualizado,
          ),
        )
        .subscribe();
  }

  /// Domiciliario independiente (JWT sub = id repartidor).
  static RealtimeChannel suscribirDomiciliarioIndep(
    String domiciliarioId, {
    required void Function() onActualizado,
    int debounceMs = _debounceMsDefault,
  }) {
    return Supabase.instance.client
        .channel('domiciliario_indep_$domiciliarioId')
        .onBroadcast(
          event: 'oferta_nueva',
          callback: (_) => _debounce(
            _timerDomIndep,
            domiciliarioId,
            debounceMs,
            onActualizado,
          ),
        )
        .subscribe();
  }
}
