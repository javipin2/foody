import 'package:latlong2/latlong.dart';

/// Tiles OpenStreetMap (gratuitos; atribución en UI).
abstract final class ConstantesMapa {
  static const urlTiles =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  static const atribucion = '© OpenStreetMap';

  /// Valledupar, Colombia — fallback si no hay GPS ni sucursal.
  static const LatLng ubicacionDefault = LatLng(10.4631, -73.2532);

  static const double zoomInicial = 15;
  static const double zoomDetalle = 16;
}
