import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import { AuthService } from '../../core/auth/auth.service';
import { DatabaseService } from '../../core/database/database.service';
import { JwtPayload } from '../../core/auth/jwt-payload';
import { PlanFeaturesService } from '../../core/auth/plan-features.service';
import { bcryptRoundsRegistro } from '../../core/auth/registro-antispike';
import { ROL_GERENTE_CADENA, esRolCocina } from '../../core/auth/roles-food';
import { SucursalScopeService } from '../../core/auth/sucursal-scope.service';
import {
  ActualizarUsuarioDto,
  CambiarEstadoUsuarioDto,
  CrearUsuarioDto,
  ROLES_STAFF_ASIGNABLES,
} from './dto/crear-usuario.dto';
import {
  envolverPaginado,
  opcionesListado,
  PaginacionQueryDto,
  resolverPaginacion,
} from '../../compartido/dto/paginacion.dto';

const ROLES_NO_EDITABLES = new Set(['admin', 'super_admin']);

@Injectable()
export class UsuariosService {
  constructor(
    private readonly database: DatabaseService,
    private readonly planFeatures: PlanFeaturesService,
    private readonly authService: AuthService,
    private readonly sucursalScope: SucursalScopeService,
  ) {}

  async listarPorSucursal(
    sucursalId: string,
    query: PaginacionQueryDto = {},
  ) {
    const opts = opcionesListado(query, 50);
    const select = `SELECT u.id, u.nombre, u.email, u.rol, u.activo, u.telefono,
              u.cocina_id, c.nombre AS cocina_nombre,
              u.ultimo_acceso, u.created_at,
              dp.id IS NOT NULL AS es_domiciliario_planta
       FROM usuarios u
       LEFT JOIN domiciliarios_planta dp ON dp.usuario_id = u.id AND dp.activo = true
       LEFT JOIN cocinas c ON c.id = u.cocina_id
       WHERE u.sucursal_id = $1
         AND u.rol <> 'super_admin'`;
    if (!opts.paginar) {
      return this.database.consultar(
        `${select}
       ORDER BY u.nombre
       LIMIT $2`,
        [sucursalId, opts.limite],
      );
    }
    const { page, limit, offset } = resolverPaginacion(
      opts.page,
      opts.limite,
      50,
    );
    const [items, totalRow] = await Promise.all([
      this.database.consultar(
        `${select}
       ORDER BY u.nombre
       LIMIT $2 OFFSET $3`,
        [sucursalId, limit, offset],
      ),
      this.database.consultarUno<{ count: number }>(
        `SELECT COUNT(*)::int AS count FROM usuarios
         WHERE sucursal_id = $1 AND rol <> 'super_admin'`,
        [sucursalId],
      ),
    ]);
    return envolverPaginado(items, totalRow?.count ?? 0, page, limit);
  }

  async listarMeserosActivos(sucursalId: string) {
    return this.database.consultar(
      `SELECT u.id, u.nombre
       FROM usuarios u
       WHERE u.sucursal_id = $1
         AND u.rol = 'mesero'
         AND u.activo = true
       ORDER BY u.nombre`,
      [sucursalId],
    );
  }

  async crear(dto: CrearUsuarioDto, actor: JwtPayload) {
    await this.sucursalScope.assertPerteneceRestaurante(
      dto.sucursal_id,
      actor.restaurante_id!,
    );
    if (
      !this.sucursalScope.esCorporativo(actor) &&
      dto.sucursal_id !== actor.sucursal_id
    ) {
      throw new ForbiddenException(
        'Solo puedes crear usuarios en tu sucursal asignada',
      );
    }
    if (
      dto.rol === ROL_GERENTE_CADENA &&
      !this.sucursalScope.esCorporativo(actor)
    ) {
      throw new ForbiddenException(
        'Solo usuarios corporativos pueden crear un gerente de cadena',
      );
    }

    const sucursal = await this.database.consultarUno<{ restaurante_id: string }>(
      `SELECT restaurante_id FROM sucursales WHERE id = $1 AND activa = true`,
      [dto.sucursal_id],
    );
    if (!sucursal) {
      throw new BadRequestException('Sucursal no válida');
    }

    await this.planFeatures.assertLimiteUsuariosStaff(sucursal.restaurante_id);

    const cocinaId = await this.resolverCocinaIdParaRol(
      dto.rol,
      dto.sucursal_id,
      dto.cocina_id,
    );

    const existe = await this.database.consultarUno<{ id: string }>(
      `SELECT id FROM usuarios WHERE LOWER(email) = LOWER($1)`,
      [dto.email.trim()],
    );
    if (existe) {
      throw new ConflictException('El correo ya está registrado');
    }

    const hash = await bcrypt.hash(dto.contrasena, bcryptRoundsRegistro());

    return this.database.enTransaccion(async (client) => {
      const insert = await client.query<{ id: string }>(
        `INSERT INTO usuarios (
           id, sucursal_id, restaurante_id, nombre, email, rol, activo, hash_contrasena, cocina_id
         ) VALUES (gen_random_uuid(), $1, $2, $3, $4, $5, true, $6, $7)
         RETURNING id`,
        [
          dto.sucursal_id,
          sucursal.restaurante_id,
          dto.nombre.trim(),
          dto.email.trim().toLowerCase(),
          dto.rol,
          hash,
          cocinaId,
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

      let permisos = await this.authService.permisosDelRol(dto.rol);
      if (dto.permisos !== undefined) {
        permisos = await this.authService.reemplazarPermisosUsuario(
          usuarioId,
          dto.rol,
          dto.permisos,
          client,
        );
      }

      return {
        id: usuarioId,
        nombre: dto.nombre.trim(),
        email: dto.email.trim().toLowerCase(),
        rol: dto.rol,
        cocina_id: cocinaId,
        activo: true,
        permisos,
      };
    });
  }

  /** Si rol cocina exige estación; otros roles → null. */
  private async resolverCocinaIdParaRol(
    rol: string,
    sucursalId: string,
    cocinaId?: string | null,
  ): Promise<string | null> {
    if (!esRolCocina(rol)) {
      return null;
    }
    if (!cocinaId) {
      throw new BadRequestException(
        'El rol Cocina requiere asignar una estación de cocina',
      );
    }
    const cocina = await this.database.consultarUno<{ id: string }>(
      `SELECT id FROM cocinas
       WHERE id = $1 AND sucursal_id = $2 AND activa = true`,
      [cocinaId, sucursalId],
    );
    if (!cocina) {
      throw new BadRequestException('Cocina no válida para esta sucursal');
    }
    return cocina.id;
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

  async catalogoRolesPermisos() {
    const filas = await this.database.consultar<{
      rol: string;
      permiso: string;
    }>(
      `SELECT rol, permiso FROM roles_permisos
       WHERE rol = ANY($1::text[])
       ORDER BY rol, permiso`,
      [[...ROLES_STAFF_ASIGNABLES]],
    );
    const mapa = new Map<string, string[]>();
    for (const f of filas) {
      const lista = mapa.get(f.rol) ?? [];
      lista.push(f.permiso);
      mapa.set(f.rol, lista);
    }
    const permisosDisponibles =
      await this.authService.catalogoPermisosDisponibles();
    return {
      roles: ROLES_STAFF_ASIGNABLES.map((rol) => ({
        rol,
        permisos: mapa.get(rol) ?? [],
      })),
      permisos_disponibles: permisosDisponibles,
    };
  }

  async permisosDeUsuario(
    usuarioId: string,
    sucursalId: string,
  ) {
    const u = await this.database.consultarUno<{
      id: string;
      rol: string;
    }>(
      `SELECT id, rol FROM usuarios
       WHERE id = $1 AND sucursal_id = $2 AND rol <> 'super_admin'`,
      [usuarioId, sucursalId],
    );
    if (!u) {
      throw new NotFoundException('Usuario no encontrado');
    }
    const personalizado =
      await this.authService.tienePermisosPersonalizados(usuarioId);
    const permisos = await this.authService.permisosEfectivos(usuarioId, u.rol);
    const plantilla = await this.authService.permisosDelRol(u.rol);
    return {
      usuario_id: usuarioId,
      rol: u.rol,
      personalizado,
      permisos,
      plantilla_rol: plantilla,
    };
  }

  async actualizar(
    usuarioId: string,
    sucursalContexto: string,
    dto: ActualizarUsuarioDto,
    actor: JwtPayload,
  ) {
    if (
      dto.rol === ROL_GERENTE_CADENA &&
      !this.sucursalScope.esCorporativo(actor)
    ) {
      throw new ForbiddenException(
        'Solo usuarios corporativos pueden asignar gerente de cadena',
      );
    }
    if (dto.sucursal_id && dto.sucursal_id !== sucursalContexto) {
      if (!this.sucursalScope.esCorporativo(actor)) {
        throw new ForbiddenException(
          'Solo usuarios corporativos pueden mover staff a otra sucursal',
        );
      }
      await this.sucursalScope.assertPerteneceRestaurante(
        dto.sucursal_id,
        actor.restaurante_id!,
      );
    }

    if (
      !dto.nombre?.trim() &&
      !dto.rol &&
      !dto.sucursal_id &&
      dto.cocina_id === undefined &&
      dto.permisos === undefined
    ) {
      throw new BadRequestException(
        'Indica nombre, rol, sucursal, cocina o permisos a actualizar',
      );
    }

    const actorId = actor.sub;
    const actual = await this.database.consultarUno<{
      id: string;
      rol: string;
      sucursal_id: string;
      restaurante_id: string;
      nombre: string;
      cocina_id: string | null;
    }>(
      `SELECT id, rol, sucursal_id, restaurante_id, nombre, cocina_id
       FROM usuarios
       WHERE id = $1 AND sucursal_id = $2 AND rol <> 'super_admin'`,
      [usuarioId, sucursalContexto],
    );
    if (!actual) {
      throw new NotFoundException('Usuario no encontrado');
    }
    if (ROLES_NO_EDITABLES.has(actual.rol)) {
      throw new ForbiddenException('No puedes editar el rol del administrador principal');
    }
    if (dto.rol && dto.rol !== actual.rol && usuarioId === actorId) {
      throw new ForbiddenException('No puedes cambiar tu propio rol');
    }

    const nuevaSucursal = dto.sucursal_id ?? actual.sucursal_id;
    if (nuevaSucursal !== actual.sucursal_id) {
      const suc = await this.database.consultarUno<{ id: string }>(
        `SELECT id FROM sucursales
         WHERE id = $1 AND restaurante_id = $2 AND activa = true`,
        [nuevaSucursal, actual.restaurante_id],
      );
      if (!suc) {
        throw new BadRequestException('Sucursal destino no válida');
      }
    }

    const nuevoRolRaw = dto.rol ?? actual.rol;
    // Unificar legado cocina_* → cocina.
    const nuevoRol = esRolCocina(nuevoRolRaw) ? 'cocina' : nuevoRolRaw;
    const nombre = dto.nombre?.trim() ?? actual.nombre;
    const cocinaId = await this.resolverCocinaIdParaRol(
      nuevoRol,
      nuevaSucursal,
      dto.cocina_id !== undefined ? dto.cocina_id : actual.cocina_id,
    );

    return this.database.enTransaccion(async (client) => {
      const upd = await client.query<{
        id: string;
        nombre: string;
        email: string;
        rol: string;
        activo: boolean;
        sucursal_id: string;
        cocina_id: string | null;
      }>(
        `UPDATE usuarios SET
           nombre = $3,
           rol = $4,
           sucursal_id = $5,
           cocina_id = $6
         WHERE id = $1 AND sucursal_id = $2
         RETURNING id, nombre, email, rol, activo, sucursal_id, cocina_id`,
        [
          usuarioId,
          sucursalContexto,
          nombre,
          nuevoRol,
          nuevaSucursal,
          cocinaId,
        ],
      );
      if (!upd.rows[0]) {
        throw new NotFoundException('Usuario no encontrado');
      }

      if (actual.rol === 'domiciliario_planta' && nuevoRol !== 'domiciliario_planta') {
        await client.query(
          `UPDATE domiciliarios_planta SET activo = false WHERE usuario_id = $1`,
          [usuarioId],
        );
      }
      if (nuevoRol === 'domiciliario_planta') {
        const dp = await client.query<{ id: string }>(
          `SELECT id FROM domiciliarios_planta WHERE usuario_id = $1 LIMIT 1`,
          [usuarioId],
        );
        if (dp.rows[0]) {
          await client.query(
            `UPDATE domiciliarios_planta SET sucursal_id = $2, activo = true WHERE usuario_id = $1`,
            [usuarioId, nuevaSucursal],
          );
        } else {
          await client.query(
            `INSERT INTO domiciliarios_planta (usuario_id, sucursal_id, activo)
             VALUES ($1, $2, true)`,
            [usuarioId, nuevaSucursal],
          );
        }
      }

      let permisos: string[];
      if (dto.permisos !== undefined) {
        permisos = await this.authService.reemplazarPermisosUsuario(
          usuarioId,
          nuevoRol,
          dto.permisos,
          client,
        );
      } else if (dto.rol && dto.rol !== actual.rol) {
        // Cambio de rol sin checklist → vuelve a la plantilla del nuevo rol.
        await client.query(
          `DELETE FROM usuario_permisos WHERE usuario_id = $1`,
          [usuarioId],
        );
        permisos = await this.authService.permisosDelRol(nuevoRol);
      } else {
        permisos = await this.authService.permisosEfectivos(
          usuarioId,
          nuevoRol,
        );
      }
      return { ...upd.rows[0], permisos };
    });
  }
}
