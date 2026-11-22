import {
  BadRequestException,
  ConflictException,
  Injectable,
} from '@nestjs/common';
import { DatabaseService } from '../database/database.service';

export type OrigenRestaurante = 'manual' | 'self_service';
export type PlanOnboarding = 'gratis' | 'basico' | 'pro' | 'enterprise';
export type EstadoSuscripcionOnboarding = 'activa' | 'prueba';
export type ProveedorAuth = 'correo' | 'google';

export interface OnboardingRestauranteInput {
  ciudad_id: string;
  nombre_restaurante: string;
  nombre_sucursal: string;
  direccion_sucursal?: string | null;
  admin_nombre: string;
  admin_email: string;
  hash_contrasena?: string | null;
  proveedor_auth?: ProveedorAuth;
  proveedor_id?: string | null;
  email_verificado?: boolean;
  origen?: OrigenRestaurante;
  plan?: PlanOnboarding;
  estado_suscripcion?: EstadoSuscripcionOnboarding;
  dias_prueba?: number;
}

export interface OnboardingRestauranteResult {
  restaurante_id: string;
  sucursal_id: string;
  admin_id: string;
  admin_email: string;
  suscripcion: {
    estado: string;
    plan: string;
    dias_prueba?: number;
  };
}

@Injectable()
export class OnboardingRestauranteService {
  constructor(private readonly database: DatabaseService) {}

  async crear(dto: OnboardingRestauranteInput): Promise<OnboardingRestauranteResult> {
    const ciudad = await this.database.consultarUno<{ id: string; slug: string }>(
      `SELECT id, slug FROM ciudades WHERE id = $1 AND activa = true`,
      [dto.ciudad_id],
    );
    if (!ciudad) throw new BadRequestException('Ciudad no válida');

    const centroCiudad = this.centroCiudadPorSlug(ciudad.slug);

    const email = dto.admin_email.trim().toLowerCase();
    const existeEmail = await this.database.consultarUno<{ id: string }>(
      `SELECT id FROM usuarios WHERE LOWER(email) = $1`,
      [email],
    );
    if (existeEmail) {
      throw new ConflictException('El correo ya está registrado');
    }

    const origen = dto.origen ?? 'manual';
    const plan = dto.plan ?? 'basico';
    const estado = dto.estado_suscripcion ?? 'prueba';
    const proveedor = dto.proveedor_auth ?? 'correo';
    const diasPrueba = dto.dias_prueba ?? 14;

    if (proveedor === 'correo' && !dto.hash_contrasena) {
      throw new BadRequestException('La contraseña es obligatoria para registro por correo');
    }

    const fechaVencimiento = new Date();
    if (plan === 'gratis') {
      fechaVencimiento.setTime(Date.parse('2099-12-31T23:59:59.000Z'));
    } else if (estado === 'prueba') {
      fechaVencimiento.setDate(fechaVencimiento.getDate() + diasPrueba);
    } else {
      fechaVencimiento.setDate(fechaVencimiento.getDate() + 30);
    }

    return this.database.enTransaccion(async (client) => {
      const rest = await client.query<{ id: string }>(
        `INSERT INTO restaurantes (ciudad_id, nombre, activo, origen)
         VALUES ($1, $2, true, $3) RETURNING id`,
        [dto.ciudad_id, dto.nombre_restaurante.trim(), origen],
      );
      const restauranteId = rest.rows[0].id;

      const suc = await client.query<{ id: string }>(
        `INSERT INTO sucursales (
           restaurante_id, ciudad_id, nombre, direccion, lat, lng, activa
         ) VALUES ($1, $2, $3, $4, $5, $6, true) RETURNING id`,
        [
          restauranteId,
          dto.ciudad_id,
          dto.nombre_sucursal.trim(),
          dto.direccion_sucursal?.trim() ?? null,
          centroCiudad?.lat ?? null,
          centroCiudad?.lng ?? null,
        ],
      );
      const sucursalId = suc.rows[0].id;

      await client.query(
        `INSERT INTO cocinas (sucursal_id, nombre) VALUES ($1, 'Cocina principal')`,
        [sucursalId],
      );

      await client.query(
        `INSERT INTO suscripciones_restaurante (
           restaurante_id, estado, plan, fecha_vencimiento
         ) VALUES ($1, $2, $3, $4)`,
        [restauranteId, estado, plan, fechaVencimiento],
      );

      const admin = await client.query<{ id: string }>(
        `INSERT INTO usuarios (
           id, sucursal_id, restaurante_id, nombre, email, rol, activo,
           hash_contrasena, proveedor_auth, proveedor_id, email_verificado
         ) VALUES (
           gen_random_uuid(), $1, $2, $3, $4, 'admin', true,
           $5, $6, $7, $8
         ) RETURNING id`,
        [
          sucursalId,
          restauranteId,
          dto.admin_nombre.trim(),
          email,
          dto.hash_contrasena ?? null,
          proveedor,
          dto.proveedor_id ?? null,
          dto.email_verificado ?? proveedor === 'google',
        ],
      );

      return {
        restaurante_id: restauranteId,
        sucursal_id: sucursalId,
        admin_id: admin.rows[0].id,
        admin_email: email,
        ciudad_slug: ciudad.slug,
        suscripcion: {
          estado,
          plan,
          ...(estado === 'prueba' ? { dias_prueba: diasPrueba } : {}),
        },
      };
    }).then(async (resultado) => {
      // VIRAL-FIX-03: zona + horarios×7 fuera del TX crítico (menos hold de pool).
      await this.completarPostCommit(resultado.sucursal_id, resultado.ciudad_slug);
      const { ciudad_slug: _slug, ...out } = resultado;
      return out;
    });
  }

  /** ponytail: best-effort; alta ya committed si esto falla. */
  private async completarPostCommit(sucursalId: string, ciudadSlug: string) {
    try {
      const centro = this.centroCiudadPorSlug(ciudadSlug);
      if (centro) {
        await this.database.consultar(
          `INSERT INTO zonas_cobertura (sucursal_id, nombre, costo_domicilio, distancia_max_km, activa)
           SELECT $1, 'Zona centro', 4000, 5, true
           WHERE NOT EXISTS (
             SELECT 1 FROM zonas_cobertura WHERE sucursal_id = $1
           )`,
          [sucursalId],
        );
      }
      await this.database.consultar(
        `INSERT INTO horarios_sucursal (sucursal_id, dia_semana, hora_apertura, hora_cierre, activo)
         SELECT $1, d, '08:00', '22:00', true
         FROM generate_series(0, 6) AS d
         WHERE NOT EXISTS (
           SELECT 1 FROM horarios_sucursal WHERE sucursal_id = $1
         )`,
        [sucursalId],
      );
    } catch {
      // no tumbar alta; admin puede configurar sede después
    }
  }

  private centroCiudadPorSlug(slug: string) {
    const centros: Record<string, { lat: number; lng: number }> = {
      valledupar: { lat: 10.463714, lng: -73.253222 },
    };
    return centros[slug.toLowerCase()] ?? null;
  }
}
