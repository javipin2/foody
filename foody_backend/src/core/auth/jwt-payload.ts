export class JwtPayload {
  sub!: string;
  email!: string;
  rol!: string;
  sucursal_id!: string | null;
  restaurante_id!: string | null;
  permisos!: string[];
  ciudad_id?: string | null;
  /** Estación KDS asignada (solo rol cocina). */
  cocina_id?: string | null;
  /** Plan comercial del restaurante (basico | pro | enterprise). */
  plan?: string;
  /**
   * Versión de sesión (AUTH-FLOW/REV).
   * Debe coincidir con `usuarios.token_version` / `domiciliarios_independientes.token_version`.
   * Tokens viejos sin claim se tratan como `tv=1`.
   */
  tv?: number;
}
