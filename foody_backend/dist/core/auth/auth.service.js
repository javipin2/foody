"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.AuthService = void 0;
const common_1 = require("@nestjs/common");
const jwt_1 = require("@nestjs/jwt");
const bcrypt = __importStar(require("bcrypt"));
const database_service_1 = require("../database/database.service");
const plan_features_service_1 = require("./plan-features.service");
const onboarding_restaurante_service_1 = require("../onboarding/onboarding-restaurante.service");
const supabase_auth_service_1 = require("./supabase-auth.service");
let AuthService = class AuthService {
    database;
    jwtService;
    planFeatures;
    onboarding;
    supabaseAuth;
    constructor(database, jwtService, planFeatures, onboarding, supabaseAuth) {
        this.database = database;
        this.jwtService = jwtService;
        this.planFeatures = planFeatures;
        this.onboarding = onboarding;
        this.supabaseAuth = supabaseAuth;
    }
    async login(email, contrasena) {
        const usuario = await this.database.consultarUno(`SELECT id, nombre, email, rol, sucursal_id, restaurante_id, activo, hash_contrasena
       FROM usuarios WHERE LOWER(email) = LOWER($1)`, [email.trim()]);
        if (!usuario?.activo) {
            throw new common_1.UnauthorizedException('Credenciales inválidas');
        }
        if (!usuario.hash_contrasena) {
            throw new common_1.UnauthorizedException('Esta cuenta usa Google. Inicia sesión con Google.');
        }
        const valida = await bcrypt.compare(contrasena, usuario.hash_contrasena);
        if (!valida) {
            throw new common_1.UnauthorizedException('Credenciales inválidas');
        }
        return this.emitirSesionStaff(usuario);
    }
    async loginGoogle(accessToken) {
        const supabaseUser = await this.supabaseAuth.usuarioDesdeAccessToken(accessToken);
        const email = supabaseUser.email.trim().toLowerCase();
        const usuario = await this.database.consultarUno(`SELECT id, nombre, email, rol, sucursal_id, restaurante_id, activo, hash_contrasena
       FROM usuarios WHERE LOWER(email) = $1`, [email]);
        if (!usuario) {
            return {
                necesita_registro: true,
                email,
                nombre: supabaseUser.user_metadata?.full_name ??
                    supabaseUser.user_metadata?.name ??
                    email.split('@')[0],
                proveedor_id: supabaseUser.id,
            };
        }
        if (!usuario.activo) {
            throw new common_1.UnauthorizedException('Cuenta desactivada');
        }
        await this.database.consultar(`UPDATE usuarios SET
         proveedor_auth = 'google',
         proveedor_id = COALESCE(proveedor_id, $2),
         email_verificado = true,
         ultimo_acceso = now()
       WHERE id = $1`, [usuario.id, supabaseUser.id]);
        return this.emitirSesionStaff(usuario);
    }
    async registrarRestaurante(dto) {
        const proveedor = dto.proveedor_auth ?? 'correo';
        let email = dto.admin_email.trim().toLowerCase();
        let proveedorId = null;
        let hash = null;
        if (proveedor === 'google' || dto.supabase_access_token) {
            const supabaseUser = await this.supabaseAuth.usuarioDesdeAccessToken(dto.supabase_access_token);
            email = supabaseUser.email.trim().toLowerCase();
            proveedorId = supabaseUser.id;
            if (dto.admin_email.trim().toLowerCase() !== email) {
                throw new common_1.BadRequestException('El correo no coincide con la cuenta de Google');
            }
        }
        else {
            if (!dto.contrasena || dto.contrasena.length < 6) {
                throw new common_1.BadRequestException('La contraseña debe tener al menos 6 caracteres');
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
        const usuario = await this.database.consultarUno(`SELECT id, nombre, email, rol, sucursal_id, restaurante_id, activo, hash_contrasena
       FROM usuarios WHERE id = $1`, [onboarding.admin_id]);
        if (!usuario) {
            throw new common_1.BadRequestException('Error al crear la cuenta');
        }
        const sesion = await this.emitirSesionStaff(usuario);
        return {
            ...sesion,
            onboarding,
            mensaje: '¡Bienvenido a Foody! Tu restaurante está listo con el plan gratis.',
        };
    }
    async emitirSesionStaff(usuario) {
        const permisos = await this.permisosDelRol(usuario.rol);
        const dashboard = this.resolverDashboard(usuario.rol);
        const plan = await this.planFeatures.obtenerPlanRestaurante(usuario.restaurante_id);
        const modulos = this.planFeatures.modulosDelPlan(plan);
        const payload = {
            sub: usuario.id,
            email: usuario.email,
            rol: usuario.rol,
            sucursal_id: usuario.sucursal_id,
            restaurante_id: usuario.restaurante_id,
            permisos,
            plan,
        };
        const token = await this.jwtService.signAsync(payload);
        await this.database.consultar(`UPDATE usuarios SET ultimo_acceso = now() WHERE id = $1`, [usuario.id]);
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
    async loginDomiciliarioIndependiente(email, contrasena) {
        const dom = await this.database.consultarUno(`SELECT id, nombre, email, ciudad_id, estado_cuenta, hash_contrasena
       FROM domiciliarios_independientes WHERE LOWER(email) = LOWER($1)`, [email.trim()]);
        if (!dom || dom.estado_cuenta !== 'activo') {
            throw new common_1.UnauthorizedException('Credenciales inválidas');
        }
        if (!dom.hash_contrasena) {
            throw new common_1.UnauthorizedException('Cuenta sin contraseña configurada');
        }
        const valida = await bcrypt.compare(contrasena, dom.hash_contrasena);
        if (!valida) {
            throw new common_1.UnauthorizedException('Credenciales inválidas');
        }
        const permisos = ['domiciliario_independiente'];
        const payload = {
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
    async registrarDomiciliarioIndependiente(dto) {
        const existe = await this.database.consultarUno(`SELECT id FROM domiciliarios_independientes WHERE LOWER(email) = LOWER($1)`, [dto.email.trim()]);
        if (existe) {
            throw new common_1.BadRequestException('Ya existe una cuenta con ese correo');
        }
        const hash = await bcrypt.hash(dto.contrasena, 10);
        const fila = await this.database.consultarUno(`INSERT INTO domiciliarios_independientes (
         nombre, email, telefono, tipo_vehiculo, placa, ciudad_id,
         hash_contrasena, estado_cuenta
       ) VALUES ($1, $2, $3, $4, $5, $6, $7, 'pendiente_verificacion')
       RETURNING id, nombre, email, estado_cuenta`, [
            dto.nombre.trim(),
            dto.email.trim().toLowerCase(),
            dto.telefono?.trim() ?? null,
            dto.tipo_vehiculo?.trim() ?? null,
            dto.placa?.trim() ?? null,
            dto.ciudad_id ?? null,
            hash,
        ]);
        return {
            id: fila.id,
            mensaje: 'Registro recibido. Un administrador revisará tu cuenta antes de activarla.',
            estado_cuenta: fila.estado_cuenta,
        };
    }
    async perfil(jwt) {
        const usuario = await this.database.consultarUno(`SELECT id, nombre, email, rol, sucursal_id, restaurante_id, activo
       FROM usuarios WHERE id = $1`, [jwt.sub]);
        if (!usuario?.activo) {
            throw new common_1.UnauthorizedException('Usuario no encontrado');
        }
        const permisos = await this.permisosDelRol(usuario.rol);
        const plan = await this.planFeatures.obtenerPlanRestaurante(usuario.restaurante_id);
        const modulos = this.planFeatures.modulosDelPlan(plan);
        const suscripcion = await this.resumenSuscripcion(usuario.restaurante_id);
        const planJwt = jwt.plan ?? 'basico';
        const permisosJwt = [...(jwt.permisos ?? [])].sort().join(',');
        const permisosActuales = [...permisos].sort().join(',');
        const necesitaTokenNuevo = planJwt !== plan || permisosJwt !== permisosActuales;
        const respuesta = {
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
            });
            respuesta.token = token;
        }
        return respuesta;
    }
    async resumenSuscripcion(restauranteId) {
        if (!restauranteId)
            return null;
        const fila = await this.database.consultarUno(`SELECT estado, plan, fecha_vencimiento
       FROM suscripciones_restaurante
       WHERE restaurante_id = $1
       LIMIT 1`, [restauranteId]);
        if (!fila)
            return null;
        const venceMs = new Date(fila.fecha_vencimiento).getTime();
        const diasRestantes = Math.ceil((venceMs - Date.now()) / 86_400_000);
        let nivelAviso = 'ok';
        if (fila.plan === 'gratis') {
            nivelAviso = 'ok';
        }
        else if (fila.estado === 'bloqueada') {
            nivelAviso = 'bloqueada';
        }
        else if (fila.estado === 'vencida') {
            nivelAviso = 'vencida';
        }
        else if (diasRestantes <= 0) {
            nivelAviso = 'hoy';
        }
        else if (diasRestantes <= 3) {
            nivelAviso = 'proximo';
        }
        return {
            estado: fila.estado,
            plan: fila.plan,
            fecha_vencimiento: fila.fecha_vencimiento,
            dias_restantes: diasRestantes,
            nivel_aviso: nivelAviso,
            mostrar_banner: fila.plan !== 'gratis' &&
                ['proximo', 'hoy', 'vencida', 'bloqueada'].includes(nivelAviso),
        };
    }
    async permisosDelRol(rol) {
        if (rol === 'domiciliario_independiente') {
            return ['domiciliario_independiente'];
        }
        if (this.esRolCocina(rol)) {
            return ['ver_cocina'];
        }
        const filas = await this.database.consultar(`SELECT permiso FROM roles_permisos WHERE rol = $1 ORDER BY permiso`, [rol]);
        return filas.map((f) => f.permiso);
    }
    esRolCocina(rol) {
        return rol === 'cocina' || rol.startsWith('cocina_');
    }
    resolverDashboard(rol) {
        if (rol === 'super_admin')
            return 'foody_control';
        if (rol === 'domiciliario_planta')
            return 'domiciliario';
        if (rol === 'cajero')
            return 'cajero';
        if (rol === 'mesero')
            return 'mesero';
        if (this.esRolCocina(rol))
            return 'cocina';
        return 'restaurante';
    }
    async registrarFcm(usuario, fcmToken, plataforma) {
        const token = fcmToken?.trim();
        if (!token) {
            throw new common_1.BadRequestException('fcm_token es requerido');
        }
        const plat = plataforma?.trim() || 'android';
        if (usuario.rol === 'domiciliario_independiente') {
            await this.database.consultar(`UPDATE tokens_push_domiciliario SET activo = false
         WHERE domiciliario_id = $1 AND fcm_token <> $2`, [usuario.sub, token]);
            const existente = await this.database.consultarUno(`SELECT id FROM tokens_push_domiciliario
         WHERE domiciliario_id = $1 AND fcm_token = $2`, [usuario.sub, token]);
            if (existente) {
                await this.database.consultar(`UPDATE tokens_push_domiciliario
           SET activo = true, plataforma = $2, updated_at = now()
           WHERE id = $1`, [existente.id, plat]);
            }
            else {
                await this.database.consultar(`INSERT INTO tokens_push_domiciliario (domiciliario_id, fcm_token, plataforma, activo)
           VALUES ($1, $2, $3, true)`, [usuario.sub, token, plat]);
            }
            return { registrado: true, tipo: 'domiciliario' };
        }
        await this.database.consultar(`UPDATE tokens_push_admin SET activo = false
       WHERE usuario_id = $1 AND fcm_token <> $2`, [usuario.sub, token]);
        const existente = await this.database.consultarUno(`SELECT id FROM tokens_push_admin
       WHERE usuario_id = $1 AND fcm_token = $2`, [usuario.sub, token]);
        if (existente) {
            await this.database.consultar(`UPDATE tokens_push_admin
         SET activo = true, plataforma = $2, updated_at = now()
         WHERE id = $1`, [existente.id, plat]);
        }
        else {
            await this.database.consultar(`INSERT INTO tokens_push_admin (usuario_id, fcm_token, plataforma, activo)
         VALUES ($1, $2, $3, true)`, [usuario.sub, token, plat]);
        }
        return { registrado: true, tipo: 'staff' };
    }
    async desactivarFcm(usuario, fcmToken) {
        const token = fcmToken?.trim();
        if (usuario.rol === 'domiciliario_independiente') {
            if (token) {
                await this.database.consultar(`UPDATE tokens_push_domiciliario SET activo = false
           WHERE domiciliario_id = $1 AND fcm_token = $2`, [usuario.sub, token]);
            }
            else {
                await this.database.consultar(`UPDATE tokens_push_domiciliario SET activo = false
           WHERE domiciliario_id = $1`, [usuario.sub]);
            }
            return { desactivado: true, tipo: 'domiciliario' };
        }
        if (token) {
            await this.database.consultar(`UPDATE tokens_push_admin SET activo = false
         WHERE usuario_id = $1 AND fcm_token = $2`, [usuario.sub, token]);
        }
        else {
            await this.database.consultar(`UPDATE tokens_push_admin SET activo = false WHERE usuario_id = $1`, [usuario.sub]);
        }
        return { desactivado: true, tipo: 'staff' };
    }
};
exports.AuthService = AuthService;
exports.AuthService = AuthService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [database_service_1.DatabaseService,
        jwt_1.JwtService,
        plan_features_service_1.PlanFeaturesService,
        onboarding_restaurante_service_1.OnboardingRestauranteService,
        supabase_auth_service_1.SupabaseAuthService])
], AuthService);
//# sourceMappingURL=auth.service.js.map