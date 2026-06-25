import 'package:url_launcher/url_launcher.dart';

/// Abre Waze o Google Maps para navegación externa (sin costo API).
abstract final class UtilidadNavegacion {
  static Future<bool> abrir({
    required double lat,
    required double lng,
    String? etiqueta,
  }) async {
    final destino = '$lat,$lng';
    final waze = Uri.parse(
      'https://waze.com/ul?ll=$destino&navigate=yes',
    );
    if (await canLaunchUrl(waze)) {
      return launchUrl(waze, mode: LaunchMode.externalApplication);
    }

    final google = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$destino'
      '${etiqueta != null ? '&destination_place_id=${Uri.encodeComponent(etiqueta)}' : ''}',
    );
    return launchUrl(google, mode: LaunchMode.externalApplication);
  }
}
