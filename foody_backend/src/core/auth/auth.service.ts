import {
  Injectable,
  UnauthorizedException,
  BadRequestException,
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

interface UsuarioFila {
  id: string;
  nombre: string;
  email: string;
  rol: string;
  sucursal_id: string | null;
  restaurante_id: string | null;
  activo: boolean;
  hash_contrasena: string | null;
}

@Injectable()
export class AuthService {
  constructor(
    private readonly database: DatabaseService,
    private readonly jwtService: JwtService,
    private readonly planFeatures: PlanFeaturesService,
    private readonly onboarding: OnboardingRestauranteService,
    private readonly supabaseAuth: SupabaseAuthService,
  ) {}

  async login(email: string, contrasena: string) {
    const usuario = await this.database.consultarUno<UsuarioFila>(
      `SELECT id, nombre, email, rol, sucursal_id, restaurante_id, activo, hash_contrasena
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
    const supabaseUser = await this.supabaseAuth.usuarioDesdeAccessToken(
      accessToken,
    );
    const email = supabaseUser.email!.trim().toLowerCase();

    const usuario = await this.database.consultarUno<UsuarioFila>(
      `SELECT id, nombre, email, rol, sucursal_id, restaurante_id, activo, hash_contrasena
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

  async registrarRestaurante(dto: RegistroRestauranteDto) {
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
        throw new BadRequestException('La contraseña debe tener al menos 6 caracteres');
      }
      hash = await bcrypt.hash(dto.contrasena, 10);
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
      `SELECT id, nombre, email, rol, sucursal_id, restaurante_id, activo, hash_contrasena
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
      mensaje: '¡Bienvenido a Foody! Tu restaurante está listo con el plan gratis.',
    };
  }

  private async emitirSesionStaff(usuario: UsuarioFila) {
    const permisos = await this.permisosDelRol(usuario.rol);
    const dashboard = this.resolverDashboard(usuario.rol);
    const plan = await this.planFeatures.obtenerPlanRestaurante(
      usuario.restaurante_id,
    );
    const modulos = this.planFeatures.modulosDelPlan(plan);

    const payload: JwtPayload = {
      sub: usuario.id,
      email: usuario.email,
      rol: usuario.rol,
      sucursal_id: usuario.sucursal_id,
      restaurante_id: usuario.restaurante_id,
      permisos,
      plan,
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
      usuario: {
        id: usuario.id,
        nombre: usuario.nombre,
        email: usuario.email,
        sucursal_id: usuario.sucursal_id,
        restaurante_id: usuario.restaurante_id,
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
    }>(
      `SELECT id, nombre, email, ciudad_id, estado_cuenta, hash_contrasena
       FROM domiciliarios_independientes WHERE LOWER(email) = LOWER($1)`,
      [email.trim()],
    );

    if (!dom || dom.estado_cuenta !== 'activo') {
      throw new UnauthorizedException('Credenciales inválidas');
    }
    if (!dom.hash_contrasena) {
      throw new UnauthorizedException('Cuenta sin contraseña configurada');
    }

    const valida = await bcrypt.compare(contrasena, dom.hash_contrasena);
    if (!valida) {
      throw new UnauthorizedException('Credenciales inválidas');
    }

    const permisos = ['domiciliario_independiente'];
    const payload: JwtPayload = {
      sub: dom.id,
      email: dom.email,
      rol: 'domiciliario_independiente',
      sucursal_id: null,
      restaurante_id: null,
      permisos,
      ciudad_id: dom.ciudad_id,
    };

    const token = await this.jwtService.signAsync(payload);

    return {
      token,
      dashboard: 'domiciliario_independiente',
      rol: 'domiciliario_independiente',
      permisos,
      usuario: {
        id: dom.id,
        nombre: dom.nombre,
        email: dom.email,
        ciudad_id: dom.ciudad_id,
      },
    };
  }

  async registrarDomiciliarioIndependiente(dto: RegistroDomiciliarioDto) {
    const existe = await this.database.consultarUno<{ id: string }>(
      `SELECT id FROM domiciliarios_independientes WHERE LOWER(email) = LOWER($1)`,
      [dto.email.trim()],
    );
    if (existe) {
      throw new BadRequestException('Ya existe una cuenta con ese correo');
    }

    const hash = await bcrypt.hash(dto.contrasena, 10);
    const fila = await this.database.consultarUno<{
      id: string;
      nombre: string;
      email: string;
      estado_cuenta: string;
    }>(
      `INSERT INTO domiciliarios_independientes (
         nombre, email, telefono, tipo_vehiculo, placa, ciudad_id,
         hash_contrasena, estado_cuenta
       ) VALUES ($1, $2, $3, $4, $5, $6, $7, 'pendiente_verificacion')
       RETURNING id, nombre, email, estado_cuenta`,
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

    return {
      id: fila!.id,
      mensaje:
        'Registro recibido. Un administrador revisará tu cuenta antes de activarla.',
      estado_cuenta: fila!.estado_cuenta,
    };
  }

  async perfil(jwt: JwtPayload) {
    const usuario = await this.database.consultarUno<UsuarioFila>(
      `SELECT id, nombre, email, rol, sucursal_id, restaurante_id, activo
       FROM usuarios WHERE id = $1`,
      [jwt.sub],
    );
    if (!usuario?.activo) {
      throw new UnauthorizedException('Usuario no encontrado');
    }
    const permisos = await this.permisosDelRol(usuario.rol);
    const plan = await this.planFeatures.obtenerPlanRestaurante(
      usuario.restaurante_id,
    );
    const modulos = this.planFeatures.modulosDelPlan(plan);
    const suscripcion = await this.resumenSuscripcion(usuario.restaurante_id);

    const planJwt = jwt.plan ?? 'basico';
    const permisosJwt = [...(jwt.permisos ?? [])].sort().join(',');
    const permisosActuales = [...permisos].sort().join(',');
    const necesitaTokenNuevo = planJwt !== plan || permisosJwt !== permisosActuales;

    const respuesta: Record<string, unknown> = {
      usuario: {
        id: usuario.id,
        nombre: usuario.nombre,
        email: usuario.email,
        sucursal_id: usuario.sucursal_id,
        restaurante_id: usuario.restaurante_id,
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
      } satisfies JwtPayload);
      respuesta.token = token;
    }

    return respuesta;
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

  /** Permisos vigentes en BD (usado en login y en cada request JWT). */
  async permisosDelRol(rol: string): Promise<string[]> {
    if (rol === 'domiciliario_independiente') {
      return ['domiciliario_independiente'];
    }
    // Roles de cocina son dinámicos (cocina_asados, cocina_bebidas...).
    // No están en roles_permisos; se les concede acceso al KDS de su sucursal.
    if (this.esRolCocina(rol)) {
      return ['ver_cocina'];
    }
    const filas = await this.database.consultar<{ permiso: string }>(
      `SELECT permiso FROM roles_permisos WHERE rol = $1 ORDER BY permiso`,
      [rol],
    );
    return filas.map((f) => f.permiso);
  }

  private esRolCocina(rol: string): boolean {
    return rol === 'cocina' || rol.startsWith('cocina_');
  }

  private resolverDashboard(rol: string): string {
    if (rol === 'super_admin') return 'foody_control';
    if (rol === 'domiciliario_planta') return 'domiciliario';
    if (rol === 'cajero') return 'cajero';
    if (rol === 'mesero') return 'mesero';
    if (this.esRolCocina(rol)) return 'cocina';
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
