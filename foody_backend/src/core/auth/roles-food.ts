/** Rol staff con alcance corporativo (todas las sucursales del restaurante). */
export const ROL_GERENTE_CADENA = 'gerente_cadena';

/** Dueño/corporativo o admin inicial con permiso de cadena. */
export function esAdminRestaurante(rol: string): boolean {
  return rol === 'admin' || rol === ROL_GERENTE_CADENA;
}

/** Rol de estación KDS (`cocina` o legado `cocina_*`). */
export function esRolCocina(rol: string): boolean {
  return rol === 'cocina' || rol.startsWith('cocina_');
}
