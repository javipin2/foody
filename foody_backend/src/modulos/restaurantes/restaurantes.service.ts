import { Injectable, NotFoundException, ForbiddenException } from '@nestjs/common';
import { DatabaseService } from '../../core/database/database.service';
import { PlanFeaturesService } from '../../core/auth/plan-features.service';
import { ActualizarHorarioDto } from './dto/actualizar-horario.dto';
import { CrearSucursalDto } from './dto/crear-sucursal.dto';

@Injectable()
export class RestaurantesService {
  constructor(
    private readonly database: DatabaseService,
    private readonly planFeatures: PlanFeaturesService,
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
      `SELECT s.id, s.nombre, s.direccion, s.lat, s.lng, s.activa, s.ciudad_id, c.nombre AS ciudad_nombre
       FROM sucursales s
       LEFT JOIN ciudades c ON c.id = s.ciudad_id
       WHERE s.restaurante_id = $1 AND s.activa = true
       ORDER BY s.nombre ASC`,
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
       RETURNING h.id, h.dia_semana, h.hora_apertura::text, h.hora_cierre::text, h.activo`,
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
    return fila;
  }
}
