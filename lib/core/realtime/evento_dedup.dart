/// Deduplica broadcasts repetidos por `event_id` (ventana corta).
class EventoDedup {
  EventoDedup._();

  static const _ttl = Duration(seconds: 12);
  static final _vistos = <String, DateTime>{};

  /// true si ya se procesó este event_id recientemente.
  static bool esDuplicado(Map<String, dynamic> payload) {
    final id = payload['event_id']?.toString();
    if (id == null || id.isEmpty) return false;
    final ahora = DateTime.now();
    _vistos.removeWhere((_, t) => ahora.difference(t) > _ttl);
    if (_vistos.containsKey(id)) return true;
    _vistos[id] = ahora;
    return false;
  }
}
