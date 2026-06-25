import 'package:dio/dio.dart';
import 'package:reserva_canchas/core/modelos/respuesta_api.dart';
import 'package:reserva_canchas/core/red/cliente_dio.dart';

class ResultadoGeografia {
  const ResultadoGeografia({
    required this.etiqueta,
    required this.lat,
    required this.lng,
  });

  final String etiqueta;
  final double lat;
  final double lng;

  factory ResultadoGeografia.fromJson(Map<String, dynamic> json) {
    return ResultadoGeografia(
      etiqueta: json['etiqueta'] as String? ?? '',
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
    );
  }
}

/// Búsqueda de direcciones vía NestJS → Photon (OpenStreetMap).
class GeografiaRepository {
  GeografiaRepository({Dio? dio})
      : _dio = dio ?? ClienteDio.instancia();

  final Dio _dio;

  Future<List<ResultadoGeografia>> buscar(
    String consulta, {
    double? lat,
    double? lng,
  }) async {
    final respuesta = await _dio.get<Map<String, dynamic>>(
      '/geografia/buscar',
      queryParameters: {
        'q': consulta,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
      },
    );
    final data = respuesta.data;
    if (data == null) throw Exception('Respuesta vacía');

    final envoltura = RespuestaApi<List<dynamic>>.fromJson(
      data,
      (raw) => raw as List<dynamic>,
    );
    if (!envoltura.exito || envoltura.datos == null) {
      throw Exception(envoltura.mensaje);
    }

    return envoltura.datos!
        .map((e) => ResultadoGeografia.fromJson(
              Map<String, dynamic>.from(e as Map<String, dynamic>),
            ))
        .toList();
  }
}
