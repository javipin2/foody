class LoginResultado {
  const LoginResultado({
    required this.dashboard,
    required this.rol,
    required this.permisos,
    required this.usuario,
    this.plan = 'basico',
    this.modulos = const [],
    this.estadoCuenta,
  });

  final String dashboard;
  final String rol;
  final List<String> permisos;
  final Map<String, dynamic> usuario;
  final String plan;
  final List<String> modulos;
  final String? estadoCuenta;
}
