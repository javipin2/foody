export class JwtPayload {
  sub!: string;
  email!: string;
  rol!: string;
  sucursal_id!: string | null;
  restaurante_id!: string | null;
  permisos!: string[];
  ciudad_id?: string | null;
  /** Plan comercial del restaurante (basico | pro | enterprise). */
  plan?: string;
}
