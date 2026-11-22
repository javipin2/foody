import 'dart:async';

import 'package:reserva_canchas/core/red/salud_repository.dart';
import 'package:reserva_canchas/services/app_backend.dart';

/// Poll de respaldo híbrido (R9 / RT-POLL-01): reevalúa salud RT en cada ciclo.
class PollRealtimeRespaldo {
  PollRealtimeRespaldo({required this.onActualizar});

  final Future<void> Function() onActualizar;

  Timer? _timer;
  bool _activo = false;

  /// Con RT operativo: respaldo ligero. Sin RT: más frecuente (OPT-05 / RT-FIX-03).
  static const intervaloRtOk = Duration(seconds: 90);
  static const intervaloRtCaido = Duration(seconds: 30);

  Future<void> iniciar() async {
    detener();
    _activo = true;
    await _programarSiguiente(ejecutarAhora: false);
  }

  void detener() {
    _activo = false;
    _timer?.cancel();
    _timer = null;
  }

  Future<Duration> _resolverIntervalo() async {
    if (!AppBackend.supabaseReady) return intervaloRtCaido;
    try {
      final s = await SaludRepository().verificarRealtime();
      if (!s.configurado || !s.conectado) return intervaloRtCaido;
      return intervaloRtOk;
    } catch (_) {
      return intervaloRtCaido;
    }
  }

  Future<void> _programarSiguiente({required bool ejecutarAhora}) async {
    if (!_activo) return;
    if (ejecutarAhora) {
      try {
        await onActualizar();
      } catch (_) {
        // ponytail: el poll no tumba la pantalla; reintenta en el próximo ciclo.
      }
    }
    if (!_activo) return;
    final intervalo = await _resolverIntervalo();
    if (!_activo) return;
    _timer?.cancel();
    _timer = Timer(intervalo, () {
      unawaited(_programarSiguiente(ejecutarAhora: true));
    });
  }
}
