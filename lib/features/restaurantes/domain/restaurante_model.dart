class RestauranteModel {
  const RestauranteModel({
    required this.id,
    required this.nombre,
    this.descripcion,
    this.logoUrl,
    this.bannerUrl,
    required this.activo,
  });

  final String id;
  final String nombre;
  final String? descripcion;
  final String? logoUrl;
  final String? bannerUrl;
  final bool activo;

  factory RestauranteModel.fromJson(Map<String, dynamic> json) {
    return RestauranteModel(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      descripcion: json['descripcion'] as String?,
      logoUrl: json['logo_url'] as String?,
      bannerUrl: json['banner_url'] as String?,
      activo: json['activo'] as bool? ?? true,
    );
  }
}
