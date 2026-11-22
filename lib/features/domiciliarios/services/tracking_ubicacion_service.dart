import 'dart:async';

import 'package:geolocator/geolocator.dart';

/// Envía GPS del repartidor al backend cada [intervalo] mientras esté activo.
class TrackingUbicacionService {
  Timer? _timer;

  Future<bool> _permisoOk() async {
    var permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }
    return permiso == LocationPermission.always ||
        permiso == LocationPermission.whileInUse;
  }

  void iniciar(
    Future<void> Function(double lat, double lng) enviar, {
    Duration intervalo = const Duration(seconds: 20),
  }) {
    detener();

    Future<void> tick() async {
      try {
        if (!await _permisoOk()) return;
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
        );
        await enviar(pos.latitude, pos.longitude);
      } catch (_) {
        // Sin GPS o sin red — reintenta en el siguiente ciclo.
      }
    }

    unawaited(tick());
    _timer = Timer.periodic(intervalo, (_) => tick());
  }

  void detener() {
    _timer?.cancel();
    _timer = null;
  }
}
