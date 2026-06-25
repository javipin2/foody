class SucursalModel {
  const SucursalModel({
    required this.id,
    required this.nombre,
    this.direccion,
    required this.activa,
    required this.ciudadId,
  });

  final String id;
  final String nombre;
  final String? direccion;
  final bool activa;
  final String ciudadId;

  factory SucursalModel.fromJson(Map<String, dynamic> json) {
    return SucursalModel(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      direccion: json['direccion'] as String?,
      activa: json['activa'] as bool? ?? true,
      ciudadId: json['ciudad_id'] as String,
    );
  }
}
