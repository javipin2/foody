/// Respuesta estándar del backend Foody.
class RespuestaApi<T> {
  final bool exito;
  final T? datos;
  final String mensaje;

  const RespuestaApi({
    required this.exito,
    this.datos,
    required this.mensaje,
  });

  factory RespuestaApi.fromJson(
    Map<String, dynamic> json,
    T Function(Object? json) convertirDatos,
  ) {
    return RespuestaApi(
      exito: json['exito'] == true,
      datos: json['datos'] != null ? convertirDatos(json['datos']) : null,
      mensaje: json['mensaje']?.toString() ?? '',
    );
  }
}
