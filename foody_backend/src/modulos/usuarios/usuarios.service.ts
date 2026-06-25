import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import { DatabaseService } from '../../core/database/database.service';
import { PlanFeaturesService } from '../../core/auth/plan-features.service';
import { CambiarEstadoUsuarioDto } from './dto/crear-usuario.dto';
import { CrearUsuarioDto } from './dto/crear-usuario.dto';

@Injectable()
export class UsuariosService {
  constructor(
    private readonly database: DatabaseService,
    private readonly planFeatures: PlanFeaturesService,
  ) {}

  async listarPorSucursal(sucursalId: string) {
    return this.database.consultar(
      `SELECT u.id, u.nombre, u.email, u.rol, u.activo, u.telefono,
              u.ultimo_acceso, u.created_at,
              dp.id IS NOT NULL AS es_domiciliario_planta
       FROM usuarios u
       LEFT JOIN domiciliarios_planta dp ON dp.usuario_id = u.id AND dp.activo = true
       WHERE u.sucursal_id = $1
         AND u.rol <> 'super_admin'
       ORDER BY u.nombre`,
      [sucursalId],
    );
  }

  async crear(dto: CrearUsuarioDto) {
    const sucursal = await this.database.consultarUno<{ restaurante_id: string }>(
      `SELECT restaurante_id FROM sucursales WHERE id = $1 AND activa = true`,
      [dto.sucursal_id],
    );
    if (!sucursal) {
      throw new BadRequestException('Sucursal no válida');
    }

    await this.planFeatures.assertLimiteUsuariosStaff(sucursal.restaurante_id);

    const existe = await this.database.consultarUno<{ id: string }>(
      `SELECT id FROM usuarios WHERE LOWER(email) = LOWER($1)`,
      [dto.email.trim()],
    );
    if (existe) {
      throw new ConflictException('El correo ya está registrado');
    }

    const hash = await bcrypt.hash(dto.contrasena, 10);

    return this.database.enTransaccion(async (client) => {
      const insert = await client.query<{ id: string }>(
        `INSERT INTO usuarios (
           id, sucursal_id, restaurante_id, nombre, email, rol, activo, hash_contrasena
         ) VALUES (gen_random_uuid(), $1, $2, $3, $4, $5, true, $6)
         RETURNING id`,
        [
          dto.sucursal_id,
          sucursal.restaurante_id,
          dto.nombre.trim(),
          dto.email.trim().toLowerCase(),
          dto.rol,
          hash,
        ],
      );
      const usuarioId = insert.rows[0].id;

      if (dto.rol === 'domiciliario_planta') {
        await client.query(
          `INSERT INTO domiciliarios_planta (usuario_id, sucursal_id, activo)
           VALUES ($1, $2, true)`,
          [usuarioId, dto.sucursal_id],
        );
      }

      return {
        id: usuarioId,
        nombre: dto.nombre.trim(),
        email: dto.email.trim().toLowerCase(),
        rol: dto.rol,
        activo: true,
      };
    });
  }

  async cambiarEstado(
    usuarioId: string,
    sucursalId: string,
    dto: CambiarEstadoUsuarioDto,
  ) {
    const fila = await this.database.consultarUno<{ id: string; rol: string }>(
      `UPDATE usuarios
       SET activo = $3
       WHERE id = $1 AND sucursal_id = $2 AND rol <> 'super_admin'
       RETURNING id, rol`,
      [usuarioId, sucursalId, dto.activo],
    );
    if (!fila) {
      throw new NotFoundException('Usuario no encontrado');
    }

    if (fila.rol === 'domiciliario_planta') {
      await this.database.consultar(
        `UPDATE domiciliarios_planta SET activo = $2 WHERE usuario_id = $1`,
        [usuarioId, dto.activo],
      );
    }

    return { id: usuarioId, activo: dto.activo };
  }
}
