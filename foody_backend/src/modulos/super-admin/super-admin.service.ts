import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import { DatabaseService } from '../../core/database/database.service';
import { OnboardingRestauranteService } from '../../core/onboarding/onboarding-restaurante.service';
import {
  ActualizarCiudadDto,
  ActualizarConfiguracionDto,
  ActualizarDomiciliarioEstadoDto,
  ActualizarRestauranteDto,
  ActualizarSuscripcionDto,
  ActualizarUsuarioSuperDto,
  AprobarDocumentoDto,
  CambiarContrasenaSuperDto,
  CambiarEstadoUsuarioSuperDto,
  CrearCiudadDto,
  CrearRestauranteDto,
  CrearUsuarioSuperDto,
  RechazarDocumentoDto,
} from './dto/super-admin.dto';

@Injectable()
export class SuperAdminService {
  constructor(
    private readonly database: DatabaseService,
    private readonly onboarding: OnboardingRestauranteService,
  ) {}

  async resumenGlobal() {
    const ciudades = await this.database.consultarUno<{ total: string }>(
      `SELECT COUNT(*)::text AS total FROM ciudades WHERE activa = true`,
    );
    const restaurantes = await this.database.consultarUno<{ total: string }>(
      `SELECT COUNT(*)::text AS total FROM restaurantes WHERE activo = true`,
    );
    const sucursales = await this.database.consultarUno<{ total: string }>(
      `SELECT COUNT(*)::text AS total FROM sucursales WHERE activa = true`,
    );
    const domiciliarios = await this.database.consultarUno<{ total: string }>(
      `SELECT COUNT(*)::text AS total FROM domiciliarios_independientes WHERE estado_cuenta = 'activo'`,
    );
    const suscripciones = await this.database.consultar(
      `SELECT estado, COUNT(*)::int AS total
       FROM suscripciones_restaurante
       GROUP BY estado`,
    );
    return {
      ciudades_activas: Number(ciudades?.total ?? 0),
      restaurantes_activos: Number(restaurantes?.total ?? 0),
      sucursales_activas: Number(sucursales?.total ?? 0),
      domiciliarios_activos: Number(domiciliarios?.total ?? 0),
      suscripciones,
    };
  }

  async crearCiudad(dto: CrearCiudadDto) {
    const slug =
      dto.slug?.trim().toLowerCase() ||
      dto.nombre
        .trim()
        .toLowerCase()
        .normalize('NFD')
        .replace(/[\u0300-\u036f]/g, '')
        .replace(/[^a-z0-9]+/g, '-')
        .replace(/^-|-$/g, '');

    const existe = await this.database.consultarUno<{ id: string }>(
      `SELECT id FROM ciudades WHERE slug = $1`,
      [slug],
    );
    if (existe) {
      throw new BadRequestException({
        error: 'SLUG_DUPLICADO',
        message: 'Ya existe una ciudad con ese slug',
      });
    }

    return this.database.consultarUno(
      `INSERT INTO ciudades (nombre, slug, activa)
       VALUES ($1, $2, true)
       RETURNING id, nombre, slug, activa, created_at`,
      [dto.nombre.trim(), slug],
    );
  }

  async actualizarCiudad(id: string, dto: ActualizarCiudadDto) {
    const ciudad = await this.database.consultarUno<{ id: string }>(
      `SELECT id FROM ciudades WHERE id = $1`,
      [id],
    );
    if (!ciudad) throw new NotFoundException('Ciudad no encontrada');

    return this.database.consultarUno(
      `UPDATE ciudades SET
         nombre = COALESCE($2, nombre),
         activa = COALESCE($3, activa)
       WHERE id = $1
       RETURNING id, nombre, slug, activa, created_at`,
      [id, dto.nombre?.trim() ?? null, dto.activa ?? null],
    );
  }

  async actualizarRestaurante(id: string, dto: ActualizarRestauranteDto) {
    const restaurante = await this.database.consultarUno<{ id: string }>(
      `SELECT id FROM restaurantes WHERE id = $1`,
      [id],
    );
    if (!restaurante) throw new NotFoundException('Restaurante no encontrado');

    const actualizado = await this.database.consultarUno(
      `UPDATE restaurantes SET activo = COALESCE($2, activo)
       WHERE id = $1
       RETURNING id, nombre, activo, ciudad_id`,
      [id, dto.activo ?? null],
    );

    if (dto.activo === false) {
      await this.database.consultar(
        `UPDATE suscripciones_restaurante SET
           estado = 'bloqueada',
           motivo_bloqueo = COALESCE($2, motivo_bloqueo)
         WHERE restaurante_id = $1 AND estado <> 'bloqueada'`,
        [id, dto.motivo_bloqueo?.trim() ?? 'Bloqueado por super admin'],
      );
    }

    return actualizado;
  }

  async listarCiudades() {
    return this.database.consultar(
      `SELECT c.id, c.nombre, c.slug, c.activa,
              COUNT(DISTINCT r.id)::int AS restaurantes
       FROM ciudades c
       LEFT JOIN restaurantes r ON r.ciudad_id = c.id AND r.activo = true
       GROUP BY c.id
       ORDER BY c.nombre ASC`,
    );
  }

  async listarRestaurantes() {
    return this.database.consultar(
      `SELECT r.id, r.nombre, r.activo, c.nombre AS ciudad_nombre,
              s.id AS suscripcion_id,
              s.estado AS suscripcion_estado,
              s.plan AS suscripcion_plan,
              s.fecha_vencimiento,
              (SELECT COUNT(*)::int FROM sucursales su
               WHERE su.restaurante_id = r.id AND su.activa = true) AS sucursales_activas
       FROM restaurantes r
       INNER JOIN ciudades c ON c.id = r.ciudad_id
       LEFT JOIN suscripciones_restaurante s ON s.restaurante_id = r.id
       ORDER BY r.nombre ASC`,
    );
  }

  async listarSucursalesRestaurante(restauranteId: string) {
    const existe = await this.database.consultarUno<{ id: string }>(
      `SELECT id FROM restaurantes WHERE id = $1`,
      [restauranteId],
    );
    if (!existe) throw new NotFoundException('Restaurante no encontrado');

    return this.database.consultar(
      `SELECT id, nombre, direccion, activa, created_at
       FROM sucursales
       WHERE restaurante_id = $1
       ORDER BY created_at ASC`,
      [restauranteId],
    );
  }

  async listarSuscripciones() {
    return this.database.consultar(
      `SELECT s.id, s.restaurante_id, s.estado, s.plan,
              s.fecha_inicio, s.fecha_vencimiento, s.motivo_bloqueo,
              r.nombre AS restaurante_nombre
       FROM suscripciones_restaurante s
       JOIN restaurantes r ON r.id = s.restaurante_id
       ORDER BY s.fecha_vencimiento ASC`,
    );
  }

  async actualizarSuscripcion(id: string, dto: ActualizarSuscripcionDto) {
    const actual = await this.database.consultarUno<{ id: string }>(
      `SELECT id FROM suscripciones_restaurante WHERE id = $1`,
      [id],
    );
    if (!actual) throw new NotFoundException('Suscripción no encontrada');

    return this.database.consultarUno(
      `UPDATE suscripciones_restaurante SET
         estado = COALESCE($2, estado),
         plan = COALESCE($3, plan),
         fecha_vencimiento = COALESCE($4, fecha_vencimiento)
       WHERE id = $1
       RETURNING *`,
      [
        id,
        dto.estado ?? null,
        dto.plan ?? null,
        dto.fecha_vencimiento ?? null,
      ],
    );
  }

  async listarDomiciliarios() {
    return this.database.consultar(
      `SELECT di.id, di.nombre, di.email, di.telefono,
              di.estado_cuenta, di.calificacion_promedio, di.total_entregas,
              c.nombre AS ciudad_nombre,
              di.created_at
       FROM domiciliarios_independientes di
       LEFT JOIN ciudades c ON c.id = di.ciudad_id
       ORDER BY di.created_at DESC
       LIMIT 200`,
    );
  }

  async actualizarEstadoDomiciliario(
    id: string,
    dto: ActualizarDomiciliarioEstadoDto,
  ) {
    const dom = await this.database.consultarUno<{ id: string }>(
      `SELECT id FROM domiciliarios_independientes WHERE id = $1`,
      [id],
    );
    if (!dom) throw new NotFoundException('Domiciliario no encontrado');

    return this.database.consultarUno(
      `UPDATE domiciliarios_independientes
       SET estado_cuenta = $2
       WHERE id = $1
       RETURNING id, nombre, email, estado_cuenta`,
      [id, dto.estado_cuenta],
    );
  }

  async listarConfiguracion() {
    return this.database.consultar(
      `SELECT clave, valor, descripcion, updated_at
       FROM configuracion_global_foody
       ORDER BY clave ASC`,
    );
  }

  async estadisticas() {
    const pedidosHoy = await this.database.consultarUno<{ total: string }>(
      `SELECT COUNT(*)::text AS total FROM pedidos
       WHERE created_at >= CURRENT_DATE`,
    );
    const ingresosFoody = await this.database.consultarUno<{ total: string }>(
      `SELECT COALESCE(SUM(comision_foody), 0)::text AS total
       FROM ganancias_domiciliario
       WHERE created_at >= CURRENT_DATE`,
    );
    const resumen = await this.resumenGlobal();
    return {
      ...resumen,
      pedidos_hoy: Number(pedidosHoy?.total ?? 0),
      ingresos_foody_hoy: Number(ingresosFoody?.total ?? 0),
    };
  }

  async actualizarConfiguracion(
    clave: string,
    dto: ActualizarConfiguracionDto,
    usuarioId: string,
  ) {
    const fila = await this.database.consultarUno<{ clave: string }>(
      `SELECT clave FROM configuracion_global_foody WHERE clave = $1`,
      [clave],
    );
    if (!fila) throw new NotFoundException('Parámetro no encontrado');

    return this.database.consultarUno(
      `UPDATE configuracion_global_foody SET
         valor = $2, editado_por = $3, updated_at = now()
       WHERE clave = $1
       RETURNING clave, valor, descripcion, updated_at`,
      [clave, dto.valor.trim(), usuarioId],
    );
  }

  async crearRestaurante(dto: CrearRestauranteDto) {
    const email = dto.admin_email.trim().toLowerCase();
    const hash = await bcrypt.hash(dto.admin_contrasena, 10);

    return this.onboarding.crear({
      ciudad_id: dto.ciudad_id,
      nombre_restaurante: dto.nombre_restaurante,
      nombre_sucursal: dto.nombre_sucursal,
      direccion_sucursal: dto.direccion_sucursal,
      admin_nombre: dto.admin_nombre,
      admin_email: email,
      hash_contrasena: hash,
      proveedor_auth: 'correo',
      origen: 'manual',
      plan: 'basico',
      estado_suscripcion: 'prueba',
      dias_prueba: 14,
    });
  }

  async listarUsuarios() {
    return this.database.consultar(
      `SELECT u.id, u.nombre, u.email, u.rol, u.activo, u.telefono,
              u.sucursal_id, u.restaurante_id, u.created_at,
              s.nombre AS sucursal_nombre,
              r.nombre AS restaurante_nombre
       FROM usuarios u
       LEFT JOIN sucursales s ON s.id = u.sucursal_id
       LEFT JOIN restaurantes r ON r.id = u.restaurante_id
       WHERE u.rol <> 'super_admin'
       ORDER BY u.created_at DESC
       LIMIT 500`,
    );
  }

  async crearUsuario(dto: CrearUsuarioSuperDto) {
    const sucursal = await this.database.consultarUno<{
      id: string;
      restaurante_id: string;
    }>(
      `SELECT id, restaurante_id FROM sucursales WHERE id = $1 AND activa = true`,
      [dto.sucursal_id],
    );
    if (!sucursal) throw new BadRequestException('Sucursal no válida');

    const email = dto.email.trim().toLowerCase();
    const existe = await this.database.consultarUno<{ id: string }>(
      `SELECT id FROM usuarios WHERE LOWER(email) = $1`,
      [email],
    );
    if (existe) throw new ConflictException('El correo ya está registrado');

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
          email,
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
        email,
        rol: dto.rol,
        sucursal_id: dto.sucursal_id,
        restaurante_id: sucursal.restaurante_id,
      };
    });
  }

  async actualizarUsuario(id: string, dto: ActualizarUsuarioSuperDto) {
    const usuario = await this.database.consultarUno<{ id: string; rol: string }>(
      `SELECT id, rol FROM usuarios WHERE id = $1 AND rol <> 'super_admin'`,
      [id],
    );
    if (!usuario) throw new NotFoundException('Usuario no encontrado');

    if (dto.email) {
      const dup = await this.database.consultarUno<{ id: string }>(
        `SELECT id FROM usuarios WHERE LOWER(email) = LOWER($1) AND id <> $2`,
        [dto.email.trim(), id],
      );
      if (dup) throw new ConflictException('El correo ya está en uso');
    }

    return this.database.consultarUno(
      `UPDATE usuarios SET
         nombre = COALESCE($2, nombre),
         email = COALESCE($3, email),
         rol = COALESCE($4, rol)
       WHERE id = $1
       RETURNING id, nombre, email, rol, activo, sucursal_id, restaurante_id`,
      [
        id,
        dto.nombre?.trim() ?? null,
        dto.email?.trim().toLowerCase() ?? null,
        dto.rol ?? null,
      ],
    );
  }

  async cambiarContrasenaUsuario(id: string, dto: CambiarContrasenaSuperDto) {
    const usuario = await this.database.consultarUno<{ id: string }>(
      `SELECT id FROM usuarios WHERE id = $1 AND rol <> 'super_admin'`,
      [id],
    );
    if (!usuario) throw new NotFoundException('Usuario no encontrado');

    const hash = await bcrypt.hash(dto.contrasena, 10);
    await this.database.consultar(
      `UPDATE usuarios SET hash_contrasena = $2 WHERE id = $1`,
      [id, hash],
    );
    return { id, actualizado: true };
  }

  async cambiarEstadoUsuario(id: string, dto: CambiarEstadoUsuarioSuperDto) {
    const fila = await this.database.consultarUno<{ id: string; rol: string }>(
      `UPDATE usuarios SET activo = $2
       WHERE id = $1 AND rol <> 'super_admin'
       RETURNING id, rol`,
      [id, dto.activo],
    );
    if (!fila) throw new NotFoundException('Usuario no encontrado');

    if (fila.rol === 'domiciliario_planta') {
      await this.database.consultar(
        `UPDATE domiciliarios_planta SET activo = $2 WHERE usuario_id = $1`,
        [id, dto.activo],
      );
    }

    return { id, activo: dto.activo };
  }

  async listarDocumentosPendientes() {
    return this.database.consultar(
      `SELECT d.id, d.tipo, d.url, d.estado, d.created_at,
              di.id AS domiciliario_id, di.nombre AS domiciliario_nombre,
              di.email AS domiciliario_email
       FROM documentos_domiciliario d
       JOIN domiciliarios_independientes di ON di.id = d.domiciliario_id
       WHERE d.estado = 'pendiente'
       ORDER BY d.created_at ASC
       LIMIT 200`,
    );
  }

  async aprobarDocumento(
    domiciliarioId: string,
    dto: AprobarDocumentoDto,
    revisorId: string,
  ) {
    return this.revisarDocumento(
      domiciliarioId,
      dto.documento_id,
      revisorId,
      'aprobado',
    );
  }

  async rechazarDocumento(
    domiciliarioId: string,
    dto: RechazarDocumentoDto,
    revisorId: string,
  ) {
    return this.revisarDocumento(
      domiciliarioId,
      dto.documento_id,
      revisorId,
      'rechazado',
      dto.motivo.trim(),
    );
  }

  private async revisarDocumento(
    domiciliarioId: string,
    documentoId: string,
    revisorId: string,
    estado: 'aprobado' | 'rechazado',
    motivoRechazo?: string,
  ) {
    const doc = await this.database.consultarUno<{ id: string }>(
      `SELECT id FROM documentos_domiciliario
       WHERE id = $1 AND domiciliario_id = $2 AND estado = 'pendiente'`,
      [documentoId, domiciliarioId],
    );
    if (!doc) throw new NotFoundException('Documento no encontrado o ya revisado');

    await this.database.consultar(
      `UPDATE documentos_domiciliario SET
         estado = $2,
         motivo_rechazo = $3,
         revisado_por = $4
       WHERE id = $1`,
      [documentoId, estado, motivoRechazo ?? null, revisorId],
    );

    if (estado === 'aprobado') {
      const pendientes = await this.database.consultarUno<{ n: number }>(
        `SELECT COUNT(*)::int AS n FROM documentos_domiciliario
         WHERE domiciliario_id = $1 AND estado = 'pendiente'`,
        [domiciliarioId],
      );
      if ((pendientes?.n ?? 0) === 0) {
        await this.database.consultar(
          `UPDATE domiciliarios_independientes
           SET estado_cuenta = 'activo'
           WHERE id = $1 AND estado_cuenta = 'pendiente_verificacion'`,
          [domiciliarioId],
        );
      }
    }

    return { documento_id: documentoId, estado };
  }
}
