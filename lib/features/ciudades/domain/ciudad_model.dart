class CiudadModel {
  final String id;
  final String nombre;
  final String slug;
  final bool activa;

  const CiudadModel({
    required this.id,
    required this.nombre,
    required this.slug,
    this.activa = true,
  });

  factory CiudadModel.fromJson(Map<String, dynamic> json) {
    return CiudadModel(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      slug: json['slug'] as String,
      activa: json['activa'] as bool? ?? true,
    );
  }
}
