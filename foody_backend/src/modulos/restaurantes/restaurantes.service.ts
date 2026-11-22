import { Injectable, NotFoundException, ForbiddenException, BadRequestException } from '@nestjs/common';
import { DatabaseService } from '../../core/database/database.service';
import { PlanFeaturesService } from '../../core/auth/plan-features.service';
import { MenuCacheService } from '../../core/cache/menu-cache.service';
import { ActualizarHorarioDto } from './dto/actualizar-horario.dto';
import { ActualizarMargenesSucursalDto } from './dto/actualizar-margenes-sucursal.dto';
import { ActualizarSucursalDto } from './dto/actualizar-sucursal.dto';
import { CrearSucursalDto } from './dto/crear-sucursal.dto';

@Injectable()
export class RestaurantesService {
  constructor(
    private readonly database: DatabaseService,
    private readonly planFeatures: PlanFeaturesService,
    private readonly menuCache: MenuCacheService,
  ) {}

  async listarSucursales(restauranteId: string) {
    const existe = await this.database.consultarUno<{ id: string }>(
      `SELECT id FROM restaurantes WHERE id = $1 AND activo = true`,
      [restauranteId],
    );
    if (!existe) {
      throw new NotFoundException('Restaurante no encontrado');
    }

    return this.database.consultar(
      `SELECT s.id, s.nombre, s.direccion, s.telefono, s.lat, s.lng, s.activa,
              s.ciudad_id, c.nombre AS ciudad_nombre
       FROM sucursales s
       LEFT JOIN ciudades c ON c.id = s.ciudad_id
       WHERE s.restaurante_id = $1
       ORDER BY s.activa DESC, s.nombre ASC`,
      [restauranteId],
    );
  }

  async listarSucursalesStaff(restauranteId: string, usuarioRestauranteId: string) {
    if (restauranteId !== usuarioRestauranteId) {
      throw new ForbiddenException('No puedes ver sucursales de otro restaurante');
    }
    return this.listarSucursales(restauranteId);
  }

  async crearSucursal(
    restauranteId: string,
    usuarioRestauranteId: string,
    dto: CrearSucursalDto,
  ) {
    if (restauranteId !== usuarioRestauranteId) {
      throw new ForbiddenException('No puedes crear sucursales en otro restaurante');
    }

    await this.planFeatures.assertLimiteSucursales(restauranteId);

    const restaurante = await this.database.consultarUno<{
      id: string;
      ciudad_id: string;
    }>(
      `SELECT id, ciudad_id FROM restaurantes WHERE id = $1 AND activo = true`,
      [restauranteId],
    );
    if (!restaurante) throw new NotFoundException('Restaurante no encontrado');

    const ciudadId = dto.ciudad_id ?? restaurante.ciudad_id;

    return this.database.enTransaccion(async (client) => {
      const insert = await client.query<{ id: string }>(
        `INSERT INTO sucursales (
           restaurante_id, ciudad_id, nombre, direccion, telefono, activa
         ) VALUES ($1, $2, $3, $4, $5, true)
         RETURNING id`,
        [
          restauranteId,
          ciudadId,
          dto.nombre.trim(),
          dto.direccion?.trim() ?? null,
          dto.telefono?.trim() ?? null,
        ],
      );
      const sucursalId = insert.rows[0].id;

      await client.query(
        `INSERT INTO cocinas (sucursal_id, nombre) VALUES ($1, 'Cocina principal')`,
        [sucursalId],
      );

      await client.query(
        `INSERT INTO horarios_sucursal (sucursal_id, dia_semana, hora_apertura, hora_cierre, activo)
         SELECT $1, d, '08:00', '22:00', true FROM generate_series(0, 6) AS d`,
        [sucursalId],
      );

      return {
        id: sucursalId,
        nombre: dto.nombre.trim(),
        restaurante_id: restauranteId,
        ciudad_id: ciudadId,
      };
    });
  }

  /** CFG-PATCH-SUCURSAL-01: editar nombre/dir/tel/activa de una sede propia. */
  async actualizarSucursal(
    restauranteId: string,
    sucursalId: string,
    dto: ActualizarSucursalDto,
  ) {
    const campos: string[] = [];
    const valores: unknown[] = [sucursalId, restauranteId];
    let i = 2;

    if (dto.nombre !== undefined) {
      campos.push(`nombre = $${++i}`);
      valores.push(dto.nombre.trim());
    }
    if (dto.direccion !== undefined) {
      campos.push(`direccion = $${++i}`);
      valores.push(
        dto.direccion === null ? null : dto.direccion.trim() || null,
      );
    }
    if (dto.telefono !== undefined) {
      campos.push(`telefono = $${++i}`);
      valores.push(
        dto.telefono === null ? null : dto.telefono.trim() || null,
      );
    }
    if (dto.activa !== undefined) {
      campos.push(`activa = $${++i}`);
      valores.push(dto.activa);
    }
    if (!campos.length) {
      throw new BadRequestException('Nada que actualizar');
    }

    const fila = await this.database.consultarUno<{
      id: string;
      nombre: string;
      direccion: string | null;
      telefono: string | null;
      activa: boolean;
    }>(
      `UPDATE sucursales SET ${campos.join(', ')}
       WHERE id = $1 AND restaurante_id = $2
       RETURNING id, nombre, direccion, telefono, activa`,
      valores,
    );
    if (!fila) throw new NotFoundException('Sucursal no encontrada');
    void this.menuCache.invalidar(sucursalId);
    return fila;
  }

  private async exigirSucursalDelRestaurante(
    sucursalId: string,
    restauranteId: string,
  ) {
    const sucursal = await this.database.consultarUno<{ id: string }>(
      `SELECT id FROM sucursales
       WHERE id = $1 AND restaurante_id = $2 AND activa = true`,
      [sucursalId, restauranteId],
    );
    if (!sucursal) {
      throw new NotFoundException('Sucursal no encontrada');
    }
    return sucursal;
  }

  async listarHorarios(sucursalId: string, restauranteId: string) {
    await this.exigirSucursalDelRestaurante(sucursalId, restauranteId);
    return this.database.consultar(
      `SELECT id, dia_semana, hora_apertura::text, hora_cierre::text, activo
       FROM horarios_sucursal
       WHERE sucursal_id = $1
       ORDER BY dia_semana ASC`,
      [sucursalId],
    );
  }

  async actualizarHorario(
    horarioId: string,
    restauranteId: string,
    dto: ActualizarHorarioDto,
  ) {
    const fila = await this.database.consultarUno<{
      id: string;
      sucursal_id: string;
      dia_semana: number;
      hora_apertura: string;
      hora_cierre: string;
      activo: boolean;
    }>(
      `UPDATE horarios_sucursal h
       SET hora_apertura = COALESCE($2::time, h.hora_apertura),
           hora_cierre = COALESCE($3::time, h.hora_cierre),
           activo = COALESCE($4, h.activo)
       FROM sucursales s
       WHERE h.id = $1
         AND h.sucursal_id = s.id
         AND s.restaurante_id = $5
       RETURNING h.id, h.sucursal_id, h.dia_semana,
                 h.hora_apertura::text, h.hora_cierre::text, h.activo`,
      [
        horarioId,
        dto.hora_apertura ?? null,
        dto.hora_cierre ?? null,
        dto.activo ?? null,
        restauranteId,
      ],
    );
    if (!fila) {
      throw new NotFoundException('Horario no encontrado');
    }
    // Sin esto el cliente sigue viendo cerrado/abierto hasta ~5 min (TTL menú).
    await this.menuCache.invalidar(fila.sucursal_id);
    const { sucursal_id: _sid, ...horario } = fila;
    return horario;
  }

  async obtenerMarca(restauranteId: string) {
    const fila = await this.database.consultarUno<{
      id: string;
      nombre: string;
      telefono: string | null;
      descripcion: string | null;
      logo_url: string | null;
      banner_url: string | null;
    }>(
      `SELECT id, nombre, telefono, descripcion, logo_url, banner_url
       FROM restaurantes WHERE id = $1`,
      [restauranteId],
    );
    if (!fila) throw new NotFoundException('Restaurante no encontrado');
    return fila;
  }

  async actualizarMarca(
    restauranteId: string,
    dto: {
      nombre?: string;
      telefono?: string | null;
      logo_url?: string | null;
      banner_url?: string | null;
      descripcion?: string | null;
    },
  ) {
    const campos: string[] = [];
    const valores: unknown[] = [];
    let i = 1;
    if (dto.nombre !== undefined) {
      const n = dto.nombre.trim();
      if (!n) {
        throw new BadRequestException('El nombre de marca no puede quedar vacío');
      }
      campos.push(`nombre = $${i++}`);
      valores.push(n);
    }
    if (dto.telefono !== undefined) {
      campos.push(`telefono = $${i++}`);
      valores.push(dto.telefono === null ? null : dto.telefono.trim() || null);
    }
    if (dto.logo_url !== undefined) {
      campos.push(`logo_url = $${i++}`);
      valores.push(dto.logo_url?.trim() || null);
    }
    if (dto.banner_url !== undefined) {
      campos.push(`banner_url = $${i++}`);
      valores.push(dto.banner_url?.trim() || null);
    }
    if (dto.descripcion !== undefined) {
      campos.push(`descripcion = $${i++}`);
      valores.push(dto.descripcion?.trim() || null);
    }
    if (!campos.length) return this.obtenerMarca(restauranteId);
    valores.push(restauranteId);
    const fila = await this.database.consultarUno(
      `UPDATE restaurantes SET ${campos.join(', ')}
       WHERE id = $${i}
       RETURNING id, nombre, telefono, descripcion, logo_url, banner_url`,
      valores,
    );
    if (!fila) throw new NotFoundException('Restaurante no encontrado');
    // CFG-CACHE-MARCA-04: listado ciudad es SQL vivo (sin caché Nest); sin bust.
    return fila;
  }

  async actualizarMargenesSucursal(
    restauranteId: string,
    sucursalId: string,
    dto: ActualizarMargenesSucursalDto,
  ) {
    const fila = await this.database.consultarUno<{
      id: string;
      restaurante_id: string;
    }>(
      `SELECT id, restaurante_id
       FROM sucursales
       WHERE id = $1 AND restaurante_id = $2 AND activa = true`,
      [sucursalId, restauranteId],
    );
    if (!fila) throw new NotFoundException('Sucursal no encontrada');

    const r = await this.database.consultarUno<{
      margen_objetivo_default: string | number | null;
      umbral_alerta_margen: string | number | null;
    }>(
      `UPDATE sucursales
       SET margen_objetivo_default = COALESCE($2, margen_objetivo_default),
           umbral_alerta_margen = COALESCE($3, umbral_alerta_margen)
       WHERE id = $1
       RETURNING margen_objetivo_default, umbral_alerta_margen`,
      [sucursalId, dto.margen_objetivo_default ?? null, dto.umbral_alerta_margen ?? null],
    );
    if (!r) throw new NotFoundException('Sucursal no encontrada');

    return {
      margen_objetivo_default: r.margen_objetivo_default != null
        ? Number(r.margen_objetivo_default)
        : 35,
      umbral_alerta_margen: r.umbral_alerta_margen != null
        ? Number(r.umbral_alerta_margen)
        : 25,
    };
  }
}
