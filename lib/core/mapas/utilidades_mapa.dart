import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Utilidades geográficas para mapas Foody (sin APIs de pago).
abstract final class UtilidadesMapa {
  static const _radioTierraKm = 6371.0;

  /// Puntos de un círculo geodésico (anillo de cobertura en km).
  static List<LatLng> puntosCirculo(
    double latCentro,
    double lngCentro,
    double radioKm, {
    int pasos = 72,
  }) {
    final puntos = <LatLng>[];
    final latRad = _aRad(latCentro);
    final lngRad = _aRad(lngCentro);
    final angular = radioKm / _radioTierraKm;

    for (var i = 0; i <= pasos; i++) {
      final rumbo = (i / pasos) * 360;
      final rumboRad = _aRad(rumbo);
      final lat2 = math.asin(
        math.sin(latRad) * math.cos(angular) +
            math.cos(latRad) * math.sin(angular) * math.cos(rumboRad),
      );
      final lng2 = lngRad +
          math.atan2(
            math.sin(rumboRad) * math.sin(angular) * math.cos(latRad),
            math.cos(angular) - math.sin(latRad) * math.sin(lat2),
          );
      puntos.add(LatLng(_aDeg(lat2), _aDeg(lng2)));
    }
    return puntos;
  }

  static double _aRad(double g) => g * math.pi / 180;
  static double _aDeg(double r) => r * 180 / math.pi;
}
