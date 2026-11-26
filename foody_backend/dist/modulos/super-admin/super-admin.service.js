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
var SuperAdminService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.SuperAdminService = void 0;
const common_1 = require("@nestjs/common");
const bcrypt = __importStar(require("bcrypt"));
const database_service_1 = require("../../core/database/database.service");
const configuracion_global_module_1 = require("../../core/config/configuracion-global.module");
const onboarding_restaurante_service_1 = require("../../core/onboarding/onboarding-restaurante.service");
const ventas_metricas_sql_1 = require("../../compartido/sql/ventas-metricas.sql");
const notificaciones_service_1 = require("../notificaciones/notificaciones.service");
const almacenamiento_service_1 = require("../almacenamiento/almacenamiento.service");
let SuperAdminService = SuperAdminService_1 = class SuperAdminService {
    database;
    onboarding;
    notificaciones;
    configGlobal;
    almacenamiento;
    logger = new common_1.Logger(SuperAdminService_1.name);
    constructor(database, onboarding, notificaciones, configGlobal, almacenamiento) {
        this.database = database;
        this.onboarding = onboarding;
        this.notificaciones = notificaciones;
        this.configGlobal = configGlobal;
        this.almacenamiento = almacenamiento;
    }
    async resumenGlobal() {
        const ciudades = await this.database.consultarUno(`SELECT COUNT(*)::text AS total FROM ciudades WHERE activa = true`);
        const restaurantes = await this.database.consultarUno(`SELECT COUNT(*)::text AS total FROM restaurantes WHERE activo = true`);
        const sucursales = await this.database.consultarUno(`SELECT COUNT(*)::text AS total FROM sucursales WHERE activa = true`);
        const domiciliarios = await this.database.consultarUno(`SELECT COUNT(*)::text AS total FROM domiciliarios_independientes WHERE estado_cuenta = 'activo'`);
        const suscripciones = await this.database.consultar(`SELECT estado, COUNT(*)::int AS total
       FROM suscripciones_restaurante
       GROUP BY estado`);
        return {
            ciudades_activas: Number(ciudades?.total ?? 0),
            restaurantes_activos: Number(restaurantes?.total ?? 0),
            sucursales_activas: Number(sucursales?.total ?? 0),
            domiciliarios_activos: Number(domiciliarios?.total ?? 0),
            suscripciones,
        };
    }
    async crearCiudad(dto) {
        const slug = dto.slug?.trim().toLowerCase() ||
            dto.nombre
                .trim()
                .toLowerCase()
                .normalize('NFD')
                .replace(/[\u0300-\u036f]/g, '')
                .replace(/[^a-z0-9]+/g, '-')
                .replace(/^-|-$/g, '');
        const existe = await this.database.consultarUno(`SELECT id FROM ciudades WHERE slug = $1`, [slug]);
        if (existe) {
            throw new common_1.BadRequestException({
                error: 'SLUG_DUPLICADO',
                message: 'Ya existe una ciudad con ese slug',
            });
        }
        return this.database.consultarUno(`INSERT INTO ciudades (nombre, slug, activa)
       VALUES ($1, $2, true)
       RETURNING id, nombre, slug, activa, created_at`, [dto.nombre.trim(), slug]);
    }
    async actualizarCiudad(id, dto) {
        const ciudad = await this.database.consultarUno(`SELECT id FROM ciudades WHERE id = $1`, [id]);
        if (!ciudad)
            throw new common_1.NotFoundException('Ciudad no encontrada');
        return this.database.consultarUno(`UPDATE ciudades SET
         nombre = COALESCE($2, nombre),
         activa = COALESCE($3, activa)
       WHERE id = $1
       RETURNING id, nombre, slug, activa, created_at`, [id, dto.nombre?.trim() ?? null, dto.activa ?? null]);
    }
    async actualizarRestaurante(id, dto) {
        const restaurante = await this.database.consultarUno(`SELECT id FROM restaurantes WHERE id = $1`, [id]);
        if (!restaurante)
            throw new common_1.NotFoundException('Restaurante no encontrado');
        const actualizado = await this.database.consultarUno(`UPDATE restaurantes SET activo = COALESCE($2, activo)
       WHERE id = $1
       RETURNING id, nombre, activo, ciudad_id`, [id, dto.activo ?? null]);
        if (dto.activo === false) {
            await this.database.consultar(`UPDATE suscripciones_restaurante SET
           estado = 'bloqueada',
           motivo_bloqueo = COALESCE($2, motivo_bloqueo)
         WHERE restaurante_id = $1 AND estado <> 'bloqueada'`, [id, dto.motivo_bloqueo?.trim() ?? 'Bloqueado por super admin']);
        }
        return actualizado;
    }
    async listarCiudades() {
        return this.database.consultar(`SELECT c.id, c.nombre, c.slug, c.activa,
              COUNT(DISTINCT r.id)::int AS restaurantes
       FROM ciudades c
       LEFT JOIN restaurantes r ON r.ciudad_id = c.id AND r.activo = true
       GROUP BY c.id
       ORDER BY c.nombre ASC`);
    }
    async listarRestaurantes() {
        return this.database.consultar(`SELECT r.id, r.nombre, r.activo, c.nombre AS ciudad_nombre,
              s.id AS suscripcion_id,
              s.estado AS suscripcion_estado,
              s.plan AS suscripcion_plan,
              s.fecha_vencimiento,
              (SELECT COUNT(*)::int FROM sucursales su
               WHERE su.restaurante_id = r.id AND su.activa = true) AS sucursales_activas
       FROM restaurantes r
       INNER JOIN ciudades c ON c.id = r.ciudad_id
       LEFT JOIN suscripciones_restaurante s ON s.restaurante_id = r.id
       ORDER BY r.nombre ASC`);
    }
    async listarSucursalesRestaurante(restauranteId) {
        const existe = await this.database.consultarUno(`SELECT id FROM restaurantes WHERE id = $1`, [restauranteId]);
        if (!existe)
            throw new common_1.NotFoundException('Restaurante no encontrado');
        return this.database.consultar(`SELECT id, nombre, direccion, activa, created_at
       FROM sucursales
       WHERE restaurante_id = $1
       ORDER BY created_at ASC`, [restauranteId]);
    }
    async listarSuscripciones() {
        return this.database.consultar(`SELECT s.id, s.restaurante_id, s.estado, s.plan,
              s.fecha_inicio, s.fecha_vencimiento, s.motivo_bloqueo,
              r.nombre AS restaurante_nombre
       FROM suscripciones_restaurante s
       JOIN restaurantes r ON r.id = s.restaurante_id
       ORDER BY s.fecha_vencimiento ASC`);
    }
    async actualizarSuscripcion(id, dto) {
        const actual = await this.database.consultarUno(`SELECT id FROM suscripciones_restaurante WHERE id = $1`, [id]);
        if (!actual)
            throw new common_1.NotFoundException('Suscripción no encontrada');
        return this.database.consultarUno(`UPDATE suscripciones_restaurante SET
         estado = COALESCE($2, estado),
         plan = COALESCE($3, plan),
         fecha_vencimiento = COALESCE($4, fecha_vencimiento)
       WHERE id = $1
       RETURNING *`, [id, dto.estado ?? null, dto.plan ?? null, dto.fecha_vencimiento ?? null]);
    }
    async listarDomiciliarios() {
        return this.database.consultar(`SELECT di.id, di.nombre, di.email, di.telefono,
              di.estado_cuenta, di.calificacion_promedio, di.total_entregas,
              c.nombre AS ciudad_nombre,
              di.created_at
       FROM domiciliarios_independientes di
       LEFT JOIN ciudades c ON c.id = di.ciudad_id
       ORDER BY di.created_at DESC
       LIMIT 200`);
    }
    async actualizarEstadoDomiciliario(id, dto) {
        const dom = await this.database.consultarUno(`SELECT id FROM domiciliarios_independientes WHERE id = $1`, [id]);
        if (!dom)
            throw new common_1.NotFoundException('Domiciliario no encontrado');
        return this.database.consultarUno(`UPDATE domiciliarios_independientes
       SET estado_cuenta = $2
       WHERE id = $1
       RETURNING id, nombre, email, estado_cuenta`, [id, dto.estado_cuenta]);
    }
    async listarConfiguracion() {
        return this.database.consultar(`SELECT clave, valor, descripcion, updated_at
       FROM configuracion_global_foody
       ORDER BY clave ASC`);
    }
    async metricasSelfService() {
        const [registros, pagos30d, pendientes, porPlan] = await Promise.all([
            this.database.consultarUno(`SELECT COUNT(*)::text AS total FROM restaurantes
         WHERE origen = 'self_service' AND activo = true`),
            this.database.consultarUno(`SELECT COUNT(*)::text AS total,
                COALESCE(SUM(monto_centavos), 0)::text AS monto
         FROM pagos_suscripcion
         WHERE estado = 'aprobado'
           AND created_at >= now() - interval '30 days'`),
            this.database.consultarUno(`SELECT COUNT(*)::text AS total FROM pagos_suscripcion
         WHERE estado = 'pendiente'`),
            this.database.consultar(`SELECT plan, COUNT(*)::int AS total
         FROM suscripciones_restaurante
         GROUP BY plan
         ORDER BY total DESC`),
        ]);
        const totalRegistros = Number(registros?.total ?? 0);
        const pagosAprobados = Number(pagos30d?.total ?? 0);
        const conversion = totalRegistros > 0
            ? Math.round((pagosAprobados / totalRegistros) * 1000) / 10
            : 0;
        return {
            registros_self_service: totalRegistros,
            pagos_aprobados_30d: pagosAprobados,
            ingresos_cop_30d: Number(pagos30d?.monto ?? 0) / 100,
            pagos_pendientes: Number(pendientes?.total ?? 0),
            tasa_conversion_pagos_pct: conversion,
            suscripciones_por_plan: porPlan,
        };
    }
    async estadisticas() {
        const pedidosHoy = await this.database.consultarUno(`SELECT COUNT(*)::text AS total FROM pedidos
       WHERE ${ventas_metricas_sql_1.SQL_PEDIDO_ES_HOY}`);
        const ingresosFoody = await this.database.consultarUno(`SELECT COALESCE(SUM(comision_foody), 0)::text AS total
       FROM ganancias_domiciliario
       WHERE ${ventas_metricas_sql_1.SQL_PEDIDO_ES_HOY}`);
        const resumen = await this.resumenGlobal();
        const selfService = await this.metricasSelfService();
        return {
            ...resumen,
            pedidos_hoy: Number(pedidosHoy?.total ?? 0),
            ingresos_foody_hoy: Number(ingresosFoody?.total ?? 0),
            self_service: selfService,
        };
    }
    async actualizarConfiguracion(clave, dto, usuarioId) {
        const fila = await this.database.consultarUno(`SELECT clave FROM configuracion_global_foody WHERE clave = $1`, [clave]);
        if (!fila)
            throw new common_1.NotFoundException('Parámetro no encontrado');
        const actualizado = await this.database.consultarUno(`UPDATE configuracion_global_foody SET
         valor = $2, editado_por = $3, updated_at = now()
       WHERE clave = $1
       RETURNING clave, valor, descripcion, updated_at`, [clave, dto.valor.trim(), usuarioId]);
        await this.configGlobal.recargar();
        return actualizado;
    }
    async crearRestaurante(dto) {
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
        return this.database.consultar(`SELECT u.id, u.nombre, u.email, u.rol, u.activo, u.telefono,
              u.sucursal_id, u.restaurante_id, u.created_at,
              s.nombre AS sucursal_nombre,
              r.nombre AS restaurante_nombre
       FROM usuarios u
       LEFT JOIN sucursales s ON s.id = u.sucursal_id
       LEFT JOIN restaurantes r ON r.id = u.restaurante_id
       WHERE u.rol <> 'super_admin'
       ORDER BY u.created_at DESC
       LIMIT 500`);
    }
    async crearUsuario(dto) {
        const sucursal = await this.database.consultarUno(`SELECT id, restaurante_id FROM sucursales WHERE id = $1 AND activa = true`, [dto.sucursal_id]);
        if (!sucursal)
            throw new common_1.BadRequestException('Sucursal no válida');
        const email = dto.email.trim().toLowerCase();
        const existe = await this.database.consultarUno(`SELECT id FROM usuarios WHERE LOWER(email) = $1`, [email]);
        if (existe)
            throw new common_1.ConflictException('El correo ya está registrado');
        const hash = await bcrypt.hash(dto.contrasena, 10);
        return this.database.enTransaccion(async (client) => {
            const insert = await client.query(`INSERT INTO usuarios (
           id, sucursal_id, restaurante_id, nombre, email, rol, activo, hash_contrasena
         ) VALUES (gen_random_uuid(), $1, $2, $3, $4, $5, true, $6)
         RETURNING id`, [
                dto.sucursal_id,
                sucursal.restaurante_id,
                dto.nombre.trim(),
                email,
                dto.rol,
                hash,
            ]);
            const usuarioId = insert.rows[0].id;
            if (dto.rol === 'domiciliario_planta') {
                await client.query(`INSERT INTO domiciliarios_planta (usuario_id, sucursal_id, activo)
           VALUES ($1, $2, true)`, [usuarioId, dto.sucursal_id]);
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
    async actualizarUsuario(id, dto) {
        const usuario = await this.database.consultarUno(`SELECT id, rol FROM usuarios WHERE id = $1 AND rol <> 'super_admin'`, [
            id,
        ]);
        if (!usuario)
            throw new common_1.NotFoundException('Usuario no encontrado');
        if (dto.email) {
            const dup = await this.database.consultarUno(`SELECT id FROM usuarios WHERE LOWER(email) = LOWER($1) AND id <> $2`, [dto.email.trim(), id]);
            if (dup)
                throw new common_1.ConflictException('El correo ya está en uso');
        }
        return this.database.consultarUno(`UPDATE usuarios SET
         nombre = COALESCE($2, nombre),
         email = COALESCE($3, email),
         rol = COALESCE($4, rol)
       WHERE id = $1
       RETURNING id, nombre, email, rol, activo, sucursal_id, restaurante_id`, [
            id,
            dto.nombre?.trim() ?? null,
            dto.email?.trim().toLowerCase() ?? null,
            dto.rol ?? null,
        ]);
    }
    async cambiarContrasenaUsuario(id, dto) {
        const usuario = await this.database.consultarUno(`SELECT id FROM usuarios WHERE id = $1 AND rol <> 'super_admin'`, [id]);
        if (!usuario)
            throw new common_1.NotFoundException('Usuario no encontrado');
        const hash = await bcrypt.hash(dto.contrasena, 10);
        await this.database.consultar(`UPDATE usuarios
       SET hash_contrasena = $2,
           token_version = COALESCE(token_version, 1) + 1
       WHERE id = $1`, [id, hash]);
        return { id, actualizado: true };
    }
    async cambiarEstadoUsuario(id, dto) {
        const fila = await this.database.consultarUno(`UPDATE usuarios SET activo = $2
       WHERE id = $1 AND rol <> 'super_admin'
       RETURNING id, rol`, [id, dto.activo]);
        if (!fila)
            throw new common_1.NotFoundException('Usuario no encontrado');
        if (fila.rol === 'domiciliario_planta') {
            await this.database.consultar(`UPDATE domiciliarios_planta SET activo = $2 WHERE usuario_id = $1`, [id, dto.activo]);
        }
        return { id, activo: dto.activo };
    }
    async listarDocumentosPendientes() {
        const docs = await this.database.consultar(`SELECT d.id, d.tipo, d.url, d.estado, d.created_at,
              di.id AS domiciliario_id, di.nombre AS domiciliario_nombre,
              di.email AS domiciliario_email, di.telefono, di.tipo_vehiculo,
              di.placa, di.estado_cuenta,
              c.nombre AS ciudad_nombre
       FROM documentos_domiciliario d
       JOIN domiciliarios_independientes di ON di.id = d.domiciliario_id
       LEFT JOIN ciudades c ON c.id = di.ciudad_id
       WHERE d.estado = 'pendiente'
       ORDER BY d.created_at ASC
       LIMIT 200`);
        return Promise.all(docs.map(async (doc) => ({
            ...doc,
            url: await this.almacenamiento.resolverUrlDocumento(doc.url),
        })));
    }
    async listarDocumentosDomiciliario(domiciliarioId) {
        const dom = await this.database.consultarUno(`SELECT id FROM domiciliarios_independientes WHERE id = $1`, [domiciliarioId]);
        if (!dom)
            throw new common_1.NotFoundException('Domiciliario no encontrado');
        const docs = await this.database.consultar(`SELECT id, tipo, url, estado, motivo_rechazo, created_at, revisado_por
       FROM documentos_domiciliario
       WHERE domiciliario_id = $1
       ORDER BY created_at DESC`, [domiciliarioId]);
        return Promise.all(docs.map(async (doc) => ({
            ...doc,
            url: await this.almacenamiento.resolverUrlDocumento(doc.url),
        })));
    }
    async aprobarDocumento(domiciliarioId, dto, revisorId) {
        return this.revisarDocumento(domiciliarioId, dto.documento_id, revisorId, 'aprobado');
    }
    async rechazarDocumento(domiciliarioId, dto, revisorId) {
        return this.revisarDocumento(domiciliarioId, dto.documento_id, revisorId, 'rechazado', dto.motivo.trim());
    }
    async revisarDocumento(domiciliarioId, documentoId, revisorId, estado, motivoRechazo) {
        const doc = await this.database.consultarUno(`SELECT id FROM documentos_domiciliario
       WHERE id = $1 AND domiciliario_id = $2 AND estado = 'pendiente'`, [documentoId, domiciliarioId]);
        if (!doc)
            throw new common_1.NotFoundException('Documento no encontrado o ya revisado');
        await this.database.consultar(`UPDATE documentos_domiciliario SET
         estado = $2,
         motivo_rechazo = $3,
         revisado_por = $4
       WHERE id = $1`, [documentoId, estado, motivoRechazo ?? null, revisorId]);
        if (estado === 'aprobado') {
            const pendientes = await this.database.consultarUno(`SELECT COUNT(*)::int AS n FROM documentos_domiciliario
         WHERE domiciliario_id = $1 AND estado = 'pendiente'`, [domiciliarioId]);
            if ((pendientes?.n ?? 0) === 0) {
                const activado = await this.database.consultarUno(`UPDATE domiciliarios_independientes
           SET estado_cuenta = 'activo'
           WHERE id = $1 AND estado_cuenta = 'pendiente_verificacion'
           RETURNING id`, [domiciliarioId]);
                if (activado) {
                    await this.notificarDomiciliario(domiciliarioId, 'Cuenta activada en Foody', 'Tu documentación fue aprobada. Ya puedes iniciar turno y recibir pedidos.', 'domiciliario_cuenta_activa');
                }
            }
        }
        else if (estado === 'rechazado' && motivoRechazo) {
            await this.notificarDomiciliario(domiciliarioId, 'Documento rechazado', motivoRechazo, 'domiciliario_documento_rechazado');
        }
        return { documento_id: documentoId, estado };
    }
    async notificarDomiciliario(domiciliarioId, titulo, cuerpo, tipo) {
        try {
            await this.notificaciones.enviar({
                tipo,
                titulo,
                cuerpo,
                destinatario_domiciliario_id: domiciliarioId,
                datos: { domiciliario_id: domiciliarioId },
            });
        }
        catch (e) {
            this.logger.warn(`FCM domiciliario ${domiciliarioId}: ${e instanceof Error ? e.message : e}`);
        }
    }
};
exports.SuperAdminService = SuperAdminService;
exports.SuperAdminService = SuperAdminService = SuperAdminService_1 = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [database_service_1.DatabaseService,
        onboarding_restaurante_service_1.OnboardingRestauranteService,
        notificaciones_service_1.NotificacionesService,
        configuracion_global_module_1.ConfiguracionGlobalService,
        almacenamiento_service_1.AlmacenamientoService])
], SuperAdminService);
//# sourceMappingURL=super-admin.service.js.map