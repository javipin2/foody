import {
  Injectable,
  UnauthorizedException,
  BadRequestException,
  ForbiddenException,
  HttpException,
  HttpStatus,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { DatabaseService } from '../database/database.service';
import { JwtPayload } from './jwt-payload';
import { RegistroDomiciliarioDto } from './dto/registro-domiciliario.dto';
import { RegistroRestauranteDto } from './dto/registro-restaurante.dto';
import { PlanFeaturesService } from './plan-features.service';
import { OnboardingRestauranteService } from '../onboarding/onboarding-restaurante.service';
import { SupabaseAuthService } from './supabase-auth.service';
import { esRolCocina } from './roles-food';
import { RealtimeBroadcastService } from '../realtime/realtime-broadcast.service';
import {
  bcryptRoundsRegistro,
  registroCupoDiario,
  registroMaxPorMinuto,
  registroSelfServiceAbierto,
} from './registro-antispike';

interface UsuarioFila {
  id: string;
  nombre: string;
  email: string;
  rol: string;
  sucursal_id: string | null;
  restaurante_id: string | null;
  activo: boolean;
  hash_contrasena: string | null;
  cocina_id?: string | null;
  token_version?: number;
}

@Injectable()
export class AuthService {
  constructor(
    private readonly database: DatabaseService,
    private readonly jwtService: JwtService,
    private readonly planFeatures: PlanFeaturesService,
    private readonly onboarding: OnboardingRestauranteService,
    private readonly supabaseAuth: SupabaseAuthService,
    private readonly realtime: RealtimeBroadcastService,
  ) {}

  /** Topics staff opacos (RT-SEC-01) — Flutter los usa en FoodyRealtime. */
  canalesRealtimeParaUsuario(
    usuario: {
      id: string;
      rol: string;
      sucursal_id: string | null;
      restaurante_id: string | null;
      cocina_id?: string | null;
    },
    sucursalOverride?: string | null,
  ): Record<string, string> {
    const canales: Record<string, string> = {};
    const sucursalId = sucursalOverride ?? usuario.sucursal_id;
    if (sucursalId) {
      canales.sucursal = this.realtime.topicSucursal(sucursalId);
    }
    if (usuario.restaurante_id) {
      canales.restaurante = this.realtime.topicRestaurante(
        usuario.restaurante_id,
      );
    }
    if (esRolCocina(usuario.rol) && usuario.cocina_id) {
      canales.cocina = this.realtime.topicCocina(usuario.cocina_id);
    }
    if (usuario.rol === 'domiciliario') {
      canales.domiciliario = this.realtime.topicDomiciliarioPlanta(usuario.id);
    }
    return canales;
  }

  async login(email: string, contrasena: string) {
    const usuario = await this.database.consultarUno<UsuarioFila>(
      `SELECT id, nombre, email, rol, sucursal_id, restaurante_id, activo, hash_contrasena, cocina_id,
              COALESCE(token_version, 1) AS token_version
       FROM usuarios WHERE LOWER(email) = LOWER($1)`,
      [email.trim()],
    );

    if (!usuario?.activo) {
      throw new UnauthorizedException('Credenciales inválidas');
    }
    if (!usuario.hash_contrasena) {
      throw new UnauthorizedException(
        'Esta cuenta usa Google. Inicia sesión con Google.',
      );
    }

    const valida = await bcrypt.compare(contrasena, usuario.hash_contrasena);
    if (!valida) {
      throw new UnauthorizedException('Credenciales inválidas');
    }

    return this.emitirSesionStaff(usuario);
  }

  async loginGoogle(accessToken: string) {
    const supabaseUser =
      await this.supabaseAuth.usuarioDesdeAccessToken(accessToken);
    const email = supabaseUser.email!.trim().toLowerCase();

    const usuario = await this.database.consultarUno<UsuarioFila>(
      `SELECT id, nombre, email, rol, sucursal_id, restaurante_id, activo, hash_contrasena, cocina_id,
              COALESCE(token_version, 1) AS token_version
       FROM usuarios WHERE LOWER(email) = $1`,
      [email],
    );

    if (!usuario) {
      return {
        necesita_registro: true,
        email,
        nombre:
          supabaseUser.user_metadata?.full_name ??
          supabaseUser.user_metadata?.name ??
          email.split('@')[0],
        proveedor_id: supabaseUser.id,
      };
    }

    if (!usuario.activo) {
      throw new UnauthorizedException('Cuenta desactivada');
    }

    await this.database.consultar(
      `UPDATE usuarios SET
         proveedor_auth = 'google',
         proveedor_id = COALESCE(proveedor_id, $2),
         email_verificado = true,
         ultimo_acceso = now()
       WHERE id = $1`,
      [usuario.id, supabaseUser.id],
    );

    return this.emitirSesionStaff(usuario);
  }

  async estadoRegistroRestaurante() {
    const abierto = registroSelfServiceAbierto();
    const cupo = registroCupoDiario();
    const maxMin = registroMaxPorMinuto();
    const usadosHoy = await this.contarSelfServiceHoy();
    const usadosMinuto = await this.contarSelfServiceUltimoMinuto();
    const cupoAgotado = cupo > 0 && usadosHoy >= cupo;
    const minutoAgotado = maxMin > 0 && usadosMinuto >= maxMin;
    const acepta = abierto && !cupoAgotado && !minutoAgotado;
    let mensaje =
      'Puedes crear tu restaurante ahora. Empezamos con el plan gratis.';
    if (!abierto) {
      mensaje =
        'El registro está temporalmente cerrado. Déjanos tu interés más tarde o escribe a soporte Foody.';
    } else if (cupoAgotado) {
      mensaje =
        'Cupo diario de altas agotado. Vuelve mañana — protegemos a los restaurantes que ya operan.';
    } else if (minutoAgotado) {
      mensaje =
        'Hay mucha demanda ahora. Espera un minuto e inténtalo de nuevo.';
    }
    return {
      abierto: acepta,
      registro_habilitado: abierto,
      cupo_diario: cupo,
      usados_hoy: usadosHoy,
      max_por_minuto: maxMin,
      usados_minuto: usadosMinuto,
      mensaje,
    };
  }

  private async contarSelfServiceHoy(): Promise<number> {
    const fila = await this.database.consultarUno<{ total: string }>(
      `SELECT COUNT(*)::text AS total
       FROM restaurantes
       WHERE origen = 'self_service'
         AND created_at >= (timezone('America/Bogota', now()))::date
             AT TIME ZONE 'America/Bogota'`,
    );
    return Number(fila?.total ?? 0);
  }

  private async contarSelfServiceUltimoMinuto(): Promise<number> {
    const fila = await this.database.consultarUno<{ total: string }>(
      `SELECT COUNT(*)::text AS total
       FROM restaurantes
       WHERE origen = 'self_service'
         AND created_at >= now() - interval '1 minute'`,
    );
    return Number(fila?.total ?? 0);
  }

  private async exigirCupoRegistroSelfService(): Promise<void> {
    const estado = await this.estadoRegistroRestaurante();
    if (estado.abierto) return;
    const codigo = !estado.registro_habilitado
      ? 'REGISTRO_CERRADO'
      : estado.cupo_diario > 0 && estado.usados_hoy >= estado.cupo_diario
        ? 'REGISTRO_CUPO'
        : 'REGISTRO_RATE';
    throw new HttpException(
      { error: codigo, mensaje: estado.mensaje },
      codigo === 'REGISTRO_RATE'
        ? HttpStatus.TOO_MANY_REQUESTS
        : HttpStatus.SERVICE_UNAVAILABLE,
    );
  }

  async registrarRestaurante(dto: RegistroRestauranteDto) {
    await this.exigirCupoRegistroSelfService();

    const proveedor = dto.proveedor_auth ?? 'correo';
    let email = dto.admin_email.trim().toLowerCase();
    let proveedorId: string | null = null;
    let hash: string | null = null;

    if (proveedor === 'google' || dto.supabase_access_token) {
      const supabaseUser = await this.supabaseAuth.usuarioDesdeAccessToken(
        dto.supabase_access_token!,
      );
      email = supabaseUser.email!.trim().toLowerCase();
      proveedorId = supabaseUser.id;
      if (dto.admin_email.trim().toLowerCase() !== email) {
        throw new BadRequestException(
          'El correo no coincide con la cuenta de Google',
        );
      }
    } else {
      if (!dto.contrasena || dto.contrasena.length < 6) {
        throw new BadRequestException(
          'La contraseña debe tener al menos 6 caracteres',
        );
      }
      hash = await bcrypt.hash(dto.contrasena, bcryptRoundsRegistro());
    }

    const onboarding = await this.onboarding.crear({
      ciudad_id: dto.ciudad_id,
      nombre_restaurante: dto.nombre_restaurante,
      nombre_sucursal: dto.nombre_sucursal?.trim() || 'Sede principal',
      direccion_sucursal: dto.direccion_sucursal,
      admin_nombre: dto.admin_nombre,
      admin_email: email,
      hash_contrasena: hash,
      proveedor_auth: proveedorId ? 'google' : 'correo',
      proveedor_id: proveedorId,
      email_verificado: proveedorId != null,
      origen: 'self_service',
      plan: 'gratis',
      estado_suscripcion: 'activa',
    });

    const usuario = await this.database.consultarUno<UsuarioFila>(
      `SELECT id, nombre, email, rol, sucursal_id, restaurante_id, activo, hash_contrasena,
              COALESCE(token_version, 1) AS token_version
       FROM usuarios WHERE id = $1`,
      [onboarding.admin_id],
    );
    if (!usuario) {
      throw new BadRequestException('Error al crear la cuenta');
    }

    const sesion = await this.emitirSesionStaff(usuario);

    return {
      ...sesion,
      onboarding,
      mensaje:
        '¡Bienvenido a Foody! Tu restaurante está listo con el plan gratis.',
    };
  }

  private async emitirSesionStaff(usuario: UsuarioFila) {
    const permisos = await this.permisosEfectivos(usuario.id, usuario.rol);
    const dashboard = this.resolverDashboard(usuario.rol);
    const plan = await this.planFeatures.obtenerPlanRestaurante(
      usuario.restaurante_id,
    );
    const modulos = this.planFeatures.modulosDelPlan(plan);
    const tv = Number(usuario.token_version ?? 1);

    const payload: JwtPayload = {
      sub: usuario.id,
      email: usuario.email,
      rol: usuario.rol,
      sucursal_id: usuario.sucursal_id,
      restaurante_id: usuario.restaurante_id,
      permisos,
      plan,
      cocina_id: esRolCocina(usuario.rol) ? (usuario.cocina_id ?? null) : null,
      tv,
    };

    const token = await this.jwtService.signAsync(payload);

    await this.database.consultar(
      `UPDATE usuarios SET ultimo_acceso = now() WHERE id = $1`,
      [usuario.id],
    );

    return {
      token,
      dashboard,
      rol: usuario.rol,
      permisos,
      plan,
      modulos,
      realtime_canales: this.canalesRealtimeParaUsuario(usuario),
      usuario: {
        id: usuario.id,
        nombre: usuario.nombre,
        email: usuario.email,
        sucursal_id: usuario.sucursal_id,
        restaurante_id: usuario.restaurante_id,
        cocina_id: esRolCocina(usuario.rol)
          ? (usuario.cocina_id ?? null)
          : null,
      },
    };
  }

  async loginDomiciliarioIndependiente(email: string, contrasena: string) {
    const dom = await this.database.consultarUno<{
      id: string;
      nombre: string;
      email: string;
      ciudad_id: string | null;
      estado_cuenta: string;
      hash_contrasena: string | null;
      token_version: number;
    }>(
      `SELECT id, nombre, email, ciudad_id, estado_cuenta, hash_contrasena,
              COALESCE(token_version, 1) AS token_version
       FROM domiciliarios_independientes WHERE LOWER(email) = LOWER($1)`,
      [email.trim()],
    );

    if (!dom || !dom.hash_contrasena) {
      throw new UnauthorizedException('Credenciales inválidas');
    }
    if (['suspendido', 'bloqueado'].includes(dom.estado_cuenta)) {
      throw new UnauthorizedException(
        'Tu cuenta está suspendida o bloqueada. Contacta a soporte Foody.',
      );
    }

    const valida = await bcrypt.compare(contrasena, dom.hash_contrasena);
    if (!valida) {
      throw new UnauthorizedException('Credenciales inválidas');
    }

    const permisos = ['domiciliario_independiente'];
    const tv = Number(dom.token_version ?? 1);
    const payload: JwtPayload = {
      sub: dom.id,
      email: dom.email,
      rol: 'domiciliario_independiente',
      sucursal_id: null,
      restaurante_id: null,
      permisos,
      ciudad_id: dom.ciudad_id,
      tv,
    };

    const token = await this.jwtService.signAsync(payload);

    return {
      token,
      dashboard: 'domiciliario_independiente',
      rol: 'domiciliario_independiente',
      permisos,
      estado_cuenta: dom.estado_cuenta,
      realtime_canales: {
        domiciliario_indep: this.realtime.topicDomiciliarioIndep(dom.id),
      },
      usuario: {
        id: dom.id,
        nombre: dom.nombre,
        email: dom.email,
        ciudad_id: dom.ciudad_id,
      },
    };
  }

  private tokenDomiciliarioIndependiente(dom: {
    id: string;
    email: string;
    ciudad_id: string | null;
    token_version?: number;
  }) {
    const permisos = ['domiciliario_independiente'];
    const payload: JwtPayload = {
      sub: dom.id,
      email: dom.email,
      rol: 'domiciliario_independiente',
      sucursal_id: null,
      restaurante_id: null,
      permisos,
      ciudad_id: dom.ciudad_id,
      tv: Number(dom.token_version ?? 1),
    };
    return this.jwtService.signAsync(payload);
  }

  async registrarDomiciliarioIndependiente(dto: RegistroDomiciliarioDto) {
    const existe = await this.database.consultarUno<{ id: string }>(
      `SELECT id FROM domiciliarios_independientes WHERE LOWER(email) = LOWER($1)`,
      [dto.email.trim()],
    );
    if (existe) {
      throw new BadRequestException('Ya existe una cuenta con ese correo');
    }

    const hash = await bcrypt.hash(dto.contrasena, bcryptRoundsRegistro());
    const fila = await this.database.consultarUno<{
      id: string;
      nombre: string;
      email: string;
      ciudad_id: string | null;
      estado_cuenta: string;
      token_version: number;
    }>(
      `INSERT INTO domiciliarios_independientes (
         nombre, email, telefono, tipo_vehiculo, placa, ciudad_id,
         hash_contrasena, estado_cuenta
       ) VALUES ($1, $2, $3, $4, $5, $6, $7, 'pendiente_verificacion')
       RETURNING id, nombre, email, ciudad_id, estado_cuenta,
                 COALESCE(token_version, 1) AS token_version`,
      [
        dto.nombre.trim(),
        dto.email.trim().toLowerCase(),
        dto.telefono?.trim() ?? null,
        dto.tipo_vehiculo?.trim() ?? null,
        dto.placa?.trim() ?? null,
        dto.ciudad_id ?? null,
        hash,
      ],
    );

    const token = await this.tokenDomiciliarioIndependiente(fila!);

    return {
      id: fila!.id,
      token,
      mensaje:
        'Registro recibido. Sube tus documentos para que un administrador active tu cuenta.',
      estado_cuenta: fila!.estado_cuenta,
      realtime_canales: {
        domiciliario_indep: this.realtime.topicDomiciliarioIndep(fila!.id),
      },
      usuario: {
        id: fila!.id,
        nombre: fila!.nombre,
        email: fila!.email,
        ciudad_id: fila!.ciudad_id,
      },
    };
  }

  async perfil(jwt: JwtPayload) {
    const usuario = await this.database.consultarUno<UsuarioFila>(
      `SELECT id, nombre, email, rol, sucursal_id, restaurante_id, activo, cocina_id,
              COALESCE(token_version, 1) AS token_version
       FROM usuarios WHERE id = $1`,
      [jwt.sub],
    );
    if (!usuario?.activo) {
      throw new UnauthorizedException('Usuario no encontrado');
    }
    const permisos = await this.permisosEfectivos(usuario.id, usuario.rol);
    const plan = await this.planFeatures.obtenerPlanRestaurante(
      usuario.restaurante_id,
    );
    const modulos = this.planFeatures.modulosDelPlan(plan);
    const suscripcion = await this.resumenSuscripcion(usuario.restaurante_id);
    const tv = Number(usuario.token_version ?? 1);

    const planJwt = jwt.plan ?? 'basico';
    const permisosJwt = [...(jwt.permisos ?? [])].sort().join(',');
    const permisosActuales = [...permisos].sort().join(',');
    const cocinaJwt = jwt.cocina_id ?? null;
    const cocinaActual = esRolCocina(usuario.rol)
      ? (usuario.cocina_id ?? null)
      : null;
    const tvJwt = Number(jwt.tv ?? 1);
    const necesitaTokenNuevo =
      planJwt !== plan ||
      permisosJwt !== permisosActuales ||
      cocinaJwt !== cocinaActual ||
      tvJwt !== tv;

    const respuesta: Record<string, unknown> = {
      usuario: {
        id: usuario.id,
        nombre: usuario.nombre,
        email: usuario.email,
        sucursal_id: usuario.sucursal_id,
        restaurante_id: usuario.restaurante_id,
        cocina_id: cocinaActual,
      },
      rol: usuario.rol,
      permisos,
      plan,
      modulos,
      suscripcion,
      dashboard: this.resolverDashboard(usuario.rol),
    };

    if (necesitaTokenNuevo) {
      const token = await this.jwtService.signAsync({
        sub: usuario.id,
        email: usuario.email,
        rol: usuario.rol,
        sucursal_id: usuario.sucursal_id,
        restaurante_id: usuario.restaurante_id,
        permisos,
        plan,
        cocina_id: cocinaActual,
        tv,
      } satisfies JwtPayload);
      respuesta.token = token;
    }

    return respuesta;
  }

  /** Renueva access JWT sin subir token_version (AUTH-FLOW-01). */
  async refresh(jwt: JwtPayload) {
    if (jwt.rol === 'domiciliario_independiente') {
      const dom = await this.database.consultarUno<{
        id: string;
        nombre: string;
        email: string;
        ciudad_id: string | null;
        estado_cuenta: string;
        token_version: number;
      }>(
        `SELECT id, nombre, email, ciudad_id, estado_cuenta,
                COALESCE(token_version, 1) AS token_version
         FROM domiciliarios_independientes WHERE id = $1`,
        [jwt.sub],
      );
      if (!dom || dom.estado_cuenta !== 'activo') {
        throw new UnauthorizedException('Domiciliario inactivo');
      }
      const tv = Number(dom.token_version);
      if (Number(jwt.tv ?? 1) !== tv) {
        throw new UnauthorizedException({
          error: 'SESION_REVOCADA',
          message: 'Sesión cerrada o invalidada. Vuelve a iniciar sesión.',
        });
      }
      const permisos = ['domiciliario_independiente'];
      const token = await this.jwtService.signAsync({
        sub: dom.id,
        email: dom.email,
        rol: 'domiciliario_independiente',
        sucursal_id: null,
        restaurante_id: null,
        permisos,
        ciudad_id: dom.ciudad_id,
        tv,
      } satisfies JwtPayload);
      return {
        token,
        dashboard: 'domiciliario_independiente',
        rol: 'domiciliario_independiente',
        permisos,
        estado_cuenta: dom.estado_cuenta,
        realtime_canales: {
          domiciliario_indep: this.realtime.topicDomiciliarioIndep(dom.id),
        },
        usuario: {
          id: dom.id,
          nombre: dom.nombre,
          email: dom.email,
          ciudad_id: dom.ciudad_id,
        },
      };
    }

    const usuario = await this.database.consultarUno<UsuarioFila>(
      `SELECT id, nombre, email, rol, sucursal_id, restaurante_id, activo, hash_contrasena, cocina_id,
              COALESCE(token_version, 1) AS token_version
       FROM usuarios WHERE id = $1`,
      [jwt.sub],
    );
    if (!usuario?.activo) {
      throw new UnauthorizedException('Usuario inactivo');
    }
    if (Number(jwt.tv ?? 1) !== Number(usuario.token_version)) {
      throw new UnauthorizedException({
        error: 'SESION_REVOCADA',
        message: 'Sesión cerrada o invalidada. Vuelve a iniciar sesión.',
      });
    }
    return this.emitirSesionStaff(usuario);
  }

  /** Invalida JWTs actuales subiendo token_version (AUTH-FLOW-02 / AUTH-REV). */
  async logout(jwt: JwtPayload) {
    if (jwt.rol === 'domiciliario_independiente') {
      await this.database.consultar(
        `UPDATE domiciliarios_independientes
         SET token_version = COALESCE(token_version, 1) + 1
         WHERE id = $1`,
        [jwt.sub],
      );
    } else {
      await this.database.consultar(
        `UPDATE usuarios
         SET token_version = COALESCE(token_version, 1) + 1
         WHERE id = $1`,
        [jwt.sub],
      );
    }
    return { cerrado: true };
  }

  /**
   * Topics realtime para la sesión (login/refresh ya los traen).
   * Query `sucursal_id` al cambiar de sede (gerente_cadena / multi-sucursal).
   */
  async realtimeCanales(
    jwt: JwtPayload,
    sucursalIdQuery?: string,
    cocinaIdQuery?: string,
  ) {
    if (jwt.rol === 'domiciliario_independiente') {
      return {
        realtime_canales: {
          domiciliario_indep: this.realtime.topicDomiciliarioIndep(jwt.sub),
        },
      };
    }

    const usuario = await this.database.consultarUno<UsuarioFila>(
      `SELECT id, nombre, email, rol, sucursal_id, restaurante_id, activo, hash_contrasena, cocina_id,
              COALESCE(token_version, 1) AS token_version
       FROM usuarios WHERE id = $1`,
      [jwt.sub],
    );
    if (!usuario?.activo) {
      throw new UnauthorizedException('Usuario inactivo');
    }

    let sucursalOverride: string | null | undefined = undefined;
    if (sucursalIdQuery) {
      if (usuario.sucursal_id && usuario.sucursal_id !== sucursalIdQuery) {
        // Misma cadena: sede hermana del restaurante
        const ok = await this.database.consultarUno<{ id: string }>(
          `SELECT s.id FROM sucursales s
           WHERE s.id = $1 AND s.restaurante_id = $2 AND s.activa = true`,
          [sucursalIdQuery, usuario.restaurante_id],
        );
        if (!ok) {
          throw new UnauthorizedException('Sucursal no permitida');
        }
      } else if (!usuario.sucursal_id) {
        const ok = await this.database.consultarUno<{ id: string }>(
          `SELECT s.id FROM sucursales s
           WHERE s.id = $1 AND s.restaurante_id = $2 AND s.activa = true`,
          [sucursalIdQuery, usuario.restaurante_id],
        );
        if (!ok && jwt.rol !== 'super_admin') {
          throw new UnauthorizedException('Sucursal no permitida');
        }
      }
      sucursalOverride = sucursalIdQuery;
    }

    const canales = this.canalesRealtimeParaUsuario(usuario, sucursalOverride);
    if (cocinaIdQuery) {
      const permisos = await this.permisosEfectivos(usuario.id, usuario.rol);
      if (!permisos.includes('ver_cocina')) {
        throw new ForbiddenException('No tienes permiso para ver cocina');
      }

      if (esRolCocina(usuario.rol) && usuario.cocina_id !== cocinaIdQuery) {
        throw new ForbiddenException('No puedes acceder a otra cocina');
      }

      const sucursalId = sucursalOverride ?? usuario.sucursal_id;
      if (!sucursalId) {
        throw new ForbiddenException(
          'Selecciona una sucursal autorizada para abrir cocina',
        );
      }
      const cocina = await this.database.consultarUno<{ id: string }>(
        `SELECT id FROM cocinas
         WHERE id = $1 AND sucursal_id = $2 AND activa = true`,
        [cocinaIdQuery, sucursalId],
      );
      if (!cocina) {
        throw new ForbiddenException(
          'La cocina no pertenece a la sucursal autorizada',
        );
      }
      canales.cocina = this.realtime.topicCocina(cocinaIdQuery);
    }

    return { realtime_canales: canales };
  }

  async resumenSuscripcion(restauranteId: string | null | undefined) {
    if (!restauranteId) return null;

    const fila = await this.database.consultarUno<{
      estado: string;
      plan: string;
      fecha_vencimiento: Date;
    }>(
      `SELECT estado, plan, fecha_vencimiento
       FROM suscripciones_restaurante
       WHERE restaurante_id = $1
       LIMIT 1`,
      [restauranteId],
    );
    if (!fila) return null;

    const venceMs = new Date(fila.fecha_vencimiento).getTime();
    const diasRestantes = Math.ceil((venceMs - Date.now()) / 86_400_000);

    let nivelAviso: 'ok' | 'proximo' | 'hoy' | 'vencida' | 'bloqueada' = 'ok';
    if (fila.plan === 'gratis') {
      nivelAviso = 'ok';
    } else if (fila.estado === 'bloqueada') {
      nivelAviso = 'bloqueada';
    } else if (fila.estado === 'vencida') {
      nivelAviso = 'vencida';
    } else if (diasRestantes <= 0) {
      nivelAviso = 'hoy';
    } else if (diasRestantes <= 3) {
      nivelAviso = 'proximo';
    }

    return {
      estado: fila.estado,
      plan: fila.plan,
      fecha_vencimiento: fila.fecha_vencimiento,
      dias_restantes: diasRestantes,
      nivel_aviso: nivelAviso,
      mostrar_banner:
        fila.plan !== 'gratis' &&
        ['proximo', 'hoy', 'vencida', 'bloqueada'].includes(nivelAviso),
    };
  }

  /** Plantilla del rol (sin overrides de usuario). */
  async permisosDelRol(rol: string): Promise<string[]> {
    if (rol === 'domiciliario_independiente') {
      return ['domiciliario_independiente'];
    }
    // Roles de cocina son dinámicos (cocina_asados, cocina_bebidas...).
    // No viven en roles_permisos; se les concede acceso al KDS de su sucursal.
    if (esRolCocina(rol)) {
      return ['ver_cocina'];
    }
    const filas = await this.database.consultar<{ permiso: string }>(
      `SELECT permiso FROM roles_permisos WHERE rol = $1 ORDER BY permiso`,
      [rol],
    );
    return filas.map((f) => f.permiso);
  }

  /**
   * Permisos vigentes: filas en `usuario_permisos` si existen;
   * si no, plantilla del rol. Usado en login y en cada request JWT.
   */
  async permisosEfectivos(usuarioId: string, rol: string): Promise<string[]> {
    if (rol === 'domiciliario_independiente') {
      return ['domiciliario_independiente'];
    }
    const custom = await this.database.consultar<{ permiso: string }>(
      `SELECT permiso FROM usuario_permisos WHERE usuario_id = $1 ORDER BY permiso`,
      [usuarioId],
    );
    if (custom.length > 0) {
      return custom.map((f) => f.permiso);
    }
    return this.permisosDelRol(rol);
  }

  async tienePermisosPersonalizados(usuarioId: string): Promise<boolean> {
    const fila = await this.database.consultarUno<{ n: number }>(
      `SELECT COUNT(*)::int AS n FROM usuario_permisos WHERE usuario_id = $1`,
      [usuarioId],
    );
    return (fila?.n ?? 0) > 0;
  }

  /** Lista canónica de permisos asignables al staff (whitelist). */
  async catalogoPermisosDisponibles(): Promise<string[]> {
    const filas = await this.database.consultar<{ permiso: string }>(
      `SELECT DISTINCT permiso FROM roles_permisos ORDER BY permiso`,
    );
    return filas.map((f) => f.permiso);
  }

  /**
   * Reemplaza overrides del usuario.
   * `null` / omitido vía caller = no tocar.
   * Array vacío no se permite (usar al menos un permiso o borrar custom).
   * Si el set coincide con la plantilla del rol, se borran overrides (vuelve al rol).
   */
  async reemplazarPermisosUsuario(
    usuarioId: string,
    rol: string,
    permisos: string[],
    client?: import('pg').PoolClient,
  ): Promise<string[]> {
    const unicos = [
      ...new Set(permisos.map((p) => p.trim()).filter(Boolean)),
    ].sort();
    if (unicos.length === 0) {
      throw new BadRequestException('Debes marcar al menos un permiso');
    }
    const plantilla = [...(await this.permisosDelRol(rol))].sort();
    const permitidos = new Set(plantilla);
    const invalidos = unicos.filter((p) => !permitidos.has(p));
    if (invalidos.length) {
      throw new BadRequestException(
        `Esos permisos no aplican al rol ${rol}: ${invalidos.slice(0, 5).join(', ')}`,
      );
    }

    const igualPlantilla =
      unicos.length === plantilla.length &&
      unicos.every((p, i) => p === plantilla[i]);

    const run = async (c: import('pg').PoolClient) => {
      await c.query(`DELETE FROM usuario_permisos WHERE usuario_id = $1`, [
        usuarioId,
      ]);
      if (igualPlantilla) {
        return plantilla;
      }
      for (const permiso of unicos) {
        await c.query(
          `INSERT INTO usuario_permisos (usuario_id, permiso) VALUES ($1, $2)`,
          [usuarioId, permiso],
        );
      }
      return unicos;
    };

    if (client) {
      return run(client);
    }
    return this.database.enTransaccion((c) => run(c));
  }

  private resolverDashboard(rol: string): string {
    if (rol === 'super_admin') return 'foody_control';
    if (rol === 'domiciliario_planta') return 'domiciliario';
    if (rol === 'cajero') return 'cajero';
    if (rol === 'mesero') return 'mesero';
    if (esRolCocina(rol)) return 'cocina';
    return 'restaurante';
  }

  async registrarFcm(
    usuario: JwtPayload,
    fcmToken: string,
    plataforma?: string,
  ) {
    const token = fcmToken?.trim();
    if (!token) {
      throw new BadRequestException('fcm_token es requerido');
    }
    const plat = plataforma?.trim() || 'android';

    if (usuario.rol === 'domiciliario_independiente') {
      await this.database.consultar(
        `UPDATE tokens_push_domiciliario SET activo = false
         WHERE domiciliario_id = $1 AND fcm_token <> $2`,
        [usuario.sub, token],
      );
      const existente = await this.database.consultarUno<{ id: string }>(
        `SELECT id FROM tokens_push_domiciliario
         WHERE domiciliario_id = $1 AND fcm_token = $2`,
        [usuario.sub, token],
      );
      if (existente) {
        await this.database.consultar(
          `UPDATE tokens_push_domiciliario
           SET activo = true, plataforma = $2, updated_at = now()
           WHERE id = $1`,
          [existente.id, plat],
        );
      } else {
        await this.database.consultar(
          `INSERT INTO tokens_push_domiciliario (domiciliario_id, fcm_token, plataforma, activo)
           VALUES ($1, $2, $3, true)`,
          [usuario.sub, token, plat],
        );
      }
      return { registrado: true, tipo: 'domiciliario' };
    }

    await this.database.consultar(
      `UPDATE tokens_push_admin SET activo = false
       WHERE usuario_id = $1 AND fcm_token <> $2`,
      [usuario.sub, token],
    );

    const existente = await this.database.consultarUno<{ id: string }>(
      `SELECT id FROM tokens_push_admin
       WHERE usuario_id = $1 AND fcm_token = $2`,
      [usuario.sub, token],
    );

    if (existente) {
      await this.database.consultar(
        `UPDATE tokens_push_admin
         SET activo = true, plataforma = $2, updated_at = now()
         WHERE id = $1`,
        [existente.id, plat],
      );
    } else {
      await this.database.consultar(
        `INSERT INTO tokens_push_admin (usuario_id, fcm_token, plataforma, activo)
         VALUES ($1, $2, $3, true)`,
        [usuario.sub, token, plat],
      );
    }

    return { registrado: true, tipo: 'staff' };
  }

  async desactivarFcm(usuario: JwtPayload, fcmToken?: string) {
    const token = fcmToken?.trim();

    if (usuario.rol === 'domiciliario_independiente') {
      if (token) {
        await this.database.consultar(
          `UPDATE tokens_push_domiciliario SET activo = false
           WHERE domiciliario_id = $1 AND fcm_token = $2`,
          [usuario.sub, token],
        );
      } else {
        await this.database.consultar(
          `UPDATE tokens_push_domiciliario SET activo = false
           WHERE domiciliario_id = $1`,
          [usuario.sub],
        );
      }
      return { desactivado: true, tipo: 'domiciliario' };
    }

    if (token) {
      await this.database.consultar(
        `UPDATE tokens_push_admin SET activo = false
         WHERE usuario_id = $1 AND fcm_token = $2`,
        [usuario.sub, token],
      );
    } else {
      await this.database.consultar(
        `UPDATE tokens_push_admin SET activo = false WHERE usuario_id = $1`,
        [usuario.sub],
      );
    }
    return { desactivado: true, tipo: 'staff' };
  }
}
