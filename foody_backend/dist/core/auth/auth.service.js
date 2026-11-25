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
const roles_food_1 = require("./roles-food");
const realtime_broadcast_service_1 = require("../realtime/realtime-broadcast.service");
const registro_antispike_1 = require("./registro-antispike");
let AuthService = class AuthService {
    database;
    jwtService;
    planFeatures;
    onboarding;
    supabaseAuth;
    realtime;
    constructor(database, jwtService, planFeatures, onboarding, supabaseAuth, realtime) {
        this.database = database;
        this.jwtService = jwtService;
        this.planFeatures = planFeatures;
        this.onboarding = onboarding;
        this.supabaseAuth = supabaseAuth;
        this.realtime = realtime;
    }
    canalesRealtimeParaUsuario(usuario, sucursalOverride) {
        const canales = {};
        const sucursalId = sucursalOverride ?? usuario.sucursal_id;
        if (sucursalId) {
            canales.sucursal = this.realtime.topicSucursal(sucursalId);
        }
        if (usuario.restaurante_id) {
            canales.restaurante = this.realtime.topicRestaurante(usuario.restaurante_id);
        }
        if ((0, roles_food_1.esRolCocina)(usuario.rol) && usuario.cocina_id) {
            canales.cocina = this.realtime.topicCocina(usuario.cocina_id);
        }
        if (usuario.rol === 'domiciliario') {
            canales.domiciliario = this.realtime.topicDomiciliarioPlanta(usuario.id);
        }
        return canales;
    }
    async login(email, contrasena) {
        const usuario = await this.database.consultarUno(`SELECT id, nombre, email, rol, sucursal_id, restaurante_id, activo, hash_contrasena, cocina_id,
              COALESCE(token_version, 1) AS token_version
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
        const usuario = await this.database.consultarUno(`SELECT id, nombre, email, rol, sucursal_id, restaurante_id, activo, hash_contrasena, cocina_id,
              COALESCE(token_version, 1) AS token_version
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
    async estadoRegistroRestaurante() {
        const abierto = (0, registro_antispike_1.registroSelfServiceAbierto)();
        const cupo = (0, registro_antispike_1.registroCupoDiario)();
        const maxMin = (0, registro_antispike_1.registroMaxPorMinuto)();
        const usadosHoy = await this.contarSelfServiceHoy();
        const usadosMinuto = await this.contarSelfServiceUltimoMinuto();
        const cupoAgotado = cupo > 0 && usadosHoy >= cupo;
        const minutoAgotado = maxMin > 0 && usadosMinuto >= maxMin;
        const acepta = abierto && !cupoAgotado && !minutoAgotado;
        let mensaje = 'Puedes crear tu restaurante ahora. Empezamos con el plan gratis.';
        if (!abierto) {
            mensaje =
                'El registro está temporalmente cerrado. Déjanos tu interés más tarde o escribe a soporte Foody.';
        }
        else if (cupoAgotado) {
            mensaje =
                'Cupo diario de altas agotado. Vuelve mañana — protegemos a los restaurantes que ya operan.';
        }
        else if (minutoAgotado) {
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
    async contarSelfServiceHoy() {
        const fila = await this.database.consultarUno(`SELECT COUNT(*)::text AS total
       FROM restaurantes
       WHERE origen = 'self_service'
         AND created_at >= (timezone('America/Bogota', now()))::date
             AT TIME ZONE 'America/Bogota'`);
        return Number(fila?.total ?? 0);
    }
    async contarSelfServiceUltimoMinuto() {
        const fila = await this.database.consultarUno(`SELECT COUNT(*)::text AS total
       FROM restaurantes
       WHERE origen = 'self_service'
         AND created_at >= now() - interval '1 minute'`);
        return Number(fila?.total ?? 0);
    }
    async exigirCupoRegistroSelfService() {
        const estado = await this.estadoRegistroRestaurante();
        if (estado.abierto)
            return;
        const codigo = !estado.registro_habilitado
            ? 'REGISTRO_CERRADO'
            : estado.cupo_diario > 0 && estado.usados_hoy >= estado.cupo_diario
                ? 'REGISTRO_CUPO'
                : 'REGISTRO_RATE';
        throw new common_1.HttpException({ error: codigo, mensaje: estado.mensaje }, codigo === 'REGISTRO_RATE'
            ? common_1.HttpStatus.TOO_MANY_REQUESTS
            : common_1.HttpStatus.SERVICE_UNAVAILABLE);
    }
    async registrarRestaurante(dto) {
        await this.exigirCupoRegistroSelfService();
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
            hash = await bcrypt.hash(dto.contrasena, (0, registro_antispike_1.bcryptRoundsRegistro)());
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
        const usuario = await this.database.consultarUno(`SELECT id, nombre, email, rol, sucursal_id, restaurante_id, activo, hash_contrasena,
              COALESCE(token_version, 1) AS token_version
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
        const permisos = await this.permisosEfectivos(usuario.id, usuario.rol);
        const dashboard = this.resolverDashboard(usuario.rol);
        const plan = await this.planFeatures.obtenerPlanRestaurante(usuario.restaurante_id);
        const modulos = this.planFeatures.modulosDelPlan(plan);
        const tv = Number(usuario.token_version ?? 1);
        const payload = {
            sub: usuario.id,
            email: usuario.email,
            rol: usuario.rol,
            sucursal_id: usuario.sucursal_id,
            restaurante_id: usuario.restaurante_id,
            permisos,
            plan,
            cocina_id: (0, roles_food_1.esRolCocina)(usuario.rol) ? (usuario.cocina_id ?? null) : null,
            tv,
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
            realtime_canales: this.canalesRealtimeParaUsuario(usuario),
            usuario: {
                id: usuario.id,
                nombre: usuario.nombre,
                email: usuario.email,
                sucursal_id: usuario.sucursal_id,
                restaurante_id: usuario.restaurante_id,
                cocina_id: (0, roles_food_1.esRolCocina)(usuario.rol)
                    ? (usuario.cocina_id ?? null)
                    : null,
            },
        };
    }
    async loginDomiciliarioIndependiente(email, contrasena) {
        const dom = await this.database.consultarUno(`SELECT id, nombre, email, ciudad_id, estado_cuenta, hash_contrasena,
              COALESCE(token_version, 1) AS token_version
       FROM domiciliarios_independientes WHERE LOWER(email) = LOWER($1)`, [email.trim()]);
        if (!dom || !dom.hash_contrasena) {
            throw new common_1.UnauthorizedException('Credenciales inválidas');
        }
        if (['suspendido', 'bloqueado'].includes(dom.estado_cuenta)) {
            throw new common_1.UnauthorizedException('Tu cuenta está suspendida o bloqueada. Contacta a soporte Foody.');
        }
        const valida = await bcrypt.compare(contrasena, dom.hash_contrasena);
        if (!valida) {
            throw new common_1.UnauthorizedException('Credenciales inválidas');
        }
        const permisos = ['domiciliario_independiente'];
        const tv = Number(dom.token_version ?? 1);
        const payload = {
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
    tokenDomiciliarioIndependiente(dom) {
        const permisos = ['domiciliario_independiente'];
        const payload = {
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
    async registrarDomiciliarioIndependiente(dto) {
        const existe = await this.database.consultarUno(`SELECT id FROM domiciliarios_independientes WHERE LOWER(email) = LOWER($1)`, [dto.email.trim()]);
        if (existe) {
            throw new common_1.BadRequestException('Ya existe una cuenta con ese correo');
        }
        const hash = await bcrypt.hash(dto.contrasena, (0, registro_antispike_1.bcryptRoundsRegistro)());
        const fila = await this.database.consultarUno(`INSERT INTO domiciliarios_independientes (
         nombre, email, telefono, tipo_vehiculo, placa, ciudad_id,
         hash_contrasena, estado_cuenta
       ) VALUES ($1, $2, $3, $4, $5, $6, $7, 'pendiente_verificacion')
       RETURNING id, nombre, email, ciudad_id, estado_cuenta,
                 COALESCE(token_version, 1) AS token_version`, [
            dto.nombre.trim(),
            dto.email.trim().toLowerCase(),
            dto.telefono?.trim() ?? null,
            dto.tipo_vehiculo?.trim() ?? null,
            dto.placa?.trim() ?? null,
            dto.ciudad_id ?? null,
            hash,
        ]);
        const token = await this.tokenDomiciliarioIndependiente(fila);
        return {
            id: fila.id,
            token,
            mensaje: 'Registro recibido. Sube tus documentos para que un administrador active tu cuenta.',
            estado_cuenta: fila.estado_cuenta,
            realtime_canales: {
                domiciliario_indep: this.realtime.topicDomiciliarioIndep(fila.id),
            },
            usuario: {
                id: fila.id,
                nombre: fila.nombre,
                email: fila.email,
                ciudad_id: fila.ciudad_id,
            },
        };
    }
    async perfil(jwt) {
        const usuario = await this.database.consultarUno(`SELECT id, nombre, email, rol, sucursal_id, restaurante_id, activo, cocina_id,
              COALESCE(token_version, 1) AS token_version
       FROM usuarios WHERE id = $1`, [jwt.sub]);
        if (!usuario?.activo) {
            throw new common_1.UnauthorizedException('Usuario no encontrado');
        }
        const permisos = await this.permisosEfectivos(usuario.id, usuario.rol);
        const plan = await this.planFeatures.obtenerPlanRestaurante(usuario.restaurante_id);
        const modulos = this.planFeatures.modulosDelPlan(plan);
        const suscripcion = await this.resumenSuscripcion(usuario.restaurante_id);
        const tv = Number(usuario.token_version ?? 1);
        const planJwt = jwt.plan ?? 'basico';
        const permisosJwt = [...(jwt.permisos ?? [])].sort().join(',');
        const permisosActuales = [...permisos].sort().join(',');
        const cocinaJwt = jwt.cocina_id ?? null;
        const cocinaActual = (0, roles_food_1.esRolCocina)(usuario.rol)
            ? (usuario.cocina_id ?? null)
            : null;
        const tvJwt = Number(jwt.tv ?? 1);
        const necesitaTokenNuevo = planJwt !== plan ||
            permisosJwt !== permisosActuales ||
            cocinaJwt !== cocinaActual ||
            tvJwt !== tv;
        const respuesta = {
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
            });
            respuesta.token = token;
        }
        return respuesta;
    }
    async refresh(jwt) {
        if (jwt.rol === 'domiciliario_independiente') {
            const dom = await this.database.consultarUno(`SELECT id, nombre, email, ciudad_id, estado_cuenta,
                COALESCE(token_version, 1) AS token_version
         FROM domiciliarios_independientes WHERE id = $1`, [jwt.sub]);
            if (!dom || dom.estado_cuenta !== 'activo') {
                throw new common_1.UnauthorizedException('Domiciliario inactivo');
            }
            const tv = Number(dom.token_version);
            if (Number(jwt.tv ?? 1) !== tv) {
                throw new common_1.UnauthorizedException({
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
            });
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
        const usuario = await this.database.consultarUno(`SELECT id, nombre, email, rol, sucursal_id, restaurante_id, activo, hash_contrasena, cocina_id,
              COALESCE(token_version, 1) AS token_version
       FROM usuarios WHERE id = $1`, [jwt.sub]);
        if (!usuario?.activo) {
            throw new common_1.UnauthorizedException('Usuario inactivo');
        }
        if (Number(jwt.tv ?? 1) !== Number(usuario.token_version)) {
            throw new common_1.UnauthorizedException({
                error: 'SESION_REVOCADA',
                message: 'Sesión cerrada o invalidada. Vuelve a iniciar sesión.',
            });
        }
        return this.emitirSesionStaff(usuario);
    }
    async logout(jwt) {
        if (jwt.rol === 'domiciliario_independiente') {
            await this.database.consultar(`UPDATE domiciliarios_independientes
         SET token_version = COALESCE(token_version, 1) + 1
         WHERE id = $1`, [jwt.sub]);
        }
        else {
            await this.database.consultar(`UPDATE usuarios
         SET token_version = COALESCE(token_version, 1) + 1
         WHERE id = $1`, [jwt.sub]);
        }
        return { cerrado: true };
    }
    async realtimeCanales(jwt, sucursalIdQuery, cocinaIdQuery) {
        if (jwt.rol === 'domiciliario_independiente') {
            return {
                realtime_canales: {
                    domiciliario_indep: this.realtime.topicDomiciliarioIndep(jwt.sub),
                },
            };
        }
        const usuario = await this.database.consultarUno(`SELECT id, nombre, email, rol, sucursal_id, restaurante_id, activo, hash_contrasena, cocina_id,
              COALESCE(token_version, 1) AS token_version
       FROM usuarios WHERE id = $1`, [jwt.sub]);
        if (!usuario?.activo) {
            throw new common_1.UnauthorizedException('Usuario inactivo');
        }
        let sucursalOverride = undefined;
        if (sucursalIdQuery) {
            if (usuario.sucursal_id && usuario.sucursal_id !== sucursalIdQuery) {
                const ok = await this.database.consultarUno(`SELECT s.id FROM sucursales s
           WHERE s.id = $1 AND s.restaurante_id = $2 AND s.activa = true`, [sucursalIdQuery, usuario.restaurante_id]);
                if (!ok) {
                    throw new common_1.UnauthorizedException('Sucursal no permitida');
                }
            }
            else if (!usuario.sucursal_id) {
                const ok = await this.database.consultarUno(`SELECT s.id FROM sucursales s
           WHERE s.id = $1 AND s.restaurante_id = $2 AND s.activa = true`, [sucursalIdQuery, usuario.restaurante_id]);
                if (!ok && jwt.rol !== 'super_admin') {
                    throw new common_1.UnauthorizedException('Sucursal no permitida');
                }
            }
            sucursalOverride = sucursalIdQuery;
        }
        const canales = this.canalesRealtimeParaUsuario(usuario, sucursalOverride);
        if (cocinaIdQuery) {
            const permisos = await this.permisosEfectivos(usuario.id, usuario.rol);
            if (!permisos.includes('ver_cocina')) {
                throw new common_1.ForbiddenException('No tienes permiso para ver cocina');
            }
            if ((0, roles_food_1.esRolCocina)(usuario.rol) && usuario.cocina_id !== cocinaIdQuery) {
                throw new common_1.ForbiddenException('No puedes acceder a otra cocina');
            }
            const sucursalId = sucursalOverride ?? usuario.sucursal_id;
            if (!sucursalId) {
                throw new common_1.ForbiddenException('Selecciona una sucursal autorizada para abrir cocina');
            }
            const cocina = await this.database.consultarUno(`SELECT id FROM cocinas
         WHERE id = $1 AND sucursal_id = $2 AND activa = true`, [cocinaIdQuery, sucursalId]);
            if (!cocina) {
                throw new common_1.ForbiddenException('La cocina no pertenece a la sucursal autorizada');
            }
            canales.cocina = this.realtime.topicCocina(cocinaIdQuery);
        }
        return { realtime_canales: canales };
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
        if ((0, roles_food_1.esRolCocina)(rol)) {
            return ['ver_cocina'];
        }
        const filas = await this.database.consultar(`SELECT permiso FROM roles_permisos WHERE rol = $1 ORDER BY permiso`, [rol]);
        return filas.map((f) => f.permiso);
    }
    async permisosEfectivos(usuarioId, rol) {
        if (rol === 'domiciliario_independiente') {
            return ['domiciliario_independiente'];
        }
        const custom = await this.database.consultar(`SELECT permiso FROM usuario_permisos WHERE usuario_id = $1 ORDER BY permiso`, [usuarioId]);
        if (custom.length > 0) {
            return custom.map((f) => f.permiso);
        }
        return this.permisosDelRol(rol);
    }
    async tienePermisosPersonalizados(usuarioId) {
        const fila = await this.database.consultarUno(`SELECT COUNT(*)::int AS n FROM usuario_permisos WHERE usuario_id = $1`, [usuarioId]);
        return (fila?.n ?? 0) > 0;
    }
    async catalogoPermisosDisponibles() {
        const filas = await this.database.consultar(`SELECT DISTINCT permiso FROM roles_permisos ORDER BY permiso`);
        return filas.map((f) => f.permiso);
    }
    async reemplazarPermisosUsuario(usuarioId, rol, permisos, client) {
        const unicos = [
            ...new Set(permisos.map((p) => p.trim()).filter(Boolean)),
        ].sort();
        if (unicos.length === 0) {
            throw new common_1.BadRequestException('Debes marcar al menos un permiso');
        }
        const plantilla = [...(await this.permisosDelRol(rol))].sort();
        const permitidos = new Set(plantilla);
        const invalidos = unicos.filter((p) => !permitidos.has(p));
        if (invalidos.length) {
            throw new common_1.BadRequestException(`Esos permisos no aplican al rol ${rol}: ${invalidos.slice(0, 5).join(', ')}`);
        }
        const igualPlantilla = unicos.length === plantilla.length &&
            unicos.every((p, i) => p === plantilla[i]);
        const run = async (c) => {
            await c.query(`DELETE FROM usuario_permisos WHERE usuario_id = $1`, [
                usuarioId,
            ]);
            if (igualPlantilla) {
                return plantilla;
            }
            for (const permiso of unicos) {
                await c.query(`INSERT INTO usuario_permisos (usuario_id, permiso) VALUES ($1, $2)`, [usuarioId, permiso]);
            }
            return unicos;
        };
        if (client) {
            return run(client);
        }
        return this.database.enTransaccion((c) => run(c));
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
        if ((0, roles_food_1.esRolCocina)(rol))
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
        supabase_auth_service_1.SupabaseAuthService,
        realtime_broadcast_service_1.RealtimeBroadcastService])
], AuthService);
//# sourceMappingURL=auth.service.js.map