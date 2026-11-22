/// Roles staff Foody — alineado con `foody_backend/src/core/auth/roles-food.ts`.
const rolGerenteCadena = 'gerente_cadena';

/// Usuario con alcance corporativo (todas las sedes del restaurante).
bool esCorporativoStaff({
  required String? rol,
  required List<String> permisos,
}) {
  return rol == rolGerenteCadena ||
      permisos.contains('gestionar_sucursales');
}

String etiquetaRolStaff(String? rol) {
  switch (rol) {
    case 'cocina':
      return 'Cocina';
    case rolGerenteCadena:
      return 'Gerente de cadena';
    case 'gerente':
      return 'Gerente';
    case 'cajero':
      return 'Cajero';
    case 'mesero':
      return 'Mesero';
    case 'domiciliario_planta':
      return 'Domiciliario planta';
    case 'admin':
      return 'Administrador';
    default:
      if (rol != null && rol.startsWith('cocina_')) return 'Cocina';
      return rol ?? '—';
  }
}
